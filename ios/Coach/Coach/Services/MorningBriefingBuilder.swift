import Foundation

/// Builds the morning briefing chat message with rich content components.
/// Called when the Coach tab opens with an empty conversation. Uses the
/// existing coach note (from CoachNoteGenerator) as the text, and attaches
/// workout cards, week summary, race countdown, and phase progress.
@MainActor
enum MorningBriefingBuilder {

    /// Assembles a ChatMessage with the coach note text and rich content
    /// from the current plan state. Returns nil if there's nothing to show.
    static func build(
        coachNote: PushMessage?,
        plan: TrainingPlan?,
        events: [Event],
        cardio: [CardioWorkout],
        strength: [StrengthSession],
        conversationId: String?
    ) -> ChatMessage? {
        let text = coachNote?.text ?? morningGreeting()
        var components: [RichComponent] = []

        // Race countdown
        if let race = primaryRace(events: events) {
            let weeksOut = weeksUntil(dateStr: race.date)
            if let weeksOut, weeksOut > 0 {
                components.append(.raceCountdown(name: race.name, weeksOut: weeksOut))
            }
        }

        // Today's workout cards
        if let plan {
            let todayIdx = todayDayIndex()
            let weekNum = plan.currentWeek
            if let wp = plan.weeklyPlans[String(weekNum)],
               todayIdx < wp.sessions.count {
                let dayPlan = wp.sessions[todayIdx]
                if dayPlan.isRest != true {
                    for (sessionIdx, session) in dayPlan.sessions.enumerated() {
                        components.append(.workoutCard(
                            session: session,
                            weekNum: weekNum,
                            dayIdx: todayIdx,
                            sessionIdx: sessionIdx
                        ))
                    }
                }
            }

            // Week summary
            if let adherence = computeWeekAdherence(
                plan: plan,
                weekNum: weekNum,
                cardio: cardio,
                strength: strength
            ) {
                let dots = adherence.days.map { day -> DotStatus in
                    if day.isRest { return .rest }
                    if day.isToday { return .today }
                    if day.sessions.isEmpty { return .pending }
                    let statuses = day.sessions.map(\.status)
                    if statuses.allSatisfy({ $0 == .completed }) { return .completed }
                    if statuses.contains(.missed) { return .skipped }
                    if statuses.contains(.substituted) { return .swapped }
                    if statuses.contains(.shortened) { return .modified }
                    if statuses.contains(.today) { return .today }
                    return .pending
                }
                components.append(.weekSummary(
                    dots: dots,
                    sessionsCompleted: adherence.completed,
                    total: adherence.prescribed,
                    adherence: Double(adherence.adherence) / 100.0
                ))
            }

            // Phase progress
            if let phase = plan.phases.first(where: { $0.number == plan.currentPhase }) {
                let weeksLeft = phase.weeks - plan.weekIndexInPhase(phase)
                components.append(.phaseProgress(
                    phaseName: phase.name,
                    phaseNumber: phase.number,
                    totalPhases: plan.phases.count,
                    weeksLeft: max(0, weeksLeft)
                ))
            }
        }

        // If we have nothing — no note and no plan — skip the briefing
        if text.isEmpty && components.isEmpty { return nil }

        return ChatMessage.assistant(
            text,
            conversationId: conversationId,
            richContent: components.isEmpty ? nil : components
        )
    }

    // MARK: - Helpers

    /// Monday-based day index: 0=Mon, 1=Tue, ..., 6=Sun
    private static func todayDayIndex() -> Int {
        (Calendar.current.component(.weekday, from: Date()) + 5) % 7
    }

    private static func primaryRace(events: [Event]) -> Event? {
        events
            .filter { $0.mode == .race && !$0.completed && $0.date != nil }
            .sorted { ($0.date ?? "") < ($1.date ?? "") }
            .first
    }

    private static func weeksUntil(dateStr: String?) -> Int? {
        guard let dateStr else { return nil }
        let fmt = DateFormatter()
        fmt.dateFormat = "yyyy-MM-dd"
        guard let date = fmt.date(from: dateStr) else { return nil }
        let days = Calendar.current.dateComponents([.day], from: Date(), to: date).day ?? 0
        return max(0, days / 7)
    }

    private static func morningGreeting() -> String {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 0..<12: return "Good morning. What's on your mind?"
        case 12..<17: return "Good afternoon. How can I help?"
        default: return "Good evening. How's it going?"
        }
    }
}
