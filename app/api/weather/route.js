// app/api/weather/route.js
//
// Proxy to Open-Meteo API for weather forecasts, historical weather, and geocoding.
// No API key required. Supports forecast (up to 16 days), historical weather
// for past dates, and climate context for dates further out.

export async function GET(request) {
  const { searchParams } = new URL(request.url);
  const location = searchParams.get('location');
  const date = searchParams.get('date');

  if (!location) {
    return Response.json({ error: 'location parameter required' }, { status: 400 });
  }

  try {
    // Step 1: Geocode the location string
    const geoRes = await fetch(
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
      const forecastRes = await fetch(
        `https://api.open-meteo.com/v1/forecast?latitude=${latitude}&longitude=${longitude}&daily=temperature_2m_max,temperature_2m_min,apparent_temperature_max,apparent_temperature_min,precipitation_probability_max,windspeed_10m_max,weathercode&timezone=auto&start_date=${date}&end_date=${date}`
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
          windMax: d.windspeed_10m_max[0],
          weatherCode: d.weathercode[0],
          condition: weatherCodeToText(d.weathercode[0]),
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
      const histRes = await fetch(
        `https://archive-api.open-meteo.com/v1/archive?latitude=${latitude}&longitude=${longitude}&daily=temperature_2m_max,temperature_2m_min,apparent_temperature_max,apparent_temperature_min,precipitation_sum,windspeed_10m_max,weathercode&timezone=auto&start_date=${date}&end_date=${date}`
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
          windMax: Math.round(d.windspeed_10m_max[0] * 0.621371),
          weatherCode: d.weathercode[0],
          condition: weatherCodeToText(d.weathercode[0]),
          units: { temp: '°F', wind: 'mph', precip: 'mm' },
        };
      }
    } else if (raceDate) {
      // Too far out for forecast — provide climate context
      weather = {
        type: 'climate',
        message: `Forecast available ${daysOut > 16 ? `in ~${daysOut - 16} days` : 'closer to race day'}`,
        daysUntilForecast: Math.max(0, daysOut - 16),
      };
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
