import Foundation
import Supabase
import Functions

// MARK: - Agent Loop Result

struct AgentResult {
    var response: String
    var effects: [ToolEffect]
    var toolCallCount: Int

    // Convenience predicates for ChatMessageMetadata
    var hasWorkoutLogs: Bool {
        effects.contains { if case .workoutLogged = $0 { return true }; return false }
    }
    var hasNutritionLogs: Bool {
        effects.contains { if case .nutritionLogged = $0 { return true }; return false }
    }
    var hasPlanChanges: Bool {
        effects.contains {
            switch $0 {
            case .planCreated, .planUpdated, .weekUpdated, .progressUpdated: return true
            default: return false
            }
        }
    }
    var hasAppActions: Bool {
        effects.contains {
            switch $0 {
            case .eventCreated, .eventUpdated, .eventDeleted: return true
            default: return false
            }
        }
    }
}

// MARK: - Anthropic API Response Types

struct AnthropicResponse: Codable {
    let id: String?
    let content: [ContentBlock]
    let stopReason: String?

    enum CodingKeys: String, CodingKey {
        case id, content
        case stopReason = "stop_reason"
    }
}

struct ContentBlock: Codable {
    let type: String
    let text: String?
    let id: String?
    let name: String?
    let input: AnyCodable?
}

/// Type-erased Codable wrapper for tool inputs
struct AnyCodable: Codable {
    let value: Any

    init(_ value: Any) { self.value = value }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let dict = try? container.decode([String: AnyCodable].self) {
            value = dict.mapValues(\.value)
        } else if let arr = try? container.decode([AnyCodable].self) {
            value = arr.map(\.value)
        } else if let str = try? container.decode(String.self) {
            value = str
        } else if let num = try? container.decode(Double.self) {
            value = num
        } else if let bool = try? container.decode(Bool.self) {
            value = bool
        } else {
            value = NSNull()
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        if let dict = value as? [String: Any] {
            try container.encode(dict.mapValues { AnyCodable($0) })
        } else if let arr = value as? [Any] {
            try container.encode(arr.map { AnyCodable($0) })
        } else if let str = value as? String {
            try container.encode(str)
        } else if let num = value as? Double {
            try container.encode(num)
        } else if let num = value as? Int {
            try container.encode(num)
        } else if let bool = value as? Bool {
            try container.encode(bool)
        } else {
            try container.encodeNil()
        }
    }
}

// MARK: - Agent Loop

/// Port of runAgentLoop from page.jsx lines 914-931.
/// Executes multi-turn tool use with the AI coach, max 7 rounds.
@MainActor
func runAgentLoop(
    personality: Personality,
    customText: String,
    messages: [ChatMessage],
    dataService: DataService,
    maxRounds: Int = 5
) async throws -> AgentResult {
    // Clean messages for API format
    let clean = messages.map { msg -> [String: Any] in
        ["role": msg.role, "content": msg.content]
    }

    var chain: [[String: Any]] = clean
    var toolCallCount = 0
    var effects: [ToolEffect] = []

    for _ in 0..<maxRounds {
        // Call Claude via Supabase Edge Function
        let response = try await callEdgeFunction(
            system: buildSystemPrompt(personality: personality, customText: customText),
            messages: chain,
            tools: coachToolDefinitions,
            maxTokens: 2048
        )

        if response.stopReason == "end_turn" {
            let text = response.content
                .filter { $0.type == "text" }
                .compactMap(\.text)
                .joined()
                .trimmingCharacters(in: .whitespacesAndNewlines)
            return AgentResult(response: text, effects: effects, toolCallCount: toolCallCount)
        }

        if response.stopReason == "tool_use" {
            let toolUses = response.content.filter { $0.type == "tool_use" }
            guard !toolUses.isEmpty else {
                let text = response.content.filter { $0.type == "text" }.compactMap(\.text).joined()
                return AgentResult(response: text, effects: effects, toolCallCount: toolCallCount)
            }

            var toolResults: [[String: Any]] = []
            for tu in toolUses {
                toolCallCount += 1
                let toolName = tu.name ?? ""
                let input = (tu.input?.value as? [String: Any]) ?? [:]

                // Publish progress so ChatTab can show a custom loading state
                dataService.activeToolName = toolName

                let result = await executeTool(
                    name: toolName,
                    input: input,
                    dataService: dataService
                )

                // Collect typed side-effects (replaces the old TODO)
                effects.append(contentsOf: result.effects)

                toolResults.append([
                    "type": "tool_result",
                    "tool_use_id": tu.id ?? "",
                    "content": result.summary,
                ])
            }

            dataService.activeToolName = nil

            // Encode assistant content for the chain
            let assistantContent: [[String: Any]] = response.content.map { block in
                var dict: [String: Any] = ["type": block.type]
                if let text = block.text { dict["text"] = text }
                if let id = block.id { dict["id"] = id }
                if let name = block.name { dict["name"] = name }
                if let input = block.input { dict["input"] = input.value }
                return dict
            }

            chain.append(["role": "assistant", "content": assistantContent])
            chain.append(["role": "user", "content": toolResults])

            try await Task.sleep(for: .milliseconds(300))
            continue
        }

        // Unexpected stop reason
        let text = response.content.filter { $0.type == "text" }.compactMap(\.text).joined()
        return AgentResult(response: text.isEmpty ? "Done." : text, effects: effects, toolCallCount: toolCallCount)
    }

    return AgentResult(
        response: "I needed more context. Try asking again.",
        effects: effects,
        toolCallCount: toolCallCount
    )
}

// MARK: - Edge Function Call

private func callEdgeFunction(
    system: String,
    messages: [[String: Any]],
    tools: [ToolDefinition],
    maxTokens: Int
) async throws -> AnthropicResponse {
    let client = SupabaseService.shared.client

    // Encode tools to JSON-compatible format
    let encoder = JSONEncoder()
    let toolsData = try encoder.encode(tools)
    let toolsJSON = try JSONSerialization.jsonObject(with: toolsData)

    let body: [String: Any] = [
        "system": system,
        "messages": messages,
        "tools": toolsJSON,
        "tool_choice": ["type": "auto"],
        "max_tokens": maxTokens,
    ]

    let bodyData = try JSONSerialization.data(withJSONObject: body)

    // The SDK's FunctionsClient.invoke pre-checks status inside rawInvoke and
    // throws FunctionsError.httpError on non-2xx BEFORE calling our decode
    // closure. So we have to catch the error out here — any status check
    // inside the closure is dead code on the non-2xx path.
    do {
        return try await client.functions.invoke(
            "chat",
            options: .init(body: bodyData)
        ) { data, _ in
            do {
                return try JSONDecoder().decode(AnthropicResponse.self, from: data)
            } catch {
                let preview = String(data: data, encoding: .utf8) ?? "<non-utf8 \(data.count) bytes>"
                NSLog("[chat] decode failed: \(error)\nbody: \(preview)")
                throw NSError(
                    domain: "ChatAgent",
                    code: -1,
                    userInfo: [
                        NSLocalizedDescriptionKey: "Decode failed: \(error.localizedDescription)\nBody: \(preview.prefix(400))"
                    ]
                )
            }
        }
    } catch let FunctionsError.httpError(code, data) {
        let preview = String(data: data, encoding: .utf8) ?? "<non-utf8 \(data.count) bytes>"
        NSLog("[chat] HTTP \(code): \(preview)")
        throw NSError(
            domain: "ChatAgent",
            code: code,
            userInfo: [
                NSLocalizedDescriptionKey: "HTTP \(code): \(preview.prefix(400))"
            ]
        )
    }
}
