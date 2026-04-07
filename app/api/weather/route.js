// app/api/weather/route.js
//
// Proxy to Open-Meteo API for weather forecasts, historical weather, and geocoding.
// No API key required. Supports forecast (up to 16 days), historical weather
// for past dates, and climate estimates (5-year ±7 day average) for dates further out.

// Force dynamic rendering and disable Next.js fetch data cache for this route
export const dynamic = 'force-dynamic';
export const fetchCache = 'force-no-store';

async function fetchWithTimeout(url, timeoutMs = 10000) {
  const attempt = async () => {
    const controller = new AbortController();
    const timer = setTimeout(() => controller.abort(), timeoutMs);
    try {
      return await fetch(url, { signal: controller.signal, cache: 'no-store' });
    } finally {
      clearTimeout(timer);
    }
  };
  try {
    return await attempt();
  } catch {
    return await attempt();
  }
}

export async function GET(request) {
  const { searchParams } = new URL(request.url);
  const location = searchParams.get('location');
  const date = searchParams.get('date');

  if (!location) {
    return Response.json({ error: 'location parameter required' }, { status: 400 });
  }

  try {
    // Step 1: Geocode the location string
    const geoRes = await fetchWithTimeout(
      `https://geocoding-api.open-meteo.com/v1/search?name=${encodeURIComponent(location)}&count=1&language=en&format=json`
    );
    if (!geoRes.ok) throw new Error('Geocoding failed');
    const geoData = await geoRes.json();

    if (!geoData.results?.length) {
      return Response.json({ error: 'Location not found', location }, { status: 404 });
    }

    const { latitude, longitude, name, admin1, country } = geoData.results[0];
    const resolvedLocation = [name, admin1, country].filter(Boolean).join(', ');

    // Step 2: Determine if we can get a forecast or need climate averages
    const now = new Date();
    const raceDate = date ? new Date(date + 'T12:00:00') : null;
    const daysOut = raceDate ? Math.ceil((raceDate - now) / 86400000) : null;

    let weather = null;

    if (daysOut !== null && daysOut >= 0 && daysOut <= 16) {
      // Forecast available — use Open-Meteo forecast API
      const forecastRes = await fetchWithTimeout(
        `https://api.open-meteo.com/v1/forecast?latitude=${latitude}&longitude=${longitude}&daily=temperature_2m_max,temperature_2m_min,apparent_temperature_max,apparent_temperature_min,precipitation_probability_max,wind_speed_10m_max,weather_code&timezone=auto&start_date=${date}&end_date=${date}`
      );
      if (!forecastRes.ok) throw new Error('Forecast fetch failed');
      const forecastData = await forecastRes.json();
      const d = forecastData.daily;

      if (d && d.time?.length > 0) {
        weather = {
          type: 'forecast',
          tempHigh: d.temperature_2m_max[0],
          tempLow: d.temperature_2m_min[0],
          feelsLikeHigh: d.apparent_temperature_max[0],
          feelsLikeLow: d.apparent_temperature_min[0],
          precipChance: d.precipitation_probability_max[0],
          windMax: d.wind_speed_10m_max[0],
          weatherCode: d.weather_code[0],
          condition: weatherCodeToText(d.weather_code[0]),
          units: { temp: '°F', wind: 'mph' },
        };

        // Convert from Celsius to Fahrenheit for US-centric display
        weather.tempHigh = cToF(weather.tempHigh);
        weather.tempLow = cToF(weather.tempLow);
        weather.feelsLikeHigh = cToF(weather.feelsLikeHigh);
        weather.feelsLikeLow = cToF(weather.feelsLikeLow);
        // Wind is already in km/h from open-meteo, convert to mph
        weather.windMax = Math.round(weather.windMax * 0.621371);
      }
    } else if (daysOut !== null && daysOut < 0) {
      // Past date — use Open-Meteo historical weather archive API
      const histRes = await fetchWithTimeout(
        `https://archive-api.open-meteo.com/v1/archive?latitude=${latitude}&longitude=${longitude}&daily=temperature_2m_max,temperature_2m_min,apparent_temperature_max,apparent_temperature_min,precipitation_sum,wind_speed_10m_max,weather_code&timezone=auto&start_date=${date}&end_date=${date}`
      );
      if (!histRes.ok) throw new Error('Historical weather fetch failed');
      const histData = await histRes.json();
      const d = histData.daily;

      if (d && d.time?.length > 0) {
        weather = {
          type: 'historical',
          tempHigh: cToF(d.temperature_2m_max[0]),
          tempLow: cToF(d.temperature_2m_min[0]),
          feelsLikeHigh: cToF(d.apparent_temperature_max[0]),
          feelsLikeLow: cToF(d.apparent_temperature_min[0]),
          precipTotal: d.precipitation_sum[0] != null ? Math.round(d.precipitation_sum[0] * 100) / 100 : null,
          windMax: Math.round(d.wind_speed_10m_max[0] * 0.621371),
          weatherCode: d.weather_code[0],
          condition: weatherCodeToText(d.weather_code[0]),
          units: { temp: '°F', wind: 'mph', precip: 'mm' },
        };
      }
    } else if (raceDate) {
      // Too far out for forecast — estimate from 5-year historical average (±7 day window)
      weather = await fetchClimateEstimate(latitude, longitude, raceDate, daysOut);
    }

    return Response.json({
      location: resolvedLocation,
      latitude,
      longitude,
      weather,
      updatedAt: new Date().toISOString(),
    });
  } catch (err) {
    return Response.json(
      { error: 'Weather fetch failed', detail: err.message },
      { status: 500 }
    );
  }
}

async function fetchClimateEstimate(latitude, longitude, raceDate, daysOut) {
  const YEARS_BACK = 5;
  const WINDOW_DAYS = 7; // ±7 days around race date

  // Build date ranges for the last 5 years
  const ranges = [];
  const month = raceDate.getMonth();
  const day = raceDate.getDate();

  for (let y = 1; y <= YEARS_BACK; y++) {
    const targetYear = raceDate.getFullYear() - y;
    // Handle Feb 29 in non-leap years
    let centerDay = day;
    if (month === 1 && day === 29) {
      const isLeap = (targetYear % 4 === 0 && targetYear % 100 !== 0) || targetYear % 400 === 0;
      if (!isLeap) centerDay = 28;
    }
    const center = new Date(targetYear, month, centerDay);
    const start = new Date(center.getTime() - WINDOW_DAYS * 86400000);
    const end = new Date(center.getTime() + WINDOW_DAYS * 86400000);
    // Skip ranges that are in the future (archive data won't exist)
    if (end > new Date()) continue;
    ranges.push({
      start: start.toISOString().slice(0, 10),
      end: end.toISOString().slice(0, 10),
    });
  }

  // Fetch all 5 ranges in parallel
  const results = await Promise.allSettled(
    ranges.map(({ start, end }) =>
      fetchWithTimeout(
        `https://archive-api.open-meteo.com/v1/archive?latitude=${latitude}&longitude=${longitude}&daily=temperature_2m_max,temperature_2m_min,apparent_temperature_max,apparent_temperature_min,precipitation_sum,wind_speed_10m_max,weather_code&timezone=auto&start_date=${start}&end_date=${end}`
      ).then(r => {
        if (!r.ok) throw new Error('Archive fetch failed');
        return r.json();
      })
    )
  );

  // Collect all daily data points from successful fetches
  const allTempMax = [], allTempMin = [], allFeelsHigh = [], allFeelsLow = [];
  const allPrecip = [], allWind = [], allCodes = [];
  let yearsUsed = 0;

  for (const result of results) {
    if (result.status !== 'fulfilled') continue;
    const d = result.value.daily;
    if (!d || !d.time?.length) continue;
    yearsUsed++;
    for (let i = 0; i < d.time.length; i++) {
      if (d.temperature_2m_max[i] != null) allTempMax.push(d.temperature_2m_max[i]);
      if (d.temperature_2m_min[i] != null) allTempMin.push(d.temperature_2m_min[i]);
      if (d.apparent_temperature_max[i] != null) allFeelsHigh.push(d.apparent_temperature_max[i]);
      if (d.apparent_temperature_min[i] != null) allFeelsLow.push(d.apparent_temperature_min[i]);
      if (d.precipitation_sum?.[i] != null) allPrecip.push(d.precipitation_sum[i]);
      if (d.wind_speed_10m_max?.[i] != null) allWind.push(d.wind_speed_10m_max[i]);
      if (d.weather_code?.[i] != null) allCodes.push(d.weather_code[i]);
    }
  }

  // Fallback if no data was retrieved
  if (allTempMax.length === 0) {
    return {
      type: 'climate',
      message: `Forecast available ${daysOut > 16 ? `in ~${daysOut - 16} days` : 'closer to race day'}`,
      daysUntilForecast: Math.max(0, daysOut - 16),
    };
  }

  const avg = arr => arr.length === 0 ? null : arr.reduce((a, b) => a + b, 0) / arr.length;
  const avgTempMax = avg(allTempMax);
  const avgTempMin = avg(allTempMin);

  // Most common weather code
  const codeCounts = {};
  for (const c of allCodes) codeCounts[c] = (codeCounts[c] || 0) + 1;
  const mostCommonCode = Object.keys(codeCounts).length > 0
    ? Number(Object.entries(codeCounts).sort((a, b) => b[1] - a[1])[0][0])
    : 0;

  return {
    type: 'climate',
    tempHigh: cToF(avgTempMax),
    tempLow: cToF(avgTempMin),
    tempHighRange: [cToF(Math.min(...allTempMax)), cToF(Math.max(...allTempMax))],
    feelsLikeHigh: allFeelsHigh.length ? cToF(avg(allFeelsHigh)) : null,
    feelsLikeLow: allFeelsLow.length ? cToF(avg(allFeelsLow)) : null,
    precipTotal: allPrecip.length ? Math.round(avg(allPrecip) * 100) / 100 : null,
    windMax: allWind.length ? Math.round(avg(allWind) * 0.621371) : null,
    weatherCode: mostCommonCode,
    condition: weatherCodeToText(mostCommonCode),
    units: { temp: '°F', wind: 'mph', precip: 'mm' },
    message: `Based on ${yearsUsed}-year average`,
    daysUntilForecast: Math.max(0, daysOut - 16),
    yearsUsed,
    dataPoints: allTempMax.length,
  };
}

function cToF(c) {
  return Math.round(c * 9 / 5 + 32);
}

function weatherCodeToText(code) {
  const map = {
    0: 'Clear sky', 1: 'Mainly clear', 2: 'Partly cloudy', 3: 'Overcast',
    45: 'Foggy', 48: 'Rime fog',
    51: 'Light drizzle', 53: 'Moderate drizzle', 55: 'Dense drizzle',
    61: 'Slight rain', 63: 'Moderate rain', 65: 'Heavy rain',
    71: 'Slight snow', 73: 'Moderate snow', 75: 'Heavy snow',
    80: 'Light showers', 81: 'Moderate showers', 82: 'Violent showers',
    95: 'Thunderstorm', 96: 'Thunderstorm w/ hail', 99: 'Thunderstorm w/ heavy hail',
  };
  return map[code] || 'Unknown';
}
