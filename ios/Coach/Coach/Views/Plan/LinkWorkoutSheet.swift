import SwiftUI

/// Presented from PrescribedSessionDetailView to let the athlete manually
/// pick a recorded CardioWorkout to fulfill the session. Lists workouts
/// within ±3 days of the session date, sorted nearest-date first, with the
/// same-sport matches floated to the top.
struct LinkWorkoutSheet: View {
    let session: PrescribedSession
    let sessionDate: String?
    let onPick: (CardioWorkout) -> Void

    @Environment(DataService.self) private var data
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme

    private let windowDays: Int = 3

    var body: some View {
        NavigationStack {
            Group {
                if candidates.isEmpty {
                    emptyState
                } else {
                    List {
                        ForEach(candidates) { workout in
                            Button {
                                onPick(workout)
                                dismiss()
                            } label: {
                                row(for: workout)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .listStyle(.insetGrouped)
                }
            }
            .navigationTitle("Link workout")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }

    private var candidates: [CardioWorkout] {
        guard let sessionDate, let target = parseDate(sessionDate) else { return [] }
        let sessionSport = session.type.lowercased()
        let alreadyLinkedIds = Set(
            data.trainingPlan?.weeklyPlans.values.flatMap { wp in
                wp.sessions.flatMap { day in
                    day.sessions.compactMap { $0.linkedWorkoutId }
                }
            } ?? []
        )
        return data.cardio
            .filter { !alreadyLinkedIds.contains($0.id) || $0.id == session.linkedWorkoutId }
            .compactMap { w -> (CardioWorkout, Int)? in
                guard let d = parseDate(w.date) else { return nil }
                let days = Calendar.current.dateComponents([.day], from: target, to: d).day ?? 99
                guard abs(days) <= windowDays else { return nil }
                return (w, days)
            }
            .sorted { (a, b) in
                let sameA = a.0.sport.rawValue == sessionSport
                let sameB = b.0.sport.rawValue == sessionSport
                if sameA != sameB { return sameA }
                if abs(a.1) != abs(b.1) { return abs(a.1) < abs(b.1) }
                return a.1 < b.1
            }
            .map { $0.0 }
    }

    @ViewBuilder
    private func row(for workout: CardioWorkout) -> some View {
        let isLinked = workout.id == session.linkedWorkoutId
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(workout.sport.swiftUIColor.opacity(0.18))
                    .frame(width: 36, height: 36)
                Image(systemName: workout.sport.sfSymbol)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(workout.sport.swiftUIColor)
            }
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(workout.sport.label)
                        .font(CoachFonts.ui(14, weight: .semibold))
                    if isLinked {
                        CoachPill(text: "LINKED", color: CoachColors.green)
                    }
                }
                HStack(spacing: 8) {
                    Text(formatDayLong(workout.date))
                        .font(CoachFonts.ui(11))
                        .foregroundStyle(.secondary)
                    Text("·").foregroundStyle(.secondary)
                    Text(formatDuration(workout.duration))
                        .font(CoachFonts.mono(11, weight: .semibold))
                        .foregroundStyle(.secondary)
                    if let dist = workout.distance, !dist.isEmpty {
                        Text("·").foregroundStyle(.secondary)
                        Text(dist)
                            .font(CoachFonts.mono(11, weight: .semibold))
                            .foregroundStyle(.secondary)
                    }
                    if let hr = workout.avgHR {
                        Text("·").foregroundStyle(.secondary)
                        Text("\(hr) bpm")
                            .font(CoachFonts.mono(11, weight: .semibold))
                            .foregroundStyle(.secondary)
                    }
                }
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 4)
    }

    private var emptyState: some View {
        VStack(spacing: 10) {
            Image(systemName: "applewatch.slash")
                .font(.system(size: 36))
                .foregroundStyle(.secondary)
            Text("No recorded workouts near this date")
                .font(CoachFonts.ui(14, weight: .semibold))
            Text("Showing Apple Watch workouts within ±\(windowDays) days of \(formattedSessionDate).")
                .font(CoachFonts.ui(12))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var formattedSessionDate: String {
        guard let sessionDate else { return "this session" }
        return formatDayLong(sessionDate)
    }

    private func parseDate(_ s: String) -> Date? {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f.date(from: s)
    }
}
