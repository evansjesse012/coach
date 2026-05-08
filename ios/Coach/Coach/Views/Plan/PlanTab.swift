import SwiftUI

struct PlanTab: View {
    @Environment(DataService.self) private var data

    @State private var path = NavigationPath()
    @State private var showPlanChat = false
    /// Phase currently expanded in the detail card. Defaults to `plan.currentPhase`.
    @State private var selectedPhaseNumber: Int?

    var body: some View {
        NavigationStack(path: $path) {
            ScrollView {
                if let plan = data.trainingPlan {
                    VStack(alignment: .leading, spacing: Theme.Spacing.section) {
                        headerBlock(planExists: true)
                        pregeneratedBanner
                        raceHeroBlock(plan: plan)
                        seasonHeaderBlock(plan: plan)
                        // Timeline + connector + detail card render as one
                        // visual unit, so they live in their own spacing-0
                        // VStack inside the page's section rhythm.
                        VStack(alignment: .leading, spacing: 0) {
                            journeyTimelineBlock(plan: plan)
                            journeyConnectorBlock(plan: plan)
                            phaseDetailCardBlock(plan: plan)
                        }
                        thisWeekBlock(plan: plan)
                    }
                    .padding(.horizontal, Theme.Spacing.screenH)
                    .padding(.top, 16)
                } else {
                    VStack(alignment: .leading, spacing: Theme.Spacing.section) {
                        headerBlock(planExists: false)
                        emptyPlanState
                    }
                    .padding(.horizontal, Theme.Spacing.screenH)
                    .padding(.top, 16)
                }
            }
            .clearsTabBar()
            .background(Theme.bg.ignoresSafeArea())
            .scrollContentBackground(.hidden)
            .sheet(isPresented: $showPlanChat) {
                PlanCreationChatSheet()
            }
            .task {
                await data.ensurePlanPreGenerated()
            }
            .onAppear {
                if selectedPhaseNumber == nil, let plan = data.trainingPlan {
                    selectedPhaseNumber = plan.currentPhase
                }
            }
        }
        .popsOnTabReselect(tabId: "plan", path: $path)
    }

    // MARK: - Header

    @ViewBuilder
    private func headerBlock(planExists: Bool) -> some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Training Plan")
                    .font(.system(size: 26, weight: .semibold))
                    .foregroundStyle(Theme.ink)
                    .tracking(-0.5)
                if planExists, let plan = data.trainingPlan {
                    headerSublineText(plan: plan)
                }
            }
            Spacer(minLength: 0)
            Button {
                if planExists {
                    modifyWithCoach()
                } else {
                    showPlanChat = true
                }
            } label: {
                Image(systemName: planExists ? "square.and.pencil" : "plus")
                    .font(.system(size: 16, weight: .regular))
                    .foregroundStyle(Theme.ink2)
                    .frame(width: 40, height: 40)
                    .background(Circle().strokeBorder(Theme.line, lineWidth: 1))
            }
            .buttonStyle(.plain)
        }
    }

    /// Subline under the page title, e.g. `Apr 19 → Sep 27 · 24 weeks`.
    /// Mono / secondary base; the trailing `{n} weeks` portion lifts to
    /// primary color + bold so the duration reads first. Renders nothing
    /// if the plan is missing either date or has zero weeks.
    private func headerSublineText(plan: TrainingPlan) -> Text {
        let startStr = plan.startDate.flatMap(formatShortDate)
        let raceStr = plan.raceDate.flatMap(formatShortDate)
        let total = plan.totalWeeks

        let dateBase: Text = {
            switch (startStr, raceStr) {
            case let (s?, r?): return Text("\(s) → \(r) · ")
            case let (s?, nil): return Text("\(s) · ")
            case let (nil, r?): return Text("→ \(r) · ")
            default: return Text("")
            }
        }()

        return dateBase
            .font(Theme.Typography.monoMeta)
            .foregroundColor(Theme.ink2)
        + Text("\(total) weeks")
            .font(Theme.Typography.monoMeta)
            .fontWeight(.bold)
            .foregroundColor(Theme.ink)
    }

    private func formatShortDate(_ yyyymmdd: String) -> String? {
        let inF = DateFormatter()
        inF.dateFormat = "yyyy-MM-dd"
        guard let d = inF.date(from: yyyymmdd) else { return nil }
        let outF = DateFormatter()
        outF.dateFormat = "MMM d"
        return outF.string(from: d)
    }

    private func modifyWithCoach() {
        guard let plan = data.trainingPlan else { return }
        let race = plan.raceName ?? "my race"
        data.pendingChatPrompt = "I want to modify my current training plan for \(race). I'm in week \(plan.currentWeek) of \(plan.totalWeeks). What would you like to change?"
        // MainTabView observes pendingChatPrompt and opens the Coach chat sheet.
    }

    // MARK: - Pre-generated week banner

    @ViewBuilder
    private var pregeneratedBanner: some View {
        if let weekNum = data.recentlyPregeneratedWeek, let plan = data.trainingPlan, weekNum <= plan.totalWeeks {
            NavigationLink {
                WeekDetailView(initialWeekNum: weekNum)
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Theme.accent)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("New week ready")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(Theme.ink)
                        Text("Your coach wrote week \(weekNum) · tap to preview")
                            .font(Theme.Typography.monoMeta)
                            .foregroundStyle(Theme.ink3)
                    }
                    Spacer(minLength: 0)
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Theme.ink3)
                }
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Theme.accentSoft)
                .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.card))
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Race hero

    @ViewBuilder
    private func raceHeroBlock(plan: TrainingPlan) -> some View {
        if let name = plan.raceName, !name.isEmpty, let dateStr = plan.raceDate {
            let (count, unit) = countdownParts(dateStr)
            CountdownHero(
                kicker: "A-Race",
                name: name,
                date: raceDateLine(plan: plan, dateStr: dateStr),
                count: count,
                unit: unit
            )
        }
    }

    private func countdownParts(_ dateStr: String) -> (Int, String) {
        let days = daysUntil(dateStr) ?? 0
        if days >= 14 {
            let weeks = days / 7
            return (weeks, weeks == 1 ? "Week out" : "Weeks out")
        }
        if days <= 0 { return (0, "Today") }
        return (days, days == 1 ? "Day out" : "Days out")
    }

    private func raceDateLine(plan: TrainingPlan, dateStr: String) -> String {
        let base = formatRaceDate(dateStr)
        guard let goalId = plan.goalId,
              let event = data.events.first(where: { $0.id == goalId }),
              let location = event.location, !location.isEmpty else { return base }
        return "\(base) · \(location)"
    }

    private func formatRaceDate(_ dateStr: String) -> String {
        let inF = DateFormatter()
        inF.dateFormat = "yyyy-MM-dd"
        guard let d = inF.date(from: dateStr) else { return dateStr }
        let outF = DateFormatter()
        outF.dateFormat = "EEE · MMM d · yyyy"
        return outF.string(from: d)
    }

    // MARK: - Season header
    //
    // Two-line header that sits above the journey timeline. Line 1 is the
    // section title plus a quiet "tap a phase" hint; line 2 is a status
    // line showing when the plan started and where the athlete is in it.

    @ViewBuilder
    private func seasonHeaderBlock(plan: TrainingPlan) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .firstTextBaseline) {
                Text("Your season")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(Theme.ink)
                Spacer(minLength: 8)
                Text("Tap a phase")
                    .font(.system(size: 9, weight: .medium, design: .monospaced))
                    .foregroundStyle(Theme.ink3)
                    .textCase(.uppercase)
                    .tracking(1.0)
            }
            seasonHeaderStatusLine(plan: plan)
        }
    }

    /// "Started **Apr 19** · Week **7 of 24**" — mono / tertiary base, with
    /// the start date and the week-of-total portions lifted to bold +
    /// secondary color so the eye lands on the actionable numbers.
    private func seasonHeaderStatusLine(plan: TrainingPlan) -> Text {
        let start = plan.startDate.flatMap(formatShortDate) ?? "—"
        let week = plan.currentWeek
        let total = plan.totalWeeks

        let mono10 = Font.system(size: 10, design: .monospaced)
        let mono10Bold = Font.system(size: 10, weight: .bold, design: .monospaced)

        return Text("Started ")
            .font(mono10)
            .foregroundColor(Theme.ink3)
        + Text(start)
            .font(mono10Bold)
            .foregroundColor(Theme.ink2)
        + Text(" · ")
            .font(mono10)
            .foregroundColor(Theme.ink3)
        + Text("Week \(week) of \(total)")
            .font(mono10Bold)
            .foregroundColor(Theme.ink2)
    }

    // MARK: - Journey timeline (step 3 — line only, no labels / connector)

    @ViewBuilder
    private func journeyTimelineBlock(plan: TrainingPlan) -> some View {
        JourneyTimeline(
            phases: plan.seasonPhases,
            currentWeek: plan.currentWeek,
            totalWeeks: plan.totalWeeks,
            selectedId: Binding(
                get: { selectedPhaseNumber ?? plan.currentPhase },
                set: { selectedPhaseNumber = $0 }
            )
        )
    }

    // MARK: - Journey connector (step 7 — vertical hairline timeline → card)

    @ViewBuilder
    private func journeyConnectorBlock(plan: TrainingPlan) -> some View {
        JourneyConnector(
            phases: plan.seasonPhases,
            totalWeeks: plan.totalWeeks,
            selectedId: selectedPhaseNumber ?? plan.currentPhase
        )
    }

    // MARK: - Phase detail card (step 6 — replaces the legacy in-page card)
    //
    // Whole card is one tap target. Tapping pushes the existing rich
    // `PhaseDetailView` onto the nav stack; the press dim handles the
    // touch-down cue without competing with the nav-push transition.

    @ViewBuilder
    private func phaseDetailCardBlock(plan: TrainingPlan) -> some View {
        let target = selectedPhaseNumber ?? plan.currentPhase
        if let seasonPhase = plan.seasonPhases.first(where: { $0.id == target }),
           let trainingPhase = plan.phases.first(where: { $0.number == target }) {
            NavigationLink {
                PhaseDetailView(plan: plan, phase: trainingPhase)
            } label: {
                PhaseJourneyCard(phase: seasonPhase)
            }
            .buttonStyle(PressDimmedButtonStyle())
        }
    }

    // MARK: - This week

    @ViewBuilder
    private func thisWeekBlock(plan: TrainingPlan) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(
                title: "This week",
                meta: weekRangeText(plan: plan, weekNum: plan.currentWeek)
            )
            weekBreakdownCard(plan: plan)
        }
    }

    @ViewBuilder
    private func weekBreakdownCard(plan: TrainingPlan) -> some View {
        if let wp = plan.weeklyPlans[String(plan.currentWeek)] {
            if wp.isStub {
                stubWeekCard(weekNum: plan.currentWeek)
            } else {
                NavigationLink {
                    WeekDetailView(initialWeekNum: plan.currentWeek)
                } label: {
                    WeekBreakdownList(
                        weeklyPlan: wp,
                        todayDayIdx: todayDayIdx
                    )
                }
                .buttonStyle(.plain)
            }
        } else {
            stubWeekCard(weekNum: plan.currentWeek)
        }
    }

    @ViewBuilder
    private func stubWeekCard(weekNum: Int) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("This week isn't generated yet")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Theme.ink)
            Text("Your coach will auto-generate it, or you can kick it off now.")
                .font(Theme.Typography.body)
                .foregroundStyle(Theme.ink2)
            GenerateWeekButton(weekNum: weekNum)
        }
        .padding(Theme.Spacing.cardP)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.surface1)
        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.card))
        .overlay(
            RoundedRectangle(cornerRadius: Theme.Radius.card)
                .strokeBorder(Theme.line, lineWidth: 1)
        )
    }

    private var todayDayIdx: Int {
        (Calendar.current.component(.weekday, from: Date()) + 5) % 7
    }

    private func weekRangeText(plan: TrainingPlan, weekNum: Int) -> String {
        weekRangeLabel(planStartDate: plan.startDate, weekNumber: weekNum) ?? ""
    }

    // MARK: - Empty state

    @ViewBuilder
    private var emptyPlanState: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("No plan yet")
                .font(Theme.Typography.sessionTitle)
                .foregroundStyle(Theme.ink)
            Text("Build a training plan with your coach — pick a race, set your constraints, and the coach will write a periodized plan.")
                .font(Theme.Typography.body)
                .foregroundStyle(Theme.ink2)
                .fixedSize(horizontal: false, vertical: true)
            Pill(title: "Build a plan with your coach", variant: .primary) {
                showPlanChat = true
            }
        }
        .padding(Theme.Spacing.cardP)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.surface1)
        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.card))
        .overlay(
            RoundedRectangle(cornerRadius: Theme.Radius.card)
                .strokeBorder(Theme.line, lineWidth: 1)
        )
    }
}


// MARK: - Week breakdown list

private struct WeekBreakdownList: View {
    let weeklyPlan: WeeklyPlan
    let todayDayIdx: Int

    var body: some View {
        VStack(spacing: 0) {
            ForEach(Array(weeklyPlan.sessions.enumerated()), id: \.offset) { dayIdx, dayPlan in
                dayGroup(dayIdx: dayIdx, dayPlan: dayPlan)
                if dayIdx < weeklyPlan.sessions.count - 1 {
                    Hairline()
                }
            }
        }
        .padding(.vertical, 4)
        .background(Theme.surface1)
        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.card))
        .overlay(
            RoundedRectangle(cornerRadius: Theme.Radius.card)
                .strokeBorder(Theme.line, lineWidth: 1)
        )
    }

    @ViewBuilder
    private func dayGroup(dayIdx: Int, dayPlan: DayPlan) -> some View {
        let isToday = dayIdx == todayDayIdx
        if dayPlan.isRest == true {
            sessionRow(
                dayLetter: dayLetter(dayIdx),
                discipline: .recovery,
                title: "Rest",
                duration: nil,
                isToday: isToday,
                statusKind: .pending
            )
        } else if dayPlan.sessions.isEmpty {
            sessionRow(
                dayLetter: dayLetter(dayIdx),
                discipline: .recovery,
                title: "—",
                duration: nil,
                isToday: isToday,
                statusKind: .pending
            )
        } else {
            VStack(spacing: 0) {
                ForEach(Array(dayPlan.sessions.enumerated()), id: \.offset) { sIdx, session in
                    sessionRow(
                        dayLetter: sIdx == 0 ? dayLetter(dayIdx) : "",
                        discipline: disciplineFor(session),
                        title: session.label,
                        duration: durationLabel(for: session),
                        isToday: isToday,
                        statusKind: session.statusKind
                    )
                }
            }
        }
    }

    private func sessionRow(
        dayLetter: String,
        discipline: Theme.Discipline,
        title: String,
        duration: String?,
        isToday: Bool,
        statusKind: Theme.SessionStatusKind
    ) -> some View {
        HStack(alignment: .center, spacing: 10) {
            Text(dayLetter)
                .font(Theme.Typography.monoLabel)
                .foregroundStyle(Theme.ink3)
                .tracking(Theme.Tracking.monoLabel)
                .frame(width: 34, alignment: .leading)
            DisciplineDot(discipline: discipline, size: 7)
            Text(title)
                .font(Theme.Typography.body)
                .foregroundStyle(Theme.ink)
                .lineLimit(1)
            if statusKind != .pending {
                Image(systemName: statusKind.icon)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(statusKind.tint)
            }
            Spacer(minLength: 8)
            if let duration {
                Text(duration)
                    .font(Theme.Typography.mono(12))
                    .foregroundStyle(Theme.ink2)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 11)
        .background {
            if isToday {
                LinearGradient(
                    colors: [Theme.accentSoft, Theme.accentSoft.opacity(0.3)],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            } else {
                Color.clear
            }
        }
    }

    private func dayLetter(_ idx: Int) -> String {
        ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"][idx]
    }

    private func disciplineFor(_ session: PrescribedSession) -> Theme.Discipline {
        if let sport = Sport(rawValue: session.type) { return sport.discipline }
        if session.type == "strength" { return .strength }
        return .recovery
    }

    private func durationLabel(for session: PrescribedSession) -> String? {
        if let d = session.duration { return "\(d)m" }
        if let lo = session.estimatedDurationMin, let hi = session.estimatedDurationMax {
            return "\(lo)–\(hi)m"
        }
        if let dist = session.distanceMiles {
            return String(format: "%.1f mi", dist)
        }
        return nil
    }
}

// MARK: - Stub week generate button

private struct GenerateWeekButton: View {
    @Environment(DataService.self) private var data
    let weekNum: Int

    @State private var isGenerating = false
    @State private var errorMessage: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Pill(
                title: isGenerating ? "Generating…" : "Generate week \(weekNum) now",
                variant: .primary
            ) {
                Task { await generate() }
            }
            if let errorMessage {
                Text(errorMessage)
                    .font(Theme.Typography.small)
                    .foregroundStyle(Theme.warn)
            }
        }
    }

    private func generate() async {
        isGenerating = true
        errorMessage = nil
        do {
            try await data.generateWeek(weekNum)
        } catch {
            errorMessage = error.localizedDescription
        }
        isGenerating = false
    }
}
