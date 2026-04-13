import Foundation
import Supabase
import Functions

/// Result of generating race conditions for an event.
struct RaceOverviewResult {
    let conditions: AIConditions
    let officialURL: String?
}

/// Calls the chat edge function with a one-shot prompt asking for race-day
/// conditions and (for races) the official race website. Uses Anthropic's
/// server-side web_search tool so URLs are sourced from real search results,
/// not model memory.
@MainActor
enum RaceConditionsGenerator {
    static func generate(for event: Event) async throws -> RaceOverviewResult {
        let client = SupabaseService.shared.client

        let location = event.location ?? "an unspecified location"
        let date = event.date ?? "an unspecified date"
        let isRace = event.mode == .race

        let urlSection: String
        if isRace {
            urlSection = """

            "official_url": "the official registration/information website for this race. ALWAYS use the web_search tool to find the real URL — never guess. If you cannot find one after searching, return an empty string. Prefer the primary/organizer site over aggregator pages (e.g., not RunSignup, BibRave, marathonguide, etc., unless that's the only home the race has).",
            """
        } else {
            urlSection = ""
        }

        let userPrompt = """
        Generate race-day conditions for "\(event.name)" on \(date) at \(location).

        Return ONLY a JSON object with these fields, no markdown fences, no commentary, no text outside the JSON:
        {
          "summary": "2 concise sentences (~40 words total) — what makes this race distinctive and what to expect on the day. Be specific, skip filler.",
          "terrain": "1 sentence on the course terrain (flat/hilly/trail/road, surface, technical sections)",
          "terrain_short": "5-8 words capturing the terrain at a glance, e.g. 'Paved, rolling hills' or 'Flat road, some gravel'",
          "elevation": "1 sentence on total elevation gain and notable climbs",
          "elevation_short": "5-8 words, e.g. '~1,000 ft gain' or 'Net downhill, 300 ft loss'",
          "climate": "1 sentence on typical weather for this race date and location",
          "climate_short": "5-8 words, e.g. '50s, foggy likely' or 'Hot and humid, mid-80s'",
          "tips": [
            { "headline": "2-4 word punchy lead-in, e.g. 'Start conservative'", "detail": "one sentence of actionable advice following the headline" }
          ],\(urlSection)
        }

        Rules:
        - Provide 5-8 tips as objects with headline + detail. The headline is a short imperative phrase; the detail is one concise sentence.
        - The *_short fields are one-liners for a compact chip UI — do not repeat the longer field.
        - If you don't know the specific race, infer reasonable conditions from the race name, location, and date.
        """

        // Request body. Enable Anthropic's native web_search tool so the
        // model can fetch real URLs instead of hallucinating.
        var body: [String: Any] = [
            "system": "You are an expert endurance coach with deep race-day knowledge. You return only valid JSON when asked, with no prose around it. When asked for official websites, you always verify via web_search — you never invent URLs.",
            "messages": [
                ["role": "user", "content": userPrompt]
            ],
            "max_tokens": 2048,
        ]
        if isRace {
            body["tools"] = [
                [
                    "type": "web_search_20250305",
                    "name": "web_search",
                    "max_uses": 3,
                ]
            ]
        }

        let bodyData = try JSONSerialization.data(withJSONObject: body)

        let response: ChatResponse = try await client.functions.invoke(
            "chat",
            options: .init(body: bodyData)
        ) { data, response in
            guard 200..<300 ~= response.statusCode else {
                let preview = String(data: data, encoding: .utf8) ?? ""
                NSLog("[race-conditions] HTTP \(response.statusCode): \(preview)")
                throw FunctionsError.httpError(code: response.statusCode, data: data)
            }
            return try JSONDecoder().decode(ChatResponse.self, from: data)
        }

        // Join all text blocks. Web search tool_use / tool_result blocks are
        // server-side and are interleaved between text — we only care about
        // the final synthesized text.
        let text = response.content
            .filter { $0.type == "text" }
            .compactMap(\.text)
            .joined(separator: "\n")

        guard let json = extractJSON(from: text) else {
            throw NSError(
                domain: "RaceConditionsGenerator", code: 1,
                userInfo: [NSLocalizedDescriptionKey: "Couldn't find JSON in model output"]
            )
        }
        guard let jsonData = json.data(using: .utf8) else {
            throw NSError(domain: "RaceConditionsGenerator", code: 2, userInfo: [NSLocalizedDescriptionKey: "JSON encode failed"])
        }

        let conditions = try JSONDecoder().decode(AIConditions.self, from: jsonData)

        // Extract optional official_url without failing decode of AIConditions
        var url: String?
        if let parsed = try JSONSerialization.jsonObject(with: jsonData) as? [String: Any],
           let raw = parsed["official_url"] as? String,
           !raw.trimmingCharacters(in: .whitespaces).isEmpty {
            url = raw.trimmingCharacters(in: .whitespaces)
        }

        return RaceOverviewResult(conditions: conditions, officialURL: url)
    }

    /// Strips markdown fences and grabs the first {...} block from a model response.
    static func extractJSON(from text: String) -> String? {
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

/// Generates a short AI-written assessment of how the day's weather will
/// affect the race. Short, opinionated, 2 sentences, returned as structured
/// JSON so we can color-code the impact box.
@MainActor
enum WeatherAssessmentGenerator {
    static func generate(for event: Event, weather: WeatherData) async throws -> WeatherAssessment {
        let client = SupabaseService.shared.client

        // Build a compact hourly summary the model can reason about.
        let hourlyLine: String
        if let hours = weather.hourly, !hours.isEmpty {
            hourlyLine = hours.map { h in
                let t = h.tempF.map { "\(Int($0))°" } ?? "?"
                let w = h.windMph.map { "\(Int($0))mph" } ?? "?"
                return "\(h.hour):00 \(t)/\(w)"
            }.joined(separator: ", ")
        } else {
            hourlyLine = "unknown"
        }

        let high = weather.temperatureHigh.map { "\(Int($0))°F" } ?? "?"
        let low = weather.temperatureLow.map { "\(Int($0))°F" } ?? "?"
        let wind = weather.windSpeed.map { "\(Int($0)) mph" } ?? "?"
        let precip = weather.precipProbability.map { "\(Int($0))%" }
            ?? weather.precipitation.map { String(format: "%.1f\"", $0) }
            ?? "?"

        let prompt = """
        Given these race-day conditions for "\(event.name)" on \(event.date ?? "?") at \(event.location ?? "?"):
        high \(high), low \(low), wind \(wind), precip \(precip), race-morning hourly \(hourlyLine).

        Write a 2-sentence assessment. First sentence: a rating phrase ending in "conditions." (e.g. "Good race conditions.", "Challenging conditions.", "Watch the wind."). Second sentence: one specific clothing or pacing recommendation based on these numbers.

        Return ONLY a JSON object, no markdown fences, no commentary:
        {
          "rating": "good" | "moderate" | "challenging",
          "assessment": "the two sentences as one string"
        }
        """

        let body: [String: Any] = [
            "system": "You are a concise endurance coach. You return only valid JSON, no prose around it.",
            "messages": [
                ["role": "user", "content": prompt]
            ],
            "max_tokens": 400,
        ]

        let bodyData = try JSONSerialization.data(withJSONObject: body)

        let response: ChatResponseLite = try await client.functions.invoke(
            "chat",
            options: .init(body: bodyData)
        ) { data, response in
            guard 200..<300 ~= response.statusCode else {
                let preview = String(data: data, encoding: .utf8) ?? ""
                NSLog("[weather-assessment] HTTP \(response.statusCode): \(preview)")
                throw FunctionsError.httpError(code: response.statusCode, data: data)
            }
            return try JSONDecoder().decode(ChatResponseLite.self, from: data)
        }

        let text = response.content
            .filter { $0.type == "text" }
            .compactMap(\.text)
            .joined(separator: "\n")

        guard let json = RaceConditionsGenerator.extractJSON(from: text),
              let jsonData = json.data(using: .utf8) else {
            throw NSError(
                domain: "WeatherAssessmentGenerator", code: 1,
                userInfo: [NSLocalizedDescriptionKey: "Couldn't parse assessment JSON"]
            )
        }

        struct RawAssessment: Codable {
            let rating: String
            let assessment: String
        }

        let raw = try JSONDecoder().decode(RawAssessment.self, from: jsonData)
        let rating = WeatherAssessment.Rating(rawValue: raw.rating.lowercased()) ?? .moderate
        return WeatherAssessment(rating: rating, text: raw.assessment)
    }
}

// MARK: - Minimal local Anthropic shape

private struct ChatResponse: Codable {
    let content: [Block]
    struct Block: Codable {
        let type: String
        let text: String?
    }
}

private struct ChatResponseLite: Codable {
    let content: [Block]
    struct Block: Codable {
        let type: String
        let text: String?
    }
}
