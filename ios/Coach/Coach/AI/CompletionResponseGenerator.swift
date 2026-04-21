import Foundation
import Supabase
import Functions

/// Generates a short (2-3 sentence) coach reaction after a workout is
/// completed, modified, skipped, or auto-matched from HealthKit.
/// Uses a lightweight single-turn Claude call — no tools, no agent loop.
@MainActor
enum CompletionResponseGenerator {

    struct CompletionContext {
        let session: PrescribedSession
        let status: CompletionStatus
        let actualDuration: Int?
        let actualDistance: Double?
        let actualSport: String?
        let skipReason: SkipReason?
        let completionNote: String?
        let source: CompletionSource
        let weekAdherenceSummary: String?
        let tomorrowPreview: String?
        let phaseName: String?
    }

    enum CompletionSource: String {
        case manual = "manually marked"
        case healthKit = "auto-matched from Apple Watch"
    }

    /// Generates 2-3 sentences of coach feedback. Returns plain text.
    static func generate(
        context: CompletionContext,
        personality: Personality,
        customPrompt: String
    ) async throws -> String {
        let personalityPrompt = getPersonalityPrompt(personality, customPrompt)

        let statusDescription: String
        switch context.status {
        case .completed:
            if let actual = context.actualDuration {
                statusDescription = "Completed: \(actual) min"
            } else {
                statusDescription = "Completed as prescribed"
            }
        case .modified:
            var parts = ["Modified"]
            if let d = context.actualDuration { parts.append("\(d) min actual") }
            if let dist = context.actualDistance { parts.append(String(format: "%.1f mi actual", dist)) }
            if let note = context.completionNote, !note.isEmpty { parts.append("note: \(note)") }
            statusDescription = parts.joined(separator: ", ")
        case .swapped:
            let sport = context.actualSport ?? "different workout"
            statusDescription = "Swapped to \(sport)"
            + (context.actualDuration.map { ", \($0) min" } ?? "")
        case .skipped:
            let reason = context.skipReason?.rawValue ?? "no reason given"
            statusDescription = "Skipped (\(reason))"
            + (context.completionNote.map { ". Note: \($0)" } ?? "")
        }

        let prompt = """
        \(personalityPrompt)

        The athlete just resolved a workout. Give a SHORT reaction — 2-3 sentences max. No greetings, no sign-offs, no bullet points. Just react like a coach who saw the update come through.

        RULES:
        1. Acknowledge what happened specifically (don't be generic).
        2. Connect it to the bigger picture — what this session was building, what's coming next, or how the week is shaping up.
        3. If they skipped or modified, acknowledge without guilt but with awareness. One skip is fine. A pattern matters.
        4. If this was auto-matched from Apple Watch, briefly acknowledge that ("saw your watch pick up...").
        5. Match the coaching personality exactly.

        SESSION: \(context.session.label) (\(context.session.type))
        PURPOSE: \(context.session.purpose ?? "general training")
        PRESCRIBED: \(context.session.duration ?? 0) min
        STATUS: \(statusDescription)
        SOURCE: \(context.source.rawValue)
        \(context.weekAdherenceSummary.map { "WEEK SO FAR: \($0)" } ?? "")
        \(context.tomorrowPreview.map { "TOMORROW: \($0)" } ?? "")
        \(context.phaseName.map { "CURRENT PHASE: \($0)" } ?? "")

        Respond with ONLY the 2-3 sentence reaction. No JSON, no formatting, just the text.
        """

        let client = SupabaseService.shared.client
        let body: [String: Any] = [
            "system": "You are an expert athletic coach giving brief post-workout feedback.",
            "messages": [["role": "user", "content": prompt]],
            "max_tokens": 300,
            "model": "claude-sonnet-4-6",
        ]
        let bodyData = try JSONSerialization.data(withJSONObject: body)

        let response: LightResponse = try await client.functions.invoke(
            "chat",
            options: .init(body: bodyData)
        ) { data, response in
            guard 200..<300 ~= response.statusCode else {
                throw NSError(
                    domain: "CompletionResponseGenerator",
                    code: response.statusCode,
                    userInfo: [NSLocalizedDescriptionKey: "HTTP \(response.statusCode)"]
                )
            }
            return try JSONDecoder().decode(LightResponse.self, from: data)
        }

        return response.content
            .filter { $0.type == "text" }
            .compactMap(\.text)
            .joined()
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private struct LightResponse: Codable {
        let content: [Block]
        struct Block: Codable {
            let type: String
            let text: String?
        }
    }
}
