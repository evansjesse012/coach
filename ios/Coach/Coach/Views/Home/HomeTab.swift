import SwiftUI

struct HomeTab: View {
    @Environment(DataService.self) var data

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    // Push message card
                    if let push = data.settings.pushMessage, !push.text.isEmpty {
                        CoachCard(accentColor: CoachColors.accent) {
                            Text(push.text)
                                .font(CoachFonts.ui(14))
                        }
                    }

                    // Today's sessions
                    if let plan = data.trainingPlan,
                       let wp = plan.weeklyPlans[String(plan.currentWeek)] {
                        CoachLabel(text: "Today's Sessions")
                        let todayIdx = Calendar.current.component(.weekday, from: Date())
                        // Convert Sunday=1...Saturday=7 to Monday=0...Sunday=6
                        let dayIdx = (todayIdx + 5) % 7
                        if dayIdx < wp.sessions.count {
                            let dayPlan = wp.sessions[dayIdx]
                            if dayPlan.isRest == true {
                                CoachCard {
                                    HStack {
                                        Image(systemName: "moon.fill")
                                            .foregroundStyle(CoachColors.purple)
                                        Text("Rest Day")
                                            .font(CoachFonts.ui(15, weight: .medium))
                                    }
                                }
                            } else {
                                ForEach(dayPlan.sessions) { session in
                                    CoachCard(accentColor: Sport(rawValue: session.type)?.swiftUIColor) {
                                        HStack {
                                            if let sport = Sport(rawValue: session.type) {
                                                SportBadge(sport: sport)
                                            }
                                            Text(session.label)
                                                .font(CoachFonts.ui(14, weight: .medium))
                                            Spacer()
                                            if let dur = session.duration {
                                                Text(formatDuration(dur))
                                                    .font(CoachFonts.mono(13))
                                                    .foregroundStyle(.secondary)
                                            }
                                        }
                                        if let purpose = session.purpose {
                                            Text(purpose)
                                                .font(CoachFonts.ui(13))
                                                .foregroundStyle(.secondary)
                                        }
                                    }
                                }
                            }
                        }
                    }

                    // Quick stats
                    CoachLabel(text: "This Week")
                    let thisWeekCardio = data.cardio.filter { isThisWeek($0.date) }
                    let thisWeekStrength = data.strength.filter { isThisWeek($0.date) }
                    let totalMinutes = thisWeekCardio.reduce(0) { $0 + $1.duration } + thisWeekStrength.reduce(0) { $0 + ($1.duration ?? 0) }

                    HStack(spacing: 12) {
                        StatCard(label: "Sessions", value: "\(thisWeekCardio.count + thisWeekStrength.count)")
                        StatCard(label: "Volume", value: formatDuration(totalMinutes))
                    }

                    // Upcoming goals
                    let activeGoals = data.events.filter { !$0.completed && $0.date != nil }
                    if !activeGoals.isEmpty {
                        CoachLabel(text: "Upcoming")
                        ForEach(activeGoals.prefix(3)) { event in
                            CoachCard {
                                HStack {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(event.name)
                                            .font(CoachFonts.ui(14, weight: .medium))
                                        if let date = event.date {
                                            Text(formatDateShort(date))
                                                .font(CoachFonts.ui(12))
                                                .foregroundStyle(.secondary)
                                        }
                                    }
                                    Spacer()
                                    if let date = event.date, let days = daysUntil(date), days >= 0 {
                                        VStack {
                                            Text("\(days)")
                                                .font(CoachFonts.display(20, weight: .bold))
                                                .foregroundStyle(CoachColors.accent)
                                            Text("days")
                                                .font(CoachFonts.ui(11))
                                                .foregroundStyle(.secondary)
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
                .padding()
            }
            .navigationTitle("Coach")
        }
    }

    private func isThisWeek(_ dateStr: String) -> Bool {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        guard let date = formatter.date(from: dateStr) else { return false }
        return Calendar.current.isDate(date, equalTo: Date(), toGranularity: .weekOfYear)
    }
}

// MARK: - Stat Card

private struct StatCard: View {
    let label: String
    let value: String

    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(CoachFonts.display(22, weight: .bold))
            Text(label)
                .font(CoachFonts.ui(12))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(colorScheme == .dark ? CoachColors.darkCard : CoachColors.lightCard)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(colorScheme == .dark ? CoachColors.darkBorder : CoachColors.lightBorder, lineWidth: 1)
        )
    }
}
