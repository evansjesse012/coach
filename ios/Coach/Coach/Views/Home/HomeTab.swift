import SwiftUI

struct HomeTab: View {
    @Environment(DataService.self) private var data
    @State private var path = NavigationPath()
    @State private var showSettings = false
    @State private var undoToast: UndoToast?

    /// Programmatic routes pushed from Today. Closure-style NavigationLinks
    /// (phase progress) continue to push onto the same stack; the
    /// `.id(UUID())` rebuild in `popsOnTabReselect` still tears them down
    /// on tab re-select.
    enum TodayRoute: Hashable {
        case sessionDetail(weekNum: Int, dayIdx: Int, sessionIdx: Int, preselected: Theme.SessionStatusKind?)
        /// Pushed from a week-strip cell on rest / empty / multi-session
        /// days, where there's no single session to drill into.
        case weekDetail(weekNum: Int)
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
    @State private var watchMatchSheet: PendingWatchMatch?
    @State private var weeklyArtifactSheet: WeeklyArtifactView.Source?

    var body: some View {
        NavigationStack(path: $path) {
            ScrollView {
                VStack(alignment: .leading, spacing: Theme.Spacing.section) {
                    headerBlock
                    todayHeaderBlocks
                    watchMatchBannerBlock
                    thisWeekBlock
                    todayBlock
                    upcomingDaysBlock
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
            .sheet(item: $weeklyArtifactSheet) { source in
                WeeklyArtifactSheet(source: source)
                    .presentationDetents([.large])
                    .presentationDragIndicator(.visible)
            }
            .sheet(item: $watchMatchSheet) { match in
                WatchMatchConfirmSheet(
                    match: match,
                    onConfirm: { kind in
                        Task { await confirmMatchAndChain(match, status: kind) }
                    },
                    onDismiss: {
                        data.dismissPendingMatch(match)
                    }
                )
                .presentationDetents([.large])
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
        case .weekDetail(let week):
            WeekDetailView(initialWeekNum: week)
        }
    }

    // MARK: - Watch match banner

    /// Inline banner above the daily brief when one or more HealthKit
    /// matches are pending the athlete's confirmation. Tapping opens
    /// `WatchMatchConfirmSheet` for the oldest pending match; once
    /// confirmed/dismissed, the next pending match's banner appears.
    @ViewBuilder
    private var watchMatchBannerBlock: some View {
        if let next = data.pendingWatchMatches.first {
            WatchMatchBanner(
                match: next,
                totalCount: data.pendingWatchMatches.count,
                onTap: { watchMatchSheet = next }
            )
        }
    }

    /// Commits a pending watch match. For modified / swapped / skipped,
    /// chains into the post-status chat sheet so the coach can ask
    /// follow-ups about what changed. Done is silent — the match
    /// applies and the banner clears.
    @MainActor
    private func confirmMatchAndChain(_ match: PendingWatchMatch, status: Theme.SessionStatusKind) async {
        let completion: CompletionStatus = {
            switch status {
            case .done:     return .completed
            case .modified: return .modified
            case .swapped:  return .swapped
            case .skipped:  return .skipped
            case .pending:  return .completed
            }
        }()
        await data.confirmPendingMatch(match, status: completion)
        if status != .done {
            postStatusSheet = PostStatusContext(
                sessionLabel: match.session.label,
                status: status,
                weekNum: match.coords.weekNum,
                dayIdx: match.coords.dayIdx,
                sessionIdx: match.coords.sessionIdx
            )
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

    // MARK: - Today header (race + phase cards)
    //
    // Two stacked cards at the top of the page — race on top, current
    // training phase below. Both share `RaceCard` / `TrainingPhaseCard`'s
    // matched chrome (surface1 fill, 1pt line border, rounded corners),
    // so the pair reads as a unit. Each is its own NavigationLink target.

    @ViewBuilder
    private var todayHeaderBlocks: some View {
        if let plan = data.trainingPlan {
            VStack(alignment: .leading, spacing: 16) {
                raceHeaderBlock(plan: plan)
                phaseHeaderBlock(plan: plan)
            }
        }
    }

    /// Race card built from the plan's linked Event when present (so we
    /// get location), falling back to plan-level fields. The card itself
    /// wires the navigation to `RaceDetailView` when an event id is
    /// available; renders flat when there is no event link yet.
    @ViewBuilder
    private func raceHeaderBlock(plan: TrainingPlan) -> some View {
        let raceEvent = linkedRaceEvent(plan: plan)

        // Source of truth: prefer the linked Event, then plan-level fields.
        let raceName = raceEvent?.name
            ?? plan.raceName?.trimmingCharacters(in: .whitespacesAndNewlines)
        let dateStr  = raceEvent?.date ?? plan.raceDate
        let location = raceEvent?.location

        if let raceName, !raceName.isEmpty,
           let dateStr, !dateStr.isEmpty {
            let (count, unit) = countdownParts(dateStr)
            RaceCard(
                raceName: raceName,
                location: location,
                dateString: formattedRaceDate(dateStr),
                count: count,
                unit: unit,
                kicker: "Training for",
                eventId: raceEvent?.id
            )
        }
    }

    /// Phase card showing the current phase's plain-language description
    /// and weeks remaining. Tapping pushes `PhaseDetailView` for the
    /// current phase.
    @ViewBuilder
    private func phaseHeaderBlock(plan: TrainingPlan) -> some View {
        if let phase = plan.current {
            TrainingPhaseCard(
                plan: plan,
                phase: phase,
                phaseDescription: phase.plainLanguageLabel,
                weeksLeft: plan.weeksLeftInPhase(phase)
            )
        }
    }

    /// Resolves the Event row that backs the plan's race, if any.
    /// Plans store `goalId` referencing the user's events table.
    private func linkedRaceEvent(plan: TrainingPlan) -> Event? {
        guard let goalId = plan.goalId, !goalId.isEmpty else { return nil }
        return data.events.first(where: { $0.id == goalId })
    }

    private func countdownParts(_ dateStr: String) -> (Int, String) {
        let days = daysUntil(dateStr) ?? 0
        if days <= 0 { return (0, "Today") }
        if days <= 30 { return (days, days == 1 ? "Day out" : "Days out") }
        let weeks = days / 7
        return (weeks, weeks == 1 ? "Week out" : "Weeks out")
    }

    private func formattedRaceDate(_ dateStr: String) -> String {
        let inF = DateFormatter()
        inF.dateFormat = "yyyy-MM-dd"
        guard let d = inF.date(from: dateStr) else { return dateStr }
        let outF = DateFormatter()
        outF.dateFormat = "EEE · MMM d · yyyy"
        return outF.string(from: d)
    }

    // MARK: - Today

    @ViewBuilder
    private var todayBlock: some View {
        VStack(alignment: .leading, spacing: 12) {
            daySectionHeader(dayIdx: todayDayIdx, meta: todaySectionMeta)
            todayContent
        }
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

    // MARK: - Upcoming days (rest of the week)
    //
    // Renders one day-section per remaining weekday (today + 1 … Sun) so
    // the week's plan is visible at a glance. Past days drop off entirely
    // — today stays put with all of its sessions (completed or not), and
    // when Mon flips to Tue, Mon's section disappears from Home.

    @ViewBuilder
    private var upcomingDaysBlock: some View {
        if let plan = data.trainingPlan,
           let wp = plan.weeklyPlans[String(plan.currentWeek)],
           !wp.sessions.isEmpty,
           todayDayIdx + 1 <= 6 {
            VStack(alignment: .leading, spacing: Theme.Spacing.section) {
                ForEach(((todayDayIdx + 1)...6), id: \.self) { dayIdx in
                    if dayIdx < wp.sessions.count {
                        upcomingDaySection(
                            plan: plan,
                            dp: wp.sessions[dayIdx],
                            dayIdx: dayIdx
                        )
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func upcomingDaySection(plan: TrainingPlan, dp: DayPlan, dayIdx: Int) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            daySectionHeader(dayIdx: dayIdx, meta: upcomingDayMeta(dp))
            upcomingDayContent(plan: plan, dp: dp, dayIdx: dayIdx)
        }
    }

    /// Shared header used by today + each upcoming day. The big label is
    /// a relative-distance phrase ("Today" / "Tomorrow" / "In two days"…)
    /// in the primary heading style; the weekday + date sit alongside it
    /// in the small mono-label style, matching the meta count on the right.
    @ViewBuilder
    private func daySectionHeader(dayIdx: Int, meta: String?) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text(relativeDayLabel(for: dayIdx))
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(Theme.ink)
            Text(weekdayDateLabel(for: dayIdx))
                .font(Theme.Typography.monoLabel)
                .foregroundStyle(Theme.ink3)
                .textCase(.uppercase)
                .tracking(Theme.Tracking.monoLabel)
            Spacer(minLength: 8)
            if let meta {
                Text(meta)
                    .font(Theme.Typography.monoLabel)
                    .foregroundStyle(Theme.ink3)
                    .textCase(.uppercase)
                    .tracking(Theme.Tracking.monoLabel)
            }
        }
    }

    @ViewBuilder
    private func upcomingDayContent(plan: TrainingPlan, dp: DayPlan, dayIdx: Int) -> some View {
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
                        day: dayIdx,
                        sessionIdx: idx
                    )
                }
            }
        }
    }

    private func upcomingDayMeta(_ dp: DayPlan) -> String? {
        if dp.isRest == true { return "Rest day" }
        let n = dp.sessions.count
        return n == 0 ? nil : "\(n) of \(n)"
    }

    /// Big-heading label for a day-section: how far away the day is in
    /// plain language. Falls back to the weekday name for any unexpected
    /// out-of-range index.
    private func relativeDayLabel(for dayIdx: Int) -> String {
        switch dayIdx - todayDayIdx {
        case 0: return "Today"
        case 1: return "Tomorrow"
        case 2: return "In two days"
        case 3: return "In three days"
        case 4: return "In four days"
        case 5: return "In five days"
        case 6: return "In six days"
        default:
            let f = DateFormatter()
            f.dateFormat = "EEEE"
            return f.string(from: dateForDay(dayIdx))
        }
    }

    /// Sub-label rendered in the smaller mono style: weekday + short date,
    /// e.g. "Tuesday · Apr 28" (uppercased by the surrounding modifier).
    private func weekdayDateLabel(for dayIdx: Int) -> String {
        let f = DateFormatter()
        f.dateFormat = "EEEE · MMM d"
        return f.string(from: dateForDay(dayIdx))
    }

    private func dateForDay(_ dayIdx: Int) -> Date {
        let delta = dayIdx - todayDayIdx
        return Calendar.current.date(byAdding: .day, value: delta, to: Date()) ?? Date()
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
    //
    // The card is purely visual — only the cells inside it are
    // interactive (they push session detail or week detail). The
    // section header above the card is a separate tap target that
    // switches to the Plan tab. The previous version's adherence /
    // sessions footer was removed in this update; those metrics live
    // on the Stats tab now.

    @ViewBuilder
    private var thisWeekBlock: some View {
        if let plan = data.trainingPlan,
           let adherence = computeWeekAdherence(
            plan: plan,
            weekNum: plan.currentWeek,
            cardio: data.cardio,
            strength: data.strength
           ) {
            VStack(alignment: .leading, spacing: 10) {
                weekSectionHeader(plan: plan)
                weeklyPreviewThemeLine
                weekStripCard(plan: plan, adherence: adherence)
            }
        }
    }

    /// Single-line theme line surfaced from the active week's preview
    /// (PR 1.5). Tappable to open the full preview sheet. Renders nothing
    /// when no preview exists for the current week — the rest of the
    /// "This week" block stands alone.
    @ViewBuilder
    private var weeklyPreviewThemeLine: some View {
        if let preview = data.activeWeekPreview {
            Button {
                weeklyArtifactSheet = .preview(preview)
            } label: {
                HStack(alignment: .top, spacing: 8) {
                    Text(preview.theme)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Theme.accent)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                    Spacer(minLength: 4)
                    Image(systemName: "chevron.right")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(Theme.accent.opacity(0.7))
                        .padding(.top, 2)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Theme.accent.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("This week's theme: \(preview.theme). Open full preview.")
        }
    }

    /// Two-part row above the card — left "THIS WEEK ›" tappable kicker
    /// switches to the Plan tab; right is the Mon–Sun date range.
    private func weekSectionHeader(plan: TrainingPlan) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Button {
                data.selectedTab = "plan"
            } label: {
                HStack(spacing: 5) {
                    Text("This week")
                        .font(.system(size: 9, weight: .semibold, design: .monospaced))
                        .textCase(.uppercase)
                        .tracking(0.18 * 9) // 0.18em on 9pt
                        .foregroundStyle(Theme.ink3)
                    Image(systemName: "chevron.right")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(Theme.ink3)
                }
            }
            .buttonStyle(.plain)
            .accessibilityLabel("This week, view full plan")

            Spacer(minLength: 8)

            Text(weekRangeShortText(plan: plan))
                .font(.system(size: 10, weight: .regular, design: .monospaced))
                .tracking(0.04 * 10)
                .foregroundStyle(Theme.ink3)
        }
    }

    /// The card itself: a 7-equal-column day strip with no internal
    /// header or footer. The card surface is non-interactive — only
    /// the cells inside have tap handlers.
    private func weekStripCard(plan: TrainingPlan, adherence: WeekAdherence) -> some View {
        HStack(spacing: 5) {
            ForEach(Array(adherence.days.enumerated()), id: \.offset) { idx, day in
                weekStripColumn(plan: plan, day: day, dayIdx: idx)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.surface1)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(Theme.line, lineWidth: 1)
        )
    }

    private func weekStripColumn(plan: TrainingPlan, day: DayReview, dayIdx: Int) -> WeekStripCell {
        let glyphs = weekStripGlyphs(for: day)
        let status = weekStripStatus(for: day)
        let isRestLike = day.isRest || day.sessions.isEmpty
        return WeekStripCell(
            letter: weekdayLetter(dayIdx),
            isToday: day.isToday,
            status: status,
            glyphs: glyphs,
            upcomingOpacity: isRestLike ? 0.4 : 0.5,
            accessibilityText: weekStripAccessibility(day: day, dayIdx: dayIdx, status: status),
            onTap: { onWeekStripCellTap(plan: plan, day: day, dayIdx: dayIdx) }
        )
    }

    private func onWeekStripCellTap(plan: TrainingPlan, day: DayReview, dayIdx: Int) {
        // Single-session days go straight to session detail; rest /
        // empty / multi-session days push the week view (acts as the
        // day overview) so the athlete can pick which session to open.
        if day.sessions.count == 1, !day.isRest {
            path.append(TodayRoute.sessionDetail(
                weekNum: plan.currentWeek,
                dayIdx: dayIdx,
                sessionIdx: 0,
                preselected: nil
            ))
        } else {
            path.append(TodayRoute.weekDetail(weekNum: plan.currentWeek))
        }
    }

    private func weekdayLetter(_ idx: Int) -> String {
        let letters = ["M", "T", "W", "T", "F", "S", "S"]
        return idx >= 0 && idx < letters.count ? letters[idx] : "·"
    }

    /// Session status collapsed to a single strip-cell status. Multi-
    /// session days use precedence: skipped > modified/swapped > done >
    /// upcoming. Rest and empty days resolve to `.upcoming` and render
    /// as a faded moon via the icon helper. "Today" is NOT folded in
    /// here — `isToday` on `WeekStripCell` handles the column wrap so
    /// the today rules can't drift.
    private func weekStripStatus(for day: DayReview) -> WeekStripStatus {
        if day.isRest || day.sessions.isEmpty { return .upcoming }
        let statuses = day.sessions.map { $0.status }
        if statuses.contains(.missed) { return .skipped }
        if statuses.contains(.shortened) || statuses.contains(.substituted) {
            return .modified
        }
        if !statuses.isEmpty, statuses.allSatisfy({ $0 == .completed }) {
            return .done
        }
        return .upcoming
    }

    /// One glyph per session, in prescribed order. Swapped sessions
    /// report the substitute sport so the strip mirrors what the
    /// athlete logged. Rest / empty days collapse to a single moon
    /// glyph. The cell stacks the first two and rolls any remainder
    /// into a "+N" line.
    private func weekStripGlyphs(for day: DayReview) -> [DisciplineGlyph] {
        if day.isRest || day.sessions.isEmpty {
            return [DisciplineGlyph(symbolName: "moon.fill", naturalColor: Theme.ink3)]
        }
        return day.sessions.map { session in
            let type = typeFor(session)
            return DisciplineGlyph(
                symbolName: symbolName(for: type),
                naturalColor: disciplineColor(for: type)
            )
        }
    }

    /// Effective sport type for a session — substitute wins for swaps
    /// so the strip mirrors what the athlete logged.
    private func typeFor(_ session: SessionReview) -> String {
        if session.status == .substituted, let sub = session.substitute, !sub.isEmpty {
            return sub
        }
        return session.type
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

    /// Compact "Apr 20 – 26" / "Apr 28 – May 4" range using an en-dash.
    /// Drops the second month when the week stays inside one month.
    /// Distinct from the dash-and-month `weekRangeLabel` helper — that
    /// format is used by the WeekDetail header where there's room.
    private func weekRangeShortText(plan: TrainingPlan) -> String {
        guard let startStr = plan.startDate else { return "" }
        let input = DateFormatter()
        input.dateFormat = "yyyy-MM-dd"
        guard let planStart = input.date(from: startStr) else { return "" }
        let cal = Calendar.current
        let raw = cal.date(byAdding: .day, value: (plan.currentWeek - 1) * 7, to: planStart) ?? planStart
        let monday = mondayOf(raw)
        guard let sunday = cal.date(byAdding: .day, value: 6, to: monday) else { return "" }

        let monthFmt = DateFormatter()
        monthFmt.dateFormat = "MMM"
        let dayFmt = DateFormatter()
        dayFmt.dateFormat = "d"

        let monMonth = monthFmt.string(from: monday)
        let monDay = dayFmt.string(from: monday)
        let sunMonth = monthFmt.string(from: sunday)
        let sunDay = dayFmt.string(from: sunday)

        if monMonth == sunMonth {
            return "\(monMonth) \(monDay) \u{2013} \(sunDay)"
        }
        return "\(monMonth) \(monDay) \u{2013} \(sunMonth) \(sunDay)"
    }

    /// VoiceOver label for one week-strip cell. Combines weekday name,
    /// today indicator, session description, and resolved status.
    private func weekStripAccessibility(
        day: DayReview,
        dayIdx: Int,
        status: WeekStripStatus
    ) -> String {
        let weekdayNames = [
            "Monday", "Tuesday", "Wednesday", "Thursday",
            "Friday", "Saturday", "Sunday"
        ]
        let dayName = (dayIdx >= 0 && dayIdx < weekdayNames.count)
            ? weekdayNames[dayIdx] : "Day"

        if day.isRest {
            return day.isToday
                ? "\(dayName), today, rest day"
                : "\(dayName), rest day"
        }
        if day.sessions.isEmpty {
            return day.isToday
                ? "\(dayName), today, no sessions"
                : "\(dayName), no sessions"
        }

        let session: String = {
            if day.sessions.count == 1 {
                let t = typeFor(day.sessions[0])
                return t.isEmpty ? "session" : "\(t) session"
            }
            let types = day.sessions.map(typeFor).filter { !$0.isEmpty }
            if types.count == 2 {
                return "\(types[0]) and \(types[1]) sessions"
            }
            return "\(day.sessions.count) sessions"
        }()

        let statusWord: String? = {
            switch status {
            case .done:     return "completed"
            case .modified: return "modified"
            case .skipped:  return "skipped"
            case .upcoming: return day.isToday ? nil : "upcoming"
            }
        }()

        var parts = [dayName]
        if day.isToday { parts.append("today") }
        parts.append(session)
        if let statusWord { parts.append(statusWord) }
        return parts.joined(separator: ", ")
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

