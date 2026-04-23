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
                        seasonPhasesBlock(plan: plan)
                        currentPhaseDetailBlock(plan: plan)
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
            VStack(alignment: .leading, spacing: 6) {
                Text("Season plan")
                    .font(Theme.Typography.monoLabel)
                    .foregroundStyle(Theme.ink3)
                    .textCase(.uppercase)
                    .tracking(Theme.Tracking.monoLabel)
                Text("Your training plan")
                    .font(Theme.Typography.pageTitle)
                    .foregroundStyle(Theme.ink)
                    .tracking(-0.5)
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

    // MARK: - Season phases

    @ViewBuilder
    private func seasonPhasesBlock(plan: TrainingPlan) -> some View {
        let sorted = plan.phases.sorted { $0.number < $1.number }
        VStack(alignment: .leading, spacing: 14) {
            SectionHeader(
                title: "Season phases",
                meta: "\(sorted.count) phases · \(plan.totalWeeks) wks"
            )
            PhaseRuler(phases: sorted, currentPhase: plan.currentPhase, totalWeeks: plan.totalWeeks)
            VStack(spacing: 6) {
                ForEach(sorted) { phase in
                    PhasePlanRow(
                        phase: phase,
                        startDate: phaseStart(for: phase, plan: plan),
                        endDate: phaseEnd(for: phase, plan: plan),
                        isCurrent: phase.number == plan.currentPhase,
                        isSelected: phase.number == (selectedPhaseNumber ?? plan.currentPhase)
                    ) {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            selectedPhaseNumber = phase.number
                        }
                    }
                }
            }
        }
    }

    // MARK: - Current phase detail

    @ViewBuilder
    private func currentPhaseDetailBlock(plan: TrainingPlan) -> some View {
        let target = selectedPhaseNumber ?? plan.currentPhase
        if let phase = plan.phases.first(where: { $0.number == target }) {
            PhaseDetailCard(phase: phase, plan: plan)
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
        guard let startStr = plan.startDate else { return "" }
        let inF = DateFormatter()
        inF.dateFormat = "yyyy-MM-dd"
        guard let planStart = inF.date(from: startStr) else { return "" }
        let cal = Calendar.current
        guard let monday = cal.date(byAdding: .day, value: (weekNum - 1) * 7, to: planStart),
              let sunday = cal.date(byAdding: .day, value: 6, to: monday) else { return "" }
        let outF = DateFormatter()
        outF.dateFormat = "MMM d"
        return "\(outF.string(from: monday)) — \(outF.string(from: sunday))"
    }

    // MARK: - Phase date helpers

    private func phaseStart(for phase: TrainingPhase, plan: TrainingPlan) -> String? {
        if let s = phase.startDate, !s.isEmpty { return s }
        guard let planStart = plan.startDate else { return nil }
        let inF = DateFormatter(); inF.dateFormat = "yyyy-MM-dd"
        guard let d = inF.date(from: planStart) else { return nil }
        let startWeekOffset = plan.startWeek(for: phase) - 1
        guard let start = Calendar.current.date(byAdding: .day, value: startWeekOffset * 7, to: d) else { return nil }
        let outF = DateFormatter(); outF.dateFormat = "yyyy-MM-dd"
        return outF.string(from: start)
    }

    private func phaseEnd(for phase: TrainingPhase, plan: TrainingPlan) -> String? {
        if let e = phase.endDate, !e.isEmpty { return e }
        guard let planStart = plan.startDate else { return nil }
        let inF = DateFormatter(); inF.dateFormat = "yyyy-MM-dd"
        guard let d = inF.date(from: planStart) else { return nil }
        let endWeekOffset = plan.endWeek(for: phase) - 1
        // end = start of end week + 6 days
        guard let start = Calendar.current.date(byAdding: .day, value: endWeekOffset * 7, to: d),
              let end = Calendar.current.date(byAdding: .day, value: 6, to: start) else { return nil }
        let outF = DateFormatter(); outF.dateFormat = "yyyy-MM-dd"
        return outF.string(from: end)
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

// MARK: - Phase ruler

private struct PhaseRuler: View {
    let phases: [TrainingPhase]
    let currentPhase: Int
    let totalWeeks: Int

    private let height: CGFloat = 8
    private let gap: CGFloat = 3

    var body: some View {
        GeometryReader { geo in
            let available = max(0, geo.size.width - gap * CGFloat(max(0, phases.count - 1)))
            HStack(spacing: gap) {
                ForEach(phases) { phase in
                    let frac = Double(phase.weeks) / Double(max(1, totalWeeks))
                    RoundedRectangle(cornerRadius: 2)
                        .fill(fill(for: phase))
                        .frame(width: max(4, CGFloat(frac) * available), height: height)
                }
            }
        }
        .frame(height: height)
    }

    private func fill(for phase: TrainingPhase) -> Color {
        if phase.number == currentPhase { return Theme.accent }
        if phase.number < currentPhase { return Theme.ink2.opacity(0.5) }
        return Theme.line2
    }
}

// MARK: - Phase plan row

private struct PhasePlanRow: View {
    let phase: TrainingPhase
    let startDate: String?
    let endDate: String?
    let isCurrent: Bool
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(alignment: .center, spacing: 12) {
                numberBadge
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        if isCurrent {
                            Circle()
                                .fill(Theme.accent)
                                .frame(width: 5, height: 5)
                        }
                        Text(phase.name)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(Theme.ink)
                            .lineLimit(1)
                    }
                    if let range = dateRangeText {
                        Text(range)
                            .font(Theme.Typography.monoMeta)
                            .foregroundStyle(Theme.ink3)
                    }
                }
                Spacer(minLength: 8)
                Text("\(phase.weeks) wks")
                    .font(Theme.Typography.mono(12, weight: .medium))
                    .foregroundStyle(isCurrent ? Theme.accent : Theme.ink2)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(background)
            .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.card))
            .overlay(
                RoundedRectangle(cornerRadius: Theme.Radius.card)
                    .strokeBorder(borderColor, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    private var numberBadge: some View {
        Text("\(phase.number)")
            .font(Theme.Typography.mono(12, weight: .medium))
            .foregroundStyle(isCurrent ? Theme.accentInk : Theme.ink2)
            .frame(width: 22, height: 22)
            .background(
                RoundedRectangle(cornerRadius: Theme.Radius.badge)
                    .fill(isCurrent ? Theme.accent : Theme.surface2)
            )
    }

    private var background: Color {
        if isCurrent { return Theme.accentSoft }
        if isSelected { return Theme.surface2 }
        return Theme.surface1
    }

    private var borderColor: Color {
        if isCurrent { return Theme.accent.opacity(0.5) }
        if isSelected { return Theme.line2 }
        return Theme.line
    }

    private var dateRangeText: String? {
        guard let s = startDate, let e = endDate else { return nil }
        let inF = DateFormatter(); inF.dateFormat = "yyyy-MM-dd"
        guard let sd = inF.date(from: s), let ed = inF.date(from: e) else { return nil }
        let outF = DateFormatter(); outF.dateFormat = "MMM d"
        return "\(outF.string(from: sd)) — \(outF.string(from: ed))"
    }
}

// MARK: - Phase detail card

private struct PhaseDetailCard: View {
    let phase: TrainingPhase
    let plan: TrainingPlan

    var body: some View {
        NavigationLink {
            PhaseDetailView(plan: plan, phase: phase)
        } label: {
            VStack(alignment: .leading, spacing: 14) {
                // Top row: chip + meta
                HStack(alignment: .center) {
                    Chip(title: statusChipTitle, variant: isCurrent ? .done : .default)
                    Spacer(minLength: 8)
                    Text(positionText)
                        .font(Theme.Typography.monoMeta)
                        .foregroundStyle(Theme.ink3)
                }

                // Serif name
                Text(phase.name)
                    .font(Theme.Typography.serifRace)
                    .foregroundStyle(Theme.ink)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)

                // Description
                if let philosophy = phase.philosophy, !philosophy.isEmpty {
                    Text(philosophy)
                        .font(Theme.Typography.body)
                        .foregroundStyle(Theme.ink2)
                        .lineLimit(3)
                        .fixedSize(horizontal: false, vertical: true)
                }

                // Stats row
                HStack(alignment: .top, spacing: 16) {
                    statColumn(label: "Volume",    value: volumeValue,    unit: volumeUnit)
                    statColumn(label: "Sessions",  value: sessionsValue,  unit: sessionsUnit)
                    statColumn(label: "Intensity", value: intensityValue, unit: nil)
                }

                // Key sessions
                if let keys = phase.keyWorkouts, !keys.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Key sessions")
                            .font(Theme.Typography.monoLabelS)
                            .foregroundStyle(Theme.ink3)
                            .textCase(.uppercase)
                            .tracking(Theme.Tracking.monoLabel)
                        VStack(alignment: .leading, spacing: 6) {
                            ForEach(Array(keys.prefix(4))) { kw in
                                HStack(alignment: .top, spacing: 8) {
                                    DisciplineDot(discipline: disciplineForKey(kw))
                                        .padding(.top, 6)
                                    Text(kw.name)
                                        .font(Theme.Typography.body)
                                        .foregroundStyle(Theme.ink)
                                        .lineLimit(1)
                                }
                            }
                        }
                    }
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
        .buttonStyle(.plain)
    }

    private var isCurrent: Bool {
        phase.number == plan.currentPhase
    }

    private var statusChipTitle: String {
        if isCurrent { return "Current phase" }
        if phase.number < plan.currentPhase { return "Completed" }
        return "Upcoming"
    }

    private var positionText: String {
        if isCurrent {
            let idx = plan.weekIndexInPhase(phase)
            return "Week \(idx) of \(phase.weeks)"
        }
        let start = plan.startWeek(for: phase)
        let end = plan.endWeek(for: phase)
        return "Wk \(start)–\(end)"
    }

    private var volumeValue: String {
        guard let vol = phase.weeklyVolumeRange else { return "—" }
        let min = vol.min.truncatingRemainder(dividingBy: 1) == 0 ? String(Int(vol.min)) : String(format: "%.1f", vol.min)
        let max = vol.max.truncatingRemainder(dividingBy: 1) == 0 ? String(Int(vol.max)) : String(format: "%.1f", vol.max)
        return "\(min)–\(max)"
    }

    private var volumeUnit: String? {
        phase.weeklyVolumeRange.map { shortUnit($0.unit) }
    }

    private func shortUnit(_ unit: String) -> String {
        switch unit.lowercased() {
        case "hours", "hr", "h": return "hr"
        case "miles", "mi":      return "mi"
        case "kilometers", "km": return "km"
        default:                 return unit
        }
    }

    private var sessionsValue: String {
        phase.sessionsPerWeek.map(String.init) ?? "—"
    }

    private var sessionsUnit: String? {
        phase.sessionsPerWeek == nil ? nil : "/ wk"
    }

    private var intensityValue: String {
        guard let dist = phase.intensityDistribution else { return "—" }
        return "Easy \(dist.easy)%"
    }

    private func statColumn(label: String, value: String, unit: String?) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(Theme.Typography.monoLabelS)
                .foregroundStyle(Theme.ink3)
                .textCase(.uppercase)
                .tracking(Theme.Tracking.monoLabel)
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(value)
                    .font(Theme.Typography.mono(16, weight: .medium))
                    .foregroundStyle(Theme.ink)
                if let unit {
                    Text(unit)
                        .font(Theme.Typography.mono(11))
                        .foregroundStyle(Theme.ink3)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func disciplineForKey(_ kw: KeyWorkout) -> Theme.Discipline {
        let lower = kw.name.lowercased()
        if lower.contains("swim") { return .swim }
        if lower.contains("bike") || lower.contains("ride") || lower.contains("cycle") || lower.contains("spin") { return .bike }
        if lower.contains("strength") || lower.contains("lift") || lower.contains("gym") { return .strength }
        if lower.contains("recovery") || lower.contains("rest") { return .recovery }
        return .run
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
                isResolved: false
            )
        } else if dayPlan.sessions.isEmpty {
            sessionRow(
                dayLetter: dayLetter(dayIdx),
                discipline: .recovery,
                title: "—",
                duration: nil,
                isToday: isToday,
                isResolved: false
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
                        isResolved: session.isResolved
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
        isResolved: Bool
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
                .foregroundStyle(isResolved ? Theme.ink3 : Theme.ink)
                .strikethrough(isResolved, color: Theme.ink3)
                .lineLimit(1)
            Spacer(minLength: 8)
            if let duration {
                Text(duration)
                    .font(Theme.Typography.mono(12))
                    .foregroundStyle(isResolved ? Theme.ink3 : Theme.ink2)
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
