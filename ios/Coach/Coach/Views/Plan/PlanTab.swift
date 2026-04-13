import SwiftUI

struct PlanTab: View {
    @Environment(DataService.self) var data
    @State private var showGoalPicker = false

    var body: some View {
        NavigationStack {
            ScrollView {
                if let plan = data.trainingPlan {
                    VStack(alignment: .leading, spacing: 20) {
                        GoalHeader(plan: plan)

                        PlanOverviewCard(plan: plan)

                        modifyWithCoachButton

                        if let current = plan.current {
                            CurrentPhaseCard(plan: plan, phase: current)
                        }

                        ForEach(allWeeks(plan: plan), id: \.weekNumber) { wp in
                            NavigationLink {
                                WeekDetailView(initialWeekNum: wp.weekNumber)
                            } label: {
                                WeekCard(plan: plan, weeklyPlan: wp)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding()
                } else {
                    emptyState
                }
            }
            .navigationTitle("Plan")
            .sheet(isPresented: $showGoalPicker) {
                GoalPickerSheet(isPresented: $showGoalPicker) { event in
                    routeToCoach(for: event, modify: false)
                }
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 24) {
            ContentUnavailableView(
                "No Training Plan",
                systemImage: "calendar.badge.plus",
                description: Text("Your coach can build one around any goal you've added.")
            )
            Button {
                showGoalPicker = true
            } label: {
                Label("Build a plan with your coach", systemImage: "sparkles")
                    .font(CoachFonts.ui(15, weight: .semibold))
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
                    .background(CoachColors.accent)
                    .foregroundStyle(.white)
                    .clipShape(Capsule())
            }
            .buttonStyle(.plain)
        }
        .padding(.top, 60)
        .frame(maxWidth: .infinity)
    }

    private var modifyWithCoachButton: some View {
        Button {
            guard let plan = data.trainingPlan else { return }
            routeToCoachForModify(plan: plan)
        } label: {
            Label("Modify plan with your coach", systemImage: "bubble.left.and.bubble.right")
                .font(CoachFonts.ui(13, weight: .semibold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(CoachColors.accent.opacity(0.12))
                .foregroundStyle(CoachColors.accent)
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(CoachColors.accent.opacity(0.4), lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
    }

    private func routeToCoach(for event: Event, modify: Bool) {
        let dateClause = event.date.map { " on \($0)" } ?? ""
        let goalClause = event.goal.map { ". Goal: \($0)." } ?? "."
        let weeksClause = event.date.flatMap { dateStr -> String? in
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd"
            guard let d = formatter.date(from: dateStr) else { return nil }
            let days = Calendar.current.dateComponents([.day], from: Date(), to: d).day ?? 0
            return days > 7 ? " I have \(days / 7) weeks." : nil
        } ?? ""
        data.pendingChatPrompt = "Build me a training plan for \(event.name)\(dateClause)\(goalClause)\(weeksClause) Let's do it together."
        data.selectedTab = "coach"
    }

    private func routeToCoachForModify(plan: TrainingPlan) {
        let race = plan.raceName ?? "my race"
        data.pendingChatPrompt = "I want to modify my current training plan for \(race). I'm in week \(plan.currentWeek) of \(plan.totalWeeks). What would you like to change?"
        data.selectedTab = "coach"
    }

    private func allWeeks(plan: TrainingPlan) -> [WeeklyPlan] {
        plan.weeklyPlans.values.sorted { $0.weekNumber < $1.weekNumber }
    }
}

// MARK: - Goal Header

private struct GoalHeader: View {
    let plan: TrainingPlan
    @Environment(DataService.self) var data

    var body: some View {
        if let event = linkedEvent {
            NavigationLink {
                RaceDetailView(eventId: event.id)
            } label: {
                content(showChevron: true)
            }
            .buttonStyle(.plain)
        } else {
            content(showChevron: false)
        }
    }

    private var linkedEvent: Event? {
        guard let goalId = plan.goalId else { return nil }
        return data.events.first { $0.id == goalId }
    }

    @ViewBuilder
    private func content(showChevron: Bool) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("YOUR GOAL")
                    .font(CoachFonts.ui(11, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .tracking(0.8)
                Spacer()
                if showChevron {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.tertiary)
                }
            }
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

// MARK: - Current Phase Card

private struct CurrentPhaseCard: View {
    let plan: TrainingPlan
    let phase: TrainingPhase

    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        NavigationLink {
            PhaseDetailView(plan: plan, phase: phase)
        } label: {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 8) {
                    Text("PHASE \(phase.number) OF \(plan.phases.count)")
                        .font(CoachFonts.ui(11, weight: .semibold))
                        .tracking(0.8)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(phase.accentColor.opacity(0.2))
                        .foregroundStyle(phase.accentColor)
                        .clipShape(Capsule())
                    Spacer()
                    if let days = plan.daysRemainingInPhase(phase) {
                        Text("\(days) days left")
                            .font(CoachFonts.mono(12))
                            .foregroundStyle(.secondary)
                    }
                }

                Text(phase.name)
                    .font(CoachFonts.display(22, weight: .bold))
                    .foregroundStyle(.primary)

                Text("Week \(plan.weekIndexInPhase(phase)) of \(phase.weeks) in this phase")
                    .font(CoachFonts.ui(12, weight: .medium))
                    .foregroundStyle(.secondary)

                if let philosophy = phase.philosophy {
                    Text(philosophy)
                        .font(CoachFonts.ui(13))
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                }

                statsRow

                phaseProgress

                if let dist = phase.intensityDistribution {
                    intensityMini(dist)
                }

                HStack {
                    Spacer()
                    Text("View phase details →")
                        .font(CoachFonts.ui(12, weight: .semibold))
                        .foregroundStyle(phase.accentColor)
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                LinearGradient(
                    colors: [phase.accentColor.opacity(0.10), phase.accentColor.opacity(0.02)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(phase.accentColor.opacity(0.5), lineWidth: 1.5)
            )
        }
        .buttonStyle(.plain)
    }

    private var statsRow: some View {
        HStack(spacing: 18) {
            if let v = phase.weeklyVolumeRange {
                miniStat(label: "Volume", value: "\(formatVol(v.min))–\(formatVol(v.max)) \(v.unit)")
            }
            if let s = phase.sessionsPerWeek {
                miniStat(label: "Sessions", value: "\(s)/wk")
            }
            if let n = phase.keyWorkouts?.count {
                miniStat(label: "Key workouts", value: "\(n)")
            }
        }
    }

    private func miniStat(label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label.uppercased())
                .font(CoachFonts.ui(9, weight: .semibold))
                .tracking(0.4)
                .foregroundStyle(.secondary)
            Text(value)
                .font(CoachFonts.ui(13, weight: .semibold))
        }
    }

    private func formatVol(_ v: Double) -> String {
        v == v.rounded() ? "\(Int(v))" : String(format: "%.1f", v)
    }

    private var phaseProgress: some View {
        let completed = plan.completedWeeks(in: phase)
        return VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 4) {
                ForEach(0..<phase.weeks, id: \.self) { idx in
                    RoundedRectangle(cornerRadius: 3)
                        .fill(idx < completed ? phase.accentColor : (colorScheme == .dark ? CoachColors.darkBorder : CoachColors.lightBorder))
                        .frame(height: 6)
                }
            }
            Text("\(completed) of \(phase.weeks) weeks complete")
                .font(CoachFonts.ui(10))
                .foregroundStyle(.secondary)
        }
    }

    private func intensityMini(_ d: IntensityDistribution) -> some View {
        let total = max(1, d.easy + d.tempo + d.threshold + d.vo2max)
        return HStack(spacing: 2) {
            Rectangle().fill(CoachColors.green).frame(maxWidth: .infinity).layoutPriority(Double(d.easy) / Double(total))
            Rectangle().fill(CoachColors.yellow).frame(maxWidth: .infinity).layoutPriority(Double(d.tempo) / Double(total))
            Rectangle().fill(CoachColors.accent).frame(maxWidth: .infinity).layoutPriority(Double(d.threshold) / Double(total))
            Rectangle().fill(CoachColors.red).frame(maxWidth: .infinity).layoutPriority(Double(d.vo2max) / Double(total))
        }
        .frame(height: 5)
        .clipShape(RoundedRectangle(cornerRadius: 2))
    }
}

// MARK: - Plan Overview Card

private struct PlanOverviewCard: View {
    let plan: TrainingPlan

    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        NavigationLink {
            PlanReviewView(plan: plan)
        } label: {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Text("PLAN OVERVIEW")
                        .font(CoachFonts.ui(11, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .tracking(0.8)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.tertiary)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("\(plan.totalWeeks)-Week Plan")
                        .font(CoachFonts.display(22, weight: .bold))
                    Text(positionLine)
                        .font(CoachFonts.ui(12))
                        .foregroundStyle(.secondary)
                }

                if !phasePillRow.isEmpty {
                    HStack(spacing: 6) {
                        ForEach(phasePillRow, id: \.0) { name, color in
                            Text(name)
                                .font(CoachFonts.ui(10, weight: .semibold))
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(color.opacity(0.15))
                                .foregroundStyle(color)
                                .clipShape(Capsule())
                        }
                    }
                }

                timeline

                HStack {
                    Spacer()
                    Text("View full plan →")
                        .font(CoachFonts.ui(12, weight: .semibold))
                        .foregroundStyle(CoachColors.accent)
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
        .buttonStyle(.plain)
    }

    private var positionLine: String {
        var parts = ["Week \(plan.currentWeek) of \(plan.totalWeeks)"]
        if let weeks = plan.weeksUntilRace() {
            parts.append("\(weeks) weeks until race day")
        }
        return parts.joined(separator: " · ")
    }

    private var phasePillRow: [(String, Color)] {
        plan.phases.sorted(by: { $0.number < $1.number }).map { ($0.name, $0.accentColor) }
    }

    private var timeline: some View {
        HStack(spacing: 3) {
            ForEach(plan.phaseSegmentFractions(), id: \.phase.number) { entry in
                let isCurrent = entry.phase.number == plan.currentPhase
                timelineSegment(phase: entry.phase, isCurrent: isCurrent)
                    .layoutPriority(entry.fraction)
            }
        }
        .frame(height: 32)
    }

    @ViewBuilder
    private func timelineSegment(phase: TrainingPhase, isCurrent: Bool) -> some View {
        let completed = plan.completedWeeks(in: phase)
        ZStack {
            RoundedRectangle(cornerRadius: 6)
                .fill(phase.accentColor.opacity(isCurrent ? 0.30 : 0.12))
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(phase.accentColor.opacity(isCurrent ? 1.0 : 0.4), lineWidth: isCurrent ? 1.5 : 1)
                )
            HStack(spacing: 2) {
                ForEach(0..<phase.weeks, id: \.self) { idx in
                    Circle()
                        .fill(idx < completed ? phase.accentColor : phase.accentColor.opacity(0.3))
                        .frame(width: 5, height: 5)
                }
            }
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Week Card

private struct WeekCard: View {
    let plan: TrainingPlan
    let weeklyPlan: WeeklyPlan

    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
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

    private var allSessions: [PrescribedSession] { weeklyPlan.sessions.flatMap(\.sessions) }
    private var totalSessions: Int { allSessions.count }
    private var completedSessions: Int { allSessions.filter { $0.completed == true }.count }
    private var totalDistance: Double { allSessions.compactMap(\.distanceMiles).reduce(0, +) }

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
