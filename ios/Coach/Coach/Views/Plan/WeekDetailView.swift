import SwiftUI

struct WeekDetailView: View {
    let initialWeekNum: Int

    @Environment(DataService.self) var data
    @Environment(\.dismiss) var dismiss
    @State private var weekNum: Int = 1
    @State private var didInit = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                weekSelector

                if let plan = data.trainingPlan,
                   let wp = plan.weeklyPlans[String(weekNum)] {
                    sessionsList(plan: plan, weeklyPlan: wp)
                } else {
                    Text("No data for this week")
                        .font(CoachFonts.ui(13))
                        .foregroundStyle(.secondary)
                        .padding(.top, 40)
                }
            }
            .padding()
        }
        .navigationTitle("Plan Overview")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            guard !didInit else { return }
            weekNum = initialWeekNum
            didInit = true
        }
    }

    // MARK: - Week Selector

    private var weekSelector: some View {
        HStack(spacing: 16) {
            Button {
                if weekNum > minWeek { weekNum -= 1 }
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(weekNum > minWeek ? CoachColors.accent : .secondary)
                    .frame(width: 36, height: 36)
            }
            .disabled(weekNum <= minWeek)

            Menu {
                ForEach(allWeekNums, id: \.self) { n in
                    Button {
                        weekNum = n
                    } label: {
                        HStack {
                            Text("Week \(n)")
                            if n == weekNum {
                                Spacer()
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
            } label: {
                HStack(spacing: 4) {
                    Text("Week \(weekNum)")
                        .font(CoachFonts.display(20, weight: .bold))
                        .foregroundStyle(.primary)
                    Image(systemName: "chevron.down")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
            }

            Button {
                if weekNum < maxWeek { weekNum += 1 }
            } label: {
                Image(systemName: "chevron.right")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(weekNum < maxWeek ? CoachColors.accent : .secondary)
                    .frame(width: 36, height: 36)
            }
            .disabled(weekNum >= maxWeek)
        }
        .padding(.vertical, 4)
    }

    private var allWeekNums: [Int] {
        (data.trainingPlan?.weeklyPlans.keys.compactMap(Int.init) ?? []).sorted()
    }
    private var minWeek: Int { allWeekNums.first ?? 1 }
    private var maxWeek: Int { allWeekNums.last ?? 1 }

    // MARK: - Sessions list

    private func sessionsList(plan: TrainingPlan, weeklyPlan: WeeklyPlan) -> some View {
        VStack(spacing: 12) {
            ForEach(Array(weeklyPlan.sessions.enumerated()), id: \.offset) { dayIdx, dayPlan in
                ForEach(Array(dayPlan.sessions.enumerated()), id: \.offset) { sessionIdx, session in
                    SessionCard(
                        session: session,
                        dateString: dateString(plan: plan, dayIdx: dayIdx),
                        weekNum: weekNum,
                        dayIdx: dayIdx,
                        sessionIdx: sessionIdx
                    )
                }
            }
        }
    }

    private func dateString(plan: TrainingPlan, dayIdx: Int) -> String {
        guard let startDateStr = plan.startDate else { return "" }
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        guard let planStart = formatter.date(from: startDateStr) else { return "" }
        let cal = Calendar.current
        let totalDays = (weekNum - 1) * 7 + dayIdx
        guard let date = cal.date(byAdding: .day, value: totalDays, to: planStart) else { return "" }
        return formatter.string(from: date)
    }
}

// MARK: - Session Card

private struct SessionCard: View {
    let session: PrescribedSession
    let dateString: String
    let weekNum: Int
    let dayIdx: Int
    let sessionIdx: Int

    @Environment(DataService.self) var data
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        HStack(spacing: 0) {
            NavigationLink {
                PrescribedSessionDetailView(session: session, dateString: dateString)
            } label: {
                HStack(spacing: 0) {
                    // Vertical color bar
                    (session.effortCategory ?? .easy).gradient
                        .frame(width: 6)

                    VStack(alignment: .leading, spacing: 6) {
                        Text(session.label)
                            .font(CoachFonts.ui(16, weight: .bold))
                            .lineLimit(2)
                            .foregroundStyle(.primary)

                        Text(secondLine)
                            .font(CoachFonts.ui(12))
                            .foregroundStyle(.secondary)

                        Text(thirdLine)
                            .font(CoachFonts.ui(12, weight: .medium))
                            .foregroundStyle((session.effortCategory ?? .easy).color)

                        if let note = session.notes, !note.isEmpty {
                            Text(note)
                                .font(CoachFonts.ui(11))
                                .foregroundStyle(.secondary)
                                .lineLimit(2)
                                .padding(.top, 2)
                        }
                    }
                    .padding(.leading, 12)
                    .padding(.vertical, 12)

                    Spacer(minLength: 0)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            Button {
                Task {
                    try? await data.toggleSessionCompleted(
                        weekNum: weekNum, dayIdx: dayIdx, sessionIdx: sessionIdx
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
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(colorScheme == .dark ? CoachColors.darkBorder : CoachColors.lightBorder, lineWidth: 1)
        )
        .opacity(session.completed == true ? 0.7 : 1.0)
    }

    // MARK: derived

    private var secondLine: String {
        var parts: [String] = []
        if !dateString.isEmpty {
            parts.append(formatDayLong(dateString))
        }
        if let durRange = durationRange {
            parts.append(durRange)
        } else if let dur = session.duration {
            parts.append("\(dur)m")
        }
        return parts.joined(separator: " · ")
    }

    private var thirdLine: String {
        var parts: [String] = []
        if let cat = session.effortCategory {
            parts.append(cat.label)
        } else if !session.type.isEmpty {
            parts.append(session.type.capitalized)
        }
        if let mi = session.distanceMiles, mi > 0 {
            parts.append(String(format: "%.1fmi", mi))
        }
        return parts.joined(separator: " · ")
    }

    private var durationRange: String? {
        if let lo = session.estimatedDurationMin, let hi = session.estimatedDurationMax {
            return "\(lo)m - \(hi)m"
        }
        return nil
    }
}
