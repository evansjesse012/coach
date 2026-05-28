import Foundation
import Supabase
import Functions

// MARK: - Agent Loop Result

struct AgentResult {
    var response: String
    var effects: [ToolEffect]
    var toolCallCount: Int
    var suggestedReplies: [String] = []

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
            case .planCreated, .planUpdated, .planDeleted, .weekUpdated, .progressUpdated: return true
            default: return false
            }
        }
    }
    var hasAppActions: Bool {
        effects.contains {
            switch $0 {
            case .eventCreated, .eventUpdated, .eventDeleted,
                 .cardioUpdated, .cardioDeleted, .strengthDeleted,
                 .memoryUpdated, .settingsUpdated, .tabChanged,
                 .reviewUpdated, .previewSaved: return true
            default: return false
            }
        }
    }
}

// MARK: - Suggested-replies marker parser

/// The coach LLM appends suggested follow-up replies to the END of its
/// final response using an HTML-comment-style marker:
///
///     <!--sr:["Reply one", "Reply two", "Reply three"]-->
///
/// The marker is stripped from the user-visible text and the parsed
/// array is returned separately. Returns the original text and an empty
/// array if no marker is present, malformed, or contains no strings.
struct ParsedAgentResponse {
    var text: String
    var suggestedReplies: [String]
}

func parseAgentResponse(_ raw: String) -> ParsedAgentResponse {
    let pattern = #"<!--sr:\s*(\[[^\]]*\])\s*-->\s*$"#
    guard let regex = try? NSRegularExpression(pattern: pattern, options: [.dotMatchesLineSeparators]) else {
        return ParsedAgentResponse(text: raw, suggestedReplies: [])
    }
    let range = NSRange(raw.startIndex..., in: raw)
    guard let match = regex.firstMatch(in: raw, range: range),
          let markerRange = Range(match.range, in: raw),
          let jsonRange = Range(match.range(at: 1), in: raw)
    else {
        return ParsedAgentResponse(text: raw, suggestedReplies: [])
    }
    let jsonStr = String(raw[jsonRange])
    let parsed: [String]
    if let data = jsonStr.data(using: .utf8),
       let arr = try? JSONDecoder().decode([String].self, from: data) {
        parsed = arr.prefix(3).map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    } else {
        parsed = []
    }
    let stripped = String(raw[..<markerRange.lowerBound])
        .trimmingCharacters(in: .whitespacesAndNewlines)
    return ParsedAgentResponse(text: stripped, suggestedReplies: parsed)
}

// MARK: - Anthropic API Response Types

struct AnthropicResponse: Codable {
    let id: String?
    let content: [ContentBlock]
    let stopReason: String?
    let usage: AnthropicUsage?

    enum CodingKeys: String, CodingKey {
        case id, content, usage
        case stopReason = "stop_reason"
    }
}

/// Token usage from a single Anthropic call. Cache-related fields are
/// populated when the request includes any block tagged with
/// `cache_control: ephemeral`.
struct AnthropicUsage: Codable {
    let inputTokens: Int?
    let outputTokens: Int?
    let cacheCreationInputTokens: Int?
    let cacheReadInputTokens: Int?

    enum CodingKeys: String, CodingKey {
        case inputTokens             = "input_tokens"
        case outputTokens            = "output_tokens"
        case cacheCreationInputTokens = "cache_creation_input_tokens"
        case cacheReadInputTokens    = "cache_read_input_tokens"
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
        // Order matters: try Int before Double so JSON integer values stay
        // as Int rather than getting silently widened to Double. The previous
        // ordering broke every strict `as? Int` cast in ToolExecutor because
        // a JSON `5` always came through as `5.0 Double`, failing the cast.
        // Bool comes before Int as defense — current Foundation rejects
        // Bool→Int decoding but the ordering protects against future
        // tolerance changes.
        if let dict = try? container.decode([String: AnyCodable].self) {
            value = dict.mapValues(\.value)
        } else if let arr = try? container.decode([AnyCodable].self) {
            value = arr.map(\.value)
        } else if let str = try? container.decode(String.self) {
            value = str
        } else if let bool = try? container.decode(Bool.self) {
            value = bool
        } else if let num = try? container.decode(Int.self) {
            value = num
        } else if let num = try? container.decode(Double.self) {
            value = num
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

// MARK: - Coach State helpers

/// Per-day cache for the LLM-generated recovery_picture narrative. The
/// recovery snapshot only meaningfully changes once per calendar day
/// (overnight HealthKit data), so we compute the narrative once and
/// reuse it across every chat turn that day. Keyed by yyyy-MM-dd; reset
/// implicitly on app restart.
@MainActor
private var recoveryPictureCache: (date: String, picture: String)?

/// Pull the last ~week of `daily_training_load` and assemble the
/// per-turn chronic-load snapshot the coach prompt sees. Returns nil
/// when the table has no rows yet (new athlete) or the fetch errors —
/// the prompt then renders without the training-load line rather than
/// blocking chat on a transient Supabase hiccup.
///
/// 7-day CTL ramp is derived from the oldest-vs-newest row in the
/// 8-row window. Left nil when there isn't enough history yet. If the
/// athlete hasn't logged in a while the asOf date in the rendered line
/// makes the staleness visible to the coach.
@MainActor
private func fetchTrainingLoadSnapshot() async -> TrainingLoadSnapshot? {
    let rows: [DailyTrainingLoad]
    do {
        rows = try await TrainingLoadService.loadRecent(days: 8)
    } catch {
        return nil
    }
    guard let latest = rows.last else { return nil }
    let ramp: Double? = rows.count >= 8 ? latest.ctl - rows.first!.ctl : nil
    return TrainingLoadSnapshot(
        asOf: latest.date,
        ctl: latest.ctl,
        atl: latest.atl,
        tsb: latest.tsb,
        ctlRamp7d: ramp
    )
}

/// Build today's recovery_picture narrative for CoachState. Pulls a
/// fresh `RecoverySnapshot` from HealthKit and feeds it (plus the
/// chronic-load snapshot for context) to a small LLM that writes a
/// 2-3 sentence coach-to-coach briefing. Cached per calendar day so
/// repeated chats in the same day don't repeatedly hit the model.
///
/// Returns nil when HealthKit yielded no usable signal or the model
/// call failed — Section 7 already covers the missing-data case.
@MainActor
private func fetchRecoveryPicture(trainingLoad: TrainingLoadSnapshot?) async -> String? {
    let todayKey: String = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f.string(from: Date())
    }()
    if let cached = recoveryPictureCache, cached.date == todayKey {
        return cached.picture
    }
    guard let snapshot = await HealthKitService.shared.fetchRecoverySnapshot() else { return nil }
    guard let picture = await RecoveryPictureGenerator.generate(
        snapshot: snapshot,
        trainingLoad: trainingLoad
    ) else { return nil }
    recoveryPictureCache = (todayKey, picture)
    return picture
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
    maxRounds: Int = 6,
    recentConversationSummaries: [String] = []
) async throws -> AgentResult {
    // Clean messages for API format — only current conversation, not
    // the full history. Recent conversation summaries give the coach
    // thread-to-thread continuity without re-sending old transcripts.
    let clean = messages.map { msg -> [String: Any] in
        ["role": msg.role, "content": msg.content]
    }

    var chain: [[String: Any]] = clean
    var toolCallCount = 0
    var effects: [ToolEffect] = []

    // Build the system prompt as TWO blocks so prompt caching fires.
    // Static block is byte-identical across turns (no persona, no date,
    // no athlete state) → cached. Dynamic block carries persona content
    // + today's date + athlete state + recent-conversation summaries →
    // sent fresh every turn.
    let staticPrompt = PromptAssembler.staticBlock()
    let trainingLoadSnapshot = await fetchTrainingLoadSnapshot()
    let recoveryPicture = await fetchRecoveryPicture(trainingLoad: trainingLoadSnapshot)
    let coachState = CoachState(
        today: Date(),
        trainingLoad: trainingLoadSnapshot,
        recoveryPicture: recoveryPicture,
        athleteSummary: nil,
        recentConversationSummaries: recentConversationSummaries
    )
    let dynamicPrompt = PromptAssembler.dynamicBlock(
        personality: personality,
        customText: customText,
        state: coachState
    )

    for _ in 0..<maxRounds {
        // Call Claude via Supabase Edge Function with the two-block shape.
        let response = try await callEdgeFunction(
            staticSystemBlock: staticPrompt,
            dynamicSystemBlock: dynamicPrompt,
            messages: chain,
            tools: coachToolDefinitions,
            maxTokens: 4096
        )

        if response.stopReason == "end_turn" {
            let text = response.content
                .filter { $0.type == "text" }
                .compactMap(\.text)
                .joined()
                .trimmingCharacters(in: .whitespacesAndNewlines)
            return makeResult(text: text, effects: effects, toolCallCount: toolCallCount)
        }

        if response.stopReason == "tool_use" {
            let toolUses = response.content.filter { $0.type == "tool_use" }
            guard !toolUses.isEmpty else {
                let text = response.content.filter { $0.type == "text" }.compactMap(\.text).joined()
                return makeResult(text: text, effects: effects, toolCallCount: toolCallCount)
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
            dataService.activeToolProgress = nil

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
        return makeResult(text: text.isEmpty ? "Done." : text, effects: effects, toolCallCount: toolCallCount)
    }

    return AgentResult(
        response: "I hit my tool limit before finishing. Try again or break your request into smaller pieces.",
        effects: effects,
        toolCallCount: toolCallCount
    )
}

/// Builds an `AgentResult` from the LLM's final text, stripping the
/// suggested-replies marker and populating the structured field.
private func makeResult(text: String, effects: [ToolEffect], toolCallCount: Int) -> AgentResult {
    let parsed = parseAgentResponse(text)
    return AgentResult(
        response: parsed.text,
        effects: effects,
        toolCallCount: toolCallCount,
        suggestedReplies: parsed.suggestedReplies
    )
}

// MARK: - Edge Function Call

private func callEdgeFunction(
    staticSystemBlock: String,
    dynamicSystemBlock: String,
    messages: [[String: Any]],
    tools: [ToolDefinition],
    maxTokens: Int
) async throws -> AnthropicResponse {
    let client = SupabaseService.shared.client

    // Encode tools to JSON-compatible format
    let encoder = JSONEncoder()
    let toolsData = try encoder.encode(tools)
    let toolsJSON = try JSONSerialization.jsonObject(with: toolsData)

    // Anthropic accepts `system` as either a string OR an array of blocks.
    // We send the array form so we can mark the static block as cacheable
    // with `cache_control: ephemeral`. The dynamic block follows without
    // a cache marker — it changes every turn and shouldn't be cached.
    var systemBlocks: [[String: Any]] = []
    if !staticSystemBlock.isEmpty {
        systemBlocks.append([
            "type": "text",
            "text": staticSystemBlock,
            "cache_control": ["type": "ephemeral"],
        ])
    }
    if !dynamicSystemBlock.isEmpty {
        systemBlocks.append([
            "type": "text",
            "text": dynamicSystemBlock,
        ])
    }

    let body: [String: Any] = [
        "system": systemBlocks,
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
        let response = try await client.functions.invoke(
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
        } as AnthropicResponse
        logUsage(response.usage)
        return response
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

/// Emits a one-line log of the call's token usage with cache hit/miss
/// data. Cached reads are billed at ~10% of normal input rate, so the
/// ratio of `cache_read_input_tokens` to `input_tokens + cache_*` over
/// time is the savings indicator.
private func logUsage(_ usage: AnthropicUsage?) {
    guard let usage else { return }
    let input = usage.inputTokens ?? 0
    let output = usage.outputTokens ?? 0
    let cacheRead = usage.cacheReadInputTokens ?? 0
    let cacheCreate = usage.cacheCreationInputTokens ?? 0
    NSLog("[chat] usage  in:\(input)  out:\(output)  cache_read:\(cacheRead)  cache_create:\(cacheCreate)")
}

// MARK: - Streaming Edge Function Call

/// Streaming variant that consumes Anthropic's SSE response through the chat
/// edge function and returns the fully assembled text content. Uses a raw
/// URLSession so we can read the response body incrementally via
/// `URLSession.bytes(for:)` — `supabase-js`'s `functions.invoke` doesn't
/// expose the stream, so we bypass it and hit the edge function directly.
///
/// Streaming removes the wall-clock cliff for long generations: each SSE
/// chunk resets iOS URLSession's internal read timer, so a 90-second
/// generation that would otherwise hit the 60s `timeoutIntervalForRequest`
/// completes without issue.
///
/// `onChunk` is invoked with the accumulated text periodically (throttled
/// so we don't flood the main actor) so callers can surface live progress
/// in the UI. It is also called once after the final chunk arrives.
@MainActor
func callEdgeFunctionStreaming(
    system: String,
    messages: [[String: Any]],
    maxTokens: Int,
    model: String = "claude-sonnet-4-6",
    onChunk: @MainActor @Sendable (String) -> Void = { _ in }
) async throws -> String {
    // Grab the current access token so the edge function's JWT check passes.
    let session = try await SupabaseService.shared.client.auth.session
    let accessToken = session.accessToken

    // These match SupabaseService.swift — safe to embed (RLS protects data).
    let supabaseURL = "https://pfbcsdkbrjdwvrckcnbg.supabase.co"
    let supabaseAnonKey = "sb_publishable_83nhtrTXoM1SvHMrV9BvMA_zIK7rkh0"

    guard let url = URL(string: "\(supabaseURL)/functions/v1/chat") else {
        throw URLError(.badURL)
    }

    var request = URLRequest(url: url)
    request.httpMethod = "POST"
    request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
    request.setValue(supabaseAnonKey, forHTTPHeaderField: "apikey")
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    request.setValue("text/event-stream", forHTTPHeaderField: "Accept")
    // Generous outer ceiling; the stream itself is what actually keeps the
    // connection alive beyond the default 60s.
    request.timeoutInterval = 600

    let body: [String: Any] = [
        "model": model,
        "system": system,
        "messages": messages,
        "max_tokens": maxTokens,
        "stream": true,
    ]
    request.httpBody = try JSONSerialization.data(withJSONObject: body)

    let (bytes, response) = try await URLSession.shared.bytes(for: request)

    guard let http = response as? HTTPURLResponse else {
        throw URLError(.badServerResponse)
    }

    if !(200..<300 ~= http.statusCode) {
        // Drain the body so we can surface a useful error message.
        var errData = Data()
        for try await byte in bytes { errData.append(byte) }
        let preview = String(data: errData, encoding: .utf8) ?? "<non-utf8>"
        NSLog("[chat-stream] HTTP \(http.statusCode): \(preview)")
        throw NSError(
            domain: "ChatStream",
            code: http.statusCode,
            userInfo: [NSLocalizedDescriptionKey: "HTTP \(http.statusCode): \(preview.prefix(300))"]
        )
    }

    var accumulated = ""
    var lastReportedCount = 0
    let reportThreshold = 120 // characters between progress callbacks

    for try await line in bytes.lines {
        // SSE frames look like:
        //
        //     event: content_block_delta
        //     data: {"type":"content_block_delta","index":0,"delta":{"type":"text_delta","text":"Hello"}}
        //
        // Blank lines separate events. We only need the `data:` lines —
        // the JSON body already carries its own `type` field.
        guard line.hasPrefix("data: ") else { continue }
        let payload = String(line.dropFirst("data: ".count))
        guard !payload.isEmpty, payload != "[DONE]" else { continue }

        guard let data = payload.data(using: .utf8),
              let event = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let type = event["type"] as? String else {
            continue
        }

        switch type {
        case "content_block_delta":
            if let delta = event["delta"] as? [String: Any],
               let text = delta["text"] as? String {
                accumulated += text
                if accumulated.count - lastReportedCount >= reportThreshold {
                    lastReportedCount = accumulated.count
                    onChunk(accumulated)
                }
            }
        case "message_stop":
            if accumulated.count != lastReportedCount {
                onChunk(accumulated)
            }
            return accumulated
        default:
            continue
        }
    }

    // Stream ended without an explicit message_stop — still return what we
    // gathered. Callers will fail to decode if the JSON is truncated and
    // surface a helpful error.
    return accumulated
}
