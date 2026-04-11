import Foundation
import Supabase

// MARK: - Agent Loop Result

struct AgentResult {
    var response: String
    var workoutsLogged: [CardioWorkout]
    var nutritionLogged: [NutritionEntry]
    var planChanges: [PlanChange]
    var appActions: [[String: Any]]
    var toolCallCount: Int
}

enum PlanChange {
    case plan(TrainingPlan)
    case week(WeeklyPlan)
    case progress(currentWeek: Int, currentPhase: Int)
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
    var workoutsLogged: [CardioWorkout] = []
    var nutritionLogged: [NutritionEntry] = []
    var planChanges: [PlanChange] = []
    var appActions: [[String: Any]] = []

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
            return AgentResult(
                response: text,
                workoutsLogged: workoutsLogged,
                nutritionLogged: nutritionLogged,
                planChanges: planChanges,
                appActions: appActions,
                toolCallCount: toolCallCount
            )
        }

        if response.stopReason == "tool_use" {
            let toolUses = response.content.filter { $0.type == "tool_use" }
            guard !toolUses.isEmpty else {
                let text = response.content.filter { $0.type == "text" }.compactMap(\.text).joined()
                return AgentResult(response: text, workoutsLogged: workoutsLogged, nutritionLogged: nutritionLogged, planChanges: planChanges, appActions: appActions, toolCallCount: toolCallCount)
            }

            var toolResults: [[String: Any]] = []
            for tu in toolUses {
                toolCallCount += 1
                let input = (tu.input?.value as? [String: Any]) ?? [:]
                let result = executeTool(
                    name: tu.name ?? "",
                    input: input,
                    dataService: dataService
                )

                // Extract side effects
                // TODO: Parse result JSON to extract workoutsLogged, nutritionLogged, planChanges, appActions
                // This mirrors the JS side-effect extraction in page.jsx lines 922-923

                toolResults.append([
                    "type": "tool_result",
                    "tool_use_id": tu.id ?? "",
                    "content": result,
                ])
            }

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
        return AgentResult(response: text.isEmpty ? "Done." : text, workoutsLogged: workoutsLogged, nutritionLogged: nutritionLogged, planChanges: planChanges, appActions: appActions, toolCallCount: toolCallCount)
    }

    return AgentResult(
        response: "I needed more context. Try asking again.",
        workoutsLogged: workoutsLogged,
        nutritionLogged: nutritionLogged,
        planChanges: planChanges,
        appActions: appActions,
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

    // Call the Supabase Edge Function
    let response = try await client.functions.invoke(
        "chat",
        options: .init(body: bodyData)
    )

    let decoder = JSONDecoder()
    return try decoder.decode(AnthropicResponse.self, from: response.data)
}
