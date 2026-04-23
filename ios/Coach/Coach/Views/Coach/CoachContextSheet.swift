import SwiftUI

/// Bottom-sheet shown from the chat overflow menu. Surfaces the context
/// the coach LLM receives in its system prompt — current race, current
/// phase, and recent resolved sessions — so the athlete can verify what
/// the coach "knows" without that information eating screen space in
/// every chat turn.
struct CoachContextSheet: View {
    @Environment(DataService.self) private var data
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Theme.Spacing.section) {
                    if let plan = data.trainingPlan {
                        currentRaceSection(plan: plan)
                        trainingPhaseSection(plan: plan)
                    } else {
                        Text("No active plan yet. Build one and your coach will have something to work with.")
                            .font(Theme.Typography.body)
                            .foregroundStyle(Theme.ink2)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    if !recentResolvedSessions.isEmpty {
                        recentTrainingSection
                    }
                }
                .padding(.horizontal, Theme.Spacing.screenH)
                .padding(.top, 8)
                .padding(.bottom, 40)
            }
            .background(Theme.bg.ignoresSafeArea())
            .scrollContentBackground(.hidden)
            .navigationTitle("What your coach knows")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(Theme.ink2)
                            .frame(width: 34, height: 34)
                            .background(Circle().strokeBorder(Theme.line, lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    // MARK: - Current race

    @ViewBuilder
    private func currentRaceSection(plan: TrainingPlan) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionLabel("Current race")
            if let name = plan.raceName, !name.isEmpty {
                Text(name)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Theme.ink)
            } else {
                Text("Unnamed race")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Theme.ink2)
            }
            if let dateLine = raceDateLine(plan: plan) {
                Text(dateLine)
                    .font(Theme.Typography.monoMeta)
                    .foregroundStyle(Theme.ink3)
            }
            weeksOutLabel(plan: plan)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Theme.Spacing.cardP)
        .background(Theme.surface1)
        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.card))
        .overlay(
            RoundedRectangle(cornerRadius: Theme.Radius.card)
                .strokeBorder(Theme.line, lineWidth: 1)
        )
    }

    private func raceDateLine(plan: TrainingPlan) -> String? {
        guard let dateStr = plan.raceDate else { return nil }
        let inF = DateFormatter(); inF.dateFormat = "yyyy-MM-dd"
        let pretty: String = {
            if let d = inF.date(from: dateStr) {
                let outF = DateFormatter(); outF.dateFormat = "EEE · MMM d · yyyy"
                return outF.string(from: d)
            }
            return dateStr
        }()
        if let goalId = plan.goalId,
           let event = data.events.first(where: { $0.id == goalId }),
           let location = event.location, !location.isEmpty {
            return "\(pretty) · \(location)"
        }
        return pretty
    }

    @ViewBuilder
    private func weeksOutLabel(plan: TrainingPlan) -> some View {
        if let dateStr = plan.raceDate, let days = daysUntil(dateStr) {
            let (count, unit) = countdownParts(days: days)
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text("\(count)")
                    .font(Theme.Typography.mono(20, weight: .medium))
                    .foregroundStyle(Theme.accent)
                Text(unit.uppercased())
                    .font(Theme.Typography.monoLabel)
                    .tracking(Theme.Tracking.monoLabel)
                    .foregroundStyle(Theme.ink3)
            }
            .padding(.top, 4)
        }
    }

    private func countdownParts(days: Int) -> (Int, String) {
        if days <= 0 { return (0, "today") }
        if days < 14 { return (days, days == 1 ? "day out" : "days out") }
        let weeks = days / 7
        return (weeks, weeks == 1 ? "week out" : "weeks out")
    }

    // MARK: - Training phase

    @ViewBuilder
    private func trainingPhaseSection(plan: TrainingPlan) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionLabel("Training phase")
            if let phase = plan.current {
                Text(phase.plainLanguageLabel)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Theme.ink)
                Text(phaseMeta(phase: phase, plan: plan))
                    .font(Theme.Typography.monoMeta)
                    .foregroundStyle(Theme.ink3)
            } else {
                Text("No phase in progress")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Theme.ink2)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Theme.Spacing.cardP)
        .background(Theme.surface1)
        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.card))
        .overlay(
            RoundedRectangle(cornerRadius: Theme.Radius.card)
                .strokeBorder(Theme.line, lineWidth: 1)
        )
    }

    private func phaseMeta(phase: TrainingPhase, plan: TrainingPlan) -> String {
        let idx = plan.weekIndexInPhase(phase)
        return "\(phase.name) · Week \(idx) of \(phase.weeks)"
    }

    // MARK: - Recent training

    @ViewBuilder
    private var recentTrainingSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionLabel("Recent training")
            VStack(spacing: 0) {
                ForEach(Array(recentResolvedSessions.enumerated()), id: \.offset) { idx, item in
                    recentRow(item: item)
                    if idx < recentResolvedSessions.count - 1 {
                        Hairline()
                    }
                }
            }
            .padding(.vertical, 4)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.surface1)
            .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.card))
            .overlay(
                RoundedRectangle(cornerRadius: Theme.Radius.card)
                    .strokeBorder(Theme.line, lineWidth: 1)
            )
        }
    }

    private func recentRow(item: RecentSession) -> some View {
        HStack(spacing: 10) {
            DisciplineDot(discipline: item.discipline)
            VStack(alignment: .leading, spacing: 2) {
                Text(item.name)
                    .font(Theme.Typography.body)
                    .foregroundStyle(Theme.ink)
                    .lineLimit(1)
                Text(item.dateLabel)
                    .font(Theme.Typography.monoMeta)
                    .foregroundStyle(Theme.ink3)
            }
            Spacer(minLength: 8)
            Text(item.statusLabel)
                .font(Theme.Typography.monoLabelS)
                .tracking(Theme.Tracking.monoLabel)
                .foregroundStyle(item.statusColor)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }

    // MARK: - Section label

    private func sectionLabel(_ text: String) -> some View {
        Text(text)
            .font(Theme.Typography.monoLabel)
            .foregroundStyle(Theme.ink3)
            .textCase(.uppercase)
            .tracking(Theme.Tracking.monoLabel)
    }

    // MARK: - Recent session model

    private struct RecentSession {
        let name: String
        let dateLabel: String
        let discipline: Theme.Discipline
        let statusLabel: String
        let statusColor: Color
    }

    /// The 3 most recent resolved sessions across the whole plan. Ordered
    /// most-recent first. Returns an empty array when nothing has been
    /// marked yet.
    private var recentResolvedSessions: [RecentSession] {
        guard let plan = data.trainingPlan else { return [] }
        var collected: [(dateStr: String, session: PrescribedSession, weekNum: Int, dayIdx: Int)] = []
        for (weekKey, wp) in plan.weeklyPlans {
            guard let weekNum = Int(weekKey) else { continue }
            for (dayIdx, dayPlan) in wp.sessions.enumerated() {
                for session in dayPlan.sessions where session.completionStatus != nil {
                    let dateStr = sessionDateString(
                        planStartDate: plan.startDate,
                        weekNumber: weekNum,
                        dayIdx: dayIdx
                    ) ?? ""
                    collected.append((dateStr, session, weekNum, dayIdx))
                }
            }
        }
        let sorted = collected.sorted { $0.dateStr > $1.dateStr }
        return sorted.prefix(3).map { item in
            RecentSession(
                name: item.session.label,
                dateLabel: prettyDate(item.dateStr),
                discipline: item.session.sessionDiscipline,
                statusLabel: statusLabel(for: item.session),
                statusColor: statusColor(for: item.session)
            )
        }
    }

    private func prettyDate(_ dateStr: String) -> String {
        guard !dateStr.isEmpty else { return "" }
        let inF = DateFormatter(); inF.dateFormat = "yyyy-MM-dd"
        guard let d = inF.date(from: dateStr) else { return dateStr }
        let outF = DateFormatter(); outF.dateFormat = "EEE · MMM d"
        return outF.string(from: d)
    }

    private func statusLabel(for session: PrescribedSession) -> String {
        switch session.completionStatus {
        case .completed: return "DONE"
        case .modified:  return "MODIFIED"
        case .swapped:   return "SWAPPED"
        case .skipped:   return "SKIPPED"
        case .none:      return ""
        }
    }

    private func statusColor(for session: PrescribedSession) -> Color {
        switch session.completionStatus {
        case .completed: return CoachColors.green
        case .modified:  return CoachColors.yellow
        case .swapped:   return Theme.info
        case .skipped:   return Theme.warn
        case .none:      return Theme.ink3
        }
    }
}

// MARK: - PrescribedSession discipline mapping for context sheet

private extension PrescribedSession {
    /// Maps the session's domain sport to the design-system discipline. For
    /// swapped sessions, prefers the sport the athlete actually did.
    var sessionDiscipline: Theme.Discipline {
        if completionStatus == .swapped,
           let actual = actualSport, !actual.isEmpty,
           let sport = Sport(rawValue: actual) {
            return sport.discipline
        }
        if let sport = Sport(rawValue: type) { return sport.discipline }
        if type == "strength" { return .strength }
        return .run
    }
}
