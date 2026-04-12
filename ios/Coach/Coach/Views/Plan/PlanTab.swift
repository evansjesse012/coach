import SwiftUI

struct PlanTab: View {
    @Environment(DataService.self) var data

    var body: some View {
        NavigationStack {
            ScrollView {
                if let plan = data.trainingPlan {
                    VStack(alignment: .leading, spacing: 24) {
                        // Goal header
                        GoalHeader(plan: plan)

                        // Period sections with nested week cards
                        ForEach(plan.phases) { phase in
                            PeriodSection(plan: plan, phase: phase)
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

// MARK: - Goal Header

private struct GoalHeader: View {
    let plan: TrainingPlan

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("YOUR GOAL")
                .font(CoachFonts.ui(11, weight: .semibold))
                .foregroundStyle(.secondary)
                .tracking(0.8)
            Text(plan.raceName ?? "Training Plan")
                .font(CoachFonts.display(24, weight: .bold))
                .lineLimit(2)
                .minimumScaleFactor(0.7)
            if let raceDate = plan.raceDate {
                Text(formatDateLong(raceDate))
                    .font(CoachFonts.ui(15, weight: .medium))
                    .foregroundStyle(CoachColors.accent)
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            LinearGradient(
                colors: [CoachColors.accent.opacity(0.15), CoachColors.accent.opacity(0.04)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(CoachColors.accent.opacity(0.3), lineWidth: 1)
        )
    }
}

// MARK: - Period Section

private struct PeriodSection: View {
    let plan: TrainingPlan
    let phase: TrainingPhase

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Phase header
            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .firstTextBaseline) {
                    Text(phase.name.uppercased())
                        .font(CoachFonts.ui(11, weight: .semibold))
                        .tracking(0.8)
                        .foregroundStyle(CoachColors.accent)
                    Spacer()
                    if let dateRange = phaseDateRange {
                        Text(dateRange)
                            .font(CoachFonts.ui(11))
                            .foregroundStyle(.secondary)
                    }
                }
                if let philosophy = phase.philosophy {
                    Text(philosophy)
                        .font(CoachFonts.ui(13))
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            // Nested week cards
            ForEach(weeksForThisPhase, id: \.weekNumber) { wp in
                NavigationLink {
                    WeekDetailView(initialWeekNum: wp.weekNumber)
                } label: {
                    WeekCard(plan: plan, weeklyPlan: wp)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var weeksForThisPhase: [WeeklyPlan] {
        plan.weeklyPlans.values
            .filter { $0.phase == phase.number }
            .sorted { $0.weekNumber < $1.weekNumber }
    }

    private var phaseDateRange: String? {
        guard let start = phase.startDate, let end = phase.endDate else { return nil }
        return "\(formatDateShort(start)) – \(formatDateShort(end))"
    }
}

// MARK: - Week Card

private struct WeekCard: View {
    let plan: TrainingPlan
    let weeklyPlan: WeeklyPlan

    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Date range + week number
            VStack(alignment: .leading, spacing: 2) {
                Text(dateRangeString)
                    .font(CoachFonts.ui(11, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .tracking(0.5)
                Text("Week \(weeklyPlan.weekNumber)")
                    .font(CoachFonts.display(20, weight: .bold))
            }

            ProgressSegments(total: totalSessions, completed: completedSessions)

            HStack(spacing: 16) {
                Label("Total Workouts: \(totalSessions)", systemImage: "checklist")
                    .font(CoachFonts.ui(12))
                    .foregroundStyle(.secondary)
                if totalDistance > 0 {
                    Label(String(format: "Distance: %.2fmi", totalDistance), systemImage: "ruler")
                        .font(CoachFonts.ui(12))
                        .foregroundStyle(.secondary)
                }
            }

            Divider()

            VStack(alignment: .leading, spacing: 6) {
                ForEach(Array(weeklyPlan.sessions.enumerated()), id: \.offset) { _, dayPlan in
                    if dayPlan.isRest != true && !dayPlan.sessions.isEmpty {
                        DayRow(dayPlan: dayPlan)
                    }
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(colorScheme == .dark ? CoachColors.darkCard : CoachColors.lightCard)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(colorScheme == .dark ? CoachColors.darkBorder : CoachColors.lightBorder, lineWidth: 1)
        )
    }

    // MARK: derived

    private var allSessions: [PrescribedSession] { weeklyPlan.sessions.flatMap(\.sessions) }

    private var totalSessions: Int { allSessions.count }

    private var completedSessions: Int { allSessions.filter { $0.completed == true }.count }

    private var totalDistance: Double {
        allSessions.compactMap(\.distanceMiles).reduce(0, +)
    }

    private var dateRangeString: String {
        guard let startDateStr = plan.startDate else { return "" }
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        guard let planStart = formatter.date(from: startDateStr) else { return "" }
        let cal = Calendar.current
        guard let weekStart = cal.date(byAdding: .day, value: (weeklyPlan.weekNumber - 1) * 7, to: planStart),
              let weekEnd = cal.date(byAdding: .day, value: 6, to: weekStart) else { return "" }
        let display = DateFormatter()
        display.dateFormat = "MMM d"
        return "\(display.string(from: weekStart).uppercased()) - \(display.string(from: weekEnd).uppercased())"
    }
}

// MARK: - Progress Segments

private struct ProgressSegments: View {
    let total: Int
    let completed: Int

    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        HStack(spacing: 4) {
            ForEach(0..<max(total, 1), id: \.self) { idx in
                RoundedRectangle(cornerRadius: 3)
                    .fill(idx < completed ? CoachColors.teal : segmentBg)
                    .frame(height: 6)
            }
        }
    }

    private var segmentBg: Color {
        colorScheme == .dark ? CoachColors.darkBorder : CoachColors.lightBorder
    }
}

// MARK: - Day Row

private struct DayRow: View {
    let dayPlan: DayPlan

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            ForEach(Array(dayPlan.sessions.enumerated()), id: \.offset) { idx, session in
                HStack(spacing: 10) {
                    Text(idx == 0 ? dayAbbreviation : "")
                        .font(CoachFonts.ui(12, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .frame(width: 32, alignment: .leading)

                    if session.completed == true {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 14))
                            .foregroundStyle(CoachColors.teal)
                            .frame(width: 14, height: 14)
                    } else {
                        Circle()
                            .fill(session.effortCategory?.color ?? Color.gray.opacity(0.5))
                            .frame(width: 10, height: 10)
                            .frame(width: 14, height: 14)
                    }

                    Text(session.label)
                        .font(CoachFonts.ui(13))
                        .lineLimit(1)
                        .strikethrough(session.completed == true, color: .secondary)
                        .foregroundStyle(session.completed == true ? .secondary : .primary)

                    Spacer()

                    Text(metricString(session))
                        .font(CoachFonts.mono(12))
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private var dayAbbreviation: String {
        let map: [String: String] = [
            "monday": "Mon", "tuesday": "Tue", "wednesday": "Wed",
            "thursday": "Thu", "friday": "Fri", "saturday": "Sat", "sunday": "Sun",
        ]
        return map[dayPlan.day.lowercased()] ?? String(dayPlan.day.prefix(3)).capitalized
    }

    private func metricString(_ session: PrescribedSession) -> String {
        if let mi = session.distanceMiles {
            return String(format: "%.1fmi", mi)
        }
        if let dur = session.duration {
            return formatDuration(dur)
        }
        return ""
    }
}
