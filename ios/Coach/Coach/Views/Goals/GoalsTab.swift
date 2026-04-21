import SwiftUI

struct GoalsTab: View {
    @Environment(DataService.self) var data
    @State private var showPicker = false
    @State private var showFormSheet = false
    @State private var showChatSheet = false
    @State private var createMode: EventMode = .goal

    private var activeGoals: [Event] { data.events.filter { $0.isGoal && !$0.completed } }
    private var activeRaces: [Event] { data.events.filter { $0.isRace && !$0.completed } }
    private var completedEvents: [Event] { data.events.filter(\.completed) }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Goals section
                    if !activeGoals.isEmpty {
                        CoachLabel(text: "Goals")
                        ForEach(activeGoals) { event in
                            NavigationLink {
                                GoalDetailView(eventId: event.id)
                            } label: {
                                GoalCard(event: event)
                            }
                            .buttonStyle(.plain)
                        }
                    }

                    // Races section
                    if !activeRaces.isEmpty {
                        CoachLabel(text: "Races")
                        ForEach(activeRaces) { event in
                            NavigationLink {
                                RaceDetailView(eventId: event.id)
                            } label: {
                                RaceCard(event: event)
                            }
                            .buttonStyle(.plain)
                        }
                    }

                    // Completed
                    if !completedEvents.isEmpty {
                        CoachLabel(text: "Completed")
                        ForEach(completedEvents) { event in
                            NavigationLink {
                                if event.isRace {
                                    RaceDetailView(eventId: event.id)
                                } else {
                                    GoalDetailView(eventId: event.id)
                                }
                            } label: {
                                GoalCard(event: event)
                            }
                            .buttonStyle(.plain)
                        }
                    }

                    if data.events.isEmpty {
                        ContentUnavailableView(
                            "No Goals Yet",
                            systemImage: "target",
                            description: Text("Add a training goal or race to get started.")
                        )
                    }
                }
                .padding()
            }
            .navigationTitle("Goals")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
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
                        Image(systemName: "plus.circle.fill")
                            .foregroundStyle(CoachColors.accent)
                    }
                }
            }
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
}

// MARK: - Goal Card (for goal-mode events)

private struct GoalCard: View {
    let event: Event

    var body: some View {
        CoachCard {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Text(event.name)
                            .font(CoachFonts.ui(15, weight: .semibold))
                        if event.completed {
                            CoachPill(text: "Done", color: CoachColors.green)
                        }
                        if event.isGoal && !event.hasLinkedRace {
                            CoachPill(text: "No race", color: .secondary)
                        }
                    }
                    if let date = event.date {
                        Text(formatDateShort(date))
                            .font(CoachFonts.ui(13))
                            .foregroundStyle(.secondary)
                    }
                    if let goal = event.goal, !goal.isEmpty {
                        Text("Goal: \(goal)")
                            .font(CoachFonts.ui(13))
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer()
                if let date = event.date, !event.completed, let text = countdownText(date, compact: true) {
                    Text(text)
                        .font(CoachFonts.mono(16, weight: .medium))
                        .foregroundStyle(CoachColors.accent)
                }
            }
        }
    }
}

// MARK: - Race Card (for race-mode events)

private struct RaceCard: View {
    let event: Event

    var body: some View {
        CoachCard(accentColor: CoachColors.accent) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Image(systemName: "flag.checkered")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(CoachColors.accent)
                        Text(event.name)
                            .font(CoachFonts.ui(15, weight: .semibold))
                    }
                    HStack(spacing: 8) {
                        if let date = event.date {
                            Text(formatDateShort(date))
                                .font(CoachFonts.ui(13))
                                .foregroundStyle(.secondary)
                        }
                        if let location = event.location, !location.isEmpty {
                            Text(location)
                                .font(CoachFonts.ui(13))
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                    }
                    if let goal = event.goal, !goal.isEmpty {
                        Text("Goal: \(goal)")
                            .font(CoachFonts.ui(13))
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer()
                if let date = event.date, !event.completed, let text = countdownText(date, compact: true) {
                    VStack(spacing: 0) {
                        Text(text)
                            .font(CoachFonts.mono(18, weight: .bold))
                            .foregroundStyle(CoachColors.accent)
                    }
                }
            }
        }
    }
}
