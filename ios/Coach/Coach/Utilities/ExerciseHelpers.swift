import Foundation

// MARK: - String Slugification

extension String {
    /// Convert exercise name to a slug for PR keying
    var slugified: String {
        lowercased()
            .replacingOccurrences(of: "[^a-z0-9]+", with: "-", options: .regularExpression)
            .trimmingCharacters(in: CharacterSet(charactersIn: "-"))
    }
}

// MARK: - Epley Formula

/// Estimate 1-rep max from weight and reps using the Epley formula
func epley1RM(weight: Double, reps: Int) -> Double {
    guard reps > 0 else { return 0 }
    if reps == 1 { return weight }
    return weight * (1 + Double(reps) / 30.0)
}

// MARK: - PR Computation

/// Determine if a new set is a PR improvement
func isPRBetter(current: PersonalRecord?, weight: Double?, reps: Int?, duration: Double?, band: String?, type: ExerciseType) -> Bool {
    guard let current else { return true }
    switch type {
    case .weighted:
        guard let w = weight, let r = reps, w > 0, r > 0 else { return false }
        let new1RM = epley1RM(weight: w, reps: r)
        return new1RM > (current.estimated1RM ?? 0)
    case .bodyweight, .cardioDrill:
        guard let r = reps, r > 0 else { return false }
        return r > (current.bestReps ?? 0)
    case .timed:
        guard let d = duration, d > 0 else { return false }
        return d > (current.bestDuration ?? 0)
    case .banded:
        // Band PRs: heavier band wins, then more reps
        guard let b = band, let r = reps else { return false }
        let bandOrder = ["light": 1, "medium": 2, "heavy": 3]
        let newLevel = bandOrder[b.lowercased()] ?? 0
        let currentLevel = bandOrder[current.band?.lowercased() ?? ""] ?? 0
        if newLevel > currentLevel { return true }
        if newLevel == currentLevel { return r > (current.bestReps ?? 0) }
        return false
    }
}

/// Compute the current PR from a completed exercise set
func computeExercisePR(existing: PersonalRecord?, name: String, set: ExerciseSet, type: ExerciseType) -> PersonalRecord? {
    let slug = name.slugified

    switch type {
    case .weighted:
        guard let w = set.weight, let r = set.reps, w > 0, r > 0 else { return nil }
        let est = epley1RM(weight: w, reps: r)
        if !isPRBetter(current: existing, weight: w, reps: r, duration: nil, band: nil, type: type) { return nil }
        let entry = PRHistoryEntry(weight: w, reps: r, estimated1RM: est, date: todayString())
        var history = existing?.history ?? []
        history.append(entry)
        return PersonalRecord(exerciseSlug: slug, exerciseType: type, weight: w, reps: r, estimated1RM: est, date: todayString(), history: history)

    case .bodyweight, .cardioDrill:
        guard let r = set.reps, r > 0 else { return nil }
        if !isPRBetter(current: existing, weight: nil, reps: r, duration: nil, band: nil, type: type) { return nil }
        let entry = PRHistoryEntry(reps: r, date: todayString())
        var history = existing?.history ?? []
        history.append(entry)
        return PersonalRecord(exerciseSlug: slug, exerciseType: type, bestReps: r, date: todayString(), history: history)

    case .timed:
        guard let d = set.duration, d > 0 else { return nil }
        if !isPRBetter(current: existing, weight: nil, reps: nil, duration: d, band: nil, type: type) { return nil }
        let entry = PRHistoryEntry(duration: d, date: todayString())
        var history = existing?.history ?? []
        history.append(entry)
        return PersonalRecord(exerciseSlug: slug, exerciseType: type, bestDuration: d, date: todayString(), history: history)

    case .banded:
        guard let b = set.band, let r = set.reps else { return nil }
        if !isPRBetter(current: existing, weight: nil, reps: r, duration: nil, band: b, type: type) { return nil }
        let entry = PRHistoryEntry(reps: r, band: b, date: todayString())
        var history = existing?.history ?? []
        history.append(entry)
        return PersonalRecord(exerciseSlug: slug, exerciseType: type, bestReps: r, band: b, date: todayString(), history: history)
    }
}

/// Format a PR for display
func formatPR(_ pr: PersonalRecord) -> String {
    switch pr.exerciseType {
    case .weighted:
        if let w = pr.weight, let r = pr.reps {
            return "\(Int(w)) lbs x \(r) (est 1RM: \(Int(pr.estimated1RM ?? 0)))"
        }
    case .bodyweight, .cardioDrill:
        if let r = pr.bestReps { return "\(r) reps" }
    case .timed:
        if let d = pr.bestDuration { return "\(Int(d))s" }
    case .banded:
        if let b = pr.band, let r = pr.bestReps { return "\(b) band x \(r)" }
    }
    return "—"
}
