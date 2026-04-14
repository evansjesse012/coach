import Foundation

// MARK: - Match Result

/// Output of the matching pipeline for a single HealthKit-sourced workout.
struct WorkoutMatchResult {
    let confidence: MatchConfidence
    let session: SessionCoordinates?   // nil for .none
    let score: Int                     // raw score (0 when .none)
}

/// Confidence level mapping from raw score.
enum MatchConfidence {
    case high      // >= 70 — auto-pair silently
    case medium    // 40-69 — auto-pair + flag needsReview
    case low       // 1-39 — don't pair; surface as unmatched
    case none      // no candidates at all
}

/// Points to a prescribed session by its position in the weekly plan tree.
struct SessionCoordinates: Equatable {
    let weekNum: Int
    let dayIdx: Int
    let sessionIdx: Int
}

/// A candidate session plus the coordinates needed to write back to the plan.
struct MatchCandidate {
    let session: PrescribedSession
    let coords: SessionCoordinates
}

// MARK: - Matcher

/// Matches a HealthKit-imported CardioWorkout to a prescribed training session.
/// Pure logic — no side effects, no DataService access. The caller is
/// responsible for gathering candidates and applying the result.
enum WorkoutMatcher {

    /// Score breakdown constants from the spec.
    private static let sportPoints = 40
    private static let durationInRangePoints = 30
    private static let durationWithin20PercentPoints = 15
    private static let timeOfDayProximityPoints = 15
    private static let zoneMatchPoints = 15
    private static let zoneAdjacentPoints = 5

    private static let highConfidenceThreshold = 70
    private static let mediumConfidenceThreshold = 40

    /// Runs the matching pipeline. `candidates` should be all unresolved
    /// prescribed sessions for today (and optionally yesterday-after-8pm /
    /// tomorrow-before-6am). The caller pre-filters by date.
    static func match(
        workout: CardioWorkout,
        against candidates: [MatchCandidate]
    ) -> WorkoutMatchResult {
        guard !candidates.isEmpty else {
            return WorkoutMatchResult(confidence: .none, session: nil, score: 0)
        }

        // Step 1: sport type filter. If nothing matches sport, bail with .none.
        let sportMatching = candidates.filter { sportMatches(workout: workout, session: $0.session) }
        guard !sportMatching.isEmpty else {
            return WorkoutMatchResult(confidence: .none, session: nil, score: 0)
        }

        // Step 2: score each sport-matching candidate.
        var scored: [(candidate: MatchCandidate, score: Int)] = []
        for candidate in sportMatching {
            let score = computeScore(workout: workout, session: candidate.session, sportMatchingPeers: sportMatching)
            scored.append((candidate, score))
        }

        // Step 3: pick the highest-scoring candidate.
        guard let best = scored.max(by: { $0.score < $1.score }) else {
            return WorkoutMatchResult(confidence: .none, session: nil, score: 0)
        }

        // Step 4: map score to confidence level.
        let confidence: MatchConfidence
        if best.score >= highConfidenceThreshold {
            confidence = .high
        } else if best.score >= mediumConfidenceThreshold {
            confidence = .medium
        } else {
            confidence = .low
        }

        return WorkoutMatchResult(
            confidence: confidence,
            session: best.candidate.coords,
            score: best.score
        )
    }

    // MARK: - Scoring

    private static func computeScore(
        workout: CardioWorkout,
        session: PrescribedSession,
        sportMatchingPeers: [MatchCandidate]
    ) -> Int {
        var score = 0

        // Sport match: always +40 since we pre-filtered.
        score += sportPoints

        // Duration scoring.
        score += durationScore(workout: workout, session: session)

        // Time-of-day proximity — only meaningful when >1 same-sport session.
        if sportMatchingPeers.count > 1 {
            score += timeOfDayScore(workout: workout, session: session, peers: sportMatchingPeers)
        }

        // Zone alignment if HR data is available.
        score += zoneScore(workout: workout, session: session)

        return score
    }

    /// Duration is in range → +30. Within 20% of range bounds → +15. Else 0.
    private static func durationScore(workout: CardioWorkout, session: PrescribedSession) -> Int {
        let (lo, hi) = prescribedRange(for: session)
        guard lo > 0, hi > 0 else { return 0 }

        let actual = workout.duration
        if actual >= lo && actual <= hi {
            return durationInRangePoints
        }

        // Within 20% of the nearest bound counts as "close".
        let tolerance = 0.20
        let loPad = Int(Double(lo) * (1.0 - tolerance))
        let hiPad = Int(Double(hi) * (1.0 + tolerance))
        if actual >= loPad && actual <= hiPad {
            return durationWithin20PercentPoints
        }

        return 0
    }

    /// Pull prescribed duration bounds from estimatedDurationMin/Max if set,
    /// else fall back to a ±10% window around `duration`, else (0, 0) which
    /// effectively disables the duration score.
    private static func prescribedRange(for session: PrescribedSession) -> (Int, Int) {
        if let lo = session.estimatedDurationMin, let hi = session.estimatedDurationMax, lo > 0, hi > 0 {
            return (lo, hi)
        }
        if let d = session.duration, d > 0 {
            let lo = Int(Double(d) * 0.9)
            let hi = Int(Double(d) * 1.1)
            return (lo, hi)
        }
        return (0, 0)
    }

    /// Among same-sport peers, the one whose prescribed time-of-day is closest
    /// to the workout's start time wins. For phase 2 we don't have a
    /// time-of-day field on PrescribedSession, so peers are currently
    /// equivalent — return 0 to all peers. This lets the duration + zone
    /// signals dominate tiebreaking until we add a time field in a later phase.
    private static func timeOfDayScore(
        workout: CardioWorkout,
        session: PrescribedSession,
        peers: [MatchCandidate]
    ) -> Int {
        // Phase 2 placeholder: prescribed sessions don't carry a time-of-day
        // attribute yet. Return 0 for everyone so the duration + zone scores
        // break ties instead. When prescribed start times exist, compute
        // absolute minute-of-day difference and award the closest peer +15.
        return 0
    }

    /// Zone/intensity alignment: if we have avg HR on the workout and a zone
    /// on the session, award points for an exact match or adjacent zone.
    /// Uses a simple HR→zone mapping anchored on max HR 190 as a placeholder
    /// until user thresholds are stored in CoachingMemory.
    private static func zoneScore(workout: CardioWorkout, session: PrescribedSession) -> Int {
        guard let actualHR = workout.avgHR, actualHR > 0,
              let zoneStr = session.zone,
              let prescribedZone = parseZone(zoneStr) else {
            return 0
        }
        let actualZone = hrZone(for: actualHR)
        let diff = abs(actualZone - prescribedZone)
        if diff == 0 { return zoneMatchPoints }
        if diff == 1 { return zoneAdjacentPoints }
        return 0
    }

    private static func parseZone(_ s: String) -> Int? {
        // Accepts "Z1" through "Z5" (any case), or a bare "1"-"5".
        let trimmed = s.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        if trimmed.hasPrefix("Z"), let n = Int(trimmed.dropFirst()) {
            return (1...5).contains(n) ? n : nil
        }
        if let n = Int(trimmed) {
            return (1...5).contains(n) ? n : nil
        }
        return nil
    }

    /// Rough HR → zone mapping using %max-HR bands with max HR 190.
    /// Z1 < 60%, Z2 60-70%, Z3 70-80%, Z4 80-90%, Z5 90%+.
    private static func hrZone(for hr: Int) -> Int {
        let maxHR: Double = 190
        let pct = Double(hr) / maxHR
        if pct < 0.60 { return 1 }
        if pct < 0.70 { return 2 }
        if pct < 0.80 { return 3 }
        if pct < 0.90 { return 4 }
        return 5
    }

    // MARK: - Sport matching

    /// Maps CardioWorkout.sport to the set of prescribed session `type` strings
    /// that should count as a match.
    private static func sportMatches(workout: CardioWorkout, session: PrescribedSession) -> Bool {
        let sessionType = session.type.lowercased()
        switch workout.sport {
        case .run:
            return sessionType == "run"
        case .bike:
            return sessionType == "bike"
        case .swim:
            return sessionType == "swim"
        case .hike:
            // Hikes are valid for hike-typed sessions; also count as a running
            // substitute if the athlete went "hiking instead of running".
            return sessionType == "hike" || sessionType == "run"
        case .strength:
            return sessionType == "strength"
        case .brick:
            return sessionType == "brick"
        case .other:
            // .other covers yoga / flexibility / unknown — don't auto-match.
            return false
        }
    }
}
