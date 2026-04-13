import Foundation

/// Open-Meteo weather service. No API key required.
/// Provides forecast (<=16 days), historical (past), or climate estimates (>16 days).

/// A single hour sample for the race-morning strip.
struct WeatherHour: Codable, Hashable {
    var hour: Int          // 0-23 in the race location's local day
    var tempF: Double?
    var windMph: Double?
    var precipProb: Double?
}

/// A lightweight, cached AI-generated take on how the weather will affect the race.
struct WeatherAssessment: Codable, Hashable {
    enum Rating: String, Codable, Hashable {
        case good, moderate, challenging
    }
    var rating: Rating
    var text: String
}

struct WeatherData: Codable {
    var temperatureHigh: Double?
    var temperatureLow: Double?
    var windSpeed: Double?
    var precipitation: Double?
    var precipProbability: Double?    // NEW: daily probability 0-100
    var weatherDescription: String?
    var weatherCode: Int?             // NEW: used to pick an icon
    var apparentTempAtStart: Double?  // NEW: feels-like at gun time
    var hourly: [WeatherHour]?        // NEW: race morning strip data
    var fetchedAt: Date?              // NEW: for "updated X ago" line
    var isClimateEstimate: Bool

    init(
        temperatureHigh: Double? = nil,
        temperatureLow: Double? = nil,
        windSpeed: Double? = nil,
        precipitation: Double? = nil,
        precipProbability: Double? = nil,
        weatherDescription: String? = nil,
        weatherCode: Int? = nil,
        apparentTempAtStart: Double? = nil,
        hourly: [WeatherHour]? = nil,
        fetchedAt: Date? = nil,
        isClimateEstimate: Bool
    ) {
        self.temperatureHigh = temperatureHigh
        self.temperatureLow = temperatureLow
        self.windSpeed = windSpeed
        self.precipitation = precipitation
        self.precipProbability = precipProbability
        self.weatherDescription = weatherDescription
        self.weatherCode = weatherCode
        self.apparentTempAtStart = apparentTempAtStart
        self.hourly = hourly
        self.fetchedAt = fetchedAt
        self.isClimateEstimate = isClimateEstimate
    }
}

actor WeatherService {
    static let shared = WeatherService()

    private let geocodeURL = "https://geocoding-api.open-meteo.com/v1/search"
    private let forecastURL = "https://api.open-meteo.com/v1/forecast"

    // MARK: - Geocode location string to coordinates

    private func geocode(_ location: String) async throws -> (lat: Double, lon: Double, timezone: String?)? {
        var components = URLComponents(string: geocodeURL)!
        components.queryItems = [
            URLQueryItem(name: "name", value: location),
            URLQueryItem(name: "count", value: "1"),
        ]
        let (data, _) = try await URLSession.shared.data(from: components.url!)
        let result = try JSONDecoder().decode(GeocodeResponse.self, from: data)
        guard let first = result.results?.first else { return nil }
        return (first.latitude, first.longitude, first.timezone)
    }

    // MARK: - Get weather for a location and date

    /// Default race gun time in local hour-of-day (24h). 7 AM unless overridden.
    func getWeather(location: String, date: String, startHour: Int = 7) async throws -> WeatherData? {
        guard let coords = try await geocode(location) else { return nil }

        let targetDate = dateFromString(date)
        let now = Date()
        let daysOut = Calendar.current.dateComponents([.day], from: now, to: targetDate).day ?? 0

        if daysOut <= 16 && daysOut >= 0 {
            return try await getForecast(
                lat: coords.lat,
                lon: coords.lon,
                timezone: coords.timezone,
                date: date,
                startHour: startHour
            )
        } else {
            return try await getClimateEstimate(lat: coords.lat, lon: coords.lon, date: date)
        }
    }

    // MARK: - 16-day forecast

    private func getForecast(lat: Double, lon: Double, timezone: String?, date: String, startHour: Int) async throws -> WeatherData {
        var components = URLComponents(string: forecastURL)!
        components.queryItems = [
            URLQueryItem(name: "latitude", value: String(lat)),
            URLQueryItem(name: "longitude", value: String(lon)),
            URLQueryItem(name: "daily", value: "temperature_2m_max,temperature_2m_min,wind_speed_10m_max,precipitation_sum,precipitation_probability_max,weather_code"),
            URLQueryItem(name: "hourly", value: "temperature_2m,apparent_temperature,wind_speed_10m,precipitation_probability"),
            URLQueryItem(name: "temperature_unit", value: "fahrenheit"),
            URLQueryItem(name: "wind_speed_unit", value: "mph"),
            URLQueryItem(name: "timezone", value: timezone ?? "auto"),
            URLQueryItem(name: "forecast_days", value: "16"),
        ]
        let (data, _) = try await URLSession.shared.data(from: components.url!)
        let forecast = try JSONDecoder().decode(ForecastResponse.self, from: data)

        guard let idx = forecast.daily.time.firstIndex(of: date) else {
            return WeatherData(fetchedAt: Date(), isClimateEstimate: false)
        }

        // Race morning hourly samples: startHour through startHour+4 on race day.
        var hourlySamples: [WeatherHour] = []
        var apparentAtStart: Double?
        if let hourly = forecast.hourly {
            let temps = hourly.temperature_2m
            let apparent = hourly.apparent_temperature ?? []
            let winds = hourly.wind_speed_10m ?? []
            let precipProbs = hourly.precipitation_probability ?? []
            let prefix = date + "T"
            for offset in 0..<5 {
                let h = startHour + offset
                let key = String(format: "%@%02d:00", prefix, h)
                guard let i = hourly.time.firstIndex(of: key) else { continue }
                let tempF: Double? = temps.indices.contains(i) ? temps[i] : nil
                let windMph: Double? = winds.indices.contains(i) ? winds[i] : nil
                let precipProb: Double? = precipProbs.indices.contains(i) ? precipProbs[i] : nil
                hourlySamples.append(
                    WeatherHour(hour: h, tempF: tempF, windMph: windMph, precipProb: precipProb)
                )
                if offset == 0, apparent.indices.contains(i) {
                    apparentAtStart = apparent[i]
                }
            }
        }

        return WeatherData(
            temperatureHigh: forecast.daily.temperature_2m_max[idx],
            temperatureLow: forecast.daily.temperature_2m_min[idx],
            windSpeed: forecast.daily.windSpeedMax.indices.contains(idx) ? forecast.daily.windSpeedMax[idx] : nil,
            precipitation: forecast.daily.precipitationSum.indices.contains(idx) ? forecast.daily.precipitationSum[idx] : nil,
            precipProbability: forecast.daily.precipProbMax.indices.contains(idx) ? forecast.daily.precipProbMax[idx] : nil,
            weatherDescription: forecast.daily.weatherCode.indices.contains(idx) ? weatherCodeToDescription(forecast.daily.weatherCode[idx]) : nil,
            weatherCode: forecast.daily.weatherCode.indices.contains(idx) ? forecast.daily.weatherCode[idx] : nil,
            apparentTempAtStart: apparentAtStart,
            hourly: hourlySamples.isEmpty ? nil : hourlySamples,
            fetchedAt: Date(),
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
                temps.append(contentsOf: archive.daily.temperature_2m_max as [Double])
            }
        }

        let avgHigh = temps.isEmpty ? nil : temps.reduce(0, +) / Double(temps.count)
        return WeatherData(
            temperatureHigh: avgHigh,
            fetchedAt: Date(),
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
    var timezone: String?
}

private struct ForecastResponse: Codable {
    var daily: DailyData
    var hourly: HourlyData?
}

private struct DailyData: Codable {
    var time: [String]
    var temperature_2m_max: [Double]
    var temperature_2m_min: [Double]
    var wind_speed_10m_max: [Double]?
    var precipitation_sum: [Double]?
    var precipitation_probability_max: [Double]?
    var weather_code: [Int]?

    // Provide defaults for optional arrays
    var windSpeedMax: [Double] { wind_speed_10m_max ?? [] }
    var precipitationSum: [Double] { precipitation_sum ?? [] }
    var precipProbMax: [Double] { precipitation_probability_max ?? [] }
    var weatherCode: [Int] { weather_code ?? [] }
}

private struct HourlyData: Codable {
    var time: [String]
    var temperature_2m: [Double]
    var apparent_temperature: [Double]?
    var wind_speed_10m: [Double]?
    var precipitation_probability: [Double?]?
}
