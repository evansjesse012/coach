import SwiftUI

struct GoalsTab: View {
    @Environment(DataService.self) var data
    @State private var showPicker = false
    @State private var showFormSheet = false
    @State private var showChatSheet = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    // Active goals
                    let active = data.events.filter { !$0.completed }
                    if !active.isEmpty {
                        CoachLabel(text: "Active Goals")
                        ForEach(active) { event in
                            NavigationLink {
                                RaceDetailView(eventId: event.id)
                            } label: {
                                GoalCard(event: event)
                            }
                            .buttonStyle(.plain)
                        }
                    }

                    // Completed goals
                    let completed = data.events.filter(\.completed)
                    if !completed.isEmpty {
                        CoachLabel(text: "Completed")
                        ForEach(completed) { event in
                            NavigationLink {
                                RaceDetailView(eventId: event.id)
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
                            description: Text("Add a race or training goal to get started.")
                        )
                    }
                }
                .padding()
            }
            .navigationTitle("Goals")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showPicker = true
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
                CreateGoalSheet(isPresented: $showFormSheet)
            }
            .sheet(isPresented: $showChatSheet) {
                RaceCreationChatSheet()
            }
        }
    }
}

// MARK: - Goal Card

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
                if let date = event.date, !event.completed, let days = daysUntil(date), days >= 0 {
                    Text("\(days)d")
                        .font(CoachFonts.mono(16, weight: .medium))
                        .foregroundStyle(CoachColors.accent)
                }
            }
        }
    }
}

