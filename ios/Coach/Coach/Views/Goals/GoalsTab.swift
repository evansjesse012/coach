import SwiftUI

struct GoalsTab: View {
    @Environment(DataService.self) private var data

    @State private var showPicker = false
    @State private var showFormSheet = false
    @State private var showChatSheet = false
    @State private var createMode: EventMode = .goal

    // MARK: - Data slices

    private var activeRaces: [Event] {
        data.events.filter { $0.isRace && !$0.completed }
            .sorted { (a, b) in
                switch (a.date, b.date) {
                case (let ad?, let bd?): return ad < bd
                case (_?, nil):          return true
                case (nil, _?):          return false
                default:                 return a.name < b.name
                }
            }
    }

    private var activeGoals: [Event] {
        data.events.filter { $0.isGoal && !$0.completed }
            .sorted { (a, b) in
                switch (a.date, b.date) {
                case (let ad?, let bd?): return ad < bd
                case (_?, nil):          return true
                case (nil, _?):          return false
                default:                 return a.name < b.name
                }
            }
    }

    private var completedEvents: [Event] {
        data.events.filter(\.completed)
            .sorted { a, b in
                (a.date ?? "") > (b.date ?? "")   // most recent first
            }
    }

    /// The "A-race" is whichever race the current training plan is linked to.
    /// Falls back to the soonest upcoming race if no plan.
    private var aRaceId: String? {
        if let linked = data.trainingPlan?.goalId,
           data.events.contains(where: { $0.id == linked && $0.isRace && !$0.completed }) {
            return linked
        }
        return activeRaces.first?.id
    }

    private var activeCount: Int { activeRaces.count + activeGoals.count }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Theme.Spacing.section) {
                    headerBlock
                    if activeCount == 0 && completedEvents.isEmpty {
                        emptyState
                    } else {
                        summaryStrip
                        activeBlock
                        completedBlock
                    }
                }
                .padding(.horizontal, Theme.Spacing.screenH)
                .padding(.top, 16)
                .padding(.bottom, Theme.Spacing.bottomReserve)
            }
            .background(Theme.bg.ignoresSafeArea())
            .scrollContentBackground(.hidden)
            .sheet(isPresented: $showPicker) {
                GoalCreationPickerSheet { mode in
                    switch mode {
                    case .chat: showChatSheet = true
                    case .form: showFormSheet = true
                    }
                }
            }
            .sheet(isPresented: $showFormSheet) {
                CreateGoalSheet(isPresented: $showFormSheet, initialMode: createMode)
            }
            .sheet(isPresented: $showChatSheet) {
                RaceCreationChatSheet()
            }
        }
    }

    // MARK: - Header

    @ViewBuilder
    private var headerBlock: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Your goals")
                    .font(Theme.Typography.monoLabel)
                    .foregroundStyle(Theme.ink3)
                    .textCase(.uppercase)
                    .tracking(Theme.Tracking.monoLabel)
                Text(activeCount == 1 ? "1 active" : "\(activeCount) active")
                    .font(Theme.Typography.pageTitle)
                    .foregroundStyle(Theme.ink)
                    .tracking(-0.5)
            }
            Spacer(minLength: 0)
            Menu {
                Button {
                    createMode = .goal
                    showPicker = true
                } label: {
                    Label("Add Goal", systemImage: "target")
                }
                Button {
                    createMode = .race
                    showPicker = true
                } label: {
                    Label("Add Race", systemImage: "flag.checkered")
                }
            } label: {
                Image(systemName: "plus")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Theme.ink2)
                    .frame(width: 40, height: 40)
                    .background(Circle().strokeBorder(Theme.line, lineWidth: 1))
            }
        }
    }

    // MARK: - Summary strip

    @ViewBuilder
    private var summaryStrip: some View {
        HStack(spacing: 0) {
            summaryCell(label: "Next race",    value: nextRaceWeeksValue,  trailing: false)
            dividerColumn
            summaryCell(label: "Active",       value: "\(activeCount)",    trailing: false)
            dividerColumn
            summaryCell(label: "PRs this year",value: "\(prsThisYear)",    trailing: true)
        }
        .padding(.vertical, 14)
        .frame(maxWidth: .infinity)
        .background(Theme.surface1)
        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.card))
        .overlay(
            RoundedRectangle(cornerRadius: Theme.Radius.card)
                .strokeBorder(Theme.line, lineWidth: 1)
        )
    }

    private var dividerColumn: some View {
        Rectangle()
            .fill(Theme.line)
            .frame(width: 1, height: 36)
    }

    private func summaryCell(label: String, value: String, trailing: Bool) -> some View {
        VStack(alignment: .center, spacing: 4) {
            Text(value)
                .font(Theme.Typography.mono(20, weight: .medium))
                .foregroundStyle(Theme.ink)
            Text(label)
                .font(Theme.Typography.monoLabelS)
                .foregroundStyle(Theme.ink3)
                .textCase(.uppercase)
                .tracking(Theme.Tracking.monoLabel)
        }
        .frame(maxWidth: .infinity)
    }

    private var nextRaceWeeksValue: String {
        guard let date = activeRaces.first?.date, let days = daysUntil(date) else { return "—" }
        if days <= 0 { return "0W" }
        if days < 14 { return "\(days)D" }
        return "\(days / 7)W"
    }

    private var prsThisYear: Int {
        let year = Calendar.current.component(.year, from: Date())
        let prefix = "\(year)"
        return data.prs.values.filter { ($0.date ?? "").hasPrefix(prefix) }.count
    }

    // MARK: - Active block

    @ViewBuilder
    private var activeBlock: some View {
        if activeCount > 0 {
            VStack(alignment: .leading, spacing: 12) {
                SectionHeader(
                    title: "Active",
                    meta: "\(activeCount) \(activeCount == 1 ? "goal" : "goals")"
                )
                VStack(spacing: 12) {
                    ForEach(activeRaces) { race in
                        NavigationLink {
                            RaceDetailView(eventId: race.id)
                        } label: {
                            ActiveEventCard(event: race, isARace: race.id == aRaceId, planContext: data.trainingPlan)
                        }
                        .buttonStyle(.plain)
                    }
                    ForEach(activeGoals) { goal in
                        NavigationLink {
                            GoalDetailView(eventId: goal.id)
                        } label: {
                            ActiveEventCard(event: goal, isARace: false, planContext: nil)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    // MARK: - Completed block

    @ViewBuilder
    private var completedBlock: some View {
        if !completedEvents.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                SectionHeader(
                    title: "Done",
                    meta: "\(completedEvents.count)"
                )
                VStack(spacing: 0) {
                    ForEach(Array(completedEvents.enumerated()), id: \.element.id) { idx, event in
                        NavigationLink {
                            if event.isRace {
                                RaceDetailView(eventId: event.id)
                            } else {
                                GoalDetailView(eventId: event.id)
                            }
                        } label: {
                            CompletedEventRow(event: event)
                        }
                        .buttonStyle(.plain)
                        if idx < completedEvents.count - 1 {
                            Hairline()
                        }
                    }
                }
            }
        }
    }

    // MARK: - Empty state

    @ViewBuilder
    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("No goals yet")
                .font(Theme.Typography.sessionTitle)
                .foregroundStyle(Theme.ink)
            Text("Add a training goal or race to give the coach something to build toward.")
                .font(Theme.Typography.body)
                .foregroundStyle(Theme.ink2)
                .fixedSize(horizontal: false, vertical: true)
            HStack(spacing: 10) {
                Pill(title: "Add a race", variant: .primary) {
                    createMode = .race
                    showPicker = true
                }
                Pill(title: "Add a goal", variant: .secondary) {
                    createMode = .goal
                    showPicker = true
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
}

// MARK: - Active event card (race or goal)

private struct ActiveEventCard: View {
    let event: Event
    let isARace: Bool
    /// Current training plan; used to show progress against the A-race.
    let planContext: TrainingPlan?

    var body: some View {
        HStack(spacing: 0) {
            if isARace {
                Rectangle()
                    .fill(Theme.accent)
                    .frame(width: 3)
            }
            VStack(alignment: .leading, spacing: 14) {
                topRow
                Text(event.name)
                    .font(isARace ? Theme.Typography.serifRace : Theme.Typography.sessionTitle)
                    .foregroundStyle(Theme.ink)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
                subRow
                if event.goal != nil || progressFraction != nil {
                    targetRow
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 16)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.surface1)
        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.card))
        .overlay(
            RoundedRectangle(cornerRadius: Theme.Radius.card)
                .strokeBorder(isARace ? Theme.accent.opacity(0.55) : Theme.line, lineWidth: 1)
        )
    }

    // MARK: Top row (kicker + countdown)

    private var topRow: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text(kicker)
                .font(Theme.Typography.monoLabel)
                .foregroundStyle(isARace ? Theme.accent : Theme.ink3)
                .textCase(.uppercase)
                .tracking(Theme.Tracking.monoLabel)
            Spacer(minLength: 0)
            if let (count, unit) = countdownParts {
                HStack(alignment: .firstTextBaseline, spacing: 3) {
                    Text("\(count)")
                        .font(Theme.Typography.mono(18, weight: .semibold))
                        .foregroundStyle(isARace ? Theme.accent : Theme.ink)
                    Text(unit)
                        .font(Theme.Typography.monoLabel)
                        .foregroundStyle(isARace ? Theme.accent : Theme.ink3)
                        .tracking(Theme.Tracking.monoLabel)
                }
            }
        }
    }

    private var kicker: String {
        if isARace { return "A-Race" }
        return event.isRace ? "Race" : "Goal"
    }

    private var countdownParts: (Int, String)? {
        guard let date = event.date, let days = daysUntil(date) else { return nil }
        if days <= 0 { return (0, "today") }
        if days < 14 { return (days, days == 1 ? "day" : "days") }
        let weeks = days / 7
        return (weeks, weeks == 1 ? "wk" : "wks")
    }

    // MARK: Sub row (date + location)

    private var subRow: some View {
        HStack(spacing: 8) {
            if let date = event.date, !date.isEmpty {
                Text(formattedDate(date))
                    .font(Theme.Typography.monoData)
                    .foregroundStyle(Theme.ink3)
            }
            if let location = event.location, !location.isEmpty {
                Text("·")
                    .font(Theme.Typography.monoData)
                    .foregroundStyle(Theme.ink3)
                Text(location)
                    .font(Theme.Typography.monoData)
                    .foregroundStyle(Theme.ink3)
                    .lineLimit(1)
            }
            Spacer(minLength: 0)
        }
    }

    private func formattedDate(_ dateStr: String) -> String {
        let inF = DateFormatter(); inF.dateFormat = "yyyy-MM-dd"
        guard let d = inF.date(from: dateStr) else { return dateStr }
        let outF = DateFormatter(); outF.dateFormat = "EEE · MMM d · yyyy"
        return outF.string(from: d)
    }

    // MARK: Target row (label/value + progress bar)

    private var targetRow: some View {
        HStack(alignment: .center, spacing: 14) {
            VStack(alignment: .leading, spacing: 3) {
                Text("Target")
                    .font(Theme.Typography.monoLabelS)
                    .foregroundStyle(Theme.ink3)
                    .textCase(.uppercase)
                    .tracking(Theme.Tracking.monoLabel)
                Text(event.goal ?? "—")
                    .font(Theme.Typography.mono(14, weight: .medium))
                    .foregroundStyle(Theme.ink)
                    .lineLimit(1)
            }
            Spacer(minLength: 12)
            if let frac = progressFraction {
                HStack(spacing: 8) {
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Capsule().fill(Theme.surface2)
                            Capsule()
                                .fill(isARace ? Theme.accent : Theme.ink2)
                                .frame(width: max(0, min(1, frac)) * geo.size.width)
                        }
                    }
                    .frame(width: 80, height: 4)
                    Text("\(Int((frac * 100).rounded()))%")
                        .font(Theme.Typography.mono(12, weight: .medium))
                        .foregroundStyle(isARace ? Theme.accent : Theme.ink2)
                }
            }
        }
    }

    private var progressFraction: Double? {
        guard isARace, let plan = planContext, plan.goalId == event.id else { return nil }
        return Double(plan.currentWeek) / Double(max(1, plan.totalWeeks))
    }
}

// MARK: - Completed event row (flat list)

private struct CompletedEventRow: View {
    let event: Event

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text(event.name)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Theme.ink)
                    .lineLimit(1)
                if let context = subContext {
                    Text(context)
                        .font(Theme.Typography.monoMeta)
                        .foregroundStyle(Theme.ink3)
                        .lineLimit(1)
                }
            }
            Spacer(minLength: 8)
            Text(resultText)
                .font(Theme.Typography.mono(11, weight: .medium))
                .foregroundStyle(Theme.accent)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(Theme.accentSoft)
                .clipShape(Capsule())
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
    }

    private var resultText: String {
        if let r = event.result, !r.isEmpty {
            return "Hit \(r)"
        }
        return "Done"
    }

    private var subContext: String? {
        var parts: [String] = []
        if let date = event.date, !date.isEmpty {
            parts.append(formatShort(date))
        }
        if let location = event.location, !location.isEmpty {
            parts.append(location)
        }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }

    private func formatShort(_ dateStr: String) -> String {
        let inF = DateFormatter(); inF.dateFormat = "yyyy-MM-dd"
        guard let d = inF.date(from: dateStr) else { return dateStr }
        let outF = DateFormatter(); outF.dateFormat = "MMM d, yyyy"
        return outF.string(from: d)
    }
}
