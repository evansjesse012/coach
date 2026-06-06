#if DEBUG
import Foundation

// MARK: - Sample coach artifacts (DEBUG only)
//
// Throwaway sample WeeklyPreview / WeeklyReview values so the week-detail
// preview and review cards are visible WITHOUT real check-in data. These are
// never compiled into a release build, never written to the database, and
// never involve an AI call.
//
// To remove: delete this file and the `#if DEBUG` fallback in
// `WeekDetailView.weeklyArtifactsBlock`.
//
// The ids are fixed so SwiftUI keeps each card's expand/collapse state stable
// across re-renders.

extension WeeklyPreview {
    static func sample(weekStart: String? = nil, weekEnd: String? = nil) -> WeeklyPreview {
        WeeklyPreview(
            id: UUID(uuidString: "00000000-0000-0000-0000-0000000000A1")!,
            userId: nil,
            weekStartDate: weekStart ?? "2026-06-02",
            weekEndDate: weekEnd ?? "2026-06-08",
            createdAt: nil,
            pairedReviewId: nil,
            theme: "Building aerobic base while protecting the long ride.",
            themeCategory: "build",
            macroPosition: "Week 4 of 20 \u{00B7} 16 weeks to race day",
            totalPlannedHours: 10.65,
            totalPlannedDistance: 28.0,
            totalPlannedTss: nil,
            deltaFromPreviousWeekPct: 6,
            numQualitySessions: 2,
            numEasySessions: 4,
            keySessions: [],
            watchOuts: [],
            tacticalNotes: [],
            lifeManagementNotes: [],
            renderedProse: """
            This week is about volume you can absorb, not volume that breaks you. \
            Three easy aerobic sessions anchor the block — keep them genuinely \
            conversational, even if the pace feels slow. Saturday's long ride is the \
            centerpiece: it's your biggest aerobic stimulus of the week, so everything \
            else exists to keep you fresh enough to ride it well.

            If life gets loud, protect the long ride and the one quality swim. The \
            midweek runs are the first thing to trim — losing one won't cost you \
            fitness, but skipping the long ride two weeks running will.
            """,
            closingQuestion: "How's the body feeling heading into Saturday's bigger ride?",
            readAt: nil,
            rereadCount: 0,
            respondedTo: false
        )
    }
}

extension WeeklyReview {
    static func sample(weekStart: String? = nil, weekEnd: String? = nil) -> WeeklyReview {
        WeeklyReview(
            id: UUID(uuidString: "00000000-0000-0000-0000-0000000000B2")!,
            userId: nil,
            weekStartDate: weekStart ?? "2026-05-26",
            weekEndDate: weekEnd ?? "2026-06-01",
            createdAt: nil,
            completedAt: "2026-06-01T08:15:00Z",
            sleepAvgHours: 7.2,
            energyRating: 7,
            motivationRating: 8,
            sorenessLevel: .mild,
            sorenessLocation: nil,
            painFlag: false,
            painDescription: nil,
            lifeStressRating: 5,
            bodyWeight: nil,
            adherencePct: 82,
            bestSessionText: "Saturday long ride felt strong start to finish.",
            bestSessionId: nil,
            worstSessionText: "Wednesday ride — legs were flat after travel.",
            worstSessionId: nil,
            lifeContext: "Two days of work travel midweek.",
            questions: nil,
            nextWeekFocus: "Consistency on the bike.",
            aiResponseText: """
            Solid week overall — you held the parts that matter most. Both swims \
            happened and the strength work stayed on track, which is exactly the \
            foundation this phase needs.

            The bike got squeezed: Wednesday's ride was cut short and Thursday's didn't \
            happen. Given the work travel you flagged, that's a reasonable trade — you \
            protected sleep and still got the key aerobic sessions in. No need to chase \
            the missed time; we'll carry the intent into next week instead.
            """,
            aiResponseComponents: WeeklyReview.AIResponseComponents(
                lifeAcknowledgment: nil,
                weekAssessment: "Swim and strength held. Bike got truncated.",
                sessionFeedback: [],
                patternCallout: nil,
                questionsAnswered: [],
                bridgeToNextWeek: "Reclaim one of the two midweek rides — aim for both, accept one."
            ),
            patternsDetected: [
                "Bike sessions slip first when travel hits — try front-loading them earlier in the week.",
                "Strength adherence is rock solid three weeks running."
            ]
        )
    }
}
#endif
