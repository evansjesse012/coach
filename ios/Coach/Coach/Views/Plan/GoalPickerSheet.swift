import SwiftUI

/// Modal shown when the athlete taps "Build a plan with your coach".
/// Lets them pick an existing goal to anchor the plan, or kicks them
/// to GoalFormSheet if they don't have one yet. Visual language matches
/// GoalFormView and the Goals tab — ScrollView + card rows on the app
/// background, not a plain SwiftUI List.
struct GoalPickerSheet: View {
    @Binding var isPresented: Bool
    let onPick: (Event) -> Void

    @Environment(DataService.self) var data
    @Environment(\.colorScheme) var colorScheme
    @State private var showGoalForm = false

    var body: some View {
        NavigationStack {
            Group {
                if activeEvents.isEmpty {
                    emptyState
                } else {
                    picker
                }
            }
            .background((colorScheme == .dark ? CoachColors.darkBg : CoachColors.lightBg).ignoresSafeArea())
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

    // MARK: - Picker

    private var picker: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                Text("PICK A GOAL TO BUILD AROUND")
                    .font(CoachFonts.ui(10, weight: .semibold))
                    .tracking(0.6)
                    .foregroundStyle(.secondary)
                    .padding(.top, 4)

                ForEach(activeEvents) { event in
                    Button {
                        onPick(event)
                        isPresented = false
                    } label: {
                        goalRow(event: event)
                    }
                    .buttonStyle(.plain)
                }

                Button {
                    showGoalForm = true
                } label: {
                    addNewRow
                }
                .buttonStyle(.plain)
                .padding(.top, 4)
            }
            .padding()
        }
    }

    private func goalRow(event: Event) -> some View {
        CoachCard(padding: 14) {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(CoachColors.accent.opacity(0.15))
                        .frame(width: 38, height: 38)
                    Image(systemName: preset(for: event)?.icon ?? "target")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(CoachColors.accent)
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text(event.name)
                        .font(CoachFonts.ui(15, weight: .semibold))
                        .foregroundStyle(.primary)
                        .lineLimit(2)
                    if let date = event.date {
                        Text(formatDateShort(date))
                            .font(CoachFonts.ui(12))
                            .foregroundStyle(.secondary)
                    }
                    if let goal = event.goal, !goal.isEmpty {
                        Text("Goal: \(goal)")
                            .font(CoachFonts.ui(12))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }

                Spacer(minLength: 8)

                if let date = event.date, let days = daysUntil(date), days >= 0 {
                    VStack(alignment: .trailing, spacing: 0) {
                        Text("\(days)")
                            .font(CoachFonts.mono(18, weight: .semibold))
                            .foregroundStyle(CoachColors.accent)
                        Text("days")
                            .font(CoachFonts.ui(10))
                            .foregroundStyle(.secondary)
                    }
                }

                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.tertiary)
            }
        }
    }

    private var addNewRow: some View {
        CoachCard(padding: 14) {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(CoachColors.accent.opacity(0.15))
                        .frame(width: 38, height: 38)
                    Image(systemName: "plus")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(CoachColors.accent)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text("Add a new goal")
                        .font(CoachFonts.ui(15, weight: .semibold))
                        .foregroundStyle(.primary)
                    Text("Create a race or training goal, then build a plan around it.")
                        .font(CoachFonts.ui(12))
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 8)

                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.tertiary)
            }
        }
    }

    private var emptyState: some View {
        ContentUnavailableView {
            Label("No goals yet", systemImage: "target")
        } description: {
            Text("Add a race or training goal first — then we can build a plan around it.")
        } actions: {
            Button {
                showGoalForm = true
            } label: {
                Label("Add a goal", systemImage: "plus.circle.fill")
                    .font(CoachFonts.ui(14, weight: .semibold))
                    .padding(.horizontal, 18)
                    .padding(.vertical, 10)
                    .background(CoachColors.accent)
                    .foregroundStyle(.white)
                    .clipShape(Capsule())
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Helpers

    private var activeEvents: [Event] {
        data.events.filter { !$0.completed }.sorted { ($0.date ?? "") < ($1.date ?? "") }
    }

    private func preset(for event: Event) -> EventPreset? {
        EventPreset.all.first { $0.id == event.presetId }
    }
}
