import SwiftUI

struct HomeTab: View {
    @Environment(DataService.self) private var data
    @State private var path = NavigationPath()
    @State private var showSettings = false
    @State private var undoToast: UndoToast?

    /// Programmatic routes pushed from Today. Closure-style NavigationLinks
    /// (week card, phase progress) continue to push onto the same stack;
    /// the `.id(UUID())` rebuild in `popsOnTabReselect` still tears them
    /// down on tab re-select.
    enum TodayRoute: Hashable {
        case sessionDetail(weekNum: Int, dayIdx: Int, sessionIdx: Int, preselected: Theme.SessionStatusKind?)
    }

    /// Ephemeral undo for a quick-logged completion. Persists for ~5s
    /// after commit, then fades. The `snapshot` captures the pre-mutation
    /// session so Undo can restore it verbatim.
    struct UndoToast: Identifiable {
        let id = UUID()
        let message: String
        let weekNum: Int
        let dayIdx: Int
        let sessionIdx: Int
        let snapshot: PrescribedSession
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
            }
            .clearsTabBar()
            .background(Theme.bg.ignoresSafeArea())
            .scrollContentBackground(.hidden)
            .navigationDestination(for: TodayRoute.self) { route in
                destinationView(for: route)
            }
            .sheet(isPresented: $showSettings) {
                NavigationStack { SettingsView() }
            }
            .overlay(alignment: .bottom) {
                if let toast = undoToast {
                    UndoToastBanner(toast: toast) {
                        Task { await undoToastAction(toast) }
                    }
                    .padding(.horizontal, Theme.Spacing.screenH)
                    .padding(.bottom, Theme.Spacing.bottomReserve + 12)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .animation(.spring(duration: 0.28), value: undoToast?.id)
        }
        .popsOnTabReselect(tabId: "today", path: $path)
    }

    @ViewBuilder
    private func destinationView(for route: TodayRoute) -> some View {
        switch route {
        case .sessionDetail(let week, let day, let idx, let pre):
            if let plan = data.trainingPlan,
               let wp = plan.weeklyPlans[String(week)],
               day >= 0, day < wp.sessions.count,
               idx >= 0, idx < wp.sessions[day].sessions.count {
                SessionDetailView(
                    session: wp.sessions[day].sessions[idx],
                    dateString: sessionDateString(
                        planStartDate: plan.startDate,
                        weekNumber: week,
                        dayIdx: day
                    ),
                    weekNum: week,
                    dayIdx: day,
                    sessionIdx: idx,
                    preselectedStatus: pre
                )
            }
        }
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
        let footerRow = TodayQuickLogRow(
            session: session,
            onDone: { Task { await markDidIt(week: week, day: day, sessionIdx: sessionIdx) } },
            onSkip: { Task { await markSkipped(week: week, day: day, sessionIdx: sessionIdx) } },
            onModified: {
                path.append(TodayRoute.sessionDetail(
                    weekNum: week, dayIdx: day, sessionIdx: sessionIdx, preselected: .modified
                ))
            },
            onSwapped: {
                path.append(TodayRoute.sessionDetail(
                    weekNum: week, dayIdx: day, sessionIdx: sessionIdx, preselected: .swapped
                ))
            },
            onEdit: {
                path.append(TodayRoute.sessionDetail(
                    weekNum: week, dayIdx: day, sessionIdx: sessionIdx, preselected: nil
                ))
            }
        )

        SessionCard(
            discipline: disciplineFor(session),
            effort: effortLabel(for: session),
            name: session.label,
            stats: statsFor(session),
            status: session.sessionCardStatus,
            footer: AnyView(footerRow),
            onTap: {
                path.append(TodayRoute.sessionDetail(
                    weekNum: week, dayIdx: day, sessionIdx: sessionIdx, preselected: nil
                ))
            }
        )
    }

    // Session status mapping lives on PrescribedSession.sessionCardStatus
    // (see SessionCard.swift) so Home Today and Week Detail render the
    // same strip content from a single source of truth.

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
                .foregroundStyle(day.isToday ? Theme.accentInk : Theme.ink3)
                .textCase(.uppercase)
                .tracking(Theme.Tracking.monoLabel)
                .padding(.horizontal, 7)
                .padding(.vertical, 3)
                .background(
                    Capsule().fill(day.isToday ? Theme.accent : Color.clear)
                )

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
        // Map the adherence `SessionStatus` onto canonical
        // `Theme.SessionStatusKind` tints so this row reads the same as
        // Today pills, status strips, and SessionDetail badges.
        let tint: Color = {
            switch session.status {
            case .completed:        return Theme.SessionStatusKind.done.tint
            case .shortened:        return Theme.SessionStatusKind.modified.tint
            case .substituted:      return Theme.SessionStatusKind.swapped.tint
            case .missed:           return Theme.SessionStatusKind.skipped.tint
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

    // MARK: - Completion mutations (quick-log path)
    //
    // Quick-log confirmations (Done / Skipped) commit inline, snapshot the
    // pre-mutation session, and surface an UndoToast for ~5s so a misfire is
    // recoverable with one tap. Modified / Swapped don't come through here —
    // they push SessionDetailView via the `path` and commit from there.

    @MainActor
    private func markDidIt(week: Int, day: Int, sessionIdx: Int) async {
        guard let before = snapshotSession(week: week, day: day, sessionIdx: sessionIdx) else { return }
        do {
            try await data.updateSessionCompletion(weekNum: week, dayIdx: day, sessionIdx: sessionIdx) { s in
                s.completionStatus = .completed
                s.completed = true
                s.completionResolvedAt = ISO8601DateFormatter().string(from: Date())
                if s.actualDuration == nil { s.actualDuration = s.duration }
                if s.actualDistance == nil { s.actualDistance = s.distanceMiles }
            }
            presentUndoToast(message: "Marked as Done", week: week, day: day, sessionIdx: sessionIdx, snapshot: before)
        } catch {
            // Guarded paths (e.g. future-dated session) throw — silently drop;
            // the UI already prevents those taps via `canQuickLog`.
        }
    }

    @MainActor
    private func markSkipped(week: Int, day: Int, sessionIdx: Int) async {
        guard let before = snapshotSession(week: week, day: day, sessionIdx: sessionIdx) else { return }
        do {
            try await data.updateSessionCompletion(weekNum: week, dayIdx: day, sessionIdx: sessionIdx) { s in
                s.completionStatus = .skipped
                s.completed = false
                s.completionResolvedAt = ISO8601DateFormatter().string(from: Date())
            }
            presentUndoToast(message: "Marked as Skipped", week: week, day: day, sessionIdx: sessionIdx, snapshot: before)
        } catch { }
    }

    private func snapshotSession(week: Int, day: Int, sessionIdx: Int) -> PrescribedSession? {
        guard let plan = data.trainingPlan,
              let wp = plan.weeklyPlans[String(week)],
              day >= 0, day < wp.sessions.count,
              sessionIdx >= 0, sessionIdx < wp.sessions[day].sessions.count else {
            return nil
        }
        return wp.sessions[day].sessions[sessionIdx]
    }

    // MARK: - Undo toast

    private func presentUndoToast(message: String, week: Int, day: Int, sessionIdx: Int, snapshot: PrescribedSession) {
        let toast = UndoToast(
            message: message, weekNum: week, dayIdx: day, sessionIdx: sessionIdx, snapshot: snapshot
        )
        undoToast = toast
        // Auto-dismiss after 5s, unless a newer toast has replaced this one.
        Task { [toastId = toast.id] in
            try? await Task.sleep(nanoseconds: 5_000_000_000)
            if undoToast?.id == toastId {
                undoToast = nil
            }
        }
    }

    @MainActor
    private func undoToastAction(_ toast: UndoToast) async {
        // Revert the mutation by writing the snapshotted session verbatim.
        try? await data.updateSessionCompletion(
            weekNum: toast.weekNum, dayIdx: toast.dayIdx, sessionIdx: toast.sessionIdx
        ) { s in
            s = toast.snapshot
        }
        undoToast = nil
    }
}

// MARK: - Today quick-log row (pending pills / Edit link)

/// Footer row rendered inside the Home Today `SessionCard`. For pending
/// sessions it shows four 2-tap-confirm / one-tap pills (Done, Modified,
/// Swapped, Skipped) using canonical `Theme.SessionStatusKind` colors.
/// For a session already marked done / modified / swapped / skipped it
/// collapses to a single "Edit" link — the SessionCard's status strip
/// at the top already signals the state.
private struct TodayQuickLogRow: View {
    let session: PrescribedSession
    let onDone: () -> Void
    let onSkip: () -> Void
    let onModified: () -> Void
    let onSwapped: () -> Void
    let onEdit: () -> Void

    /// Which pill is currently armed (awaiting a second tap). Local state —
    /// tapping a second pill disarms the first without any cross-row coupling.
    @State private var armed: Theme.SessionStatusKind?
    @State private var armTimer: Task<Void, Never>?

    var body: some View {
        if session.completionStatus != nil {
            editRow
        } else {
            // The Today tab only renders today's sessions, so the
            // "no future marks" guard in DataService never trips here —
            // the pill row is always live.
            pillsRow
        }
    }

    private var pillsRow: some View {
        HStack(spacing: 8) {
            TodayStatusPill(
                kind: .done,
                isArmed: armed == .done,
                action: { handleTap(.done) }
            )
            TodayStatusPill(
                kind: .modified,
                isArmed: false,
                action: onModified
            )
            TodayStatusPill(
                kind: .swapped,
                isArmed: false,
                action: onSwapped
            )
            TodayStatusPill(
                kind: .skipped,
                isArmed: armed == .skipped,
                action: { handleTap(.skipped) }
            )
            Spacer(minLength: 0)
        }
    }

    private var editRow: some View {
        HStack(spacing: 6) {
            Spacer(minLength: 0)
            Button(action: onEdit) {
                HStack(spacing: 4) {
                    Text("Edit")
                        .font(.system(size: 13, weight: .medium))
                    Image(systemName: "chevron.right")
                        .font(.system(size: 10, weight: .semibold))
                }
                .foregroundStyle(Theme.ink2)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Theme.surface2, in: Capsule())
            }
            .buttonStyle(.plain)
        }
    }

    private func handleTap(_ kind: Theme.SessionStatusKind) {
        guard kind == .done || kind == .skipped else { return }
        if armed == kind {
            // Second tap — commit.
            armed = nil
            armTimer?.cancel()
            armTimer = nil
            switch kind {
            case .done: onDone()
            case .skipped: onSkip()
            default: break
            }
        } else {
            // First tap — arm and start a 4s auto-disarm timer.
            armed = kind
            armTimer?.cancel()
            armTimer = Task { [kind] in
                try? await Task.sleep(nanoseconds: 4_000_000_000)
                await MainActor.run {
                    if self.armed == kind { self.armed = nil }
                }
            }
        }
    }

}

/// One of four Today quick-log pills (Done / Modified / Swapped / Skipped).
/// Colors come from `Theme.SessionStatusKind` — the canonical source —
/// so the pill row is visually aligned with the status strip, badges, and
/// SessionDetailView's status picker. An armed pill (Done / Skipped only)
/// inverts to a filled treatment with a "Tap to confirm" label.
private struct TodayStatusPill: View {
    let kind: Theme.SessionStatusKind
    let isArmed: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Image(systemName: kind.icon)
                    .font(.system(size: 11, weight: .semibold))
                Text(isArmed ? "Confirm?" : kind.label)
                    .font(.system(size: 12, weight: .medium))
            }
            .foregroundStyle(isArmed ? Color.white : kind.tint)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(isArmed ? kind.tint : kind.fill)
            .overlay(
                Capsule().strokeBorder(kind.tint.opacity(isArmed ? 0 : 0.5), lineWidth: 1)
            )
            .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Undo toast banner

private struct UndoToastBanner: View {
    let toast: HomeTab.UndoToast
    let onUndo: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Text(toast.message)
                .font(Theme.Typography.bodyS)
                .foregroundStyle(Theme.ink)
            Spacer(minLength: 8)
            Button(action: onUndo) {
                Text("Undo")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Theme.accent)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Theme.accentSoft, in: Capsule())
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(Theme.surface1)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .strokeBorder(Theme.line, lineWidth: 1)
        )
        .dsCardShadow()
    }
}
