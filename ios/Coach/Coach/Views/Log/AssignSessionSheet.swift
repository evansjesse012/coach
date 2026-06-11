import SwiftUI

/// Presented from WorkoutDetailView to let the athlete manually assign a
/// recorded workout to a prescribed session. Lists unresolved prescribed
/// sessions within ±3 days of the workout date, sorted nearest-date first
/// with same-sport sessions floated to the top.
struct AssignSessionSheet: View {
    let workout: CardioWorkout
    let onPick: (_ session: PrescribedSession, _ sessionDate: String) -> Void

    @Environment(DataService.self) private var data
    @Environment(\.dismiss) private var dismiss

    private let windowDays: Int = 3

    var body: some View {
        NavigationStack {
            Group {
                if candidates.isEmpty {
                    emptyState
                } else {
                    List {
                        ForEach(candidates, id: \.0.id) { (session, dateStr, _) in
                            Button {
                                onPick(session, dateStr)
                                dismiss()
                            } label: {
                                row(session: session, dateStr: dateStr)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .listStyle(.insetGrouped)
                }
            }
            .navigationTitle("Assign to plan")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }

    /// (session, computed date string, day offset vs workout date)
    private var candidates: [(PrescribedSession, String, Int)] {
        guard let plan = data.trainingPlan,
              plan.startDate != nil,
              let workoutDate = parseDate(workout.date) else { return [] }

        let workoutSport = workout.sport.rawValue
        var out: [(PrescribedSession, String, Int)] = []

        for (weekKey, wp) in plan.weeklyPlans {
            guard let weekNum = Int(weekKey) else { continue }
            for (dayIdx, dayPlan) in wp.sessions.enumerated() {
                // Resolve the day's date through the canonical anchor-snapped
                // helper — the raw planStart + offset math here drifted by up
                // to 6 days whenever startDate wasn't on the week anchor.
                guard let isoDateStr = sessionDateString(
                    planStartDate: plan.startDate,
                    weekNumber: weekNum,
                    dayIdx: dayIdx,
                    anchor: plan.weekAnchor
                ), let sessionDate = parseDate(isoDateStr) else { continue }
                let offset = Calendar.current.dateComponents([.day], from: workoutDate, to: sessionDate).day ?? 99
                guard abs(offset) <= windowDays else { continue }
                let dateStr = formatDate(sessionDate)
                for s in dayPlan.sessions {
                    // Skip sessions already linked to some workout (including this one — we're reassigning from the other side).
                    if s.linkedWorkoutId != nil, s.linkedWorkoutId != workout.id { continue }
                    // Skip strength sessions — the manual-link flow is for cardio only.
                    if s.type.lowercased() == "strength" { continue }
                    out.append((s, dateStr, offset))
                }
            }
        }

        return out.sorted { a, b in
            let sameA = a.0.type.lowercased() == workoutSport
            let sameB = b.0.type.lowercased() == workoutSport
            if sameA != sameB { return sameA }
            if abs(a.2) != abs(b.2) { return abs(a.2) < abs(b.2) }
            return a.2 < b.2
        }
    }

    @ViewBuilder
    private func row(session: PrescribedSession, dateStr: String) -> some View {
        let sport = Sport(rawValue: session.type.lowercased())
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill((sport?.swiftUIColor ?? CoachColors.accent).opacity(0.18))
                    .frame(width: 36, height: 36)
                Image(systemName: sport?.sfSymbol ?? "figure.run")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(sport?.swiftUIColor ?? CoachColors.accent)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(session.label)
                    .font(CoachFonts.ui(14, weight: .semibold))
                    .lineLimit(2)
                HStack(spacing: 8) {
                    Text(formatDayLong(dateStr))
                        .font(CoachFonts.ui(11))
                        .foregroundStyle(.secondary)
                    if let dur = session.duration, dur > 0 {
                        Text("·").foregroundStyle(.secondary)
                        Text(formatDuration(dur))
                            .font(CoachFonts.mono(11, weight: .semibold))
                            .foregroundStyle(.secondary)
                    }
                    if let zone = session.zone, !zone.isEmpty {
                        Text("·").foregroundStyle(.secondary)
                        Text(zone)
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
            Image(systemName: "calendar.badge.exclamationmark")
                .font(.system(size: 36))
                .foregroundStyle(.secondary)
            Text("No prescribed sessions near this date")
                .font(CoachFonts.ui(14, weight: .semibold))
            Text("Showing unresolved cardio sessions within ±\(windowDays) days of \(formatDayLong(workout.date)).")
                .font(CoachFonts.ui(12))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func parseDate(_ s: String) -> Date? {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f.date(from: s)
    }

    private func formatDate(_ d: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f.string(from: d)
    }
}
