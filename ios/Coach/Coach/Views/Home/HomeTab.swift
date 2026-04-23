import SwiftUI

struct HomeTab: View {
    @Environment(DataService.self) private var data
    @State private var path = NavigationPath()
    @State private var showSettings = false
    @State private var activeSheet: ActiveSheet?

    // Sheets for did-it / modified / swapped / skipped flows
    enum ActiveSheet: Identifiable {
        case modified(week: Int, day: Int, session: Int, prescribed: PrescribedSession)
        case swapped(week: Int, day: Int, session: Int, prescribed: PrescribedSession, others: [PrescribedSession])
        case skipped(week: Int, day: Int, session: Int)

        var id: String {
            switch self {
            case .modified(let w, let d, let s, _):    return "mod-\(w)-\(d)-\(s)"
            case .swapped(let w, let d, let s, _, _):  return "swp-\(w)-\(d)-\(s)"
            case .skipped(let w, let d, let s):        return "skp-\(w)-\(d)-\(s)"
            }
        }
    }

    var body: some View {
        NavigationStack(path: $path) {
            ScrollView {
                VStack(alignment: .leading, spacing: Theme.Spacing.section) {
                    headerBlock
                    raceHeroBlock
                    coachBriefBlock
                    todayBlock
                    thisWeekBlock
                    phaseProgressBlock
                }
                .padding(.horizontal, Theme.Spacing.screenH)
                .padding(.top, 16)
                .padding(.bottom, Theme.Spacing.bottomReserve)
            }
            .background(Theme.bg.ignoresSafeArea())
            .scrollContentBackground(.hidden)
            .sheet(isPresented: $showSettings) {
                NavigationStack { SettingsView() }
            }
            .sheet(item: $activeSheet) { sheet in
                sheetView(for: sheet)
            }
        }
        .popsOnTabReselect(tabId: "today", path: $path)
    }

    // MARK: - Header

    @ViewBuilder
    private var headerBlock: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 6) {
                Text(dateKicker)
                    .font(Theme.Typography.monoLabel)
                    .foregroundStyle(Theme.ink3)
                    .textCase(.uppercase)
                    .tracking(Theme.Tracking.monoLabel)
                Text(greetingText)
                    .font(Theme.Typography.pageTitle)
                    .foregroundStyle(Theme.ink)
                    .tracking(-0.5)
            }
            Spacer(minLength: 0)
            Button {
                showSettings = true
            } label: {
                Image(systemName: "gearshape")
                    .font(.system(size: 16, weight: .regular))
                    .foregroundStyle(Theme.ink2)
                    .frame(width: 40, height: 40)
                    .background(Circle().strokeBorder(Theme.line, lineWidth: 1))
            }
            .buttonStyle(.plain)
        }
    }

    private var dateKicker: String {
        let f = DateFormatter()
        f.dateFormat = "EEEE · MMMM d"
        return f.string(from: Date())
    }

    private var greetingText: String {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 5..<12:  return "Good morning"
        case 12..<17: return "Good afternoon"
        default:      return "Good evening"
        }
    }

    // MARK: - Race hero

    @ViewBuilder
    private var raceHeroBlock: some View {
        if let plan = data.trainingPlan,
           let name = plan.raceName, !name.isEmpty,
           let date = plan.raceDate {
            let (count, unit) = countdownParts(date)
            CountdownHero(
                kicker: "A-Race",
                name: name,
                date: formattedRaceDate(date),
                count: count,
                unit: unit
            )
        }
    }

    private func countdownParts(_ dateStr: String) -> (Int, String) {
        let days = daysUntil(dateStr) ?? 0
        if days >= 14 {
            let weeks = days / 7
            return (weeks, weeks == 1 ? "Week out" : "Weeks out")
        }
        if days <= 0 { return (0, "Today") }
        return (days, days == 1 ? "Day out" : "Days out")
    }

    private func formattedRaceDate(_ dateStr: String) -> String {
        let inF = DateFormatter()
        inF.dateFormat = "yyyy-MM-dd"
        guard let d = inF.date(from: dateStr) else { return dateStr }
        let outF = DateFormatter()
        outF.dateFormat = "EEE · MMM d · yyyy"
        return outF.string(from: d)
    }

    // MARK: - Coach brief

    @ViewBuilder
    private var coachBriefBlock: some View {
        if let msg = data.settings.pushMessage, !msg.text.isEmpty {
            CoachBrief(
                kicker: "Today's brief",
                source: data.settings.personality.label,
                time: formattedBriefTime(msg.ts),
                message: .briefMessage(msg.text),
                actions: briefActions(from: msg.actions)
            )
        }
    }

    private func formattedBriefTime(_ ts: String?) -> String {
        guard let ts, !ts.isEmpty else { return "" }
        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let date = iso.date(from: ts) ?? ISO8601DateFormatter().date(from: ts)
        guard let d = date else { return "" }
        let out = DateFormatter()
        out.dateFormat = "h:mm a"
        return out.string(from: d)
    }

    private func briefActions(from actions: [String]?) -> [CoachBrief.BriefAction] {
        guard let actions, !actions.isEmpty else { return [] }
        return Array(actions.prefix(2)).enumerated().map { idx, title in
            CoachBrief.BriefAction(
                title: title,
                variant: idx == 0 ? .primary : .secondary
            ) {
                // MainTabView observes pendingChatPrompt and opens the Coach chat sheet.
                data.pendingChatPrompt = title
            }
        }
    }

    // MARK: - Today

    @ViewBuilder
    private var todayBlock: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(
                title: todaySectionTitle,
                meta: todaySectionMeta,
                variant: .system
            )
            todayContent
        }
    }

    private var todaySectionTitle: String {
        let f = DateFormatter()
        f.dateFormat = "EEEE"
        return "Today · \(f.string(from: Date()))"
    }

    private var todaySectionMeta: String? {
        guard let plan = data.trainingPlan,
              let wp = plan.weeklyPlans[String(plan.currentWeek)],
              !wp.sessions.isEmpty,
              todayDayIdx >= 0, todayDayIdx < wp.sessions.count
        else { return nil }
        let dp = wp.sessions[todayDayIdx]
        if dp.isRest == true { return "Rest day" }
        let n = dp.sessions.count
        return n == 0 ? nil : "\(n) of \(n)"
    }

    private var todayDayIdx: Int {
        (Calendar.current.component(.weekday, from: Date()) + 5) % 7
    }

    @ViewBuilder
    private var todayContent: some View {
        if let plan = data.trainingPlan,
           let wp = plan.weeklyPlans[String(plan.currentWeek)],
           !wp.sessions.isEmpty,
           todayDayIdx >= 0, todayDayIdx < wp.sessions.count {
            let dp = wp.sessions[todayDayIdx]
            if dp.isRest == true {
                restCard(note: dp.restNote)
            } else if dp.sessions.isEmpty {
                emptyTodayCard
            } else {
                VStack(spacing: 12) {
                    ForEach(Array(dp.sessions.enumerated()), id: \.offset) { idx, session in
                        sessionRow(
                            session: session,
                            week: plan.currentWeek,
                            day: todayDayIdx,
                            sessionIdx: idx
                        )
                    }
                }
            }
        } else if data.trainingPlan == nil {
            noPlanCTA
        } else {
            emptyTodayCard
        }
    }

    @ViewBuilder
    private func sessionRow(session: PrescribedSession, week: Int, day: Int, sessionIdx: Int) -> some View {
        NavigationLink {
            PrescribedSessionDetailView(session: session, dateString: todayString())
        } label: {
            SessionCard(
                discipline: disciplineFor(session),
                effort: effortLabel(for: session),
                name: session.label,
                stats: statsFor(session),
                chips: chipsFor(session, week: week, day: day, sessionIdx: sessionIdx)
            )
        }
        .buttonStyle(.plain)
    }

    private func chipsFor(_ session: PrescribedSession, week: Int, day: Int, sessionIdx: Int) -> [SessionCard.ChipAction] {
        if let status = session.completionStatus {
            let title: String
            switch status {
            case .completed: title = "Did it · tap to undo"
            case .modified:  title = "Modified · tap to undo"
            case .swapped:   title = "Swapped · tap to undo"
            case .skipped:   title = "Skipped · tap to undo"
            }
            return [
                SessionCard.ChipAction(title: title, variant: .done) {
                    Task { try? await resetCompletion(week: week, day: day, sessionIdx: sessionIdx) }
                }
            ]
        }
        return [
            SessionCard.ChipAction(title: "Did it", variant: .done) {
                Task { try? await markDidIt(week: week, day: day, sessionIdx: sessionIdx) }
            },
            SessionCard.ChipAction(title: "Modified") {
                activeSheet = .modified(week: week, day: day, session: sessionIdx, prescribed: session)
            },
            SessionCard.ChipAction(title: "Swapped") {
                activeSheet = .swapped(
                    week: week,
                    day: day,
                    session: sessionIdx,
                    prescribed: session,
                    others: otherSessionsToday(week: week, day: day, exclude: sessionIdx)
                )
            },
            SessionCard.ChipAction(title: "Skipped") {
                activeSheet = .skipped(week: week, day: day, session: sessionIdx)
            },
        ]
    }

    private func disciplineFor(_ session: PrescribedSession) -> Theme.Discipline {
        if let sport = Sport(rawValue: session.type) { return sport.discipline }
        if session.type == "strength" { return .strength }
        return .recovery
    }

    private func effortLabel(for session: PrescribedSession) -> String? {
        if let e = session.effortCategory {
            return e.rawValue
                .replacingOccurrences(of: "_", with: " ")
                .capitalized
        }
        return session.zone
    }

    private func statsFor(_ session: PrescribedSession) -> [SessionCard.Stat] {
        var out: [SessionCard.Stat] = []
        if let dur = session.duration {
            out.append(.init(label: "Time", value: "\(dur)", unit: "m"))
        } else if let lo = session.estimatedDurationMin, let hi = session.estimatedDurationMax {
            out.append(.init(label: "Time", value: "\(lo)–\(hi)", unit: "m"))
        }
        if let zone = session.zone, !zone.isEmpty {
            out.append(.init(label: "Zone", value: zone.uppercased()))
        }
        if let pace = session.paceRange, !pace.isEmpty {
            out.append(.init(label: "Pace", value: pace))
        } else if let dist = session.distanceMiles {
            out.append(.init(label: "Distance", value: String(format: "%.1f", dist), unit: "mi"))
        } else if let target = session.targetIntensity, !target.isEmpty, out.count < 3 {
            out.append(.init(label: "Target", value: target))
        }
        return Array(out.prefix(3))
    }

    private func otherSessionsToday(week: Int, day: Int, exclude: Int) -> [PrescribedSession] {
        guard let plan = data.trainingPlan,
              let wp = plan.weeklyPlans[String(week)],
              day >= 0, day < wp.sessions.count else { return [] }
        return wp.sessions[day].sessions.enumerated().compactMap { idx, s in
            idx == exclude ? nil : s
        }
    }

    // MARK: - Rest / empty / no-plan states

    private func restCard(note: String?) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "leaf.fill")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Theme.Discipline.recovery.color)
                Text("REST · RECOVERY")
                    .font(Theme.Typography.monoLabel)
                    .foregroundStyle(Theme.Discipline.recovery.color)
                    .tracking(Theme.Tracking.monoLabel)
            }
            Text("Rest day")
                .font(Theme.Typography.sessionTitle)
                .foregroundStyle(Theme.ink)
            if let note, !note.isEmpty {
                Text(note)
                    .font(Theme.Typography.body)
                    .foregroundStyle(Theme.ink2)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(Theme.Spacing.cardP)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.surface1)
        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.card))
        .overlay(
            RoundedRectangle(cornerRadius: Theme.Radius.card)
                .strokeBorder(Theme.line, lineWidth: 1)
        )
    }

    private var emptyTodayCard: some View {
        Text("Nothing scheduled today.")
            .font(Theme.Typography.body)
            .foregroundStyle(Theme.ink3)
            .padding(Theme.Spacing.cardP)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.surface1)
            .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.card))
            .overlay(
                RoundedRectangle(cornerRadius: Theme.Radius.card)
                    .strokeBorder(Theme.line, lineWidth: 1)
            )
    }

    private var noPlanCTA: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("No training plan yet")
                .font(Theme.Typography.sessionTitle)
                .foregroundStyle(Theme.ink)
            Text("Create a plan to see today's session and weekly progress.")
                .font(Theme.Typography.body)
                .foregroundStyle(Theme.ink2)
            Pill(title: "Go to Plan", variant: .primary) {
                data.selectedTab = "plan"
            }
        }
        .padding(Theme.Spacing.cardP)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.surface1)
        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.card))
        .overlay(
            RoundedRectangle(cornerRadius: Theme.Radius.card)
                .strokeBorder(Theme.line, lineWidth: 1)
        )
    }

    // MARK: - This week

    @ViewBuilder
    private var thisWeekBlock: some View {
        if let plan = data.trainingPlan,
           let adherence = computeWeekAdherence(
            plan: plan,
            weekNum: plan.currentWeek,
            cardio: data.cardio,
            strength: data.strength
           ) {
            VStack(alignment: .leading, spacing: 12) {
                SectionHeader(
                    title: "This week",
                    meta: "Wk \(plan.currentWeek) / \(plan.totalWeeks)"
                )
                weekCard(adherence: adherence, plan: plan)
            }
        }
    }

    private func weekCard(adherence: WeekAdherence, plan: TrainingPlan) -> some View {
        let phase = plan.current
        return NavigationLink {
            WeekDetailView(initialWeekNum: plan.currentWeek)
        } label: {
            VStack(alignment: .leading, spacing: 14) {
                WeekOverviewHeader(
                    weekNumber: plan.currentWeek,
                    dateRange: weekRangeText(plan: plan),
                    phaseLabel: phase?.plainLanguageLabel,
                    weeksLeft: phase.map { plan.weeksLeftInPhase($0) }
                )

                // 7 day columns with icon stacks
                HStack(spacing: 4) {
                    ForEach(Array(adherence.days.enumerated()), id: \.offset) { idx, day in
                        weekDayColumn(day: day, letter: weekdayLetter(idx))
                    }
                }

                // Footer — sessions / adherence / missed
                HStack(alignment: .top, spacing: 16) {
                    weekFooterStat(label: "Sessions",  value: "\(adherence.completed) / \(adherence.prescribed)")
                    weekFooterStat(label: "Adherence", value: "\(adherence.adherence)%")
                    weekFooterStat(label: "Missed",    value: "\(adherence.missed)")
                }
                .padding(.top, 4)
            }
            .padding(Theme.Spacing.cardP)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.surface1)
            .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.card))
            .overlay(
                RoundedRectangle(cornerRadius: Theme.Radius.card)
                    .strokeBorder(Theme.line, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    private func weekdayLetter(_ idx: Int) -> String {
        let letters = ["M", "T", "W", "T", "F", "S", "S"]
        return idx >= 0 && idx < letters.count ? letters[idx] : "·"
    }

    private func weekDayColumn(day: DayReview, letter: String) -> some View {
        VStack(spacing: 6) {
            Text(letter)
                .font(Theme.Typography.monoLabel)
                .foregroundStyle(day.isToday ? Theme.accent : Theme.ink3)
                .textCase(.uppercase)
                .tracking(Theme.Tracking.monoLabel)

            VStack(spacing: 3) {
                if day.isRest {
                    Image(systemName: "moon.fill")
                        .font(.system(size: 14, weight: .regular))
                        .foregroundStyle(Theme.ink3)
                } else if day.sessions.isEmpty {
                    // Nothing scheduled (ungenerated day etc.) — small neutral dot
                    Circle()
                        .fill(Theme.line2)
                        .frame(width: 4, height: 4)
                        .padding(.vertical, 5)
                } else {
                    ForEach(Array(day.sessions.prefix(2).enumerated()), id: \.offset) { _, session in
                        sessionIcon(session: session)
                    }
                    if day.sessions.count > 2 {
                        Text("+\(day.sessions.count - 2)")
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundStyle(Theme.ink3)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity)
        .frame(minHeight: 64, alignment: .top)
        .padding(.vertical, 8)
        .background(
            day.isToday ? Theme.accentSoft : Color.clear,
            in: RoundedRectangle(cornerRadius: 10, style: .continuous)
        )
    }

    private func sessionIcon(session: SessionReview) -> some View {
        // For a swapped session, the icon should reflect what was *actually*
        // done rather than what was prescribed.
        let rawType: String = {
            if session.status == .substituted, let sub = session.substitute, !sub.isEmpty {
                return sub
            }
            return session.type
        }()
        let sport = Sport(rawValue: rawType)
        let symbol: String = {
            if let sport { return sport.sfSymbol }
            if rawType == "strength" { return "dumbbell.fill" }
            return "questionmark"
        }()
        let tint: Color = {
            switch session.status {
            case .completed:   return CoachColors.green
            case .shortened:   return CoachColors.yellow
            case .substituted: return Theme.info
            case .missed:      return Theme.warn
            case .today, .upcoming: return Theme.ink2
            }
        }()
        return Image(systemName: symbol)
            .font(.system(size: 14, weight: .regular))
            .foregroundStyle(tint)
            .frame(height: 14)
    }

    private func weekFooterStat(label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(label)
                .font(Theme.Typography.monoLabelS)
                .foregroundStyle(Theme.ink3)
                .textCase(.uppercase)
                .tracking(Theme.Tracking.monoLabel)
            Text(value)
                .font(Theme.Typography.mono(15, weight: .medium))
                .foregroundStyle(Theme.ink)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func weekRangeText(plan: TrainingPlan) -> String {
        guard let startStr = plan.startDate else { return "" }
        let inF = DateFormatter()
        inF.dateFormat = "yyyy-MM-dd"
        guard let planStart = inF.date(from: startStr) else { return "" }
        let cal = Calendar.current
        guard let monday = cal.date(byAdding: .day, value: (plan.currentWeek - 1) * 7, to: planStart),
              let sunday = cal.date(byAdding: .day, value: 6, to: monday) else { return "" }
        let outF = DateFormatter()
        outF.dateFormat = "MMM d"
        return "\(outF.string(from: monday)) — \(outF.string(from: sunday))"
    }

    // MARK: - Phase progress

    @ViewBuilder
    private var phaseProgressBlock: some View {
        if let plan = data.trainingPlan, let phase = plan.current {
            let weekInPhase = plan.weekIndexInPhase(phase)
            let progress = Double(weekInPhase) / Double(max(1, phase.weeks))
            NavigationLink {
                PhaseDetailView(plan: plan, phase: phase)
            } label: {
                PhaseProgressRow(
                    number: phase.number,
                    name: phase.name,
                    progress: min(1, progress),
                    caption: "Wk \(weekInPhase) of \(phase.weeks)",
                    isCurrent: true
                )
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Sheet dispatch

    @ViewBuilder
    private func sheetView(for sheet: ActiveSheet) -> some View {
        switch sheet {
        case .modified(let w, let d, let s, let pre):
            ModifiedCompletionSheet(session: pre) { actual in
                Task { try? await applyModified(actual, week: w, day: d, sessionIdx: s) }
            }
            .presentationDetents([.medium])

        case .swapped(let w, let d, let s, let pre, let others):
            SwappedCompletionSheet(session: pre, otherSessions: others) { actual in
                Task { try? await applySwapped(actual, week: w, day: d, sessionIdx: s) }
            }
            .presentationDetents([.medium, .large])

        case .skipped(let w, let d, let s):
            SkippedCompletionSheet { reason, note in
                Task { try? await applySkipped(reason: reason, note: note, week: w, day: d, sessionIdx: s) }
            }
            .presentationDetents([.height(340)])
        }
    }

    // MARK: - Completion mutations (preserved from legacy)

    private func markDidIt(week: Int, day: Int, sessionIdx: Int) async throws {
        try await data.updateSessionCompletion(weekNum: week, dayIdx: day, sessionIdx: sessionIdx) { s in
            s.completionStatus = .completed
            s.completed = true
            s.completionResolvedAt = ISO8601DateFormatter().string(from: Date())
            if s.actualDuration == nil { s.actualDuration = s.duration }
            if s.actualDistance == nil { s.actualDistance = s.distanceMiles }
        }
    }

    private func applyModified(_ actual: ModifiedActualInput, week: Int, day: Int, sessionIdx: Int) async throws {
        try await data.updateSessionCompletion(weekNum: week, dayIdx: day, sessionIdx: sessionIdx) { s in
            s.completionStatus = .modified
            s.completed = true
            s.actualDuration = actual.duration
            s.actualDistance = actual.distance
            s.completionNote = actual.note
            s.completionResolvedAt = ISO8601DateFormatter().string(from: Date())
        }
    }

    private func applySwapped(_ actual: SwappedActualInput, week: Int, day: Int, sessionIdx: Int) async throws {
        try await data.updateSessionCompletion(weekNum: week, dayIdx: day, sessionIdx: sessionIdx) { s in
            s.completionStatus = .swapped
            s.completed = true
            s.actualSport = actual.sport
            s.actualDuration = actual.duration
            s.completionNote = actual.note
            s.completionResolvedAt = ISO8601DateFormatter().string(from: Date())
        }
    }

    private func applySkipped(reason: SkipReason, note: String, week: Int, day: Int, sessionIdx: Int) async throws {
        try await data.updateSessionCompletion(weekNum: week, dayIdx: day, sessionIdx: sessionIdx) { s in
            s.completionStatus = .skipped
            s.completed = false
            s.skipReason = reason
            s.completionNote = note
            s.completionResolvedAt = ISO8601DateFormatter().string(from: Date())
        }
    }

    private func resetCompletion(week: Int, day: Int, sessionIdx: Int) async throws {
        try await data.updateSessionCompletion(weekNum: week, dayIdx: day, sessionIdx: sessionIdx) { s in
            s.completionStatus = nil
            s.completed = nil
            s.actualDuration = nil
            s.actualDistance = nil
            s.actualSport = nil
            s.skipReason = nil
            s.completionNote = nil
            s.completionResolvedAt = nil
        }
    }
}
