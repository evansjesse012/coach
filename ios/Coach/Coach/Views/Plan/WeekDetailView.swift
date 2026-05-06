import SwiftUI

struct WeekDetailView: View {
    let initialWeekNum: Int

    @Environment(DataService.self) var data
    @Environment(\.dismiss) var dismiss
    @State private var weekNum: Int = 1
    @State private var didInit = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                weekSelector

                weeklyArtifactsBlock

                if let plan = data.trainingPlan,
                   let wp = plan.weeklyPlans[String(weekNum)] {
                    if wp.isStub {
                        StubWeekCard(plan: plan, weeklyPlan: wp)
                    } else {
                        sessionsList(plan: plan, weeklyPlan: wp)
                    }
                } else {
                    Text("No data for this week")
                        .font(Theme.Typography.body)
                        .foregroundStyle(Theme.ink3)
                        .padding(.top, 40)
                }
            }
            .padding(.horizontal, Theme.Spacing.screenH)
            .padding(.top, 8)
        }
        .clearsTabBar()
        .background(Theme.bg.ignoresSafeArea())
        .scrollContentBackground(.hidden)
        .navigationTitle("Plan Overview")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            guard !didInit else { return }
            weekNum = initialWeekNum
            didInit = true
        }
    }

    // MARK: - Weekly artifacts (review + preview)

    /// Embed the prior-week's review (if it exists) and the current
    /// week's preview (if it exists) at the top of the week view.
    /// Renders nothing for weeks with neither artifact.
    @ViewBuilder
    private var weeklyArtifactsBlock: some View {
        let weekStart = mondayOfWeek(weekNum: weekNum)
        let priorWeekStart = priorMonday(of: weekStart)

        let preview = weekStart.flatMap(data.weeklyPreview(forWeekStarting:))
        let priorReview = priorWeekStart.flatMap(data.weeklyReview(forWeekStarting:))

        VStack(spacing: 12) {
            if let preview {
                WeeklyArtifactView(source: .preview(preview))
            }
            if let priorReview, priorReview.isComplete {
                WeeklyArtifactView(source: .review(priorReview))
            }
        }
    }

    /// Monday-of-week as `yyyy-MM-dd` for `weekNum`. Computes against
    /// the plan's startDate and falls back to nil when the plan or
    /// start date isn't available.
    private func mondayOfWeek(weekNum: Int) -> String? {
        guard let plan = data.trainingPlan,
              let startStr = plan.startDate else { return nil }
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        guard let start = f.date(from: startStr) else { return nil }
        let monday = Calendar.current.date(byAdding: .day, value: (weekNum - 1) * 7, to: start) ?? start
        return f.string(from: monday)
    }

    private func priorMonday(of weekStart: String?) -> String? {
        guard let weekStart else { return nil }
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        guard let date = f.date(from: weekStart) else { return nil }
        let prior = Calendar.current.date(byAdding: .day, value: -7, to: date) ?? date
        return f.string(from: prior)
    }

    // MARK: - Week selector

    private var weekSelector: some View {
        HStack(spacing: 16) {
            Button {
                if weekNum > minWeek { weekNum -= 1 }
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(weekNum > minWeek ? Theme.ink2 : Theme.ink3)
                    .frame(width: 36, height: 36)
                    .background(Circle().strokeBorder(Theme.line, lineWidth: 1))
            }
            .buttonStyle(.plain)
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
                VStack(spacing: 2) {
                    HStack(spacing: 4) {
                        Text(weekTitle)
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundStyle(Theme.ink)
                        Image(systemName: "chevron.down")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(Theme.ink3)
                    }
                    if let range = weekDateRange {
                        Text(range)
                            .font(Theme.Typography.monoMeta)
                            .foregroundStyle(Theme.ink3)
                    }
                }
                .frame(maxWidth: .infinity)
            }

            Button {
                if weekNum < maxWeek { weekNum += 1 }
            } label: {
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(weekNum < maxWeek ? Theme.ink2 : Theme.ink3)
                    .frame(width: 36, height: 36)
                    .background(Circle().strokeBorder(Theme.line, lineWidth: 1))
            }
            .buttonStyle(.plain)
            .disabled(weekNum >= maxWeek)
        }
        .padding(.vertical, 4)
    }

    private var allWeekNums: [Int] {
        (data.trainingPlan?.weeklyPlans.keys.compactMap(Int.init) ?? []).sorted()
    }
    private var minWeek: Int { allWeekNums.first ?? 1 }
    private var maxWeek: Int { allWeekNums.last ?? 1 }

    private var weekTitle: String {
        if let plan = data.trainingPlan {
            return "Week \(weekNum) of \(plan.totalWeeks)"
        }
        return "Week \(weekNum)"
    }

    private var weekDateRange: String? {
        weekRangeLabel(planStartDate: data.trainingPlan?.startDate, weekNumber: weekNum)
    }

    // MARK: - Sessions list

    private func sessionsList(plan: TrainingPlan, weeklyPlan: WeeklyPlan) -> some View {
        VStack(alignment: .leading, spacing: 18) {
            ForEach(Array(weeklyPlan.sessions.enumerated()), id: \.offset) { dayIdx, dayPlan in
                dayGroup(plan: plan, dayPlan: dayPlan, dayIdx: dayIdx)
            }
        }
    }

    @ViewBuilder
    private func dayGroup(plan: TrainingPlan, dayPlan: DayPlan, dayIdx: Int) -> some View {
        let dateStr = dateString(plan: plan, dayIdx: dayIdx)
        let isToday = !dateStr.isEmpty && dateStr == todayString()
        let isRest = dayPlan.isRest == true

        if isRest || !dayPlan.sessions.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                DayHeader(dayName: dayPlan.day, isToday: isToday)
                    .padding(.leading, 4)

                if isRest {
                    RestDayCard(dayPlan: dayPlan, dateString: dateStr)
                } else {
                    VStack(spacing: 12) {
                        ForEach(Array(dayPlan.sessions.enumerated()), id: \.offset) { sessionIdx, session in
                            WeekDaySessionCard(
                                session: session,
                                dateString: dateStr,
                                weekNum: weekNum,
                                dayIdx: dayIdx,
                                sessionIdx: sessionIdx
                            )
                        }
                    }
                }
            }
        }
    }

    private func dateString(plan: TrainingPlan, dayIdx: Int) -> String {
        sessionDateString(planStartDate: plan.startDate, weekNumber: weekNum, dayIdx: dayIdx) ?? ""
    }
}

// MARK: - Day header

private struct DayHeader: View {
    let dayName: String
    let isToday: Bool

    var body: some View {
        HStack(spacing: 8) {
            Text(dayName.capitalized)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Theme.ink)
            if isToday {
                Text("TODAY")
                    .font(Theme.Typography.monoLabel)
                    .tracking(Theme.Tracking.monoLabel)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(Capsule().fill(Theme.accent))
                    .foregroundStyle(Theme.accentInk)
            }
            Spacer()
        }
    }
}

// MARK: - Session card

private struct WeekDaySessionCard: View {
    let session: PrescribedSession
    let dateString: String
    let weekNum: Int
    let dayIdx: Int
    let sessionIdx: Int

    @Environment(DataService.self) private var data
    @State private var postStatusSheet: HomeTab.PostStatusContext?

    var body: some View {
        let status = session.sessionCardStatus
        return ZStack(alignment: .topTrailing) {
            NavigationLink {
                SessionDetailView(
                    session: session,
                    dateString: dateString,
                    weekNum: weekNum,
                    dayIdx: dayIdx,
                    sessionIdx: sessionIdx
                )
            } label: {
                VStack(spacing: 0) {
                    if let status {
                        SessionStatusStrip(status: status)
                    }

                    HStack(spacing: 0) {
                        // Sport-colored left rule — matches Home's Today SessionCard.
                        Rectangle()
                            .fill(discipline.color)
                            .frame(width: 3)

                        VStack(alignment: .leading, spacing: 6) {
                            Text(session.label)
                                .font(Theme.Typography.sessionTitle)
                                .foregroundStyle(Theme.ink)
                                .tracking(Theme.Tracking.headline)
                                .lineLimit(2)
                                .fixedSize(horizontal: false, vertical: true)

                            Text(secondLine)
                                .font(Theme.Typography.monoMeta)
                                .foregroundStyle(Theme.ink3)

                            Text(thirdLine)
                                .font(Theme.Typography.bodyS)
                                .foregroundStyle(Theme.ink2)

                            if let note = session.notes, !note.isEmpty {
                                Text(note)
                                    .font(Theme.Typography.small)
                                    .foregroundStyle(Theme.ink2)
                                    .lineLimit(2)
                                    .padding(.top, 2)
                            }

                            if let completionNote = session.completionNote, !completionNote.isEmpty {
                                Text("\u{201C}\(completionNote)\u{201D}")
                                    .font(Theme.Typography.small)
                                    .italic()
                                    .foregroundStyle(Theme.ink3)
                                    .lineLimit(2)
                                    .padding(.top, 2)
                            }
                        }
                        .padding(.leading, 14)
                        .padding(.vertical, 14)
                        // Leave trailing space for the absolute-positioned menu.
                        .padding(.trailing, 50)

                        Spacer(minLength: 0)
                    }
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            // Menu lives outside the NavigationLink so its taps don't
            // trigger the push. Positioned in the top-right corner of
            // the body (below the status strip when one is present).
            SessionStatusMenu(
                sessionLabel: session.label,
                currentStatus: session.statusKind,
                onDone:     { Task { await commitStatus(.done) } },
                onModified: { Task { await commitStatus(.modified) } },
                onSwapped:  { Task { await commitStatus(.swapped) } },
                onSkipped:  { Task { await commitStatus(.skipped) } },
                onEdit:     {}, // Body tap handles navigation.
                onClear:    { Task { await clearStatus() } }
            )
            .padding(.top, status == nil ? 10 : 40)
            .padding(.trailing, 10)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.surface1)
        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.card))
        .overlay(
            RoundedRectangle(cornerRadius: Theme.Radius.card)
                .strokeBorder(Theme.line, lineWidth: 1)
        )
        .dsCardShadow()
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
    }

    // MARK: - Status mutations

    @MainActor
    private func commitStatus(_ kind: Theme.SessionStatusKind) async {
        do {
            try await data.updateSessionCompletion(
                weekNum: weekNum, dayIdx: dayIdx, sessionIdx: sessionIdx
            ) { s in
                let iso = ISO8601DateFormatter().string(from: Date())
                switch kind {
                case .done:
                    s.completionStatus = .completed
                    s.completed = true
                    s.completionResolvedAt = iso
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
                    return
                }
            }
            // Same check-in pattern as Today: every status opens the
            // sheet so the coach gets context on every logged session,
            // not just the ones the athlete botched.
            postStatusSheet = HomeTab.PostStatusContext(
                sessionLabel: session.label,
                status: kind,
                weekNum: weekNum, dayIdx: dayIdx, sessionIdx: sessionIdx
            )
        } catch {
            print("WeekDetail.commitStatus failed (\(kind) week \(weekNum) day \(dayIdx) idx \(sessionIdx)): \(error)")
        }
    }

    @MainActor
    private func clearStatus() async {
        do {
            try await data.updateSessionCompletion(
                weekNum: weekNum, dayIdx: dayIdx, sessionIdx: sessionIdx
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
        } catch {
            print("WeekDetail.clearStatus failed (week \(weekNum) day \(dayIdx) idx \(sessionIdx)): \(error)")
        }
    }

    // MARK: Derived — discipline

    private var discipline: Theme.Discipline {
        if let sport = Sport(rawValue: session.type) { return sport.discipline }
        if session.type == "strength" { return .strength }
        return .run
    }

    // MARK: Derived — text

    private var secondLine: String {
        var parts: [String] = []
        if let short = shortDate {
            parts.append(short)
        }
        if let durRange = durationRange {
            parts.append(durRange)
        } else if let dur = session.duration {
            parts.append("\(dur)m")
        }
        return parts.joined(separator: " · ")
    }

    private var shortDate: String? {
        guard !dateString.isEmpty else { return nil }
        let input = DateFormatter()
        input.dateFormat = "yyyy-MM-dd"
        guard let date = input.date(from: dateString) else { return nil }
        let output = DateFormatter()
        output.dateFormat = "MMM d"
        return output.string(from: date)
    }

    private var thirdLine: String {
        var parts: [String] = []
        if let cat = session.effortCategory {
            parts.append(cat.label)
        } else if !session.type.isEmpty {
            parts.append(session.type.capitalized)
        }
        if let mi = session.distanceMiles, mi > 0 {
            parts.append(String(format: "%.1f mi", mi))
        }
        return parts.joined(separator: " · ")
    }

    private var durationRange: String? {
        if let lo = session.estimatedDurationMin, let hi = session.estimatedDurationMax {
            return "\(lo)–\(hi)m"
        }
        return nil
    }
}

// MARK: - Rest day card

private struct RestDayCard: View {
    let dayPlan: DayPlan
    let dateString: String

    var body: some View {
        HStack(spacing: 0) {
            Rectangle()
                .fill(Theme.Discipline.recovery.color)
                .frame(width: 3)

            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 8) {
                    Image(systemName: "moon.zzz.fill")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Theme.Discipline.recovery.color)
                    Text("Rest day")
                        .font(Theme.Typography.sessionTitle)
                        .foregroundStyle(Theme.ink)
                }

                if !dateString.isEmpty {
                    Text(formatDayLong(dateString))
                        .font(Theme.Typography.monoMeta)
                        .foregroundStyle(Theme.ink3)
                }

                if let note = dayPlan.restNote, !note.isEmpty {
                    Text(note)
                        .font(Theme.Typography.body)
                        .foregroundStyle(Theme.ink2)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.top, 4)
                }
            }
            .padding(.leading, 14)
            .padding(.vertical, 14)
            .padding(.trailing, 14)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(Theme.surface1)
        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.card))
        .overlay(
            RoundedRectangle(cornerRadius: Theme.Radius.card)
                .strokeBorder(Theme.line, lineWidth: 1)
        )
        .dsCardShadow()
    }
}

// MARK: - Stub week card

/// Shown when the athlete opens a week that only has a focus/phase stored
/// (no daily sessions yet). Explains the lazy-generation model and offers
/// a one-tap button to run the generator for this week.
private struct StubWeekCard: View {
    let plan: TrainingPlan
    let weeklyPlan: WeeklyPlan

    @Environment(DataService.self) var data
    @State private var isGenerating = false
    @State private var generationError: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 8) {
                    Image(systemName: "calendar.badge.clock")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(Theme.accent)
                    Text("Not yet planned")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Theme.ink)
                }

                if let phaseNum = weeklyPlan.phase,
                   let phase = plan.phases.first(where: { $0.number == phaseNum }) {
                    Text("Phase \(phaseNum) \u{2014} \(phase.name)")
                        .font(Theme.Typography.monoLabel)
                        .tracking(Theme.Tracking.monoLabel)
                        .textCase(.uppercase)
                        .foregroundStyle(Theme.ink3)
                }

                if let focus = weeklyPlan.focusOfWeek, !focus.isEmpty {
                    Text(focus)
                        .font(Theme.Typography.body)
                        .foregroundStyle(Theme.ink2)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.top, 2)
                }
            }

            Rectangle()
                .fill(Theme.line)
                .frame(height: 1)

            Text("Your coach shapes each week closer to its start so it can adapt to how the prior weeks actually went. You can generate it now if you want to see what's coming.")
                .font(Theme.Typography.body)
                .foregroundStyle(Theme.ink2)
                .fixedSize(horizontal: false, vertical: true)

            Pill(
                title: isGenerating ? "Generating\u{2026}" : "Generate this week now",
                icon: isGenerating ? nil : "sparkles",
                variant: .primary
            ) {
                Task { await generate() }
            }
            .disabled(isGenerating)

            if let err = generationError {
                Text(err)
                    .font(Theme.Typography.small)
                    .foregroundStyle(Theme.warn)
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
        .dsCardShadow()
    }

    private func generate() async {
        isGenerating = true
        generationError = nil
        do {
            try await data.generateWeek(weeklyPlan.weekNumber)
        } catch {
            generationError = error.localizedDescription
        }
        isGenerating = false
    }
}
