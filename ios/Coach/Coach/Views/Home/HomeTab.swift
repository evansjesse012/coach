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

    /// Session + status for the post-status chat sheet. Identifiable so
    /// `.sheet(item:)` can drive presentation directly off this state.
    struct PostStatusContext: Identifiable {
        let id = UUID()
        let sessionLabel: String
        let status: Theme.SessionStatusKind
        let weekNum: Int
        let dayIdx: Int
        let sessionIdx: Int
    }

    @State private var postStatusSheet: PostStatusContext?

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
            .sheet(item: $postStatusSheet) { ctx in
                PostStatusChatSheet(
                    sessionLabel: ctx.sessionLabel,
                    status: ctx.status,
                    weekNum: ctx.weekNum,
                    dayIdx: ctx.dayIdx,
                    sessionIdx: ctx.sessionIdx
                )
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
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
        let menu = SessionStatusMenu(
            sessionLabel: session.label,
            currentStatus: session.statusKind,
            onDone:     { Task { await commitStatus(.done,     week: week, day: day, sessionIdx: sessionIdx, label: session.label) } },
            onModified: { Task { await commitStatus(.modified, week: week, day: day, sessionIdx: sessionIdx, label: session.label) } },
            onSwapped:  { Task { await commitStatus(.swapped,  week: week, day: day, sessionIdx: sessionIdx, label: session.label) } },
            onSkipped:  { Task { await commitStatus(.skipped,  week: week, day: day, sessionIdx: sessionIdx, label: session.label) } },
            onEdit: {
                path.append(TodayRoute.sessionDetail(
                    weekNum: week, dayIdx: day, sessionIdx: sessionIdx, preselected: nil
                ))
            },
            onClear: { Task { await clearStatus(week: week, day: day, sessionIdx: sessionIdx, label: session.label) } }
        )

        SessionCard(
            discipline: disciplineFor(session),
            effort: effortLabel(for: session),
            name: session.label,
            stats: statsFor(session),
            status: session.sessionCardStatus,
            trailingAction: AnyView(menu),
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
            VStack(alignment: .leading, spacing: 16) {
                WeekOverviewHeader(
                    weekNumber: plan.currentWeek,
                    dateRange: weekRangeText(plan: plan),
                    phaseLabel: phase?.plainLanguageLabel,
                    weeksLeft: phase.map { plan.weeksLeftInPhase($0) }
                )

                // 7 tinted day cells — canonical status colors from
                // Theme.SessionStatusKind, today gets the dark-fill emphasis.
                HStack(spacing: 6) {
                    ForEach(Array(adherence.days.enumerated()), id: \.offset) { idx, day in
                        WeekStripCell(
                            letter: weekdayLetter(idx),
                            isToday: day.isToday,
                            state: weekStripState(for: day),
                            glyphs: weekStripGlyphs(for: day)
                        )
                    }
                }

                Hairline()

                // Footer — sessions / adherence
                HStack(alignment: .top, spacing: 16) {
                    weekFooterStat(label: "Sessions",  value: "\(adherence.completed) / \(adherence.prescribed)")
                    weekFooterStat(label: "Adherence", value: "\(adherence.adherence)%")
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
        .buttonStyle(.plain)
    }

    private func weekdayLetter(_ idx: Int) -> String {
        let letters = ["M", "T", "W", "T", "F", "S", "S"]
        return idx >= 0 && idx < letters.count ? letters[idx] : "·"
    }

    /// Session status resolved to a strip-cell state. Multi-session days
    /// use this precedence: skipped > modified/swapped > done > pending.
    /// "Today" is NOT folded in here — that's handled by `isToday` on
    /// `WeekStripCell` so today's visual override remains explicit.
    private func weekStripState(for day: DayReview) -> WeekStripCellState {
        if day.isRest { return .rest }
        if day.sessions.isEmpty { return .upcoming }

        let statuses = day.sessions.map { $0.status }
        if statuses.contains(.missed) { return .resolved(.skipped) }
        if statuses.contains(.shortened) || statuses.contains(.substituted) {
            return .resolved(.modified)
        }
        if !statuses.isEmpty, statuses.allSatisfy({ $0 == .completed }) {
            return .resolved(.done)
        }
        return .upcoming
    }

    /// One glyph per session on the day, in prescribed order. Swapped
    /// sessions render the substitute sport so the cell reflects what
    /// was actually done. Rest days return a single moon glyph; empty
    /// days return a dotted placeholder.
    private func weekStripGlyphs(for day: DayReview) -> [WeekStripCell.Glyph] {
        if day.isRest {
            return [.init(symbolName: "moon.fill", naturalColor: Theme.ink3)]
        }
        if day.sessions.isEmpty {
            return [.init(symbolName: "circle.dotted", naturalColor: Theme.ink3)]
        }
        return day.sessions.map { session in
            let rawType: String = {
                if session.status == .substituted, let sub = session.substitute, !sub.isEmpty {
                    return sub
                }
                return session.type
            }()
            return WeekStripCell.Glyph(
                symbolName: symbolName(for: rawType),
                naturalColor: disciplineColor(for: rawType)
            )
        }
    }

    private func symbolName(for type: String) -> String {
        if let sport = Sport(rawValue: type) { return sport.sfSymbol }
        if type == "strength" { return "dumbbell.fill" }
        return "circle.dotted"
    }

    private func disciplineColor(for type: String) -> Color {
        if let sport = Sport(rawValue: type) { return sport.discipline.color }
        if type == "strength" { return Theme.Discipline.strength.color }
        return Theme.ink3
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
        weekRangeLabel(planStartDate: plan.startDate, weekNumber: plan.currentWeek) ?? ""
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

    /// Shared write path for every status tap from the compact menu.
    /// Commits the status, fires the undo toast, and — for non-Done
    /// statuses — opens the post-status chat sheet so the athlete can
    /// jot what changed. Done skips the sheet ("done is done").
    @MainActor
    private func commitStatus(
        _ kind: Theme.SessionStatusKind,
        week: Int, day: Int, sessionIdx: Int, label: String
    ) async {
        guard let before = snapshotSession(week: week, day: day, sessionIdx: sessionIdx) else { return }
        do {
            try await data.updateSessionCompletion(
                weekNum: week, dayIdx: day, sessionIdx: sessionIdx
            ) { s in
                let iso = ISO8601DateFormatter().string(from: Date())
                switch kind {
                case .done:
                    s.completionStatus = .completed
                    s.completed = true
                    s.completionResolvedAt = iso
                    if s.actualDuration == nil { s.actualDuration = s.duration }
                    if s.actualDistance == nil { s.actualDistance = s.distanceMiles }
                case .modified:
                    s.completionStatus = .modified
                    s.completed = true
                    s.completionResolvedAt = iso
                case .swapped:
                    s.completionStatus = .swapped
                    s.completed = true
                    s.completionResolvedAt = iso
                case .skipped:
                    s.completionStatus = .skipped
                    s.completed = false
                    s.completionResolvedAt = iso
                case .pending:
                    // `.pending` isn't offered in the menu — use clearStatus.
                    return
                }
            }
            presentUndoToast(
                message: "Marked as \(kind.label)",
                week: week, day: day, sessionIdx: sessionIdx, snapshot: before
            )
            // Every status opens the check-in sheet — a good coach asks
            // "how did it go?" on a done session as much as "what got in
            // the way?" on a skipped one. Skip in the sheet is one tap.
            postStatusSheet = PostStatusContext(
                sessionLabel: label,
                status: kind,
                weekNum: week, dayIdx: day, sessionIdx: sessionIdx
            )
        } catch {
            print("commitStatus failed (\(kind) week \(week) day \(day) idx \(sessionIdx)): \(error)")
        }
    }

    /// Unmark a session — "Clear status" menu item. Wipes every logged
    /// field so the session returns to Not-yet.
    @MainActor
    private func clearStatus(week: Int, day: Int, sessionIdx: Int, label: String) async {
        guard let before = snapshotSession(week: week, day: day, sessionIdx: sessionIdx) else { return }
        do {
            try await data.updateSessionCompletion(
                weekNum: week, dayIdx: day, sessionIdx: sessionIdx
            ) { s in
                s.completionStatus = nil
                s.completed = nil
                s.actualDuration = nil
                s.actualDistance = nil
                s.actualSport = nil
                s.actualEffort = nil
                s.replacedWithLabel = nil
                s.skipReason = nil
                s.completionNote = nil
                s.completionResolvedAt = nil
            }
            presentUndoToast(
                message: "Cleared",
                week: week, day: day, sessionIdx: sessionIdx, snapshot: before
            )
        } catch {
            print("clearStatus failed (week \(week) day \(day) idx \(sessionIdx)): \(error)")
        }
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

// MARK: - Session status menu

/// Compact ellipsis button on a session card that opens a native iOS
/// `Menu` with the five status actions. Used by both Home's Today and
/// the Week Detail list so the session-status UX is uniform across
/// every surface: tap body → detail; tap ellipsis → menu → commit.
///
/// Single-tap commit inside the menu (no two-tap confirm) — opening
/// the menu is already a deliberate gesture, and the 5s undo toast
/// handles misfires.
struct SessionStatusMenu: View {
    let sessionLabel: String
    let currentStatus: Theme.SessionStatusKind
    let onDone: () -> Void
    let onModified: () -> Void
    let onSwapped: () -> Void
    let onSkipped: () -> Void
    let onEdit: () -> Void
    let onClear: () -> Void

    var body: some View {
        Menu {
            Button(action: onDone)     { Label("Mark done",     systemImage: Theme.SessionStatusKind.done.icon) }
            Button(action: onModified) { Label("Mark modified", systemImage: Theme.SessionStatusKind.modified.icon) }
            Button(action: onSwapped)  { Label("Mark swapped",  systemImage: Theme.SessionStatusKind.swapped.icon) }
            Button(role: .destructive, action: onSkipped) { Label("Mark skipped", systemImage: Theme.SessionStatusKind.skipped.icon) }
            if currentStatus != .pending {
                Divider()
                Button(role: .destructive, action: onClear) {
                    Label("Clear status", systemImage: "arrow.uturn.backward")
                }
            }
            Divider()
            Button(action: onEdit) {
                Label("Edit details", systemImage: "square.and.pencil")
            }
        } label: {
            Image(systemName: "ellipsis")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Theme.ink2)
                .frame(width: 28, height: 28)
                .background(Circle().strokeBorder(Theme.line, lineWidth: 1))
                .contentShape(Circle())
        }
        .menuStyle(.button)
        .accessibilityLabel("Session actions for \(sessionLabel)")
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

