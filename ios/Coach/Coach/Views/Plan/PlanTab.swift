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
                        headerBlock(plan: plan, planExists: true)
                        pregeneratedBanner
                        raceHeroBlock(plan: plan)
                        seasonBlock(plan: plan)
                    }
                    .padding(.horizontal, Theme.Spacing.screenH)
                    .padding(.top, 16)
                } else {
                    VStack(alignment: .leading, spacing: Theme.Spacing.section) {
                        headerBlock(plan: nil, planExists: false)
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
    private func headerBlock(plan: TrainingPlan?, planExists: Bool) -> some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Training Plan")
                    .font(Theme.Typography.pageTitle)
                    .foregroundStyle(Theme.ink)
                    .tracking(-0.5)
                if let subtitle = planRangeSubtitle(plan: plan) {
                    Text(subtitle)
                        .font(Theme.Typography.monoData)
                        .foregroundStyle(Theme.ink3)
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

    /// "Apr 19 → Sep 27 · 24 weeks" — start of plan, race day, total length.
    private func planRangeSubtitle(plan: TrainingPlan?) -> String? {
        guard let plan else { return nil }
        let start = plan.startDate.flatMap(monthDay)
        let end = plan.raceDate.flatMap(monthDay)
        let weeks = "\(plan.totalWeeks) weeks"
        switch (start, end) {
        case let (s?, e?): return "\(s) → \(e) · \(weeks)"
        case let (s?, nil): return "\(s) · \(weeks)"
        default:            return weeks
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

    // MARK: - Race hero (containerized)

    @ViewBuilder
    private func raceHeroBlock(plan: TrainingPlan) -> some View {
        if let name = plan.raceName, !name.isEmpty, let dateStr = plan.raceDate {
            let (count, unit) = countdownParts(dateStr)
            let location = raceLocation(plan: plan)
            RaceHeroCard(
                name: raceTypeTitle(name: name, location: location),
                location: location,
                date: formatRaceDate(dateStr),
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

    private func raceLocation(plan: TrainingPlan) -> String? {
        guard let goalId = plan.goalId,
              let event = data.events.first(where: { $0.id == goalId }),
              let location = event.location, !location.isEmpty else { return nil }
        return location
    }

    private func formatRaceDate(_ dateStr: String) -> String {
        let inF = DateFormatter()
        inF.dateFormat = "yyyy-MM-dd"
        guard let d = inF.date(from: dateStr) else { return dateStr }
        let outF = DateFormatter()
        outF.dateFormat = "EEE · MMM d · yyyy"
        return outF.string(from: d)
    }

    // MARK: - Season (timeline + phase detail)

    @ViewBuilder
    private func seasonBlock(plan: TrainingPlan) -> some View {
        let sorted = plan.phases.sorted { $0.number < $1.number }
        let selected = selectedPhaseNumber ?? plan.currentPhase
        VStack(alignment: .leading, spacing: 18) {
            seasonHeader(plan: plan)

            SeasonTimeline(
                phases: sorted,
                totalWeeks: plan.totalWeeks,
                currentPhase: plan.currentPhase,
                selectedPhase: selected,
                progress: progressFraction(plan: plan)
            ) { number in
                select(number)
            }

            if let phase = sorted.first(where: { $0.number == selected }) {
                PhaseDetailCard(
                    phase: phase,
                    plan: plan,
                    startDate: phaseStart(for: phase, plan: plan),
                    endDate: phaseEnd(for: phase, plan: plan),
                    phaseNumbers: sorted.map(\.number),
                    onSelectPhase: { select($0) }
                )
                .id(selected)
                .transition(.opacity)
            }
        }
    }

    @ViewBuilder
    private func seasonHeader(plan: TrainingPlan) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline) {
                Text("Your season")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(Theme.ink)
                    .tracking(-0.3)
                Spacer(minLength: 8)
                Text("Tap a phase")
                    .font(Theme.Typography.monoLabelS)
                    .foregroundStyle(Theme.ink3)
                    .textCase(.uppercase)
                    .tracking(Theme.Tracking.monoLabel)
            }
            seasonSubtitle(plan: plan)
        }
    }

    @ViewBuilder
    private func seasonSubtitle(plan: TrainingPlan) -> some View {
        let started = plan.startDate.flatMap(monthDay) ?? "—"
        Text("Started **\(started)**  ·  Week **\(plan.currentWeek) of \(plan.totalWeeks)**")
            .font(Theme.Typography.monoMeta)
            .foregroundStyle(Theme.ink3)
    }

    private func select(_ number: Int) {
        withAnimation(.easeInOut(duration: 0.22)) {
            selectedPhaseNumber = number
        }
    }

    /// Fraction [0,1] of the plan elapsed as of today — drives the "now" dot.
    /// Anchored to the midpoint of the current week so the dot sits inside the
    /// active week's slot rather than on its boundary.
    private func progressFraction(plan: TrainingPlan) -> Double {
        guard plan.totalWeeks > 0 else { return 0 }
        let raw = (Double(plan.currentWeek) - 0.5) / Double(plan.totalWeeks)
        return min(0.985, max(0.015, raw))
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

// MARK: - Month/day helper

/// "Apr 19" from a "yyyy-MM-dd" string, or nil.
private func monthDay(_ dateStr: String) -> String? {
    let inF = DateFormatter(); inF.dateFormat = "yyyy-MM-dd"
    guard let d = inF.date(from: dateStr) else { return nil }
    let outF = DateFormatter(); outF.dateFormat = "MMM d"
    return outF.string(from: d)
}

// MARK: - Season timeline

/// Horizontal phase timeline: tappable phase labels above an axis, proportional
/// phase segments, boundary ticks, a glowing "now" dot at today's position, and
/// a connector dropping from the selected phase toward the detail card below.
private struct SeasonTimeline: View {
    let phases: [TrainingPhase]
    let totalWeeks: Int
    let currentPhase: Int
    let selectedPhase: Int
    /// Fraction [0,1] of the plan elapsed as of today.
    let progress: Double
    let onSelect: (Int) -> Void

    private let axisY: CGFloat = 30
    private let labelY: CGFloat = 8
    private let connectorDrop: CGFloat = 20
    private var totalHeight: CGFloat { axisY + connectorDrop + 8 }

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let layout = segments()

            ZStack(alignment: .topLeading) {
                // Phase labels (tappable)
                ForEach(layout, id: \.number) { seg in
                    let x = clamp(seg.center * w, w)
                    Button { onSelect(seg.number) } label: {
                        Text(seg.label)
                            .font(.system(size: 13, weight: seg.number == selectedPhase ? .semibold : .medium))
                            .foregroundStyle(labelColor(seg.number))
                            .lineLimit(1)
                            .fixedSize()
                    }
                    .buttonStyle(.plain)
                    .position(x: x, y: labelY)
                }

                // Track (unfilled)
                Capsule()
                    .fill(Theme.line2)
                    .frame(width: w, height: 2)
                    .position(x: w / 2, y: axisY)

                // Filled portion up to "now"
                Capsule()
                    .fill(Theme.accent)
                    .frame(width: max(2, progress * w), height: 2)
                    .position(x: max(2, progress * w) / 2, y: axisY)

                // Boundary ticks (internal phase joins)
                ForEach(layout.dropLast(), id: \.number) { seg in
                    Rectangle()
                        .fill(Theme.line2)
                        .frame(width: 1, height: 9)
                        .position(x: seg.end * w, y: axisY)
                }

                // End arrow
                Image(systemName: "arrowtriangle.right.fill")
                    .font(.system(size: 9))
                    .foregroundStyle(Theme.line2)
                    .position(x: w - 2, y: axisY)

                // Connector from selected phase down to the card
                if let sel = layout.first(where: { $0.number == selectedPhase }) {
                    let cx = clamp(sel.center * w, w)
                    let connectorColor = selectedPhase == currentPhase ? Theme.accent : Theme.line2
                    Rectangle()
                        .fill(connectorColor)
                        .frame(width: 1.5, height: connectorDrop)
                        .position(x: cx, y: axisY + connectorDrop / 2)
                }

                // "Now" dot (glowing) — drawn last so it sits on top
                nowDot
                    .position(x: progress * w, y: axisY)
            }
            .frame(width: w, height: totalHeight)
        }
        .frame(height: totalHeight)
    }

    private var nowDot: some View {
        ZStack {
            Circle()
                .fill(Theme.accent.opacity(0.25))
                .frame(width: 18, height: 18)
            Circle()
                .fill(Theme.accent)
                .frame(width: 10, height: 10)
                .overlay(Circle().strokeBorder(Theme.bg, lineWidth: 2))
        }
        .shadow(color: Theme.accent.opacity(0.6), radius: 5)
    }

    private func labelColor(_ number: Int) -> Color {
        if number == currentPhase { return Theme.accent }
        if number == selectedPhase { return Theme.ink }
        return Theme.ink3
    }

    /// Keeps a label/connector center inside the timeline so edge phases
    /// don't clip past the screen padding.
    private func clamp(_ x: CGFloat, _ w: CGFloat) -> CGFloat {
        min(w - 24, max(24, x))
    }

    private struct Segment {
        let number: Int
        let label: String
        let start: Double   // fraction
        let end: Double     // fraction
        var center: Double { (start + end) / 2 }
    }

    private func segments() -> [Segment] {
        let total = max(1, totalWeeks)
        var cursor = 0
        return phases.map { phase in
            let start = Double(cursor) / Double(total)
            cursor += phase.weeks
            let end = Double(cursor) / Double(total)
            return Segment(number: phase.number, label: shortName(phase.name), start: start, end: end)
        }
    }

    /// Timeline labels use the leading word of the phase name
    /// ("Base Development" → "Base", "Build 2" → "Build").
    private func shortName(_ name: String) -> String {
        name.split(separator: " ").first.map(String.init) ?? name
    }
}

// MARK: - Phase detail card

private struct PhaseDetailCard: View {
    let phase: TrainingPhase
    let plan: TrainingPlan
    let startDate: String?
    let endDate: String?
    let phaseNumbers: [Int]
    let onSelectPhase: (Int) -> Void

    @GestureState private var dragOffset: CGFloat = 0

    var body: some View {
        NavigationLink {
            PhaseDetailView(plan: plan, phase: phase)
        } label: {
            cardBody
        }
        .buttonStyle(.plain)
        .offset(x: dragOffset)
        .simultaneousGesture(swipeGesture)
    }

    private var cardBody: some View {
        VStack(alignment: .leading, spacing: 14) {
            // Top row: status pill + chevron
            HStack(alignment: .center, spacing: 8) {
                Text(phase.name)
                    .font(Theme.Typography.serifRace)
                    .foregroundStyle(Theme.ink)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 8)
                statusPill
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Theme.ink3)
            }

            // Date range
            if let range = dateRangeText {
                Text(range)
                    .font(Theme.Typography.monoMeta)
                    .foregroundStyle(Theme.ink3)
            }

            Hairline()

            // Description
            if let philosophy = phase.philosophy, !philosophy.isEmpty {
                Text(philosophy)
                    .font(Theme.Typography.body)
                    .foregroundStyle(Theme.ink2)
                    .lineLimit(4)
                    .fixedSize(horizontal: false, vertical: true)
            }

            // Stats row
            HStack(alignment: .top, spacing: 16) {
                statColumn(label: "Volume",    value: volumeValue,    unit: volumeUnit)
                statColumn(label: "Sessions",  value: sessionsValue,  unit: sessionsUnit)
                statColumn(label: "Easy work", value: easyValue,      unit: nil)
            }
        }
        .padding(Theme.Spacing.cardP)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(isCurrent ? Theme.accentSoft : Theme.surface1)
        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.card))
        .overlay(
            RoundedRectangle(cornerRadius: Theme.Radius.card)
                .strokeBorder(isCurrent ? Theme.accent.opacity(0.5) : Theme.line, lineWidth: 1)
        )
    }

    // MARK: Swipe between phases

    private var swipeGesture: some Gesture {
        DragGesture(minimumDistance: 24)
            .updating($dragOffset) { value, state, _ in
                // Only track largely-horizontal drags; resist past the ends.
                guard abs(value.translation.width) > abs(value.translation.height) else { return }
                state = value.translation.width * 0.35
            }
            .onEnded { value in
                guard abs(value.translation.width) > abs(value.translation.height) else { return }
                let threshold: CGFloat = 60
                if value.translation.width <= -threshold {
                    advance(by: 1)
                } else if value.translation.width >= threshold {
                    advance(by: -1)
                }
            }
    }

    private func advance(by step: Int) {
        guard let idx = phaseNumbers.firstIndex(of: phase.number) else { return }
        let next = idx + step
        guard next >= 0, next < phaseNumbers.count else { return }
        onSelectPhase(phaseNumbers[next])
    }

    // MARK: Status pill

    @ViewBuilder
    private var statusPill: some View {
        Text(pillText)
            .font(Theme.Typography.mono(11, weight: .semibold))
            .textCase(.uppercase)
            .tracking(Theme.Tracking.monoLabelTight)
            .foregroundStyle(isCurrent ? Theme.accentInk : Theme.ink2)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(
                Capsule().fill(isCurrent ? Theme.accent : Theme.surface2)
            )
            .overlay(
                Capsule().strokeBorder(isCurrent ? .clear : Theme.line, lineWidth: 1)
            )
    }

    private var pillText: String {
        if isCurrent {
            let idx = plan.weekIndexInPhase(phase)
            return "Now · Wk \(idx) of \(phase.weeks)"
        }
        if phase.number < plan.currentPhase {
            return "Completed"
        }
        if let start = startDate, let days = daysUntil(start), days > 0 {
            let weeks = Int((Double(days) / 7.0).rounded())
            if weeks >= 1 { return "\(weeks) \(weeks == 1 ? "week" : "weeks") out" }
            return "\(days) \(days == 1 ? "day" : "days") out"
        }
        return "Upcoming"
    }

    private var isCurrent: Bool {
        phase.number == plan.currentPhase
    }

    // MARK: Stats

    private var dateRangeText: String? {
        guard let s = startDate, let e = endDate else { return nil }
        let inF = DateFormatter(); inF.dateFormat = "yyyy-MM-dd"
        guard let sd = inF.date(from: s), let ed = inF.date(from: e) else { return nil }
        let outF = DateFormatter(); outF.dateFormat = "MMM d"
        let weeks = "\(phase.weeks) \(phase.weeks == 1 ? "week" : "weeks")"
        return "\(outF.string(from: sd)) — \(outF.string(from: ed))  ·  \(weeks)"
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

    private var easyValue: String {
        guard let dist = phase.intensityDistribution else { return "—" }
        return "\(dist.easy)%"
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
}
