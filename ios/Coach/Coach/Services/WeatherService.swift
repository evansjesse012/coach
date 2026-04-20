import Foundation

/// Open-Meteo weather service. No API key required.
/// Provides forecast (<=16 days), historical (past), or climate estimates (>16 days).
struct WeatherData: Codable {
    var temperatureHigh: Double?
    var temperatureLow: Double?
    var windSpeed: Double?
    var precipitation: Double?        // total daily precip in inches
    var precipitationProbability: Double?  // peak daily precip probability %
    var weatherDescription: String?
    var weatherCode: Int?             // WMO code for icon mapping
    var isClimateEstimate: Bool
    var hourly: [HourlyWeatherPoint]?
    var impact: WeatherImpact?
    var fetchedAt: Double?            // unix seconds

    enum CodingKeys: String, CodingKey {
        case temperatureHigh = "temperature_high"
        case temperatureLow = "temperature_low"
        case windSpeed = "wind_speed"
        case precipitation
        case precipitationProbability = "precipitation_probability"
        case weatherDescription = "weather_description"
        case weatherCode = "weather_code"
        case isClimateEstimate = "is_climate_estimate"
        case hourly
        case impact
        case fetchedAt = "fetched_at"
    }
}

/// One hour of forecast data, used for the race-morning strip.
struct HourlyWeatherPoint: Codable, Hashable {
    var hour: Int              // 0-23
    var tempF: Double
    var apparentTempF: Double?
    var windMph: Double?
    var precipProb: Double?

    enum CodingKeys: String, CodingKey {
        case hour
        case tempF = "temp_f"
        case apparentTempF = "apparent_temp_f"
        case windMph = "wind_mph"
        case precipProb = "precip_prob"
    }
}

/// AI-generated race-day impact assessment, cached alongside the weather
/// so we only regenerate when the underlying forecast changes.
struct WeatherImpact: Codable, Hashable {
    var rating: String         // "good" | "moderate" | "challenging"
    var assessment: String
    var generatedAt: Double    // unix seconds
    var weatherFetchedAt: Double  // links to WeatherData.fetchedAt at generation time

    enum CodingKeys: String, CodingKey {
        case rating, assessment
        case generatedAt = "generated_at"
        case weatherFetchedAt = "weather_fetched_at"
    }
}

actor WeatherService {
    static let shared = WeatherService()

    private let geocodeURL = "https://geocoding-api.open-meteo.com/v1/search"
    private let forecastURL = "https://api.open-meteo.com/v1/forecast"

    // MARK: - Geocode location string to coordinates

    private func geocode(_ location: String) async throws -> (lat: Double, lon: Double)? {
        var components = URLComponents(string: geocodeURL)!
        components.queryItems = [
            URLQueryItem(name: "name", value: location),
            URLQueryItem(name: "count", value: "1"),
        ]
        let (data, _) = try await URLSession.shared.data(from: components.url!)
        let result = try JSONDecoder().decode(GeocodeResponse.self, from: data)
        guard let first = result.results?.first else { return nil }
        return (first.latitude, first.longitude)
    }

    // MARK: - Get weather for a location and date

    func getWeather(location: String, date: String) async throws -> WeatherData? {
        guard let coords = try await geocode(location) else { return nil }

        let targetDate = dateFromString(date)
        let now = Date()
        let daysOut = Calendar.current.dateComponents([.day], from: now, to: targetDate).day ?? 0

        if daysOut <= 16 && daysOut >= 0 {
            return try await getForecast(lat: coords.lat, lon: coords.lon, date: date)
        } else {
            return try await getClimateEstimate(lat: coords.lat, lon: coords.lon, date: date)
        }
    }

    // MARK: - 16-day forecast

    private func getForecast(lat: Double, lon: Double, date: String) async throws -> WeatherData {
        var components = URLComponents(string: forecastURL)!
        components.queryItems = [
            URLQueryItem(name: "latitude", value: String(lat)),
            URLQueryItem(name: "longitude", value: String(lon)),
            URLQueryItem(name: "daily", value: "temperature_2m_max,temperature_2m_min,wind_speed_10m_max,precipitation_sum,precipitation_probability_max,weather_code"),
            URLQueryItem(name: "hourly", value: "temperature_2m,windspeed_10m,apparent_temperature,precipitation_probability,weather_code"),
            URLQueryItem(name: "temperature_unit", value: "fahrenheit"),
            URLQueryItem(name: "wind_speed_unit", value: "mph"),
            URLQueryItem(name: "forecast_days", value: "16"),
        ]
        let (data, _) = try await URLSession.shared.data(from: components.url!)
        let forecast = try JSONDecoder().decode(ForecastResponse.self, from: data)

        guard let dayIdx = forecast.daily.time.firstIndex(of: date) else {
            return WeatherData(isClimateEstimate: false)
        }

        // Build race-morning hourly series (6 AM through 10 AM, 5 hours)
        let hourly = buildHourlyWindow(for: date, in: forecast.hourly, startHour: 6, hours: 5)

        let wCode = forecast.daily.weatherCode.indices.contains(dayIdx) ? forecast.daily.weatherCode[dayIdx] : nil

        return WeatherData(
            temperatureHigh: forecast.daily.temperature_2m_max[dayIdx],
            temperatureLow: forecast.daily.temperature_2m_min[dayIdx],
            windSpeed: forecast.daily.windSpeedMax.indices.contains(dayIdx) ? forecast.daily.windSpeedMax[dayIdx] : nil,
            precipitation: forecast.daily.precipitationSum.indices.contains(dayIdx) ? forecast.daily.precipitationSum[dayIdx] : nil,
            precipitationProbability: forecast.daily.precipProbMax?.indices.contains(dayIdx) == true ? forecast.daily.precipProbMax?[dayIdx] : nil,
            weatherDescription: wCode.map(weatherCodeToDescription),
            weatherCode: wCode,
            isClimateEstimate: false,
            hourly: hourly,
            impact: nil,
            fetchedAt: Date().timeIntervalSince1970
        )
    }

    /// Extracts a window of hourly forecast points for the given race date.
    /// `startHour` is the first hour-of-day to include (default 6 AM) and
    /// `hours` is how many consecutive hours to return.
    private func buildHourlyWindow(
        for date: String,
        in hourly: HourlyData?,
        startHour: Int,
        hours: Int
    ) -> [HourlyWeatherPoint]? {
        guard let hourly else { return nil }
        // Open-Meteo hourly.time is "yyyy-MM-ddTHH:mm" (ISO local, no tz).
        var result: [HourlyWeatherPoint] = []
        for h in startHour..<(startHour + hours) {
            let prefix = "\(date)T\(String(format: "%02d", h)):00"
            guard let idx = hourly.time.firstIndex(where: { $0.hasPrefix(prefix) }) else { continue }
            let temp = hourly.temperature_2m.indices.contains(idx) ? hourly.temperature_2m[idx] : 0
            let wind: Double? = (hourly.windspeed_10m?.indices.contains(idx) == true) ? hourly.windspeed_10m?[idx] : nil
            let feels: Double? = (hourly.apparent_temperature?.indices.contains(idx) == true) ? hourly.apparent_temperature?[idx] : nil
            var prob: Double? = nil
            if let probArr = hourly.precipitation_probability, probArr.indices.contains(idx) {
                prob = Double(probArr[idx])
            }
            result.append(
                HourlyWeatherPoint(
                    hour: h,
                    tempF: temp,
                    apparentTempF: feels,
                    windMph: wind,
                    precipProb: prob
                )
            )
        }
        return result.isEmpty ? nil : result
    }

    // MARK: - Climate estimate (5-year average +-7 days)

    private func getClimateEstimate(lat: Double, lon: Double, date: String) async throws -> WeatherData {
        // Use archive API with 5-year historical average around the same date
        let targetDate = dateFromString(date)
        let calendar = Calendar.current
        var temps: [Double] = []

        for yearsBack in 1...5 {
            guard let yearDate = calendar.date(byAdding: .year, value: -yearsBack, to: targetDate) else { continue }
            let start = calendar.date(byAdding: .day, value: -7, to: yearDate)!
            let end = calendar.date(byAdding: .day, value: 7, to: yearDate)!

            var components = URLComponents(string: "https://archive-api.open-meteo.com/v1/archive")!
            components.queryItems = [
                URLQueryItem(name: "latitude", value: String(lat)),
                URLQueryItem(name: "longitude", value: String(lon)),
                URLQueryItem(name: "daily", value: "temperature_2m_max,temperature_2m_min"),
                URLQueryItem(name: "temperature_unit", value: "fahrenheit"),
                URLQueryItem(name: "start_date", value: dateToString(start)),
                URLQueryItem(name: "end_date", value: dateToString(end)),
            ]

            if let (data, _) = try? await URLSession.shared.data(from: components.url!),
               let archive = try? JSONDecoder().decode(ForecastResponse.self, from: data) {
                temps.append(contentsOf: archive.daily.temperature_2m_max as [Double])
            }
        }

        let avgHigh = temps.isEmpty ? nil : temps.reduce(0, +) / Double(temps.count)
        return WeatherData(
            temperatureHigh: avgHigh,
            isClimateEstimate: true,
            fetchedAt: Date().timeIntervalSince1970
        )
    }

    // MARK: - Helpers

    private func dateFromString(_ s: String) -> Date {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.date(from: s) ?? Date()
    }

    private func dateToString(_ d: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: d)
    }

    private func weatherCodeToDescription(_ code: Int) -> String {
        switch code {
        case 0: return "Clear sky"
        case 1, 2, 3: return "Partly cloudy"
        case 45, 48: return "Foggy"
        case 51, 53, 55: return "Drizzle"
        case 61, 63, 65: return "Rain"
        case 66, 67: return "Freezing rain"
        case 71, 73, 75: return "Snow"
        case 80, 81, 82: return "Rain showers"
        case 85, 86: return "Snow showers"
        case 95: return "Thunderstorm"
        case 96, 99: return "Thunderstorm with hail"
        default: return "Unknown"
        }
    }
}

// MARK: - API Response Types

private struct GeocodeResponse: Codable, Sendable {
    var results: [GeocodeResult]?
}

private struct GeocodeResult: Codable, Sendable {
    var latitude: Double
    var longitude: Double
    var name: String
}

private struct ForecastResponse: Codable, Sendable {
    var daily: DailyData
    var hourly: HourlyData?
}

private struct DailyData: Codable, Sendable {
    var time: [String]
    var temperature_2m_max: [Double]
    var temperature_2m_min: [Double]
    var wind_speed_10m_max: [Double]?
    var precipitation_sum: [Double]?
    var precipitation_probability_max: [Double]?
    var weather_code: [Int]?

    var windSpeedMax: [Double] { wind_speed_10m_max ?? [] }
    var precipitationSum: [Double] { precipitation_sum ?? [] }
    var precipProbMax: [Double]? { precipitation_probability_max }
    var weatherCode: [Int] { weather_code ?? [] }
}

private struct HourlyData: Codable, Sendable {
    var time: [String]
    var temperature_2m: [Double]
    var windspeed_10m: [Double]?
    var apparent_temperature: [Double]?
    var precipitation_probability: [Int]?
}
