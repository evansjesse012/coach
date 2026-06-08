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
                        WeekTotalsCard(weeklyPlan: wp)
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

        let artifacts = resolvedArtifacts(weekStart: weekStart, priorWeekStart: priorWeekStart)

        // Review on top (expanded by default), preview below (collapsed).
        // The `.id` resets each card's expand state when the week changes.
        VStack(spacing: 12) {
            if let review = artifacts.review {
                WeekReviewCard(review: review)
                    .id(review.id)
            }
            if let preview = artifacts.preview {
                WeekPreviewCard(preview: preview)
                    .id(preview.id)
            }
        }
    }

    /// Resolves which preview/review to show for the current week. Real
    /// artifacts when present; in DEBUG, sample content fills the gaps so the
    /// cards are visible without check-in data. Release builds return nil when
    /// data is absent. Kept out of the `@ViewBuilder` body because `#if` inside
    /// a builder is parsed as conditional view content. See SampleCoachArtifacts.
    private func resolvedArtifacts(
        weekStart: String?,
        priorWeekStart: String?
    ) -> (review: WeeklyReview?, preview: WeeklyPreview?) {
        let realPreview = weekStart.flatMap(data.weeklyPreview(forWeekStarting:))
        let realReview = priorWeekStart.flatMap(data.weeklyReview(forWeekStarting:))
        #if DEBUG
        let review: WeeklyReview? = (realReview?.isComplete == true)
            ? realReview : .sample(weekStart: priorWeekStart)
        let preview: WeeklyPreview? = realPreview ?? .sample(weekStart: weekStart)
        #else
        let review: WeeklyReview? = (realReview?.isComplete == true) ? realReview : nil
        let preview: WeeklyPreview? = realPreview
        #endif
        return (review, preview)
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
                    // Week number — "Week 4 /20". The "/20" total reads
                    // faint and smaller, per the week-header spec.
                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        Text("Week \(weekNum)")
                            .font(.system(size: 34, weight: .semibold))
                            .tracking(-0.68)   // ~-0.02em on 34pt
                            .foregroundStyle(Theme.ink)
                        if let total = data.trainingPlan?.totalWeeks {
                            Text("/\(total)")
                                .font(.system(size: 20, weight: .regular))
                                .foregroundStyle(Theme.ink3)
                        }
                    }
                    // Date range — "Jun 1 - Jun 7".
                    if let range = weekDateRangeText {
                        Text(range)
                            .font(Theme.Typography.monoMeta)
                            .foregroundStyle(Theme.ink3)
                            .padding(.top, 2)
                    }
                    // Phase label — "△ BASE phase". Keyword uppercase,
                    // "phase" lowercase, moss accent.
                    if let phase = phaseLabel {
                        Text(phase)
                            .font(Theme.Typography.monoLabel)
                            .tracking(1.3)     // ~0.1em on 13pt
                            .foregroundStyle(Theme.accent)
                            .padding(.top, 2)
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

    /// Week date range for the header, e.g. "Jun 1 - Jun 7".
    private var weekDateRangeText: String? {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        guard let monStr = mondayOfWeek(weekNum: weekNum),
              let monday = f.date(from: monStr) else { return nil }
        let sunday = Calendar.current.date(byAdding: .day, value: 6, to: monday) ?? monday
        let out = DateFormatter()
        out.dateFormat = "MMM d"
        return "\(out.string(from: monday)) - \(out.string(from: sunday))"
    }

    /// "△ BASE phase" for the week header — keyword uppercased, "phase"
    /// lowercase. Nil when the week has no phase recorded (e.g. no plan).
    private var phaseLabel: String? {
        guard let plan = data.trainingPlan,
              let wp = plan.weeklyPlans[String(weekNum)],
              let phaseNum = wp.phase,
              let phase = plan.phases.first(where: { $0.number == phaseNum })
        else { return nil }
        return "\u{25B3} \(phase.name.uppercased()) phase"
    }

    // MARK: - Sessions list

    private func sessionsList(plan: TrainingPlan, weeklyPlan: WeeklyPlan) -> some View {
        VStack(alignment: .leading, spacing: 20) {
            monthYearHeader
            ForEach(Array(weeklyPlan.sessions.enumerated()), id: \.offset) { dayIdx, dayPlan in
                dayRow(plan: plan, dayPlan: dayPlan, dayIdx: dayIdx)
            }
        }
    }

    /// Year + month(s) the week spans, e.g. "2026 JUN" or "2026 JUN / JUL".
    @ViewBuilder
    private var monthYearHeader: some View {
        if let text = monthYearText {
            Text(text)
                .font(.system(size: 22, weight: .light))
                .tracking(4)
                .foregroundStyle(Theme.ink3)
        }
    }

    private var monthYearText: String? {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        guard let monStr = mondayOfWeek(weekNum: weekNum),
              let monday = f.date(from: monStr) else { return nil }
        let sunday = Calendar.current.date(byAdding: .day, value: 6, to: monday) ?? monday
        let mo = DateFormatter(); mo.dateFormat = "MMM"
        let yr = DateFormatter(); yr.dateFormat = "yyyy"
        let startMonth = mo.string(from: monday).uppercased()
        let endMonth = mo.string(from: sunday).uppercased()
        let startYear = yr.string(from: monday)
        let endYear = yr.string(from: sunday)
        if startYear == endYear {
            return startMonth == endMonth
                ? "\(startYear) \(startMonth)"
                : "\(startYear) \(startMonth) / \(endMonth)"
        }
        // Week straddles New Year.
        return "\(startYear) \(startMonth) / \(endYear) \(endMonth)"
    }

    @ViewBuilder
    private func dayRow(plan: TrainingPlan, dayPlan: DayPlan, dayIdx: Int) -> some View {
        let dateStr = dateString(plan: plan, dayIdx: dayIdx)
        let isToday = !dateStr.isEmpty && dateStr == todayString()
        let isRest = dayPlan.isRest == true

        if isRest || !dayPlan.sessions.isEmpty {
            HStack(alignment: .top, spacing: 12) {
                // Day column with the multi-session connector line centered
                // beneath the day name / number.
                ZStack(alignment: .top) {
                    if dayPlan.sessions.count > 1 {
                        Rectangle()
                            .fill(Theme.line)
                            .frame(width: 1)
                            .frame(maxHeight: .infinity)
                            .padding(.top, 40)
                            .padding(.bottom, 6)
                    }
                    DayDateColumn(dayName: dayPlan.day, dateString: dateStr, isToday: isToday)
                        .frame(maxWidth: .infinity)
                }
                .frame(width: 46)

                if isRest {
                    RestDayRow().padding(.top, 14)
                    Spacer(minLength: 0)
                } else {
                    VStack(spacing: 8) {
                        ForEach(Array(dayPlan.sessions.enumerated()), id: \.offset) { sessionIdx, session in
                            WeekSessionRow(
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

// MARK: - Day / date column

/// Left-column label for a day: "MON" over the date number. Today's date
/// number gets a white box highlight.
private struct DayDateColumn: View {
    let dayName: String
    let dateString: String
    let isToday: Bool

    var body: some View {
        VStack(alignment: .center, spacing: 3) {
            Text(dayAbbrev)
                .font(Theme.Typography.mono(11, weight: .medium))
                .tracking(1.0)
                .foregroundStyle(Theme.ink3)
            Text(dayNumber)
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(isToday ? Theme.bg : Theme.ink2)
                .padding(.horizontal, isToday ? 7 : 0)
                .padding(.vertical, isToday ? 3 : 0)
                .background {
                    if isToday {
                        RoundedRectangle(cornerRadius: 7).fill(.white)
                    }
                }
        }
    }

    private var parsedDate: Date? {
        guard !dateString.isEmpty else { return nil }
        let f = DateFormatter(); f.dateFormat = "yyyy-MM-dd"
        return f.date(from: dateString)
    }

    private var dayAbbrev: String {
        if let d = parsedDate {
            let f = DateFormatter(); f.dateFormat = "EEE"
            return f.string(from: d).uppercased()
        }
        return String(dayName.prefix(3)).uppercased()
    }

    private var dayNumber: String {
        guard let d = parsedDate else { return "" }
        let f = DateFormatter(); f.dateFormat = "d"
        return f.string(from: d)
    }
}

// MARK: - Rest day row

/// Borderless inline rest-day marker shown next to the date column.
private struct RestDayRow: View {
    var body: some View {
        HStack(spacing: 8) {
            Text("\u{1F6CF}\u{FE0F}")   // 🛏️
                .font(.system(size: 17))
            Text("Rest day")
                .font(.system(size: 17, weight: .medium))
                .foregroundStyle(Theme.ink2)
        }
    }
}

// MARK: - Session row

/// Compact session row for the week view: status badge · discipline icon ·
/// title · duration/distance. Upcoming sessions show a right chevron instead
/// of a left status badge. Tapping opens the same SessionDetailView as Home.
private struct WeekSessionRow: View {
    let session: PrescribedSession
    let dateString: String
    let weekNum: Int
    let dayIdx: Int
    let sessionIdx: Int

    var body: some View {
        NavigationLink {
            SessionDetailView(
                session: session,
                dateString: dateString,
                weekNum: weekNum,
                dayIdx: dayIdx,
                sessionIdx: sessionIdx
            )
        } label: {
            HStack(spacing: 10) {
                if statusKind != .pending {
                    statusBadge
                }

                Image(systemName: discipline.icon)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(discipline.color)
                    .frame(width: 22)

                VStack(alignment: .leading, spacing: 2) {
                    Text(session.displayTitle)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Theme.ink)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                    if !metaLine.isEmpty {
                        Text(metaLine)
                            .font(Theme.Typography.mono(11))
                            .foregroundStyle(Theme.ink2)
                    }
                }

                Spacer(minLength: 6)

                if statusKind == .pending {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Theme.ink3)
                }
            }
            .padding(.vertical, 10)
            .padding(.horizontal, 12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .background(Theme.surface1)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .strokeBorder(Theme.line, lineWidth: 1)
        )
    }

    // MARK: Status badge

    /// Rounded-square badge in the canonical status color family. Shown only
    /// for resolved sessions; pending sessions use the right chevron instead.
    private var statusBadge: some View {
        let kind = statusKind
        return RoundedRectangle(cornerRadius: 8)
            .fill(kind.fill)
            .frame(width: 28, height: 28)
            .overlay(
                Image(systemName: badgeGlyph)
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(kind.tint)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .strokeBorder(kind.border ?? .clear, lineWidth: 1)
            )
    }

    private var badgeGlyph: String {
        switch statusKind {
        case .done:     return "checkmark"
        case .skipped:  return "xmark"
        case .modified: return "pencil"
        case .swapped:  return "arrow.2.squarepath"
        case .pending:  return "circle"
        }
    }

    private var statusKind: Theme.SessionStatusKind { session.statusKind }

    // MARK: Derived — discipline

    private var discipline: Theme.Discipline {
        if let sport = Sport(rawValue: session.type) { return sport.discipline }
        if session.type == "strength" { return .strength }
        return .run
    }

    // MARK: Derived — meta line (discipline-aware)

    /// One uppercase mono line: swim → duration · meters, bike/run →
    /// duration · miles, strength → exercise count · duration.
    private var metaLine: String {
        let dur = durationUpper
        switch session.type.lowercased() {
        case "strength":
            if let n = session.exercises?.count, n > 0 {
                return joinMeta(["\(n) EXERCISE\(n == 1 ? "" : "S")", dur])
            }
            return dur
        case "swim":
            // No native meters field — convert from distance_miles and round
            // to the nearest 25m. TODO: use a real meters field if added.
            if let mi = session.distanceMiles, mi > 0 {
                let meters = Int((mi * 1609.34 / 25).rounded()) * 25
                return joinMeta([dur, "\(meters) M"])
            }
            return dur
        // TODO: mobility / yoga / functional descriptors once in the model.
        default:
            if let mi = session.distanceMiles, mi > 0 {
                return joinMeta([dur, String(format: "%.1f MI", mi)])
            }
            return dur
        }
    }

    private var durationUpper: String {
        if let d = session.duration, d > 0 {
            let h = d / 60, m = d % 60
            if h > 0 && m > 0 { return "\(h) HR \(m) MIN" }
            if h > 0 { return "\(h) HR" }
            return "\(m) MIN"
        }
        if let lo = session.estimatedDurationMin, let hi = session.estimatedDurationMax {
            return "\(lo)\u{2013}\(hi) MIN"
        }
        return ""
    }

    private func joinMeta(_ parts: [String]) -> String {
        parts.filter { !$0.isEmpty }.joined(separator: " \u{00B7} ")
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
