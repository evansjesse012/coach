import SwiftUI

struct HomeTab: View {
    @Environment(DataService.self) var data
    @State private var showSettings = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    GreetingHeader()
                    CoachMessageCard()
                    GoalCountdownBanner()
                    TodaysFocusSection()
                    WeekGlanceSection()
                    PhaseMiniCard()
                    MomentumRow()
                    TomorrowPreview()
                    OtherGoalsSection()
                }
                .padding()
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showSettings = true
                    } label: {
                        Image(systemName: "gearshape")
                    }
                }
            }
            .sheet(isPresented: $showSettings) {
                NavigationStack { SettingsView() }
            }
        }
    }
}

// MARK: - Greeting

private struct GreetingHeader: View {
    private var greeting: String {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 0..<12: return "Good morning"
        case 12..<17: return "Good afternoon"
        case 17..<22: return "Good evening"
        default: return "Hello"
        }
    }

    private var dateLine: String {
        let f = DateFormatter()
        f.dateFormat = "EEEE, MMMM d"
        return f.string(from: Date())
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(greeting)
                .font(CoachFonts.display(26, weight: .bold))
                .foregroundStyle(.primary)
            Text(dateLine)
                .font(CoachFonts.ui(13))
                .foregroundStyle(.secondary)
        }
    }
}

// MARK: - Coach Message Card

private struct CoachMessageCard: View {
    @Environment(DataService.self) var data

    var body: some View {
        if let msg = data.settings.pushMessage, !msg.text.isEmpty {
            card(msg: msg)
        }
    }

    private func card(msg: PushMessage) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [CoachColors.accent, CoachColors.purple],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 32, height: 32)
                    Image(systemName: "sparkles")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.white)
                }
                VStack(alignment: .leading, spacing: 1) {
                    Text("MESSAGE FROM COACH")
                        .font(CoachFonts.ui(10, weight: .semibold))
                        .tracking(0.8)
                        .foregroundStyle(.secondary)
                    Text(data.settings.personality.label)
                        .font(CoachFonts.ui(13, weight: .semibold))
                        .foregroundStyle(.primary)
                }
                Spacer()
                Button {
                    data.selectedTab = "coach"
                } label: {
                    Image(systemName: "arrow.up.right")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(CoachColors.accent)
                        .padding(7)
                        .background(Circle().fill(CoachColors.accent.opacity(0.12)))
                }
                .buttonStyle(.plain)
            }

            Text(msg.text)
                .font(CoachFonts.ui(14))
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)
                .multilineTextAlignment(.leading)

            if let actions = msg.actions, !actions.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(Array(actions.prefix(3)), id: \.self) { action in
                            Button {
                                data.pendingChatPrompt = action
                                data.selectedTab = "coach"
                            } label: {
                                Text(action)
                                    .font(CoachFonts.ui(12, weight: .semibold))
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .background(Capsule().fill(CoachColors.accent.opacity(0.15)))
                                    .foregroundStyle(CoachColors.accent)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            LinearGradient(
                colors: [
                    CoachColors.accent.opacity(0.12),
                    CoachColors.purple.opacity(0.06)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(CoachColors.accent.opacity(0.3), lineWidth: 1)
        )
    }
}

// MARK: - Goal Countdown Banner

private struct GoalCountdownBanner: View {
    @Environment(DataService.self) var data

    var body: some View {
        if let plan = data.trainingPlan,
           let raceDate = plan.raceDate,
           let days = daysUntil(raceDate) {
            banner(plan: plan, raceDate: raceDate, days: days)
        }
    }

    @ViewBuilder
    private func banner(plan: TrainingPlan, raceDate: String, days: Int) -> some View {
        if let event = data.events.first(where: { $0.id == plan.goalId }) {
            NavigationLink {
                RaceDetailView(eventId: event.id)
            } label: {
                bannerContent(plan: plan, raceDate: raceDate, days: days)
            }
            .buttonStyle(.plain)
        } else {
            bannerContent(plan: plan, raceDate: raceDate, days: days)
        }
    }

    private func bannerContent(plan: TrainingPlan, raceDate: String, days: Int) -> some View {
        HStack(alignment: .top, spacing: 16) {
            VStack(alignment: .leading, spacing: 6) {
                Text("RACE DAY")
                    .font(CoachFonts.ui(10, weight: .semibold))
                    .tracking(0.8)
                    .foregroundStyle(.secondary)
                Text(plan.raceName ?? "Race")
                    .font(CoachFonts.display(20, weight: .bold))
                    .foregroundStyle(.primary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                Text(formatDateLong(raceDate))
                    .font(CoachFonts.ui(12, weight: .medium))
                    .foregroundStyle(CoachColors.accent)
            }
            Spacer()
            VStack(spacing: 0) {
                Text("\(days)")
                    .font(CoachFonts.display(44, weight: .bold))
                    .foregroundStyle(CoachColors.accent)
                Text(days == 1 ? "day" : "days")
                    .font(CoachFonts.ui(11, weight: .semibold))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            LinearGradient(
                colors: [
                    CoachColors.accent.opacity(0.15),
                    CoachColors.accent.opacity(0.04)
                ],
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

// MARK: - Today's Focus

private struct TodaysFocusSection: View {
    @Environment(DataService.self) var data

    private var todayDayIdx: Int {
        (Calendar.current.component(.weekday, from: Date()) + 5) % 7
    }

    private var headerDate: String {
        let f = DateFormatter()
        f.dateFormat = "EEE, MMM d"
        return f.string(from: Date()).uppercased()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                CoachLabel(text: "Today's Focus")
                Spacer()
                Text(headerDate)
                    .font(CoachFonts.ui(10, weight: .semibold))
                    .tracking(0.6)
                    .foregroundStyle(.secondary)
            }
            content
        }
    }

    @ViewBuilder
    private var content: some View {
        if let plan = data.trainingPlan {
            planContent(plan)
        } else {
            NoPlanCTA()
        }
    }

    @ViewBuilder
    private func planContent(_ plan: TrainingPlan) -> some View {
        if let wp = plan.weeklyPlans[String(plan.currentWeek)],
           todayDayIdx < wp.sessions.count {
            dayContent(dayPlan: wp.sessions[todayDayIdx], plan: plan)
        } else {
            EmptyFocusCard()
        }
    }

    @ViewBuilder
    private func dayContent(dayPlan: DayPlan, plan: TrainingPlan) -> some View {
        if dayPlan.isRest == true {
            HomeRestDayCard()
        } else if dayPlan.sessions.isEmpty {
            EmptyFocusCard()
        } else {
            ForEach(Array(dayPlan.sessions.enumerated()), id: \.offset) { sessionIdx, session in
                TodaySessionCard(
                    session: session,
                    weekNum: plan.currentWeek,
                    dayIdx: todayDayIdx,
                    sessionIdx: sessionIdx
                )
            }
        }
    }
}

// MARK: - No Plan CTA

private struct NoPlanCTA: View {
    @Environment(DataService.self) var data

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("No training plan yet")
                .font(CoachFonts.ui(15, weight: .semibold))
                .foregroundStyle(.primary)
            Text("Add a goal and build a plan with your coach.")
                .font(CoachFonts.ui(13))
                .foregroundStyle(.secondary)
            Button {
                data.selectedTab = "plan"
            } label: {
                Text("Go to Plan")
                    .font(CoachFonts.ui(13, weight: .semibold))
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(Capsule().fill(CoachColors.accent))
                    .foregroundStyle(.white)
            }
            .buttonStyle(.plain)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(CoachColors.accent.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(CoachColors.accent.opacity(0.25), lineWidth: 1)
        )
    }
}

// MARK: - Rest Day Card (home variant)

private struct HomeRestDayCard: View {
    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: "moon.stars.fill")
                .font(.system(size: 26, weight: .semibold))
                .foregroundStyle(CoachColors.purple)
            VStack(alignment: .leading, spacing: 4) {
                Text("Rest Day")
                    .font(CoachFonts.display(18, weight: .bold))
                    .foregroundStyle(.primary)
                Text("Sleep, hydrate, mobility. Recovery is training.")
                    .font(CoachFonts.ui(12))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .multilineTextAlignment(.leading)
            }
            Spacer()
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            LinearGradient(
                colors: [
                    CoachColors.purple.opacity(0.12),
                    CoachColors.purple.opacity(0.04)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(CoachColors.purple.opacity(0.3), lineWidth: 1)
        )
    }
}

// MARK: - Empty Focus Card

private struct EmptyFocusCard: View {
    var body: some View {
        CoachCard {
            Text("Nothing scheduled today — your call.")
                .font(CoachFonts.ui(13))
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

// MARK: - Today Session Card (hero)

private struct TodaySessionCard: View {
    let session: PrescribedSession
    let weekNum: Int
    let dayIdx: Int
    let sessionIdx: Int

    @Environment(DataService.self) var data
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        HStack(spacing: 0) {
            NavigationLink {
                PrescribedSessionDetailView(session: session, dateString: todayString())
            } label: {
                cardContent
            }
            .buttonStyle(.plain)

            Button {
                Task {
                    try? await data.toggleSessionCompleted(
                        weekNum: weekNum,
                        dayIdx: dayIdx,
                        sessionIdx: sessionIdx
                    )
                }
            } label: {
                Image(systemName: session.completed == true ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 26))
                    .foregroundStyle(session.completed == true ? CoachColors.teal : .secondary)
            }
            .buttonStyle(.plain)
            .padding(.trailing, 14)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(colorScheme == .dark ? CoachColors.darkCard : CoachColors.lightCard)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(colorScheme == .dark ? CoachColors.darkBorder : CoachColors.lightBorder, lineWidth: 1)
        )
        .opacity(session.completed == true ? 0.72 : 1.0)
    }

    private var cardContent: some View {
        HStack(spacing: 0) {
            (session.effortCategory ?? .easy).gradient
                .frame(width: 6)

            VStack(alignment: .leading, spacing: 10) {
                headerRow
                Text(session.label)
                    .font(CoachFonts.display(19, weight: .bold))
                    .lineLimit(2)
                    .foregroundStyle(.primary)
                    .multilineTextAlignment(.leading)
                if let purpose = session.purpose, !purpose.isEmpty {
                    Text(purpose)
                        .font(CoachFonts.ui(12))
                        .italic()
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                        .multilineTextAlignment(.leading)
                }
                statsRow
                effortFuelRow
                if let warning = session.warning, !warning.isEmpty {
                    warningRow(warning)
                }
            }
            .padding(.leading, 12)
            .padding(.vertical, 14)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .contentShape(Rectangle())
    }

    @ViewBuilder
    private var headerRow: some View {
        HStack(spacing: 8) {
            if let sport = Sport(rawValue: session.type.lowercased()) {
                SportBadge(sport: sport)
            }
            if session.priority == .red {
                CoachPill(text: "KEY", color: CoachColors.accent)
            }
            Spacer()
        }
    }

    @ViewBuilder
    private var statsRow: some View {
        HStack(alignment: .top, spacing: 16) {
            if let time = timeValue {
                statItem(label: "TIME", value: time)
            }
            if let dist = distValue {
                statItem(label: "DIST", value: dist)
            }
            if let paceOrZone {
                statItem(label: paceOrZone.0, value: paceOrZone.1)
            }
            Spacer()
        }
    }

    private var timeValue: String? {
        if let lo = session.estimatedDurationMin, let hi = session.estimatedDurationMax {
            return "\(lo)-\(hi)m"
        }
        if let d = session.duration, d > 0 {
            return formatDuration(d)
        }
        return nil
    }

    private var distValue: String? {
        if let mi = session.distanceMiles, mi > 0 {
            return String(format: "%.1f mi", mi)
        }
        return nil
    }

    private var paceOrZone: (String, String)? {
        if let pace = session.paceRange, !pace.isEmpty {
            return ("PACE", pace)
        }
        if let zone = session.zone, !zone.isEmpty {
            return ("ZONE", zone)
        }
        return nil
    }

    @ViewBuilder
    private var effortFuelRow: some View {
        HStack(spacing: 8) {
            let effort = session.effortCategory ?? .easy
            CoachPill(text: effort.label.uppercased(), color: effort.color)
            if let pre = session.fuel?.pre, !pre.isEmpty {
                HStack(spacing: 4) {
                    Image(systemName: "fork.knife")
                        .font(.system(size: 10, weight: .semibold))
                    Text(pre)
                        .font(CoachFonts.ui(11))
                        .lineLimit(1)
                }
                .foregroundStyle(.secondary)
            }
            Spacer()
        }
    }

    private func warningRow(_ warning: String) -> some View {
        HStack(alignment: .top, spacing: 6) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(CoachColors.yellow)
            Text(warning)
                .font(CoachFonts.ui(11, weight: .medium))
                .foregroundStyle(.primary)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
                .multilineTextAlignment(.leading)
        }
        .padding(8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(CoachColors.yellow.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

// MARK: - File-scope helper: stat item

private func statItem(label: String, value: String) -> some View {
    VStack(alignment: .leading, spacing: 2) {
        Text(label)
            .font(CoachFonts.ui(10, weight: .semibold))
            .tracking(0.6)
            .foregroundStyle(.secondary)
        Text(value)
            .font(CoachFonts.mono(12, weight: .semibold))
            .foregroundStyle(.primary)
    }
}

// MARK: - Week Glance

private struct WeekGlanceSection: View {
    @Environment(DataService.self) var data
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        if let plan = data.trainingPlan,
           let adherence = computeWeekAdherence(
               plan: plan,
               weekNum: plan.currentWeek,
               cardio: data.cardio,
               strength: data.strength
           ) {
            NavigationLink {
                WeekDetailView(initialWeekNum: plan.currentWeek)
            } label: {
                card(plan: plan, adherence: adherence)
            }
            .buttonStyle(.plain)
        }
    }

    private func card(plan: TrainingPlan, adherence: WeekAdherence) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text("THIS WEEK")
                    .font(CoachFonts.ui(10, weight: .semibold))
                    .tracking(0.8)
                    .foregroundStyle(.secondary)
                Text("Week \(plan.currentWeek)")
                    .font(CoachFonts.display(18, weight: .bold))
                    .foregroundStyle(.primary)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.tertiary)
            }

            HStack(spacing: 6) {
                ForEach(Array(adherence.days.enumerated()), id: \.offset) { _, day in
                    DayDot(day: day)
                }
            }

            HStack(spacing: 14) {
                Text("SESSIONS \(adherence.completed)/\(adherence.prescribed)")
                    .font(CoachFonts.mono(10, weight: .semibold))
                    .foregroundStyle(.secondary)
                Text("ADHERENCE \(adherence.adherence)%")
                    .font(CoachFonts.mono(10, weight: .semibold))
                    .foregroundStyle(.secondary)
                if adherence.missed > 0 {
                    Text("MISSED \(adherence.missed)")
                        .font(CoachFonts.mono(10, weight: .semibold))
                        .foregroundStyle(CoachColors.yellow)
                }
                Spacer()
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(colorScheme == .dark ? CoachColors.darkCard : CoachColors.lightCard)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(colorScheme == .dark ? CoachColors.darkBorder : CoachColors.lightBorder, lineWidth: 1)
        )
    }
}

// MARK: - Day Dot

private struct DayDot: View {
    let day: DayReview

    @Environment(\.colorScheme) var colorScheme

    private var isAllDone: Bool {
        !day.sessions.isEmpty && day.sessions.allSatisfy {
            $0.status == .completed || $0.status == .shortened || $0.status == .substituted
        }
    }

    private var hasMissed: Bool {
        day.sessions.contains { $0.status == .missed }
    }

    private var fillColor: Color {
        if day.isRest { return CoachColors.purple.opacity(0.12) }
        if isAllDone { return CoachColors.teal.opacity(0.18) }
        if hasMissed { return CoachColors.red.opacity(0.1) }
        if day.isToday { return CoachColors.accent.opacity(0.15) }
        return .clear
    }

    private var strokeColor: Color {
        if day.isToday { return CoachColors.accent }
        return colorScheme == .dark ? CoachColors.darkBorder : CoachColors.lightBorder
    }

    private var strokeWidth: CGFloat { day.isToday ? 2 : 1 }

    var body: some View {
        VStack(spacing: 4) {
            Text(String(day.day.prefix(1)).uppercased())
                .font(CoachFonts.ui(10, weight: .semibold))
                .foregroundStyle(day.isToday ? CoachColors.accent : .secondary)
            ZStack {
                Circle()
                    .fill(fillColor)
                    .overlay(Circle().stroke(strokeColor, lineWidth: strokeWidth))
                    .frame(width: 28, height: 28)
                glyph
            }
        }
        .frame(maxWidth: .infinity)
    }

    @ViewBuilder
    private var glyph: some View {
        if day.isRest {
            Image(systemName: "moon.fill")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(CoachColors.purple)
        } else if isAllDone {
            Image(systemName: "checkmark")
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(CoachColors.teal)
        } else if hasMissed {
            Image(systemName: "xmark")
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(CoachColors.red)
        } else if day.isToday {
            Circle()
                .fill(CoachColors.accent)
                .frame(width: 6, height: 6)
        }
    }
}

// MARK: - Phase Mini Card

private struct PhaseMiniCard: View {
    @Environment(DataService.self) var data
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        if let plan = data.trainingPlan, let phase = plan.current {
            NavigationLink {
                PhaseDetailView(plan: plan, phase: phase)
            } label: {
                card(plan: plan, phase: phase)
            }
            .buttonStyle(.plain)
        }
    }

    private func card(plan: TrainingPlan, phase: TrainingPhase) -> some View {
        let accent = phase.accentColor
        let completed = plan.completedWeeks(in: phase)
        return VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Text("PHASE \(phase.number) OF \(plan.phases.count)")
                    .font(CoachFonts.ui(9, weight: .semibold))
                    .tracking(0.6)
                    .foregroundStyle(accent)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 2)
                    .background(Capsule().fill(accent.opacity(0.2)))
                Text(phase.name.uppercased())
                    .font(CoachFonts.ui(11, weight: .semibold))
                    .tracking(0.6)
                    .foregroundStyle(.secondary)
                Spacer()
                if let days = plan.daysRemainingInPhase(phase) {
                    Text("\(days)d left")
                        .font(CoachFonts.mono(11, weight: .semibold))
                        .foregroundStyle(.secondary)
                }
            }

            HStack(spacing: 3) {
                ForEach(0..<max(1, phase.weeks), id: \.self) { i in
                    RoundedRectangle(cornerRadius: 2)
                        .fill(i < completed ? accent : (colorScheme == .dark ? CoachColors.darkBorder : CoachColors.lightBorder))
                        .frame(height: 5)
                }
            }

            Text(footerText(plan: plan, phase: phase))
                .font(CoachFonts.ui(11))
                .foregroundStyle(.secondary)
                .lineLimit(2)
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            LinearGradient(
                colors: [accent.opacity(0.08), accent.opacity(0.02)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(accent.opacity(0.35), lineWidth: 1)
        )
    }

    private func footerText(plan: TrainingPlan, phase: TrainingPhase) -> String {
        let intro = "Week \(plan.weekIndexInPhase(phase)) of \(phase.weeks)"
        if let desc = phase.philosophy ?? phase.focus, !desc.isEmpty {
            return "\(intro) · \(desc)"
        }
        return intro
    }
}

// MARK: - Momentum Row

private struct MomentumRow: View {
    @Environment(DataService.self) var data

    var body: some View {
        HStack(spacing: 12) {
            StreakCard()
            if data.cardio.isEmpty {
                EmptyMomentumCard()
            } else {
                LastWorkoutCard()
            }
        }
    }
}

// MARK: - Streak Card

private struct StreakCard: View {
    @Environment(DataService.self) var data
    @Environment(\.colorScheme) var colorScheme

    private var streakCount: Int {
        var dates = Set<String>()
        for w in data.cardio { dates.insert(w.date) }
        for s in data.strength { dates.insert(s.date) }

        let cal = Calendar.current
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        var cursor = Date()

        // If today is empty, step back one day — don't break streak at midnight.
        if !dates.contains(formatter.string(from: cursor)) {
            cursor = cal.date(byAdding: .day, value: -1, to: cursor) ?? cursor
        }

        var count = 0
        while dates.contains(formatter.string(from: cursor)) {
            count += 1
            if count >= 365 { break }
            cursor = cal.date(byAdding: .day, value: -1, to: cursor) ?? cursor
        }
        return count
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Image(systemName: "flame.fill")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(CoachColors.accent)
                Text("STREAK")
                    .font(CoachFonts.ui(10, weight: .semibold))
                    .tracking(0.6)
                    .foregroundStyle(.secondary)
            }
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text("\(streakCount)")
                    .font(CoachFonts.display(28, weight: .bold))
                    .foregroundStyle(CoachColors.accent)
                Text(streakCount == 1 ? "day" : "days")
                    .font(CoachFonts.ui(12, weight: .medium))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(colorScheme == .dark ? CoachColors.darkCard : CoachColors.lightCard)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(colorScheme == .dark ? CoachColors.darkBorder : CoachColors.lightBorder, lineWidth: 1)
        )
    }
}

// MARK: - Last Workout Card

private struct LastWorkoutCard: View {
    @Environment(DataService.self) var data
    @Environment(\.colorScheme) var colorScheme

    private var last: CardioWorkout? {
        data.cardio.max(by: { $0.date < $1.date })
    }

    var body: some View {
        if let workout = last {
            card(workout)
        } else {
            EmptyMomentumCard()
        }
    }

    private func card(_ workout: CardioWorkout) -> some View {
        let sport = workout.sport
        return VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Image(systemName: sport.sfSymbol)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(sport.swiftUIColor)
                Text("LAST \(sport.label.uppercased())")
                    .font(CoachFonts.ui(10, weight: .semibold))
                    .tracking(0.6)
                    .foregroundStyle(.secondary)
            }
            Text(formatDateRelative(workout.date))
                .font(CoachFonts.ui(13, weight: .semibold))
                .foregroundStyle(.primary)
            Text(statsLine(workout))
                .font(CoachFonts.mono(11))
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(colorScheme == .dark ? CoachColors.darkCard : CoachColors.lightCard)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(colorScheme == .dark ? CoachColors.darkBorder : CoachColors.lightBorder, lineWidth: 1)
        )
    }

    private func statsLine(_ workout: CardioWorkout) -> String {
        var parts: [String] = [formatDuration(workout.duration)]
        if let d = workout.distance, !d.isEmpty {
            parts.append(d)
        }
        if let hr = workout.avgHR {
            parts.append("\(hr)bpm")
        }
        return parts.joined(separator: " · ")
    }
}

// MARK: - Empty Momentum Card

private struct EmptyMomentumCard: View {
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Image(systemName: "sparkle")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.secondary)
                Text("NO WORKOUTS")
                    .font(CoachFonts.ui(10, weight: .semibold))
                    .tracking(0.6)
                    .foregroundStyle(.secondary)
            }
            Text("Log something to start")
                .font(CoachFonts.ui(13))
                .foregroundStyle(.secondary)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(colorScheme == .dark ? CoachColors.darkCard : CoachColors.lightCard)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(colorScheme == .dark ? CoachColors.darkBorder : CoachColors.lightBorder, lineWidth: 1)
        )
    }
}

// MARK: - Tomorrow Preview

private struct TomorrowPreview: View {
    @Environment(DataService.self) var data
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        if let session = resolvedSession() {
            card(session)
        }
    }

    private func resolvedSession() -> PrescribedSession? {
        guard let plan = data.trainingPlan else { return nil }
        let todayDayIdx = (Calendar.current.component(.weekday, from: Date()) + 5) % 7

        let dayPlan: DayPlan?
        if todayDayIdx == 6 {
            // Sunday → tomorrow is next week's Monday (index 0)
            guard let wp = plan.weeklyPlans[String(plan.currentWeek + 1)],
                  !wp.sessions.isEmpty else { return nil }
            dayPlan = wp.sessions[0]
        } else {
            guard let wp = plan.weeklyPlans[String(plan.currentWeek)],
                  todayDayIdx + 1 < wp.sessions.count else { return nil }
            dayPlan = wp.sessions[todayDayIdx + 1]
        }

        guard let dp = dayPlan, dp.isRest != true, !dp.sessions.isEmpty else { return nil }
        return dp.sessions.first(where: { $0.priority == .red }) ?? dp.sessions.first
    }

    private func card(_ session: PrescribedSession) -> some View {
        let effort = session.effortCategory ?? .easy
        return VStack(alignment: .leading, spacing: 8) {
            CoachLabel(text: "Up Next · Tomorrow")
            HStack(spacing: 10) {
                Capsule()
                    .fill(effort.gradient)
                    .frame(width: 4, height: 36)
                if let sport = Sport(rawValue: session.type.lowercased()) {
                    SportBadge(sport: sport)
                }
                Text(session.label)
                    .font(CoachFonts.ui(14, weight: .semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                Spacer()
                if let dur = durationString(session) {
                    Text(dur)
                        .font(CoachFonts.mono(12))
                        .foregroundStyle(.secondary)
                }
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(colorScheme == .dark ? CoachColors.darkCard : CoachColors.lightCard)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(colorScheme == .dark ? CoachColors.darkBorder : CoachColors.lightBorder, lineWidth: 1)
            )
        }
    }

    private func durationString(_ session: PrescribedSession) -> String? {
        if let d = session.duration, d > 0 {
            return formatDuration(d)
        }
        if let lo = session.estimatedDurationMin, let hi = session.estimatedDurationMax {
            return "\(lo)-\(hi)m"
        }
        return nil
    }
}

// MARK: - Other Goals

private struct OtherGoalsSection: View {
    @Environment(DataService.self) var data

    private var others: [Event] {
        let primaryId = data.trainingPlan?.goalId
        return data.events
            .filter { !$0.completed && $0.date != nil && $0.id != primaryId }
            .sorted { ($0.date ?? "") < ($1.date ?? "") }
            .prefix(3)
            .map { $0 }
    }

    var body: some View {
        if !others.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                CoachLabel(text: "Other Goals")
                ForEach(others) { event in
                    NavigationLink {
                        RaceDetailView(eventId: event.id)
                    } label: {
                        row(event)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private func row(_ event: Event) -> some View {
        CoachCard {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(event.name)
                        .font(CoachFonts.ui(14, weight: .semibold))
                        .foregroundStyle(.primary)
                    if let date = event.date {
                        Text(formatDateShort(date))
                            .font(CoachFonts.ui(11))
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer()
                if let date = event.date, let days = daysUntil(date), days >= 0 {
                    Text("\(days)d")
                        .font(CoachFonts.mono(14, weight: .bold))
                        .foregroundStyle(CoachColors.accent)
                }
            }
        }
    }
}
