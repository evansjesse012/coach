import SwiftUI

struct PlanTab: View {
    @Environment(DataService.self) var data

    var body: some View {
        NavigationStack {
            ScrollView {
                if let plan = data.trainingPlan {
                    VStack(alignment: .leading, spacing: 16) {
                        // Race header
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

                        // Weekly cards
                        let weekNums = plan.weeklyPlans.keys.compactMap(Int.init).sorted()
                        ForEach(weekNums, id: \.self) { num in
                            if let wp = plan.weeklyPlans[String(num)] {
                                WeekCard(
                                    plan: plan,
                                    weeklyPlan: wp,
                                    adherence: computeWeekAdherence(
                                        plan: plan,
                                        weekNum: num,
                                        cardio: data.cardio,
                                        strength: data.strength
                                    )
                                )
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

// MARK: - Week Card

private struct WeekCard: View {
    let plan: TrainingPlan
    let weeklyPlan: WeeklyPlan
    let adherence: WeekAdherence?

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

            // Segmented progress bar
            ProgressSegments(total: totalSessions, completed: completedSessions)

            // Summary
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

            // Session list
            VStack(alignment: .leading, spacing: 6) {
                ForEach(Array(weeklyPlan.sessions.enumerated()), id: \.offset) { dayIdx, dayPlan in
                    if dayPlan.isRest != true && !dayPlan.sessions.isEmpty {
                        DayRow(
                            dayPlan: dayPlan,
                            statuses: sessionStatuses(forDayIndex: dayIdx)
                        )
                    }
                }
            }
        }
        .padding(16)
        .background(colorScheme == .dark ? CoachColors.darkCard : CoachColors.lightCard)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(colorScheme == .dark ? CoachColors.darkBorder : CoachColors.lightBorder, lineWidth: 1)
        )
    }

    // MARK: derived

    private var totalSessions: Int {
        weeklyPlan.sessions.flatMap(\.sessions).count
    }

    private var completedSessions: Int {
        guard let adherence else { return 0 }
        return adherence.days
            .flatMap(\.sessions)
            .filter { $0.status == .completed }
            .count
    }

    private var totalDistance: Double {
        weeklyPlan.sessions
            .flatMap(\.sessions)
            .compactMap(\.distanceMiles)
            .reduce(0, +)
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

    private func sessionStatuses(forDayIndex dayIdx: Int) -> [SessionStatus] {
        guard let adherence, dayIdx < adherence.days.count else {
            return Array(repeating: .upcoming, count: weeklyPlan.sessions[dayIdx].sessions.count)
        }
        return adherence.days[dayIdx].sessions.map(\.status)
    }
}

// MARK: - Progress Segments

private struct ProgressSegments: View {
    let total: Int
    let completed: Int

    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        GeometryReader { geo in
            HStack(spacing: 4) {
                ForEach(0..<total, id: \.self) { idx in
                    RoundedRectangle(cornerRadius: 3)
                        .fill(idx < completed ? CoachColors.teal : segmentBg)
                        .frame(height: 6)
                }
            }
            .frame(width: geo.size.width)
        }
        .frame(height: 6)
    }

    private var segmentBg: Color {
        colorScheme == .dark ? CoachColors.darkBorder : CoachColors.lightBorder
    }
}

// MARK: - Day Row (handles same-day stacking)

private struct DayRow: View {
    let dayPlan: DayPlan
    let statuses: [SessionStatus]

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            ForEach(Array(dayPlan.sessions.enumerated()), id: \.offset) { idx, session in
                HStack(spacing: 10) {
                    // Day label only on first session of the day
                    Text(idx == 0 ? dayAbbreviation : "")
                        .font(CoachFonts.ui(12, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .frame(width: 32, alignment: .leading)

                    // Dot or checkmark
                    let status = idx < statuses.count ? statuses[idx] : .upcoming
                    if status == .completed {
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

                    // Name
                    Text(session.label)
                        .font(CoachFonts.ui(13))
                        .lineLimit(1)
                        .strikethrough(status == .completed, color: .secondary)
                        .foregroundStyle(status == .completed ? .secondary : .primary)

                    Spacer()

                    // Distance or duration
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
