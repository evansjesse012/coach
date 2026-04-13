import Foundation
import Supabase
import Functions

/// Lightweight AI call that rates race-day weather and returns one sentence
/// of coach-style guidance. Result is cached alongside WeatherData so we
/// only regenerate when the underlying forecast changes.
@MainActor
enum WeatherImpactGenerator {
    static func generate(for event: Event, weather: WeatherData) async throws -> WeatherImpact {
        let client = SupabaseService.shared.client

        let contextLine = buildContextLine(event: event, weather: weather)

        let system = """
        You are a running/triathlon coach assessing race-day weather. Given conditions for a race, return a JSON object with exactly two fields:
        - "rating": one of "good", "moderate", or "challenging"
        - "assessment": exactly 2 sentences. First sentence rates the conditions with a short reason. Second sentence gives one specific actionable recommendation about clothing, pacing, or hydration.

        Rules:
        - "good": temps 45-65°F, wind <15mph, precip <30%
        - "moderate": temps 65-75°F or 35-45°F, wind 15-25mph, or precip 30-60%
        - "challenging": temps >75°F or <35°F, wind >25mph, or precip >60%

        Respond with ONLY the JSON object. No markdown fences, no explanation.
        """

        let body: [String: Any] = [
            "system": system,
            "messages": [
                ["role": "user", "content": contextLine]
            ],
            "max_tokens": 400,
        ]
        let bodyData = try JSONSerialization.data(withJSONObject: body)

        let response: ImpactChatResponse = try await client.functions.invoke(
            "chat",
            options: .init(body: bodyData)
        ) { data, response in
            guard 200..<300 ~= response.statusCode else {
                let preview = String(data: data, encoding: .utf8) ?? ""
                NSLog("[weather-impact] HTTP \(response.statusCode): \(preview)")
                throw FunctionsError.httpError(code: response.statusCode, data: data)
            }
            return try JSONDecoder().decode(ImpactChatResponse.self, from: data)
        }

        let text = response.content
            .filter { $0.type == "text" }
            .compactMap(\.text)
            .joined(separator: "\n")

        guard let json = extractJSON(from: text) else {
            throw NSError(
                domain: "WeatherImpactGenerator", code: 1,
                userInfo: [NSLocalizedDescriptionKey: "No JSON in impact response"]
            )
        }
        guard let jsonData = json.data(using: .utf8) else {
            throw NSError(domain: "WeatherImpactGenerator", code: 2, userInfo: [NSLocalizedDescriptionKey: "JSON encode failed"])
        }

        let raw = try JSONDecoder().decode(RawImpact.self, from: jsonData)
        return WeatherImpact(
            rating: raw.rating,
            assessment: raw.assessment,
            generatedAt: Date().timeIntervalSince1970,
            weatherFetchedAt: weather.fetchedAt ?? 0
        )
    }

    /// True if the current impact was generated from the current weather
    /// fetch, so we don't re-call the model unnecessarily.
    static func isCached(_ impact: WeatherImpact?, for weather: WeatherData) -> Bool {
        guard let impact, let fetchedAt = weather.fetchedAt else { return false }
        // Within 1 second is "same fetch"
        return abs(impact.weatherFetchedAt - fetchedAt) < 1.0
    }

    // MARK: - Helpers

    private static func buildContextLine(event: Event, weather: WeatherData) -> String {
        var parts: [String] = []
        parts.append("Race: \(event.name)")
        if let d = event.distance, !d.isEmpty { parts[parts.count - 1] += " (\(d))" }

        var conditions: [String] = []
        if let high = weather.temperatureHigh { conditions.append("High \(Int(high.rounded()))°F") }
        if let low = weather.temperatureLow { conditions.append("Low \(Int(low.rounded()))°F") }
        if let wind = weather.windSpeed { conditions.append("Wind \(Int(wind.rounded())) mph") }
        if let prob = weather.precipitationProbability { conditions.append("Precip \(Int(prob.rounded()))%") }
        if let first = weather.hourly?.first {
            conditions.append("Start temp \(Int(first.tempF.rounded()))°F")
            if let feel = first.apparentTempF {
                conditions[conditions.count - 1] += " (feels like \(Int(feel.rounded()))°F)"
            }
        }
        parts.append("Conditions: " + conditions.joined(separator: ", "))

        return parts.joined(separator: "\n")
    }

    private static func extractJSON(from text: String) -> String? {
        var s = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if s.hasPrefix("```") {
            if let firstNewline = s.firstIndex(of: "\n") {
                s = String(s[s.index(after: firstNewline)...])
            }
            if let lastFence = s.range(of: "```", options: .backwards) {
                s = String(s[s.startIndex..<lastFence.lowerBound])
            }
            s = s.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        guard let start = s.firstIndex(of: "{"),
              let end = s.lastIndex(of: "}"),
              start <= end else { return nil }
        return String(s[start...end])
    }
}

private struct ImpactChatResponse: Codable {
    let content: [Block]
    struct Block: Codable {
        let type: String
        let text: String?
    }
}

private struct RawImpact: Codable {
    let rating: String
    let assessment: String
}
