import SwiftUI

/// Modal shown when the athlete taps "Build a plan with your coach".
/// Lets them pick an existing goal to anchor the plan, or kicks them
/// to GoalFormSheet if they don't have one yet.
struct GoalPickerSheet: View {
    @Binding var isPresented: Bool
    let onPick: (Event) -> Void

    @Environment(DataService.self) var data
    @State private var showGoalForm = false

    var body: some View {
        NavigationStack {
            Group {
                if activeEvents.isEmpty {
                    ContentUnavailableView {
                        Label("No goals yet", systemImage: "target")
                    } description: {
                        Text("Add a race or training goal first — then we can build a plan around it.")
                    } actions: {
                        Button("Add a goal") {
                            showGoalForm = true
                        }
                        .buttonStyle(.borderedProminent)
                    }
                } else {
                    List {
                        Section {
                            ForEach(activeEvents) { event in
                                Button {
                                    onPick(event)
                                    isPresented = false
                                } label: {
                                    HStack {
                                        if let preset = EventPreset.all.first(where: { $0.id == event.presetId }) {
                                            Image(systemName: preset.icon)
                                                .font(.system(size: 16))
                                                .foregroundStyle(CoachColors.accent)
                                                .frame(width: 24)
                                        }
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(event.name)
                                                .font(CoachFonts.ui(15, weight: .semibold))
                                                .foregroundStyle(.primary)
                                            if let date = event.date {
                                                Text(formatDateShort(date))
                                                    .font(CoachFonts.ui(12))
                                                    .foregroundStyle(.secondary)
                                            }
                                        }
                                        Spacer()
                                        if let date = event.date, let days = daysUntil(date), days >= 0 {
                                            Text("\(days)d")
                                                .font(CoachFonts.mono(13, weight: .semibold))
                                                .foregroundStyle(CoachColors.accent)
                                        }
                                    }
                                }
                                .buttonStyle(.plain)
                            }
                        } header: {
                            Text("Pick a goal to build the plan around")
                        }

                        Section {
                            Button {
                                showGoalForm = true
                            } label: {
                                Label("Add new goal", systemImage: "plus.circle")
                            }
                        }
                    }
                }
            }
            .navigationTitle("Build a Plan")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { isPresented = false }
                }
            }
            .sheet(isPresented: $showGoalForm) {
                CreateGoalSheet(isPresented: $showGoalForm)
            }
        }
    }

    private var activeEvents: [Event] {
        data.events.filter { !$0.completed }.sorted { ($0.date ?? "") < ($1.date ?? "") }
    }
}
