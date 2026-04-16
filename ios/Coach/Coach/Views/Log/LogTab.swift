import SwiftUI

// MARK: - Unified Activity Item

private enum ActivityItem: Identifiable {
    case cardio(CardioWorkout)
    case strength(StrengthSession)

    var id: String {
        switch self {
        case .cardio(let w): return "c-\(w.id)"
        case .strength(let s): return "s-\(s.id)"
        }
    }

    var date: String {
        switch self {
        case .cardio(let w): return w.date
        case .strength(let s): return s.date
        }
    }

    var sport: Sport {
        switch self {
        case .cardio(let w): return w.sport
        case .strength: return .strength
        }
    }
}

// MARK: - Date Range Filter

private enum DateRange: String, CaseIterable, Identifiable {
    case allTime = "All Time"
    case last7Days = "7 Days"
    case last30Days = "30 Days"
    case last90Days = "90 Days"
    case thisYear = "This Year"

    var id: String { rawValue }

    var cutoffDate: Date? {
        let cal = Calendar.current
        switch self {
        case .allTime: return nil
        case .last7Days: return cal.date(byAdding: .day, value: -7, to: Date())
        case .last30Days: return cal.date(byAdding: .day, value: -30, to: Date())
        case .last90Days: return cal.date(byAdding: .day, value: -90, to: Date())
        case .thisYear: return cal.date(from: cal.dateComponents([.year], from: Date()))
        }
    }
}

// MARK: - Log Tab

struct LogTab: View {
    @Environment(DataService.self) var data
    @State private var typeFilter: Sport?
    @State private var dateRange: DateRange = .allTime
    @State private var showWorkoutLogger = false

    private var activities: [ActivityItem] {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"

        var items: [ActivityItem] = data.cardio.map { .cardio($0) }
            + data.strength.map { .strength($0) }

        if let typeFilter {
            items = items.filter { $0.sport == typeFilter }
        }

        if let cutoff = dateRange.cutoffDate {
            items = items.filter { item in
                guard let date = formatter.date(from: item.date) else { return true }
                return date >= cutoff
            }
        }

        return items.sorted { $0.date > $1.date }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    // In-progress workout banner or start workout button
                    if data.activeStrengthSession != nil {
                        ActiveWorkoutResumeCard {
                            showWorkoutLogger = true
                        }
                        .padding(.horizontal)
                    } else {
                        StartWorkoutButton {
                            data.startStrengthWorkout(StrengthSession.quickStart())
                            showWorkoutLogger = true
                        }
                        .padding(.horizontal)
                    }

                    NavigationLink {
                        ExerciseLibraryView()
                    } label: {
                        CoachCard {
                            HStack(spacing: 12) {
                                Image(systemName: "dumbbell.fill")
                                    .font(.system(size: 18, weight: .semibold))
                                    .foregroundStyle(CoachColors.accent)
                                    .frame(width: 28)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Exercise Library")
                                        .font(CoachFonts.ui(14, weight: .semibold))
                                    Text("Browse lifts, PRs, and full history")
                                        .font(CoachFonts.ui(11))
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundStyle(.tertiary)
                            }
                        }
                        .padding(.horizontal)
                    }
                    .buttonStyle(.plain)

                    // Filter dropdowns
                    HStack(spacing: 10) {
                        Menu {
                            Button {
                                typeFilter = nil
                            } label: {
                                if typeFilter == nil {
                                    Label("All Types", systemImage: "checkmark")
                                } else {
                                    Text("All Types")
                                }
                            }
                            ForEach(Sport.allCases) { sport in
                                Button {
                                    typeFilter = sport
                                } label: {
                                    if typeFilter == sport {
                                        Label(sport.label, systemImage: "checkmark")
                                    } else {
                                        Text(sport.label)
                                    }
                                }
                            }
                        } label: {
                            FilterDropdown(
                                label: typeFilter?.label ?? "All Types",
                                icon: typeFilter?.sfSymbol ?? "line.3.horizontal.decrease",
                                isActive: typeFilter != nil
                            )
                        }

                        Menu {
                            ForEach(DateRange.allCases) { range in
                                Button {
                                    dateRange = range
                                } label: {
                                    if dateRange == range {
                                        Label(range.rawValue, systemImage: "checkmark")
                                    } else {
                                        Text(range.rawValue)
                                    }
                                }
                            }
                        } label: {
                            FilterDropdown(
                                label: dateRange.rawValue,
                                icon: "calendar",
                                isActive: dateRange != .allTime
                            )
                        }

                        Spacer()
                    }
                    .padding(.horizontal)

                    // Unified activity list
                    ForEach(activities) { item in
                        switch item {
                        case .cardio(let workout):
                            NavigationLink {
                                WorkoutDetailView(workout: workout)
                            } label: {
                                CoachCard {
                                    HStack {
                                        SportBadge(sport: workout.sport)
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(formatDateRelative(workout.date))
                                                .font(CoachFonts.ui(13, weight: .medium))
                                            if let notes = workout.notes, !notes.isEmpty {
                                                Text(notes)
                                                    .font(CoachFonts.ui(12))
                                                    .foregroundStyle(.secondary)
                                                    .lineLimit(1)
                                            }
                                        }
                                        Spacer()
                                        Text(formatDuration(workout.duration))
                                            .font(CoachFonts.mono(14))
                                        Image(systemName: "chevron.right")
                                            .font(.system(size: 12, weight: .semibold))
                                            .foregroundStyle(.tertiary)
                                    }
                                }
                                .padding(.horizontal)
                            }
                            .buttonStyle(.plain)

                        case .strength(let session):
                            NavigationLink {
                                StrengthDetailView(session: session)
                            } label: {
                                CoachCard {
                                    HStack {
                                        SportBadge(sport: .strength)
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(session.name)
                                                .font(CoachFonts.ui(13, weight: .medium))
                                            let sets = session.exercises.reduce(0) { $0 + $1.sets.filter(\.completed).count }
                                            Text("\(session.exercises.count) exercises, \(sets) sets")
                                                .font(CoachFonts.ui(12))
                                                .foregroundStyle(.secondary)
                                        }
                                        Spacer()
                                        Text(formatDateRelative(session.date))
                                            .font(CoachFonts.ui(12))
                                            .foregroundStyle(.secondary)
                                        Image(systemName: "chevron.right")
                                            .font(.system(size: 12, weight: .semibold))
                                            .foregroundStyle(.tertiary)
                                    }
                                }
                                .padding(.horizontal)
                            }
                            .buttonStyle(.plain)
                        }
                    }

                    if activities.isEmpty {
                        ContentUnavailableView(
                            "No Activities",
                            systemImage: "figure.run",
                            description: Text("Log a workout or start a strength session to see it here.")
                        )
                    }
                }
                .padding(.vertical)
            }
            .navigationTitle("Activities")
            .fullScreenCover(isPresented: $showWorkoutLogger) {
                NavigationStack {
                    WorkoutLoggingView()
                }
            }
        }
    }
}

// MARK: - Start Workout Button

private struct StartWorkoutButton: View {
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 10) {
                ZStack {
                    Circle()
                        .fill(Color.white.opacity(0.22))
                        .frame(width: 36, height: 36)
                    Image(systemName: "play.fill")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(.white)
                }
                VStack(alignment: .leading, spacing: 1) {
                    Text("Start Workout")
                        .font(CoachFonts.ui(15, weight: .bold))
                        .foregroundStyle(.white)
                    Text("Quick-log sets with a rest timer")
                        .font(CoachFonts.ui(11))
                        .foregroundStyle(.white.opacity(0.85))
                }
                Spacer()
                Image(systemName: "arrow.right")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(.white)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(
                LinearGradient(
                    colors: [CoachColors.accent, CoachColors.accent.opacity(0.85)],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .shadow(color: CoachColors.accent.opacity(0.25), radius: 8, y: 3)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Resume Banner

private struct ActiveWorkoutResumeCard: View {
    @Environment(DataService.self) private var data
    let onResume: () -> Void

    var body: some View {
        Button(action: onResume) {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(Color.white.opacity(0.22))
                        .frame(width: 38, height: 38)
                    Image(systemName: "figure.strengthtraining.traditional")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(.white)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text("WORKOUT IN PROGRESS")
                        .font(CoachFonts.ui(9, weight: .bold))
                        .tracking(0.8)
                        .foregroundStyle(.white.opacity(0.8))
                    Text(data.activeStrengthSession?.name ?? "Active workout")
                        .font(CoachFonts.ui(15, weight: .bold))
                        .foregroundStyle(.white)
                    if let session = data.activeStrengthSession {
                        Text("\(session.completedSetCount) sets logged · tap to resume")
                            .font(CoachFonts.ui(11))
                            .foregroundStyle(.white.opacity(0.85))
                    }
                }
                Spacer()
                ElapsedTimeView(startedAt: data.activeWorkoutStartedAt)
                    .foregroundStyle(.white)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(
                LinearGradient(
                    colors: [CoachColors.green, CoachColors.green.opacity(0.85)],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .shadow(color: CoachColors.green.opacity(0.25), radius: 8, y: 3)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Filter Dropdown Label

private struct FilterDropdown: View {
    let label: String
    let icon: String
    let isActive: Bool

    var body: some View {
        HStack(spacing: 5) {
            Image(systemName: icon)
                .font(.system(size: 11, weight: .semibold))
            Text(label)
                .font(CoachFonts.ui(13, weight: .medium))
            Image(systemName: "chevron.down")
                .font(.system(size: 9, weight: .bold))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(isActive ? CoachColors.accent.opacity(0.15) : Color(.secondarySystemBackground))
        .foregroundStyle(isActive ? CoachColors.accent : .primary)
        .clipShape(Capsule())
    }
}
