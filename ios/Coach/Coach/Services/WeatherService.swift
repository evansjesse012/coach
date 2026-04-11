import Foundation

/// Open-Meteo weather service. No API key required.
/// Provides forecast (<=16 days), historical (past), or climate estimates (>16 days).
struct WeatherData: Codable {
    var temperatureHigh: Double?
    var temperatureLow: Double?
    var windSpeed: Double?
    var precipitation: Double?
    var weatherDescription: String?
    var isClimateEstimate: Bool
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
            URLQueryItem(name: "daily", value: "temperature_2m_max,temperature_2m_min,wind_speed_10m_max,precipitation_sum,weather_code"),
            URLQueryItem(name: "temperature_unit", value: "fahrenheit"),
            URLQueryItem(name: "wind_speed_unit", value: "mph"),
            URLQueryItem(name: "forecast_days", value: "16"),
        ]
        let (data, _) = try await URLSession.shared.data(from: components.url!)
        let forecast = try JSONDecoder().decode(ForecastResponse.self, from: data)

        guard let idx = forecast.daily.time.firstIndex(of: date) else {
            return WeatherData(isClimateEstimate: false)
        }

        return WeatherData(
            temperatureHigh: forecast.daily.temperature_2m_max[idx],
            temperatureLow: forecast.daily.temperature_2m_min[idx],
            windSpeed: forecast.daily.wind_speed_10m_max[idx],
            precipitation: forecast.daily.precipitation_sum[idx],
            weatherDescription: weatherCodeToDescription(forecast.daily.weather_code[idx]),
            isClimateEstimate: false
        )
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
                temps.append(contentsOf: archive.daily.temperature_2m_max)
            }
        }

        let avgHigh = temps.isEmpty ? nil : temps.reduce(0, +) / Double(temps.count)
        return WeatherData(
            temperatureHigh: avgHigh,
            isClimateEstimate: true
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

private struct GeocodeResponse: Codable {
    var results: [GeocodeResult]?
}

private struct GeocodeResult: Codable {
    var latitude: Double
    var longitude: Double
    var name: String
}

private struct ForecastResponse: Codable {
    var daily: DailyData
}

private struct DailyData: Codable {
    var time: [String]
    var temperature_2m_max: [Double]
    var temperature_2m_min: [Double]
    var wind_speed_10m_max: [Double]?
    var precipitation_sum: [Double]?
    var weather_code: [Int]?

    // Provide defaults for optional arrays
    var windSpeedMax: [Double] { wind_speed_10m_max ?? [] }
    var precipitationSum: [Double] { precipitation_sum ?? [] }
    var weatherCode: [Int] { weather_code ?? [] }
}
