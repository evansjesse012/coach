import SwiftUI

// MARK: - Daily View State

private enum DailyViewState {
    case preWorkout
    case postWorkout
}

/// The primary tab — a minimal daily view that answers: What am I doing
/// today? Why? Am I on track? Post-workout, it transforms in-place to
/// show a coach observation + RPE input + tomorrow preview.
struct CoachTab: View {
    @Environment(DataService.self) var data
    @Environment(\.colorScheme) var colorScheme
    @State private var showSettings = false
    @State private var showCoachChat = false
    @State private var completionSheet: ChatCompletionSheet?
    @State private var reviewingMatch: MatchReviewData?
    @State private var postWorkoutObservation: String?
    @State private var selectedRPE: RPELevel?
    @State private var rpeNote: String = ""

    private var viewState: DailyViewState {
        guard let plan = data.trainingPlan,
              let wp = plan.weeklyPlans[String(plan.currentWeek)] else { return .preWorkout }
        let dayIdx = todayDayIndex()
        guard dayIdx < wp.sessions.count else { return .preWorkout }
        let dayPlan = wp.sessions[dayIdx]
        if dayPlan.isRest == true { return .preWorkout }
        if dayPlan.sessions.isEmpty { return .preWorkout }
        let allResolved = dayPlan.sessions.allSatisfy { $0.completionStatus != nil }
        return allResolved ? .postWorkout : .preWorkout
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    switch viewState {
                    case .preWorkout:
                        preWorkoutView
                    case .postWorkout:
                        postWorkoutView
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 80)
            }
            .background((colorScheme == .dark ? CoachColors.darkBg : CoachColors.lightBg).ignoresSafeArea())
            .navigationTitle("Coach")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showSettings = true } label: {
                        Image(systemName: "gearshape")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .overlay(alignment: .bottomTrailing) {
                FloatingCoachButton { showCoachChat = true }
                    .padding(.trailing, 18)
                    .padding(.bottom, 16)
            }
            .sheet(isPresented: $showSettings) {
                NavigationStack { SettingsView() }
            }
            .sheet(isPresented: $showCoachChat) {
                NavigationStack {
                    CoachChatSheet()
                        .toolbar {
                            ToolbarItem(placement: .cancellationAction) {
                                Button { showCoachChat = false } label: {
                                    Image(systemName: "xmark.circle.fill")
                                        .font(.system(size: 22))
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                }
                .presentationDetents([.large, .medium])
                .presentationDragIndicator(.visible)
            }
            .sheet(item: $completionSheet) { sheet in
                completionSheetContent(sheet)
            }
            .sheet(item: $reviewingMatch) { match in
                MatchReviewSheet(match: match) {
                    // Confirm: clear needsReview flag
                    Task {
                        let now = ISO8601DateFormatter().string(from: Date())
                        try? await data.updateSessionCompletion(
                            weekNum: match.weekNum, dayIdx: match.dayIdx, sessionIdx: match.sessionIdx
                        ) { s in
                            s.completionNeedsReview = false
                            s.completionResolvedAt = now
                        }
                    }
                    reviewingMatch = nil
                }
            }
        }
        .task {
            await data.ensurePlanPreGenerated()
        }
        .onAppear {
            if data.pendingChatPrompt != nil { showCoachChat = true }
        }
        .onChange(of: data.pendingChatPrompt) { _, newVal in
            if newVal != nil { showCoachChat = true }
        }
    }

    // ┌──────────────────────────────────────────────────────────────────┐
    // │                      PRE-WORKOUT VIEW                           │
    // └──────────────────────────────────────────────────────────────────┘

    private var preWorkoutView: some View {
        VStack(alignment: .leading, spacing: 16) {
            raceGoalBar
            statusLine
            todayHeroCard
            coachWhySection
            weekStrip
            planPositionLine
            quickActions
        }
    }

    // MARK: 1 — Race / Goal Bar

    @ViewBuilder
    private var raceGoalBar: some View {
        if let plan = data.trainingPlan,
           let goalId = plan.goalId,
           let event = data.events.first(where: { $0.id == goalId }),
           let dateStr = event.date ?? plan.raceDate,
           let weeksOut = weeksUntil(dateStr), weeksOut > 0 {
            NavigationLink {
                if event.isRace {
                    RaceDetailView(eventId: event.id)
                } else {
                    GoalDetailView(eventId: event.id)
                }
            } label: {
                HStack(spacing: 6) {
                    Text(event.name)
                        .font(CoachFonts.ui(12, weight: .semibold))
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                    Text("\u{00B7}")
                        .foregroundStyle(.tertiary)
                    Text("\(weeksOut) weeks")
                        .font(CoachFonts.mono(12, weight: .medium))
                        .foregroundStyle(CoachColors.accent)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(.tertiary)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(CoachColors.accent.opacity(0.06))
                .clipShape(RoundedRectangle(cornerRadius: 10))
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: 2 — Status Line

    @ViewBuilder
    private var statusLine: some View {
        let msg = data.settings.pushMessage
        let readiness = msg?.readiness ?? "green"
        let text = msg?.statusLine ?? "Ready to train."

        HStack(spacing: 8) {
            Circle()
                .fill(readinessColor(readiness))
                .frame(width: 8, height: 8)
            Text(text)
                .font(CoachFonts.ui(13))
                .foregroundStyle(.primary)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func readinessColor(_ level: String) -> Color {
        switch level {
        case "red": return CoachColors.red
        case "yellow": return CoachColors.yellow
        default: return CoachColors.green
        }
    }

    // MARK: 3 — Today's Hero Workout Card

    @ViewBuilder
    private var todayHeroCard: some View {
        if let plan = data.trainingPlan,
           let wp = plan.weeklyPlans[String(plan.currentWeek)] {
            let dayIdx = todayDayIndex()
            if dayIdx < wp.sessions.count {
                let dayPlan = wp.sessions[dayIdx]
                if dayPlan.isRest == true {
                    restDayHero
                } else {
                    ForEach(Array(dayPlan.sessions.enumerated()), id: \.offset) { sessionIdx, session in
                        heroCard(session: session, weekNum: plan.currentWeek, dayIdx: dayIdx, sessionIdx: sessionIdx)
                    }
                }
            }
        }
    }

    private func heroCard(session: PrescribedSession, weekNum: Int, dayIdx: Int, sessionIdx: Int) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header: sport badge + name
            NavigationLink {
                PrescribedSessionDetailView(session: session, dateString: todayString())
            } label: {
                VStack(alignment: .leading, spacing: 8) {
                    if let sport = Sport(rawValue: session.type.lowercased()) {
                        SportBadge(sport: sport)
                    }
                    Text(session.label)
                        .font(CoachFonts.display(20, weight: .bold))
                        .foregroundStyle(.primary)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)

                    if let purpose = session.purpose, !purpose.isEmpty {
                        Text(purpose)
                            .font(CoachFonts.ui(13))
                            .italic()
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    // Stats row
                    HStack(spacing: 16) {
                        if let time = heroTimeValue(session) {
                            Text(time)
                                .font(CoachFonts.mono(14, weight: .bold))
                        }
                        if let zone = session.zone, !zone.isEmpty {
                            Text(zone)
                                .font(CoachFonts.mono(14, weight: .bold))
                                .foregroundStyle(.secondary)
                        }
                        if let pace = session.paceRange, !pace.isEmpty {
                            Text(pace)
                                .font(CoachFonts.mono(13, weight: .medium))
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .buttonStyle(.plain)

            // Action buttons — three states: unresolved, needs-review, resolved
            if session.completionNeedsReview == true {
                // Auto-matched from Apple Watch — needs confirmation
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 6) {
                        Image(systemName: "applewatch")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(CoachColors.yellow)
                        Text("Match found from Apple Watch")
                            .font(CoachFonts.ui(12, weight: .semibold))
                            .foregroundStyle(CoachColors.yellow)
                        Spacer()
                    }
                    if let actual = session.actualDuration, actual > 0 {
                        Text("\(actual) min recorded")
                            .font(CoachFonts.mono(11, weight: .medium))
                            .foregroundStyle(.secondary)
                    }
                    HStack(spacing: 8) {
                        heroAction(label: "Review & Confirm", icon: "checkmark.circle", color: CoachColors.green, prominent: true) {
                            // Find the matching CardioWorkout
                            let matched = findMatchedWorkout(for: session)
                            reviewingMatch = MatchReviewData(
                                session: session, workout: matched,
                                weekNum: weekNum, dayIdx: dayIdx, sessionIdx: sessionIdx
                            )
                        }
                        heroAction(label: "Dismiss", icon: "xmark", color: .secondary) {
                            Task {
                                try? await data.updateSessionCompletion(weekNum: weekNum, dayIdx: dayIdx, sessionIdx: sessionIdx) { s in
                                    s.completionStatus = nil
                                    s.completed = false
                                    s.completionNeedsReview = nil
                                    s.actualDuration = nil
                                    s.actualDistance = nil
                                    s.completionNote = nil
                                    s.completionResolvedAt = nil
                                }
                            }
                        }
                    }
                }
            } else if session.completionStatus == nil {
                HStack(spacing: 8) {
                    heroAction(label: "Did it", icon: "checkmark", color: CoachColors.green, prominent: true) {
                        Task {
                            let now = ISO8601DateFormatter().string(from: Date())
                            try? await data.updateSessionCompletion(weekNum: weekNum, dayIdx: dayIdx, sessionIdx: sessionIdx) { s in
                                s.completionStatus = .completed
                                s.completed = true
                                s.completionResolvedAt = now
                            }
                        }
                    }
                    heroAction(label: "Modified", icon: "pencil", color: CoachColors.yellow) {
                        if let s = sessionAt(weekNum: weekNum, dayIdx: dayIdx, sessionIdx: sessionIdx) {
                            completionSheet = .modified(session: s, weekNum: weekNum, dayIdx: dayIdx, sessionIdx: sessionIdx)
                        }
                    }
                    heroAction(label: "Skipped", icon: "xmark", color: .secondary) {
                        completionSheet = .skipped(weekNum: weekNum, dayIdx: dayIdx, sessionIdx: sessionIdx)
                    }
                }
            } else {
                HStack(spacing: 6) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(CoachColors.green)
                    Text(session.completionStatus == .skipped ? "Skipped" : "Done")
                        .font(CoachFonts.ui(13, weight: .semibold))
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(16)
        .background(colorScheme == .dark ? CoachColors.darkCard : CoachColors.lightCard)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(
                    session.completionNeedsReview == true
                        ? CoachColors.yellow.opacity(0.6)
                        : (colorScheme == .dark ? CoachColors.darkBorder : CoachColors.lightBorder),
                    lineWidth: session.completionNeedsReview == true ? 1.5 : 1
                )
        )
    }

    private var restDayHero: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: "moon.fill")
                    .font(.system(size: 18))
                    .foregroundStyle(CoachColors.purple)
                Text("Rest Day")
                    .font(CoachFonts.display(20, weight: .bold))
            }
            Text("Recovery is part of the plan.")
                .font(CoachFonts.ui(13))
                .foregroundStyle(.secondary)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(colorScheme == .dark ? CoachColors.darkCard : CoachColors.lightCard)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(colorScheme == .dark ? CoachColors.darkBorder : CoachColors.lightBorder, lineWidth: 1)
        )
    }

    private func heroAction(label: String, icon: String, color: Color, prominent: Bool = false, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 5) {
                Image(systemName: icon)
                    .font(.system(size: 11, weight: .bold))
                Text(label)
                    .font(CoachFonts.ui(12, weight: .semibold))
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 9)
            .frame(maxWidth: .infinity)
            .background(prominent ? color.opacity(0.15) : Color.clear)
            .foregroundStyle(color)
            .clipShape(Capsule())
            .overlay(Capsule().stroke(color.opacity(prominent ? 0 : 0.3), lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    private func heroTimeValue(_ session: PrescribedSession) -> String? {
        if let lo = session.estimatedDurationMin, let hi = session.estimatedDurationMax {
            return "\(lo)\u{2013}\(hi)min"
        }
        if let d = session.duration, d > 0 { return formatDuration(d) }
        return nil
    }

    // MARK: 4 — The "Why" (Coach Note)

    @ViewBuilder
    private var coachWhySection: some View {
        if let msg = data.settings.pushMessage, !msg.text.isEmpty {
            Text(renderedMarkdown(msg.text))
                .font(CoachFonts.ui(13))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: 5 — Week Strip

    @ViewBuilder
    private var weekStrip: some View {
        if let plan = data.trainingPlan,
           let wp = plan.weeklyPlans[String(plan.currentWeek)] {
            NavigationLink {
                WeekDetailView(initialWeekNum: plan.currentWeek)
            } label: {
                HStack(spacing: 0) {
                    ForEach(Array(wp.sessions.enumerated()), id: \.offset) { dayIdx, dayPlan in
                        let isToday = dayIdx == todayDayIndex()
                        weekColumn(dayPlan: dayPlan, dayIdx: dayIdx, isToday: isToday)
                            .frame(maxWidth: .infinity)
                    }
                }
                .padding(.vertical, 10)
                .padding(.horizontal, 8)
                .background(colorScheme == .dark ? CoachColors.darkCard : CoachColors.lightCard)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(colorScheme == .dark ? CoachColors.darkBorder : CoachColors.lightBorder, lineWidth: 1)
                )
            }
            .buttonStyle(.plain)
        }
    }

    private func weekColumn(dayPlan: DayPlan, dayIdx: Int, isToday: Bool) -> some View {
        let dayLabels = ["M", "T", "W", "T", "F", "S", "S"]
        let isPast = dayIdx < todayDayIndex()

        return VStack(spacing: 4) {
            Text(dayIdx < dayLabels.count ? dayLabels[dayIdx] : "?")
                .font(CoachFonts.mono(10, weight: isToday ? .bold : .medium))
                .foregroundStyle(isToday ? CoachColors.accent : .secondary)

            if dayPlan.isRest == true {
                Image(systemName: "moon.fill")
                    .font(.system(size: 10))
                    .foregroundStyle(CoachColors.purple.opacity(isPast ? 0.5 : 1))
            } else if dayPlan.sessions.isEmpty {
                Circle()
                    .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                    .frame(width: 14, height: 14)
            } else {
                VStack(spacing: 2) {
                    ForEach(Array(dayPlan.sessions.enumerated()), id: \.offset) { _, session in
                        sessionDot(session: session, isToday: isToday, isPast: isPast)
                    }
                }
            }
        }
        .padding(.vertical, 4)
        .padding(.horizontal, 2)
        .background(isToday ? CoachColors.accent.opacity(0.08) : Color.clear)
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }

    private func sessionDot(session: PrescribedSession, isToday: Bool, isPast: Bool) -> some View {
        let sport = Sport(rawValue: session.type.lowercased())
        let icon = sport?.sfSymbol ?? "circle.fill"
        let color = sessionDotColor(session: session, isToday: isToday, isPast: isPast)
        return Image(systemName: icon)
            .font(.system(size: 10, weight: .medium))
            .foregroundStyle(color)
    }

    private func sessionDotColor(session: PrescribedSession, isToday: Bool, isPast: Bool) -> Color {
        if let status = session.completionStatus {
            switch status {
            case .completed: return CoachColors.green
            case .modified: return CoachColors.yellow
            case .swapped: return CoachColors.blue
            case .skipped: return CoachColors.red
            }
        }
        if isToday { return CoachColors.accent }
        if isPast { return CoachColors.red.opacity(0.6) }
        return Color.gray.opacity(0.4)
    }

    // MARK: 6 — Plan Position Line

    @ViewBuilder
    private var planPositionLine: some View {
        if let plan = data.trainingPlan {
            Button {
                data.selectedTab = "plan"
            } label: {
                HStack(spacing: 4) {
                    let phaseName = plan.phases.first(where: { $0.number == plan.currentPhase })?.name ?? ""
                    let weeksToRace = plan.totalWeeks - plan.currentWeek
                    Text("Week \(plan.currentWeek) of \(plan.totalWeeks)")
                    Text("\u{00B7}").foregroundStyle(.tertiary)
                    Text(phaseName)
                    if weeksToRace > 0 {
                        Text("\u{00B7}").foregroundStyle(.tertiary)
                        Text("\(weeksToRace)w to race day")
                    }
                }
                .font(CoachFonts.mono(11, weight: .medium))
                .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: 7 — Quick Actions

    private var quickActions: some View {
        HStack(spacing: 10) {
            quickActionButton(label: "Start workout", icon: "play.fill", prominent: true) {
                // TODO: open strength logger or workout tracking
            }
            quickActionButton(label: "Log manually", icon: "square.and.pencil") {
                data.pendingChatPrompt = "Log today's workout"
                showCoachChat = true
            }
            quickActionButton(label: "Can't do today", icon: "xmark") {
                data.pendingChatPrompt = "I can't do today's workout"
                showCoachChat = true
            }
        }
    }

    private func quickActionButton(label: String, icon: String, prominent: Bool = false, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .semibold))
                Text(label)
                    .font(CoachFonts.ui(10, weight: .semibold))
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(prominent ? CoachColors.accent.opacity(0.1) : (colorScheme == .dark ? CoachColors.darkCard : CoachColors.lightCard))
            .foregroundStyle(prominent ? CoachColors.accent : .secondary)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(prominent ? CoachColors.accent.opacity(0.2) : (colorScheme == .dark ? CoachColors.darkBorder : CoachColors.lightBorder), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    // ┌──────────────────────────────────────────────────────────────────┐
    // │                      POST-WORKOUT VIEW                          │
    // └──────────────────────────────────────────────────────────────────┘

    private var postWorkoutView: some View {
        VStack(alignment: .leading, spacing: 20) {
            raceGoalBar

            // Observation
            VStack(alignment: .leading, spacing: 8) {
                Text("Nice work.")
                    .font(CoachFonts.display(22, weight: .bold))

                if let observation = postWorkoutObservation {
                    Text(observation)
                        .font(CoachFonts.ui(14))
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            // RPE Input
            VStack(alignment: .leading, spacing: 10) {
                Text("How did it feel?")
                    .font(CoachFonts.ui(13, weight: .semibold))
                    .foregroundStyle(.secondary)

                HStack(spacing: 10) {
                    ForEach(RPELevel.allCases) { level in
                        Button {
                            selectedRPE = level
                        } label: {
                            Text(level.label)
                                .font(CoachFonts.ui(13, weight: .semibold))
                                .padding(.horizontal, 16)
                                .padding(.vertical, 10)
                                .frame(maxWidth: .infinity)
                                .background(selectedRPE == level ? level.color.opacity(0.15) : (colorScheme == .dark ? CoachColors.darkCard : CoachColors.lightCard))
                                .foregroundStyle(selectedRPE == level ? level.color : .secondary)
                                .clipShape(Capsule())
                                .overlay(
                                    Capsule().stroke(selectedRPE == level ? level.color.opacity(0.3) : (colorScheme == .dark ? CoachColors.darkBorder : CoachColors.lightBorder), lineWidth: 1)
                                )
                        }
                        .buttonStyle(.plain)
                    }
                }

                TextField("Add a note (optional)", text: $rpeNote)
                    .font(CoachFonts.ui(13))
                    .padding(10)
                    .background(Color(.secondarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
            }

            // Tomorrow Preview
            tomorrowPreview

            // Week strip
            weekStrip

            planPositionLine
        }
    }

    @ViewBuilder
    private var tomorrowPreview: some View {
        if let plan = data.trainingPlan,
           let wp = plan.weeklyPlans[String(plan.currentWeek)] {
            let tomorrowIdx = todayDayIndex() + 1
            if tomorrowIdx < wp.sessions.count,
               let session = wp.sessions[tomorrowIdx].sessions.first {
                let tomorrowDate = tomorrowDateString()
                NavigationLink {
                    PrescribedSessionDetailView(session: session, dateString: tomorrowDate)
                } label: {
                    HStack(spacing: 8) {
                        Text("Tomorrow:")
                            .font(CoachFonts.ui(13, weight: .semibold))
                            .foregroundStyle(.secondary)
                        Text(session.label)
                            .font(CoachFonts.ui(13))
                            .foregroundStyle(.primary)
                            .lineLimit(1)
                        if let d = session.duration ?? session.estimatedDurationMin {
                            Text(formatDuration(d))
                                .font(CoachFonts.mono(12, weight: .medium))
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(.tertiary)
                    }
                    .padding(12)
                    .background(colorScheme == .dark ? CoachColors.darkCard : CoachColors.lightCard)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(colorScheme == .dark ? CoachColors.darkBorder : CoachColors.lightBorder, lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }

    // ┌──────────────────────────────────────────────────────────────────┐
    // │                      MATCH REVIEW HELPERS                       │

    private func findMatchedWorkout(for session: PrescribedSession) -> CardioWorkout? {
        // Find a workout from today that matches the session's sport and has similar duration
        let today = todayString()
        let sportStr = session.type.lowercased()
        return data.cardio.first { w in
            w.date == today && w.sport.rawValue == sportStr
        }
    }

    // │                         SHARED HELPERS                          │
    // └──────────────────────────────────────────────────────────────────┘

    private func todayDayIndex() -> Int {
        (Calendar.current.component(.weekday, from: Date()) + 5) % 7
    }

    private func tomorrowDateString() -> String {
        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: Date()) ?? Date()
        let fmt = DateFormatter()
        fmt.dateFormat = "yyyy-MM-dd"
        return fmt.string(from: tomorrow)
    }

    private func weeksUntil(_ dateStr: String) -> Int? {
        let fmt = DateFormatter()
        fmt.dateFormat = "yyyy-MM-dd"
        guard let date = fmt.date(from: dateStr) else { return nil }
        let days = Calendar.current.dateComponents([.day], from: Date(), to: date).day ?? 0
        return max(0, days / 7)
    }

    private func sessionAt(weekNum: Int, dayIdx: Int, sessionIdx: Int) -> PrescribedSession? {
        guard let plan = data.trainingPlan,
              let wp = plan.weeklyPlans[String(weekNum)],
              dayIdx >= 0, dayIdx < wp.sessions.count,
              sessionIdx >= 0, sessionIdx < wp.sessions[dayIdx].sessions.count else { return nil }
        return wp.sessions[dayIdx].sessions[sessionIdx]
    }

    private func renderedMarkdown(_ text: String) -> AttributedString {
        let options = AttributedString.MarkdownParsingOptions(interpretedSyntax: .inlineOnlyPreservingWhitespace)
        return (try? AttributedString(markdown: text, options: options)) ?? AttributedString(text)
    }

    // MARK: - Completion Sheets

    @ViewBuilder
    private func completionSheetContent(_ sheet: ChatCompletionSheet) -> some View {
        switch sheet {
        case .modified(let session, let w, let d, let s):
            ModifiedCompletionSheet(session: session) { actual in
                Task {
                    let now = ISO8601DateFormatter().string(from: Date())
                    try? await data.updateSessionCompletion(weekNum: w, dayIdx: d, sessionIdx: s) { s in
                        s.completionStatus = .modified
                        s.completed = true
                        s.actualDuration = actual.duration
                        s.actualDistance = actual.distance
                        s.completionNote = actual.note.isEmpty ? nil : actual.note
                        s.completionResolvedAt = now
                    }
                }
            }
            .presentationDetents([.medium])
        case .swapped(let session, let w, let d, let s):
            SwappedCompletionSheet(session: session, otherSessions: []) { actual in
                Task {
                    let now = ISO8601DateFormatter().string(from: Date())
                    try? await data.updateSessionCompletion(weekNum: w, dayIdx: d, sessionIdx: s) { s in
                        s.completionStatus = .swapped
                        s.completed = true
                        s.actualSport = actual.sport
                        s.actualDuration = actual.duration
                        s.completionNote = actual.note.isEmpty ? nil : actual.note
                        s.completionResolvedAt = now
                    }
                }
            }
            .presentationDetents([.medium, .large])
        case .skipped(let w, let d, let s):
            SkippedCompletionSheet { reason, note in
                Task {
                    let now = ISO8601DateFormatter().string(from: Date())
                    try? await data.updateSessionCompletion(weekNum: w, dayIdx: d, sessionIdx: s) { s in
                        s.completionStatus = .skipped
                        s.skipReason = reason
                        s.completionNote = note.isEmpty ? nil : note
                        s.completionResolvedAt = now
                    }
                }
            }
            .presentationDetents([.height(340)])
        }
    }
}

// MARK: - Match Review Data

struct MatchReviewData: Identifiable {
    let id = UUID()
    let session: PrescribedSession
    let workout: CardioWorkout?
    let weekNum: Int
    let dayIdx: Int
    let sessionIdx: Int
}

// MARK: - Match Review Sheet

struct MatchReviewSheet: View {
    let match: MatchReviewData
    let onConfirm: () -> Void

    @Environment(\.dismiss) var dismiss
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    // Prescribed session
                    VStack(alignment: .leading, spacing: 8) {
                        Text("PRESCRIBED")
                            .font(CoachFonts.mono(10, weight: .semibold))
                            .foregroundStyle(.secondary)
                        CoachCard {
                            VStack(alignment: .leading, spacing: 6) {
                                if let sport = Sport(rawValue: match.session.type.lowercased()) {
                                    SportBadge(sport: sport)
                                }
                                Text(match.session.label)
                                    .font(CoachFonts.ui(15, weight: .semibold))
                                HStack(spacing: 12) {
                                    if let d = match.session.duration ?? match.session.estimatedDurationMin {
                                        Text("\(d) min")
                                            .font(CoachFonts.mono(13, weight: .medium))
                                            .foregroundStyle(.secondary)
                                    }
                                    if let zone = match.session.zone {
                                        Text(zone)
                                            .font(CoachFonts.mono(13, weight: .medium))
                                            .foregroundStyle(.secondary)
                                    }
                                }
                            }
                        }
                    }

                    // Apple Watch workout
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 6) {
                            Image(systemName: "applewatch")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(CoachColors.green)
                            Text("RECORDED")
                                .font(CoachFonts.mono(10, weight: .semibold))
                                .foregroundStyle(.secondary)
                        }
                        if let workout = match.workout {
                            CoachCard {
                                VStack(alignment: .leading, spacing: 8) {
                                    SportBadge(sport: workout.sport)
                                    HStack(spacing: 16) {
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text("DURATION")
                                                .font(CoachFonts.mono(9, weight: .semibold))
                                                .foregroundStyle(.secondary)
                                            Text(formatDuration(workout.duration))
                                                .font(CoachFonts.mono(15, weight: .bold))
                                        }
                                        if let dist = workout.distance, !dist.isEmpty {
                                            VStack(alignment: .leading, spacing: 2) {
                                                Text("DISTANCE")
                                                    .font(CoachFonts.mono(9, weight: .semibold))
                                                    .foregroundStyle(.secondary)
                                                Text(dist)
                                                    .font(CoachFonts.mono(15, weight: .bold))
                                            }
                                        }
                                        if let hr = workout.avgHR {
                                            VStack(alignment: .leading, spacing: 2) {
                                                Text("AVG HR")
                                                    .font(CoachFonts.mono(9, weight: .semibold))
                                                    .foregroundStyle(.secondary)
                                                Text("\(hr) bpm")
                                                    .font(CoachFonts.mono(15, weight: .bold))
                                            }
                                        }
                                    }
                                    if let cal = workout.calories {
                                        Text("\(cal) cal")
                                            .font(CoachFonts.ui(12))
                                            .foregroundStyle(.secondary)
                                    }
                                }
                            }
                        } else {
                            CoachCard {
                                Text("Workout data not available")
                                    .font(CoachFonts.ui(13))
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }

                    // Confirm button
                    Button {
                        onConfirm()
                        dismiss()
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "checkmark")
                                .font(.system(size: 14, weight: .bold))
                            Text("Confirm Match")
                                .font(CoachFonts.ui(15, weight: .semibold))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(CoachColors.green)
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    .buttonStyle(.plain)
                }
                .padding()
            }
            .background((colorScheme == .dark ? CoachColors.darkBg : CoachColors.lightBg).ignoresSafeArea())
            .navigationTitle("Review Match")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }
}

// MARK: - RPE Level

enum RPELevel: String, CaseIterable, Identifiable {
    case easy, onTarget, hard
    var id: String { rawValue }

    var label: String {
        switch self {
        case .easy: return "Felt easy"
        case .onTarget: return "On target"
        case .hard: return "Hard"
        }
    }

    var color: Color {
        switch self {
        case .easy: return CoachColors.green
        case .onTarget: return CoachColors.blue
        case .hard: return CoachColors.red
        }
    }
}

// MARK: - Floating Coach Button

struct FloatingCoachButton: View {
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [CoachColors.accent, CoachColors.accent.opacity(0.85)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 56, height: 56)
                    .shadow(color: CoachColors.accent.opacity(0.35), radius: 10, y: 4)
                Image(systemName: "bubble.left.and.bubble.right.fill")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(.white)
            }
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Coach Chat Sheet

/// The chat interface presented as a modal sheet.
struct CoachChatSheet: View {
    @Environment(DataService.self) var data
    @State private var inputText = ""
    @State private var isLoading = false
    @State private var showHistory = false
    @FocusState private var isInputFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 12) {
                        if data.currentMessages.isEmpty && !isLoading {
                            VStack(spacing: 8) {
                                Image(systemName: "sparkles")
                                    .font(.system(size: 20, weight: .semibold))
                                    .foregroundStyle(CoachColors.accent.opacity(0.6))
                                Text("What's on your mind?")
                                    .font(CoachFonts.ui(14))
                                    .foregroundStyle(.secondary)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.top, 40)
                        }
                        ForEach(Array(data.currentMessages.enumerated()), id: \.offset) { index, message in
                            MessageBubble(message: message)
                                .id(index)
                        }
                        if isLoading {
                            HStack(spacing: 8) {
                                DotsLoader()
                                Text(loadingLabel)
                                    .font(CoachFonts.ui(13))
                                    .foregroundStyle(.secondary)
                            }
                            .padding(.horizontal)
                            .id("loading")
                        }
                    }
                    .padding()
                }
                .onChange(of: data.currentMessages.count) {
                    withAnimation { proxy.scrollTo(data.currentMessages.count - 1, anchor: .bottom) }
                }
                .onAppear {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        if !data.currentMessages.isEmpty {
                            proxy.scrollTo(data.currentMessages.count - 1, anchor: .bottom)
                        }
                    }
                }
            }

            Divider()

            HStack(spacing: 8) {
                TextField("Message your coach...", text: $inputText, axis: .vertical)
                    .font(CoachFonts.ui(15))
                    .lineLimit(1...5)
                    .focused($isInputFocused)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color(.secondarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 20))

                Button {
                    Task { await sendMessage() }
                } label: {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.system(size: 32))
                        .foregroundStyle(inputText.trimmingCharacters(in: .whitespaces).isEmpty ? Color.gray.opacity(0.3) : CoachColors.accent)
                }
                .disabled(inputText.trimmingCharacters(in: .whitespaces).isEmpty || isLoading)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
        }
        .navigationTitle("Coach")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { showHistory = true } label: {
                    Image(systemName: "clock.arrow.circlepath")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.secondary)
                }
            }
        }
        .sheet(isPresented: $showHistory) {
            NavigationStack { ConversationHistoryView() }
        }
        .task {
            await data.ensureActiveConversation()
            if data.currentMessages.isEmpty {
                await injectCoachNote()
            }
            await drainAutoMatches()
        }
        .onAppear { consumePendingPrompt() }
        .onChange(of: data.pendingChatPrompt) { _, _ in consumePendingPrompt() }
    }

    private var loadingLabel: String {
        if let progress = data.activeToolProgress, !progress.isEmpty { return progress }
        switch data.activeToolName {
        case "create_training_plan": return "Building your plan\u{2026}"
        case "get_workouts", "get_training_stats", "get_week_review", "get_plan_history":
            return "Reviewing your data\u{2026}"
        case "get_athlete_profile": return "Checking your profile\u{2026}"
        case "log_workout": return "Logging workout\u{2026}"
        case "log_nutrition": return "Logging nutrition\u{2026}"
        case nil: return "Thinking\u{2026}"
        default: return "Working\u{2026}"
        }
    }

    private func consumePendingPrompt() {
        guard let prompt = data.pendingChatPrompt, !prompt.isEmpty else { return }
        inputText = prompt
        isInputFocused = true
        data.pendingChatPrompt = nil
    }

    private func injectCoachNote() async {
        guard let msg = data.settings.pushMessage, !msg.text.isEmpty else { return }
        let chatMsg = ChatMessage.assistant(msg.text, conversationId: data.currentConversation?.id)
        try? await data.addMessage(chatMsg)
    }

    private func drainAutoMatches() async {
        let matches = data.unacknowledgedAutoMatches
        guard !matches.isEmpty else { return }
        data.unacknowledgedAutoMatches.removeAll()

        for match in matches {
            // Use the status detected by the matcher (completed/modified/swapped)
            await generateCompletionResponse(
                session: match.session,
                status: match.detectedStatus,
                source: .healthKit,
                actualDuration: match.actualDuration,
                actualDistance: match.actualDistance
            )

            // If swapped or modified, also trigger a full coach evaluation
            // by sending a system message asking coach to review the plan
            if match.detectedStatus == .swapped || match.detectedStatus == .modified {
                let description = match.detectedStatus == .swapped
                    ? "I did a different workout than prescribed — can you check if the rest of the week needs adjusting?"
                    : "My workout was significantly different from the prescription — should we adjust anything?"
                let systemMsg = ChatMessage.user(description, conversationId: data.currentConversation?.id)
                try? await data.addMessage(systemMsg)
                await sendAgentMessage(description)
            }
        }
    }

    /// Sends a message through the agent loop without user input.
    private func sendAgentMessage(_ text: String) async {
        do {
            let recentSummaries = data.archivedConversations.prefix(3).compactMap(\.summary)
            let result = try await runAgentLoop(
                personality: data.settings.personality,
                customText: data.settings.customPrompt,
                messages: data.currentMessages,
                dataService: data,
                recentConversationSummaries: recentSummaries
            )
            let assistantMsg = ChatMessage.assistant(
                result.response,
                metadata: ChatMessageMetadata(
                    logged: result.hasWorkoutLogs, nutritionLogged: result.hasNutritionLogs,
                    planChanged: result.hasPlanChanges, appActionTaken: result.hasAppActions
                ),
                conversationId: data.currentConversation?.id
            )
            try? await data.addMessage(assistantMsg)
            for effect in result.effects {
                switch effect {
                case .workoutLogged(let w): try? await data.addCardio(w)
                case .cardioUpdated(let w): try? await data.updateCardio(w)
                case .cardioDeleted(let id): try? await data.deleteCardio(id)
                case .strengthDeleted(let id): try? await data.deleteStrength(id)
                case .nutritionLogged(let e): try? await data.addNutrition(e)
                case .planCreated(let p), .planUpdated(let p): try? await data.savePlan(p)
                case .planDeleted(let id, let h): try? await data.deletePlan(id, archiveTo: h)
                case .weekUpdated(let n, let wp):
                    if var c = data.trainingPlan { c.weeklyPlans[String(n)] = wp; try? await data.savePlan(c) }
                case .progressUpdated(let w, let p):
                    if var c = data.trainingPlan { c.currentWeek = w; c.currentPhase = p; try? await data.savePlan(c) }
                case .eventCreated(let e): try? await data.addEvent(e)
                case .eventUpdated(let e): try? await data.updateEvent(e)
                case .eventDeleted(let id): try? await data.deleteEvent(id)
                case .memoryUpdated(let m): try? await data.saveMemory(m)
                case .settingsUpdated(let s): try? await data.saveSettings(s)
                case .tabChanged(let t): data.selectedTab = t
                }
            }
        } catch {
            NSLog("[auto-match-eval] agent call failed: \(error)")
        }
    }

    private func sendMessage() async {
        let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        inputText = ""
        isInputFocused = false
        await data.ensureActiveConversation()
        let userMsg = ChatMessage.user(text, conversationId: data.currentConversation?.id)
        try? await data.addMessage(userMsg)
        isLoading = true
        do {
            let recentSummaries = data.archivedConversations.prefix(3).compactMap(\.summary)
            let result = try await runAgentLoop(
                personality: data.settings.personality,
                customText: data.settings.customPrompt,
                messages: data.currentMessages,
                dataService: data,
                recentConversationSummaries: recentSummaries
            )
            let assistantMsg = ChatMessage.assistant(
                result.response,
                metadata: ChatMessageMetadata(
                    logged: result.hasWorkoutLogs, nutritionLogged: result.hasNutritionLogs,
                    planChanged: result.hasPlanChanges, appActionTaken: result.hasAppActions
                ),
                conversationId: data.currentConversation?.id
            )
            try? await data.addMessage(assistantMsg)
            for effect in result.effects {
                switch effect {
                case .workoutLogged(let w): try? await data.addCardio(w)
                case .cardioUpdated(let w): try? await data.updateCardio(w)
                case .cardioDeleted(let id): try? await data.deleteCardio(id)
                case .strengthDeleted(let id): try? await data.deleteStrength(id)
                case .nutritionLogged(let e): try? await data.addNutrition(e)
                case .planCreated(let p), .planUpdated(let p): try? await data.savePlan(p)
                case .planDeleted(let id, let h): try? await data.deletePlan(id, archiveTo: h)
                case .weekUpdated(let n, let wp):
                    if var c = data.trainingPlan { c.weeklyPlans[String(n)] = wp; try? await data.savePlan(c) }
                case .progressUpdated(let w, let p):
                    if var c = data.trainingPlan { c.currentWeek = w; c.currentPhase = p; try? await data.savePlan(c) }
                case .eventCreated(let e): try? await data.addEvent(e)
                case .eventUpdated(let e): try? await data.updateEvent(e)
                case .eventDeleted(let id): try? await data.deleteEvent(id)
                case .memoryUpdated(let m): try? await data.saveMemory(m)
                case .settingsUpdated(let s): try? await data.saveSettings(s)
                case .tabChanged(let t): data.selectedTab = t
                }
            }
            Task { await extractMemory(messages: data.currentMessages, existingMemory: data.memory, dataService: data) }
        } catch {
            NSLog("[chat] sendMessage failed: \(error)")
            let errorMsg = ChatMessage.assistant(
                "Sorry, I ran into an error. Please try again.\n\n\(error.localizedDescription)",
                metadata: ChatMessageMetadata(isError: true),
                conversationId: data.currentConversation?.id
            )
            try? await data.addMessage(errorMsg)
        }
        isLoading = false
    }

    private func generateCompletionResponse(
        session: PrescribedSession, status: CompletionStatus,
        source: CompletionResponseGenerator.CompletionSource,
        actualDuration: Int? = nil, actualDistance: Double? = nil
    ) async {
        var adherenceSummary: String?
        if let plan = data.trainingPlan,
           let adh = computeWeekAdherence(plan: plan, weekNum: plan.currentWeek, cardio: data.cardio, strength: data.strength) {
            adherenceSummary = "\(adh.completed)/\(adh.prescribed) sessions completed, \(adh.missed) missed"
        }
        let context = CompletionResponseGenerator.CompletionContext(
            session: session, status: status, actualDuration: actualDuration, actualDistance: actualDistance,
            actualSport: nil, skipReason: nil, completionNote: nil, source: source,
            weekAdherenceSummary: adherenceSummary, tomorrowPreview: nil, phaseName: nil
        )
        do {
            let response = try await CompletionResponseGenerator.generate(
                context: context, personality: data.settings.personality, customPrompt: data.settings.customPrompt
            )
            let msg = ChatMessage.assistant(response, conversationId: data.currentConversation?.id)
            try? await data.addMessage(msg)
        } catch {
            NSLog("[completion-response] failed: \(error.localizedDescription)")
        }
    }
}
