import Foundation
import SwiftUI

/// View-layer presentation of a phase in the journey timeline. Derived
/// from the persistence model `TrainingPhase` plus the plan's `currentWeek`,
/// so the timeline / detail card don't have to reach back into raw plan
/// state on every render. Constructed via `TrainingPlan.seasonPhases`.
///
/// Built to fit any plan the AI generates — no hardcoded names, no
/// hardcoded counts. The display label, status, and per-phase progress
/// are all computed from the underlying `TrainingPhase`.
struct SeasonPhase: Identifiable {
    let id: Int
    /// Technical phase name, e.g. "Race-Specific Peak". Used as the title
    /// in the detail card and as the navigation push title.
    let name: String
    /// Multi-line label for the timeline tick. Single-word names render
    /// as one line; multi-word names break before the last word so the
    /// label stays narrow above a phase tick. Embeds an explicit `\n`.
    let displayName: String
    let weeks: Int
    /// First and last week numbers this phase occupies in the plan
    /// (1-indexed, inclusive). Used by the detail card as a fallback for
    /// the date range when calendar dates aren't on the underlying
    /// `TrainingPhase` (e.g. legacy plan rows).
    let startWeek: Int
    let endWeek: Int
    let startDate: Date?
    let endDate: Date?
    let status: PhaseStatus
    /// 1-indexed week within the phase (e.g. 3 means the athlete is in
    /// week 3 of this phase). Set only when `status == .current`.
    let weekProgressInPhase: Int?
    /// Weeks from now until this phase begins. Set only when `.upcoming`.
    let weeksUntilStart: Int?
    /// Phase philosophy / focus paragraph for the detail card body.
    let focusText: String?
    /// Pre-formatted weekly volume range, e.g. "8–10.5h" or "30–40mi".
    /// Falls back to the legacy `weeklyVolume` string when the structured
    /// `weeklyVolumeRange` is absent.
    let volumeDisplay: String?
    let sessionsPerWeek: Int?
    let easyWorkPercentage: Int?
    let keySessions: [KeySession]
}

enum PhaseStatus {
    case completed
    case current
    case upcoming
}

/// A featured workout within a phase. `discipline` is inferred from the
/// workout name via keyword match, `nil` when no markers hit — the
/// renderer should show a neutral dot in that case rather than guessing.
struct KeySession: Identifiable {
    let id = UUID()
    let discipline: Theme.Discipline?
    let name: String
    let detail: String
}

// MARK: - Derivation from TrainingPlan

extension TrainingPlan {
    /// Build the timeline-ready phase list from this plan's underlying
    /// `phases` array plus `currentPhase` / `currentWeek`. Phases are
    /// returned in order by `number`. Safe on plans with no phases —
    /// returns an empty array.
    var seasonPhases: [SeasonPhase] {
        let sorted = phases.sorted { $0.number < $1.number }
        return sorted.map { phase in
            let cumulativeBefore = weeksBefore(phaseNumber: phase.number, in: sorted)
            let status: PhaseStatus = {
                if phase.number < currentPhase { return .completed }
                if phase.number == currentPhase { return .current }
                return .upcoming
            }()

            // weekProgressInPhase: only meaningful for the current phase.
            // Clamp to the phase's range so a slightly stale `currentWeek`
            // can't produce a value past `phase.weeks`.
            let weekProgressInPhase: Int? = {
                guard status == .current else { return nil }
                let raw = currentWeek - cumulativeBefore
                return max(1, min(phase.weeks, raw))
            }()

            // weeksUntilStart: phases that haven't begun yet. The phase
            // starts on the first week after `cumulativeBefore`, so the
            // distance from `currentWeek` is `cumulativeBefore + 1 - currentWeek`.
            let weeksUntilStart: Int? = {
                guard status == .upcoming else { return nil }
                return max(0, cumulativeBefore + 1 - currentWeek)
            }()

            return SeasonPhase(
                id: phase.number,
                name: phase.name,
                displayName: SeasonPhase.makeDisplayName(from: phase.name),
                weeks: phase.weeks,
                startWeek: cumulativeBefore + 1,
                endWeek: cumulativeBefore + phase.weeks,
                startDate: SeasonPhase.parseDate(phase.startDate),
                endDate: SeasonPhase.parseDate(phase.endDate),
                status: status,
                weekProgressInPhase: weekProgressInPhase,
                weeksUntilStart: weeksUntilStart,
                focusText: phase.philosophy ?? phase.focus,
                volumeDisplay: SeasonPhase.formatVolume(phase.weeklyVolumeRange) ?? phase.weeklyVolume,
                sessionsPerWeek: phase.sessionsPerWeek,
                easyWorkPercentage: phase.intensityDistribution?.easy,
                keySessions: (phase.keyWorkouts ?? []).map { kw in
                    KeySession(
                        discipline: SeasonPhase.inferDiscipline(name: kw.name, detail: kw.description),
                        name: kw.name,
                        detail: kw.description
                    )
                }
            )
        }
    }

    private func weeksBefore(phaseNumber n: Int, in sorted: [TrainingPhase]) -> Int {
        sorted.filter { $0.number < n }.reduce(0) { $0 + $1.weeks }
    }
}

// MARK: - Helpers

extension SeasonPhase {
    /// Produce a multi-line label from the technical phase name. Splits
    /// before the last word so "Race-Specific Peak" → "Race-Specific\nPeak"
    /// and "Threshold Introduction" → "Threshold\nIntroduction". Single
    /// words pass through unchanged. The renderer must respect explicit
    /// `\n` rather than relying on word-wrap (per the redesign spec).
    static func makeDisplayName(from name: String) -> String {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        let parts = trimmed.split(separator: " ", omittingEmptySubsequences: true)
        guard parts.count >= 2 else { return trimmed }
        let last = String(parts.last!)
        let head = parts.dropLast().joined(separator: " ")
        return "\(head)\n\(last)"
    }

    static func parseDate(_ s: String?) -> Date? {
        guard let s, !s.isEmpty else { return nil }
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f.date(from: s)
    }

    /// Compact display string for a `VolumeRange`, e.g.
    /// `VolumeRange(min: 8, max: 10.5, unit: "hours")` → `"8–10.5h"`.
    /// Trims `.0` so whole numbers don't render as `"8.0–10.0h"`.
    static func formatVolume(_ v: VolumeRange?) -> String? {
        guard let v else { return nil }
        let unitShort: String = {
            switch v.unit.lowercased() {
            case "hours", "hrs", "hr": return "h"
            case "miles", "mi":        return "mi"
            case "km", "kilometers":   return "km"
            default:                   return v.unit
            }
        }()
        return "\(formatNumber(v.min))–\(formatNumber(v.max))\(unitShort)"
    }

    private static func formatNumber(_ n: Double) -> String {
        n.truncatingRemainder(dividingBy: 1) == 0
            ? String(Int(n))
            : String(format: "%g", n)
    }

    /// Best-effort discipline tag for a key workout. Scans the name and
    /// detail for discipline keywords; returns nil when nothing matches
    /// so the renderer can show a neutral dot instead of mis-tagging.
    /// More specific tokens (e.g. "brick") are checked first to avoid
    /// false positives from the broader keyword set.
    static func inferDiscipline(name: String, detail: String) -> Theme.Discipline? {
        let haystack = "\(name) \(detail)".lowercased()
        // Specific compound first.
        if matches(haystack, pattern: #"\bbrick\b"#) { return .bike }
        if matches(haystack, pattern: #"\b(swim|swimming|pool|open\s*water|owr|kick|pull)\b"#) {
            return .swim
        }
        if matches(haystack, pattern: #"\b(bike|biking|ride|riding|cycle|cycling|trainer|spin|spin\s*bike|watt(s|age)?)\b"#) {
            return .bike
        }
        if matches(haystack, pattern: #"\b(run|running|jog|jogging|tempo|track|fartlek|strides?|interval(s)?|hill\s*repeat(s)?)\b"#) {
            return .run
        }
        if matches(haystack, pattern: #"\b(strength|lift|lifting|squat|deadlift|press|gym|core|stability|mobility|hypertrophy)\b"#) {
            return .strength
        }
        if matches(haystack, pattern: #"\b(recovery|rest|easy\s*spin|shake[-\s]*out|walk)\b"#) {
            return .recovery
        }
        return nil
    }

    private static func matches(_ s: String, pattern: String) -> Bool {
        s.range(of: pattern, options: .regularExpression) != nil
    }
}
