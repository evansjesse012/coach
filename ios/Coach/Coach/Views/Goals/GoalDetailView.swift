import SwiftUI

/// Detail view for goal-mode events (not races). Shows target, stretch goal,
/// baseline, linked race, and a CTA to create a plan. No race overview
/// or weather — those belong on RaceDetailView.
struct GoalDetailView: View {
    let eventId: String

    @Environment(DataService.self) var data
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.dismiss) var dismiss

    @State private var showEditSheet = false

    private var event: Event? {
        data.events.first { $0.id == eventId }
    }

    private var linkedRace: Event? {
        guard let raceId = event?.linkedRaceId else { return nil }
        return data.events.first { $0.id == raceId }
    }

    private var hasPlan: Bool {
        data.trainingPlan?.goalId == eventId
    }

    var body: some View {
        ScrollView {
            if let event {
                VStack(alignment: .leading, spacing: 16) {
                    header(event: event)
                    targetCard(event: event)
                    linkedRaceCard
                    planCard
                    notesCard(event: event)
                }
                .padding()
            } else {
                ContentUnavailableView(
                    "Goal not found",
                    systemImage: "exclamationmark.triangle",
                    description: Text("This goal may have been deleted.")
                )
            }
        }
        .clearsTabBar()
        .background((colorScheme == .dark ? CoachColors.darkBg : CoachColors.lightBg).ignoresSafeArea())
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if event != nil {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showEditSheet = true
                    } label: {
                        Image(systemName: "pencil")
                    }
                }
            }
        }
        .sheet(isPresented: $showEditSheet) {
            EditGoalSheet(eventId: eventId, isPresented: $showEditSheet) { result in
                if case .deleted = result {
                    dismiss()
                }
            }
        }
    }

    // MARK: - Header

    private func header(event: Event) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                if let preset = EventPreset.all.first(where: { $0.id == event.presetId }) {
                    Image(systemName: preset.icon)
                        .font(.system(size: 18))
                        .foregroundStyle(CoachColors.accent)
                }
                CoachPill(text: "GOAL", color: CoachColors.green)
                if event.completed {
                    CoachPill(text: "ACHIEVED", color: CoachColors.green)
                }
                Spacer()
                if let date = event.date, !event.completed, let text = countdownText(date, compact: true) {
                    Text(text)
                        .font(CoachFonts.mono(18, weight: .bold))
                        .foregroundStyle(CoachColors.accent)
                }
            }

            Text(event.name)
                .font(CoachFonts.display(22, weight: .bold))
                .lineLimit(2)

            if let date = event.date {
                Label("Target: \(formatDateLong(date))", systemImage: "calendar")
                    .font(CoachFonts.ui(13))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            LinearGradient(
                colors: [CoachColors.green.opacity(0.12), CoachColors.green.opacity(0.02)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(CoachColors.green.opacity(0.3), lineWidth: 1)
        )
    }

    // MARK: - Target card

    private func targetCard(event: Event) -> some View {
        CoachCard {
            VStack(alignment: .leading, spacing: 12) {
                CoachLabel(text: "Target")

                if let goal = event.goal, !goal.isEmpty {
                    HStack(spacing: 16) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("GOAL")
                                .font(CoachFonts.mono(10, weight: .semibold))
                                .foregroundStyle(.secondary)
                            Text(goal)
                                .font(CoachFonts.display(20, weight: .bold))
                        }
                        if let stretch = event.stretchGoal, !stretch.isEmpty {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("STRETCH")
                                    .font(CoachFonts.mono(10, weight: .semibold))
                                    .foregroundStyle(.secondary)
                                Text(stretch)
                                    .font(CoachFonts.display(20, weight: .bold))
                                    .foregroundStyle(CoachColors.accent)
                            }
                        }
                    }
                }

                if let baseline = event.baseline, !baseline.isEmpty {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("CURRENT BASELINE")
                            .font(CoachFonts.mono(10, weight: .semibold))
                            .foregroundStyle(.secondary)
                        Text(baseline)
                            .font(CoachFonts.ui(14))
                    }
                }

                if let result = event.result, !result.isEmpty {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("RESULT")
                            .font(CoachFonts.mono(10, weight: .semibold))
                            .foregroundStyle(CoachColors.green)
                        Text(result)
                            .font(CoachFonts.display(18, weight: .bold))
                            .foregroundStyle(CoachColors.green)
                    }
                }
            }
        }
    }

    // MARK: - Linked race

    @ViewBuilder
    private var linkedRaceCard: some View {
        CoachCard {
            if let race = linkedRace {
                VStack(alignment: .leading, spacing: 8) {
                    CoachLabel(text: "Linked Race")
                    NavigationLink {
                        RaceDetailView(eventId: race.id)
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(race.name)
                                    .font(CoachFonts.ui(14, weight: .semibold))
                                    .foregroundStyle(.primary)
                                if let date = race.date {
                                    Text(formatDateShort(date))
                                        .font(CoachFonts.ui(12))
                                        .foregroundStyle(.secondary)
                                }
                            }
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(.tertiary)
                        }
                    }
                    .buttonStyle(.plain)
                }
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    CoachLabel(text: "Race")
                    Text("No race linked to this goal yet.")
                        .font(CoachFonts.ui(13))
                        .foregroundStyle(.secondary)
                    Button {
                        // TODO: link race picker
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "link")
                                .font(.system(size: 12, weight: .semibold))
                            Text("Link to a race")
                                .font(CoachFonts.ui(13, weight: .semibold))
                        }
                        .foregroundStyle(CoachColors.accent)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    // MARK: - Plan card

    @ViewBuilder
    private var planCard: some View {
        CoachCard {
            VStack(alignment: .leading, spacing: 8) {
                CoachLabel(text: "Training Plan")
                if hasPlan, let plan = data.trainingPlan {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Week \(plan.currentWeek) of \(plan.totalWeeks)")
                                .font(CoachFonts.ui(14, weight: .semibold))
                            if let phase = plan.phases.first(where: { $0.number == plan.currentPhase }) {
                                Text(phase.name)
                                    .font(CoachFonts.ui(12))
                                    .foregroundStyle(.secondary)
                            }
                        }
                        Spacer()
                        Button {
                            data.selectedTab = "plan"
                        } label: {
                            Text("View Plan")
                                .font(CoachFonts.ui(13, weight: .semibold))
                                .foregroundStyle(CoachColors.accent)
                        }
                        .buttonStyle(.plain)
                    }
                } else {
                    Text("No plan created for this goal yet.")
                        .font(CoachFonts.ui(13))
                        .foregroundStyle(.secondary)
                    Button {
                        data.pendingChatPrompt = "Create a training plan for my goal: \(event?.name ?? "this goal")"
                        data.selectedTab = "coach"
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "sparkles")
                                .font(.system(size: 12, weight: .semibold))
                            Text("Create plan with coach")
                                .font(CoachFonts.ui(13, weight: .semibold))
                        }
                        .foregroundStyle(CoachColors.accent)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    // MARK: - Notes

    private func notesCard(event: Event) -> some View {
        CoachCard {
            VStack(alignment: .leading, spacing: 8) {
                CoachLabel(text: "Notes")
                if event.notes.isEmpty {
                    Text("No notes yet.")
                        .font(CoachFonts.ui(13))
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(event.notes, id: \.self) { note in
                        Text(note)
                            .font(CoachFonts.ui(13))
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
        }
    }
}
