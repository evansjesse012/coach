import SwiftUI

struct LogTab: View {
    @Environment(DataService.self) var data
    @State private var showCardio = true
    @State private var sportFilter: Sport?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
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

                    // Toggle: Workouts / Strength
                    Picker("View", selection: $showCardio) {
                        Text("Workouts").tag(true)
                        Text("Strength").tag(false)
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal)

                    if showCardio {
                        // Sport filter chips
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                FilterChip(label: "All", isSelected: sportFilter == nil) {
                                    sportFilter = nil
                                }
                                ForEach([Sport.run, .bike, .swim, .hike], id: \.self) { sport in
                                    FilterChip(label: sport.label, isSelected: sportFilter == sport) {
                                        sportFilter = sport
                                    }
                                }
                            }
                            .padding(.horizontal)
                        }

                        // Cardio list
                        let filtered = sportFilter == nil
                            ? data.cardio
                            : data.cardio.filter { $0.sport == sportFilter }

                        ForEach(filtered.sorted(by: { $0.date > $1.date })) { workout in
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
                        }

                        if filtered.isEmpty {
                            ContentUnavailableView(
                                "No Workouts",
                                systemImage: "figure.run",
                                description: Text("Log a workout with your coach or import from Apple Health.")
                            )
                        }
                    } else {
                        // Strength sessions list
                        ForEach(data.strength.sorted(by: { $0.date > $1.date })) { session in
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

                        if data.strength.isEmpty {
                            ContentUnavailableView(
                                "No Strength Sessions",
                                systemImage: "dumbbell.fill",
                                description: Text("Start tracking your strength workouts.")
                            )
                        }
                    }
                }
                .padding(.vertical)
            }
            .navigationTitle("Activities")
        }
    }
}

// MARK: - Filter Chip

private struct FilterChip: View {
    let label: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(label)
                .font(CoachFonts.ui(13, weight: isSelected ? .semibold : .regular))
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(isSelected ? CoachColors.accent.opacity(0.15) : Color(.secondarySystemBackground))
                .foregroundStyle(isSelected ? CoachColors.accent : .primary)
                .clipShape(Capsule())
        }
    }
}
