import SwiftUI

struct PlanTab: View {
    @Environment(DataService.self) var data

    var body: some View {
        NavigationStack {
            ScrollView {
                if let plan = data.trainingPlan {
                    VStack(alignment: .leading, spacing: 16) {
                        // Plan header
                        CoachCard(accentColor: CoachColors.accent) {
                            VStack(alignment: .leading, spacing: 6) {
                                Text(plan.raceName ?? "Training Plan")
                                    .font(CoachFonts.display(18, weight: .bold))
                                HStack(spacing: 12) {
                                    if let raceDate = plan.raceDate {
                                        Label(formatDateShort(raceDate), systemImage: "calendar")
                                            .font(CoachFonts.ui(13))
                                            .foregroundStyle(.secondary)
                                    }
                                    Text("Week \(plan.currentWeek)/\(plan.totalWeeks)")
                                        .font(CoachFonts.mono(13))
                                        .foregroundStyle(CoachColors.accent)
                                }
                            }
                        }

                        // Phase overview
                        CoachLabel(text: "Phases")
                        ForEach(plan.phases) { phase in
                            PhaseRow(phase: phase, isCurrent: phase.number == plan.currentPhase)
                        }

                        // Current week sessions
                        if let wp = plan.weeklyPlans[String(plan.currentWeek)] {
                            CoachLabel(text: "Week \(wp.weekNumber)")
                            if let focus = wp.focusOfWeek, !focus.isEmpty {
                                Text(focus)
                                    .font(CoachFonts.ui(13))
                                    .foregroundStyle(.secondary)
                            }
                            ForEach(wp.sessions) { dayPlan in
                                DayRow(dayPlan: dayPlan)
                            }
                        }
                    }
                    .padding()
                } else {
                    ContentUnavailableView(
                        "No Training Plan",
                        systemImage: "calendar.badge.plus",
                        description: Text("Ask your coach to create a periodized training plan.")
                    )
                    .padding(.top, 60)
                }
            }
            .navigationTitle("Plan")
        }
    }
}

// MARK: - Phase Row

private struct PhaseRow: View {
    let phase: TrainingPhase
    let isCurrent: Bool

    var body: some View {
        CoachCard(accentColor: isCurrent ? CoachColors.green : nil) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(phase.name)
                        .font(CoachFonts.ui(14, weight: .medium))
                    Text("\(phase.weeks) weeks")
                        .font(CoachFonts.ui(12))
                        .foregroundStyle(.secondary)
                }
                Spacer()
                if isCurrent {
                    CoachPill(text: "Current", color: CoachColors.green)
                }
            }
        }
    }
}

// MARK: - Day Row

private struct DayRow: View {
    let dayPlan: DayPlan

    var body: some View {
        if dayPlan.isRest == true {
            HStack(spacing: 8) {
                Text(dayPlan.day.prefix(3))
                    .font(CoachFonts.ui(12, weight: .medium))
                    .frame(width: 36)
                    .foregroundStyle(.secondary)
                Text("Rest")
                    .font(CoachFonts.ui(13))
                    .foregroundStyle(.tertiary)
            }
        } else {
            VStack(alignment: .leading, spacing: 4) {
                Text(dayPlan.day.prefix(3))
                    .font(CoachFonts.ui(12, weight: .medium))
                    .foregroundStyle(.secondary)
                ForEach(dayPlan.sessions) { session in
                    HStack(spacing: 8) {
                        if let sport = Sport(rawValue: session.type) {
                            Circle()
                                .fill(sport.swiftUIColor)
                                .frame(width: 8, height: 8)
                        }
                        Text(session.label)
                            .font(CoachFonts.ui(13))
                        Spacer()
                        if let dur = session.duration {
                            Text(formatDuration(dur))
                                .font(CoachFonts.mono(12))
                                .foregroundStyle(.secondary)
                        }
                        if session.priority == .red {
                            Image(systemName: "circle.fill")
                                .font(.system(size: 6))
                                .foregroundStyle(CoachColors.red)
                        }
                    }
                }
            }
            .padding(.vertical, 4)
        }
    }
}
