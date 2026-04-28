import Foundation
import Supabase

// MARK: - Memory Merge Helpers

/// Port of mergeMemory and helpers from page.jsx lines 238-336

/// Additive merge: adds unique items to target array
private func mergeAdditive(_ target: inout [String], _ source: [String]) {
    let existing = Set(target)
    for item in source where !item.isEmpty && !existing.contains(item) {
        target.append(item)
    }
}

/// Fuzzy merge: adds items unless they are substrings of existing items (or vice versa)
private func mergeFuzzy(_ target: inout [String], _ source: [String]) {
    for item in source {
        guard !item.isEmpty else { continue }
        let itemLower = item.lowercased()
        let isDupe = target.contains { existing in
            let el = existing.lowercased()
            return el == itemLower
                || (itemLower.count >= 15 && el.contains(itemLower))
                || (el.count >= 15 && itemLower.contains(el))
        }
        if !isDupe { target.append(item) }
    }
}

/// Fuzzy merge for the structured `[CoachingNoteEntry]` list. Compares
/// by `.text` (same dupe rule as the string version) and skips
/// duplicates outright. New entries from extraction land as tracking
/// notes per their original metadata. Existing entries' status /
/// relatedTopic / lastReviewedAt are NOT modified by extraction —
/// those are reserved for the agent's explicit `update_coaching_memory`
/// tool calls so extraction can't accidentally flip a tracking note
/// to resolved.
private func mergeFuzzyNotes(_ target: inout [CoachingNoteEntry], _ source: [CoachingNoteEntry]) {
    for item in source {
        let itemText = item.text
        guard !itemText.isEmpty else { continue }
        let itemLower = itemText.lowercased()
        let isDupe = target.contains { existing in
            let el = existing.text.lowercased()
            return el == itemLower
                || (itemLower.count >= 15 && el.contains(itemLower))
                || (el.count >= 15 && itemLower.contains(el))
        }
        if !isDupe { target.append(item) }
    }
}

/// Merge benchmarks: update existing by metric if newer, otherwise append
private func mergeBenchmarks(_ target: inout [Benchmark], _ source: [Benchmark]) {
    for b in source {
        guard !b.metric.isEmpty else { continue }
        if let idx = target.firstIndex(where: { $0.metric == b.metric }) {
            if target[idx].testDate == nil || (b.testDate != nil && b.testDate! > (target[idx].testDate ?? "")) {
                target[idx] = b
            }
        } else {
            target.append(b)
        }
    }
}

/// Merge injuries: update existing by area, otherwise append
private func mergeInjuries(_ target: inout [InjuryRecord], _ source: [InjuryRecord]) {
    let today = todayString()
    for inj in source {
        guard !inj.area.isEmpty else { continue }
        if let idx = target.firstIndex(where: { $0.id == inj.id || $0.area.lowercased() == inj.area.lowercased() }) {
            var existing = target[idx]
            if !inj.status.isEmpty { existing.status = inj.status }
            if !inj.severity.isEmpty { existing.severity = inj.severity }
            if !inj.triggers.isEmpty { mergeAdditive(&existing.triggers, inj.triggers) }
            if !inj.safeActivities.isEmpty { mergeAdditive(&existing.safeActivities, inj.safeActivities) }
            if !inj.modifications.isEmpty { mergeAdditive(&existing.modifications, inj.modifications) }
            if let rc = inj.returnCriteria, !rc.isEmpty { existing.returnCriteria = rc }
            if !inj.history.isEmpty { existing.history.append(contentsOf: inj.history) }
            existing.lastUpdated = today
            target[idx] = existing
        } else {
            var newInj = inj
            newInj.id = inj.id.isEmpty ? inj.area.lowercased().replacingOccurrences(of: " ", with: "-") : inj.id
            newInj.lastUpdated = today
            target.append(newInj)
        }
    }
}

/// Merge safety rules: add unique by rule text
private func mergeSafetyRules(_ target: inout [SafetyRule], _ source: [SafetyRule]) {
    let today = todayString()
    for r in source {
        guard !r.rule.isEmpty else { continue }
        if !target.contains(where: { $0.rule == r.rule }) {
            target.append(SafetyRule(rule: r.rule, reason: r.reason, addedDate: r.addedDate ?? today))
        }
    }
}

// MARK: - Main Merge Function

/// Merge an update (from AI extraction) into existing coaching memory
func mergeMemory(_ existing: CoachingMemory, _ update: CoachingMemory?) -> CoachingMemory {
    guard let update else { return existing }
    var m = existing

    // Permanent
    mergeAdditive(&m.permanent.equipment, update.permanent.equipment)
    mergeAdditive(&m.permanent.facilities, update.permanent.facilities)
    mergeAdditive(&m.permanent.medicalHistory, update.permanent.medicalHistory)
    mergeAdditive(&m.permanent.dietaryConstraints, update.permanent.dietaryConstraints)

    if update.permanent.schedule.availableDays > 0 {
        m.permanent.schedule.availableDays = update.permanent.schedule.availableDays
    }
    if !update.permanent.schedule.preferredTimes.trimmingCharacters(in: .whitespaces).isEmpty {
        m.permanent.schedule.preferredTimes = update.permanent.schedule.preferredTimes
    }
    mergeAdditive(&m.permanent.schedule.constraints, update.permanent.schedule.constraints)

    if !update.permanent.communicationPrefs.trimmingCharacters(in: .whitespaces).isEmpty {
        m.permanent.communicationPrefs = update.permanent.communicationPrefs
    }
    mergeSafetyRules(&m.permanent.safetyRules, update.permanent.safetyRules)

    // Benchmarks
    mergeBenchmarks(&m.benchmarks, update.benchmarks)

    // Injuries
    mergeInjuries(&m.injuries, update.injuries)

    // Observations
    mergeFuzzy(&m.observations.patterns, update.observations.patterns)
    mergeFuzzy(&m.observations.motivators, update.observations.motivators)
    mergeFuzzyNotes(&m.observations.coachingNotes, update.observations.coachingNotes)
    if !update.observations.consistency.trimmingCharacters(in: .whitespaces).isEmpty {
        m.observations.consistency = update.observations.consistency
    }
    if !update.observations.currentFocus.trimmingCharacters(in: .whitespaces).isEmpty {
        m.observations.currentFocus = update.observations.currentFocus
    }
    mergeAdditive(&m.observations.openItems, update.observations.openItems)

    // Response profile
    let rp = update.responseProfile
    if !rp.volumeVsIntensity.trimmingCharacters(in: .whitespaces).isEmpty { m.responseProfile.volumeVsIntensity = rp.volumeVsIntensity }
    if !rp.recoveryRate.trimmingCharacters(in: .whitespaces).isEmpty { m.responseProfile.recoveryRate = rp.recoveryRate }
    if !rp.easyDayDiscipline.trimmingCharacters(in: .whitespaces).isEmpty { m.responseProfile.easyDayDiscipline = rp.easyDayDiscipline }
    if !rp.sessionPreferences.trimmingCharacters(in: .whitespaces).isEmpty { m.responseProfile.sessionPreferences = rp.sessionPreferences }
    if !rp.communicationNeeds.trimmingCharacters(in: .whitespaces).isEmpty { m.responseProfile.communicationNeeds = rp.communicationNeeds }
    mergeAdditive(&m.responseProfile.skipPatterns, rp.skipPatterns)

    m.lastUpdated = todayString()
    return m
}

// MARK: - Extract Memory from Conversation

/// Calls Claude to extract new facts from recent messages and merges them into memory.
/// Port of extractMemory from page.jsx.
@MainActor
func extractMemory(
    messages: [ChatMessage],
    existingMemory: CoachingMemory,
    dataService: DataService
) async {
    // Only analyze last 8 messages
    let recent = messages.suffix(8)
    guard recent.count >= 2 else { return }

    let conversationText = recent.map { "\($0.role): \($0.content)" }.joined(separator: "\n")

    do {
        let client = SupabaseService.shared.client
        let body: [String: Any] = [
            "system": memoryExtractionPrompt,
            "messages": [["role": "user", "content": conversationText]],
            "max_tokens": 1024,
        ]
        let bodyData = try JSONSerialization.data(withJSONObject: body)
        let anthropicResponse: AnthropicResponse = try await client.functions.invoke(
            "chat",
            options: .init(body: bodyData)
        )
        let text = anthropicResponse.content.first(where: { $0.type == "text" })?.text ?? ""


        // Try to parse the JSON from the response
        let jsonDecoder = JSONDecoder()
        guard let jsonData = text.data(using: .utf8),
              let update = try? jsonDecoder.decode(CoachingMemory.self, from: jsonData) else {
            return
        }

        let merged = mergeMemory(existingMemory, update)
        try await dataService.saveMemory(merged)
    } catch {
        // Memory extraction is best-effort — don't disrupt the user experience
        print("Memory extraction failed: \(error)")
    }
}
