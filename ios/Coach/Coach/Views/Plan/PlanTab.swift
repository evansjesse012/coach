import SwiftUI

struct PlanTab: View {
    @Environment(DataService.self) var data
    @State private var showPlanChat = false
    /// Phase number whose detail panel is currently expanded below the row
    /// list. nil means "use plan.currentPhase as the default" — set on first
    /// load so a fresh plan always opens to the active phase.
    @State private var selectedPhaseNumber: Int?

    var body: some View {
        NavigationStack {
            ScrollView {
                if let plan = data.trainingPlan {
                    content(plan: plan)
                } else {
                    emptyState
                }
            }
            .navigationTitle("Plan")
            .sheet(isPresented: $showPlanChat) {
                PlanCreationChatSheet()
            }
            .task {
                // Auto-advance currentWeek and pre-generate upcoming weeks.
                // Safe to call repeatedly — deduped internally.
                await data.ensurePlanPreGenerated()
            }
        }
    }

    private func content(plan: TrainingPlan) -> some View {
        let phaseBinding = Binding<Int?>(
            get: { selectedPhaseNumber ?? plan.currentPhase },
            set: { selectedPhaseNumber = $0 }
        )
        return VStack(alignment: .leading, spacing: 18) {
            CompactGoalHeader(plan: plan)
            if let freshWeek = data.recentlyPregeneratedWeek,
               freshWeek <= plan.totalWeeks {
                FreshlyGeneratedBanner(weekNumber: freshWeek)
            }
            FullPlanTimeline(plan: plan)
            PhaseRowList(plan: plan, selectedPhaseNumber: phaseBinding)
            PhaseDetailCarousel(plan: plan, selectedPhaseNumber: phaseBinding)
            thisWeekSection(plan: plan)
            modifyWithCoachButton
        }
        .padding()
        .onAppear {
            // Default the selection to the plan's current phase the first
            // time we render, so the carousel scrolls to the right card on
            // initial appearance instead of starting at phase 1.
            if selectedPhaseNumber == nil {
                selectedPhaseNumber = plan.currentPhase
            }
        }
    }

    @ViewBuilder
    private func thisWeekSection(plan: TrainingPlan) -> some View {
        if let wp = plan.weeklyPlans[String(plan.currentWeek)] {
            VStack(alignment: .leading, spacing: 8) {
                Text("THIS WEEK")
                    .font(CoachFonts.ui(11, weight: .semibold))
                    .tracking(0.8)
                    .foregroundStyle(.secondary)
                NavigationLink {
                    WeekDetailView(initialWeekNum: plan.currentWeek)
                } label: {
                    WeekCard(plan: plan, weeklyPlan: wp)
                }
                .buttonStyle(.plain)
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
                showPlanChat = true
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
            HStack(spacing: 6) {
                Image(systemName: "bubble.left.and.bubble.right")
                    .font(.system(size: 11, weight: .medium))
                Text("Modify plan with your coach")
                    .font(CoachFonts.ui(12, weight: .medium))
            }
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
        }
        .buttonStyle(.plain)
        .padding(.top, 8)
    }

    private func routeToCoachForModify(plan: TrainingPlan) {
        let race = plan.raceName ?? "my race"
        data.pendingChatPrompt = "I want to modify my current training plan for \(race). I'm in week \(plan.currentWeek) of \(plan.totalWeeks). What would you like to change?"
        data.showCoachSheet = true
    }
}

// MARK: - Freshly Generated Banner

/// Shown at the top of the Plan tab when `data.recentlyPregeneratedWeek`
/// is set — i.e. the background pre-generation just wrote a future week
/// while the athlete wasn't looking. Tapping navigates into that week and
/// clears the flag, so the banner auto-dismisses on interaction.
private struct FreshlyGeneratedBanner: View {
    let weekNumber: Int

    @Environment(DataService.self) var data
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        NavigationLink {
            WeekDetailView(initialWeekNum: weekNumber)
                .onAppear {
                    // Dismiss the cue as soon as the athlete acts on it.
                    data.recentlyPregeneratedWeek = nil
                }
        } label: {
            HStack(alignment: .center, spacing: 12) {
                ZStack {
                    Circle()
                        .fill(CoachColors.accent.opacity(0.18))
                        .frame(width: 36, height: 36)
                    Image(systemName: "sparkles")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(CoachColors.accent)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text("Your coach wrote week \(weekNumber)")
                        .font(CoachFonts.ui(14, weight: .semibold))
                        .foregroundStyle(.primary)
                    Text("Tap to preview what's coming up next.")
                        .font(CoachFonts.ui(12))
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 8)
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.tertiary)
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                LinearGradient(
                    colors: [CoachColors.accent.opacity(0.14), CoachColors.accent.opacity(0.04)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(CoachColors.accent.opacity(0.35), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .transition(.asymmetric(
            insertion: .scale(scale: 0.96).combined(with: .opacity),
            removal: .opacity
        ))
    }
}

// MARK: - Compact Goal Header

private struct CompactGoalHeader: View {
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

    private func content(showChevron: Bool) -> some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(plan.raceName ?? "Training Plan")
                    .font(CoachFonts.display(18, weight: .bold))
                    .foregroundStyle(.primary)
                    .lineLimit(2)
                    .minimumScaleFactor(0.8)
                if let raceDate = plan.raceDate {
                    Text(formatDateLong(raceDate))
                        .font(CoachFonts.ui(12, weight: .medium))
                        .foregroundStyle(CoachColors.accent)
                }
                Text(statusLine)
                    .font(CoachFonts.ui(11))
                    .foregroundStyle(.secondary)
            }
            Spacer()
            if showChevron {
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            LinearGradient(
                colors: [CoachColors.accent.opacity(0.10), CoachColors.accent.opacity(0.02)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(CoachColors.accent.opacity(0.2), lineWidth: 1)
        )
    }

    private var statusLine: String {
        var parts = ["Week \(plan.currentWeek) of \(plan.totalWeeks)"]
        if let weeks = plan.weeksUntilRace() {
            parts.append("\(weeks) weeks until race day")
        }
        return parts.joined(separator: " · ")
    }
}

// MARK: - Full Plan Timeline

private struct FullPlanTimeline: View {
    let plan: TrainingPlan

    var body: some View {
        GeometryReader { geo in
            timelineContent(totalWidth: geo.size.width)
        }
        .frame(height: 18)
    }

    private func timelineContent(totalWidth: CGFloat) -> some View {
        let segments = plan.phaseSegmentFractions()
        let totalWeeks = max(1, plan.totalWeeks)
        // Put marker mid-column so week 1 isn't clipped and week N sits inside its own segment.
        let markerFraction = (CGFloat(plan.currentWeek) - 0.5) / CGFloat(totalWeeks)
        let rawMarkerX = totalWidth * markerFraction
        let markerX = max(7, min(totalWidth - 7, rawMarkerX))

        return ZStack(alignment: .topLeading) {
            HStack(spacing: 0) {
                ForEach(segments, id: \.phase.number) { entry in
                    Rectangle()
                        .fill(segmentFill(phase: entry.phase))
                        .frame(width: totalWidth * CGFloat(entry.fraction), height: 8)
                }
            }
            .clipShape(Capsule())
            .overlay(
                Capsule()
                    .stroke(
                        (colorSchemeBorder),
                        lineWidth: 0.5
                    )
            )
            .frame(height: 8)
            .offset(y: 5)

            Circle()
                .fill(Color.white)
                .overlay(
                    Circle()
                        .stroke(CoachColors.accent, lineWidth: 2)
                )
                .frame(width: 14, height: 14)
                .shadow(color: Color.black.opacity(0.15), radius: 1.5, x: 0, y: 1)
                .position(x: markerX, y: 9)
        }
    }

    @Environment(\.colorScheme) private var colorScheme
    private var colorSchemeBorder: Color {
        colorScheme == .dark ? CoachColors.darkBorder : CoachColors.lightBorder
    }

    private func segmentFill(phase: TrainingPhase) -> Color {
        let isCurrent = phase.number == plan.currentPhase
        let isCompleted = phase.number < plan.currentPhase
        if isCurrent { return phase.accentColor.opacity(0.6) }
        if isCompleted { return phase.accentColor.opacity(0.35) }
        return phase.accentColor.opacity(0.18)
    }
}

// MARK: - Phase status

private enum PhaseStatus {
    case completed
    case current
    case upcoming
}

private func phaseStatus(for phase: TrainingPhase, in plan: TrainingPlan) -> PhaseStatus {
    if phase.number < plan.currentPhase { return .completed }
    if phase.number == plan.currentPhase { return .current }
    return .upcoming
}

// MARK: - Phase Row List

/// Compact vertical list of every phase in the plan. Tapping any row
/// updates `selectedPhaseNumber`, which the parent view uses to swap the
/// detail panel below. The current phase is highlighted with its accent
/// color and a CURRENT chip.
private struct PhaseRowList: View {
    let plan: TrainingPlan
    /// Optional so it can share the same binding the carousel's
    /// `scrollPosition(id:)` needs. nil means no row is highlighted.
    @Binding var selectedPhaseNumber: Int?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("SEASON PHASES")
                .font(CoachFonts.ui(11, weight: .semibold))
                .tracking(0.8)
                .foregroundStyle(.secondary)

            VStack(spacing: 6) {
                ForEach(plan.phases.sorted(by: { $0.number < $1.number }), id: \.number) { phase in
                    PhaseRow(
                        plan: plan,
                        phase: phase,
                        isSelected: selectedPhaseNumber == phase.number
                    ) {
                        withAnimation(.easeInOut(duration: 0.32)) {
                            selectedPhaseNumber = phase.number
                        }
                    }
                }
            }
        }
    }
}

private struct PhaseRow: View {
    let plan: TrainingPlan
    let phase: TrainingPhase
    let isSelected: Bool
    let onTap: () -> Void

    @Environment(\.colorScheme) var colorScheme

    private var status: PhaseStatus { phaseStatus(for: phase, in: plan) }

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                statusPip
                    .frame(width: 14, height: 14)

                Text("\(phase.number)")
                    .font(CoachFonts.mono(14, weight: .bold))
                    .foregroundStyle(phase.accentColor)
                    .frame(width: 16, alignment: .leading)

                VStack(alignment: .leading, spacing: 1) {
                    Text(phase.name)
                        .font(CoachFonts.ui(14, weight: .semibold))
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                    Text(weekRange)
                        .font(CoachFonts.ui(11))
                        .foregroundStyle(.secondary)
                }

                Spacer(minLength: 8)

                if status == .current {
                    Text("CURRENT")
                        .font(CoachFonts.ui(9, weight: .bold))
                        .tracking(0.6)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3)
                        .background(Capsule().fill(phase.accentColor))
                        .foregroundStyle(.white)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(rowBackground)
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(rowBorder, lineWidth: isSelected ? 1.5 : 1)
            )
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private var statusPip: some View {
        switch status {
        case .completed:
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 14))
                .foregroundStyle(.secondary)
        case .current:
            Circle()
                .fill(phase.accentColor)
                .frame(width: 11, height: 11)
        case .upcoming:
            Circle()
                .stroke(phase.accentColor.opacity(0.55), lineWidth: 1.5)
                .frame(width: 11, height: 11)
        }
    }

    private var weekRange: String {
        let start = plan.startWeek(for: phase)
        let end = plan.endWeek(for: phase)
        return "Weeks \(start)–\(end) · \(phase.weeks)w"
    }

    private var rowBackground: Color {
        if isSelected {
            return phase.accentColor.opacity(0.12)
        }
        return colorScheme == .dark ? CoachColors.darkCard.opacity(0.5) : CoachColors.lightCard.opacity(0.7)
    }

    private var rowBorder: Color {
        if isSelected {
            return phase.accentColor.opacity(0.65)
        }
        return colorScheme == .dark ? CoachColors.darkBorder : CoachColors.lightBorder
    }
}

// MARK: - Phase Detail Carousel

/// Horizontally-pageable carousel of `PhaseDetailPanel` cards. The user can
/// swipe left/right between phases, and selection stays in two-way sync with
/// the phase row list above via `selectedPhaseNumber`:
///
/// - Tapping a row in `PhaseRowList` updates the binding → the carousel
///   scrolls (animated) to that phase.
/// - Swiping the carousel snaps to the next phase → the binding updates →
///   the row list re-highlights.
///
/// Built on iOS 17+'s `scrollPosition(id:)` + `scrollTargetBehavior(.viewAligned)`
/// + `containerRelativeFrame(.horizontal)` for native paging behavior.
private struct PhaseDetailCarousel: View {
    let plan: TrainingPlan
    @Binding var selectedPhaseNumber: Int?

    var body: some View {
        ScrollView(.horizontal) {
            HStack(alignment: .top, spacing: 12) {
                ForEach(plan.phases.sorted(by: { $0.number < $1.number }), id: \.number) { phase in
                    PhaseDetailPanel(plan: plan, phase: phase)
                        .containerRelativeFrame(.horizontal)
                        .id(phase.number)
                }
            }
            .scrollTargetLayout()
        }
        .scrollPosition(id: $selectedPhaseNumber)
        .scrollTargetBehavior(.viewAligned)
        .scrollIndicators(.hidden)
    }
}

// MARK: - Phase Detail Panel

/// Shows the full detail card for whichever phase is currently selected in
/// the row list above. The card body is the same for current / upcoming /
/// completed phases — what changes is the `positionLine` and a few subtle
/// affordances (only show the in-progress week bar when this is the
/// athlete's current phase).
private struct PhaseDetailPanel: View {
    let plan: TrainingPlan
    let phase: TrainingPhase

    @Environment(\.colorScheme) var colorScheme

    private var status: PhaseStatus { phaseStatus(for: phase, in: plan) }

    var body: some View {
        NavigationLink {
            PhaseDetailView(plan: plan, phase: phase)
        } label: {
            VStack(alignment: .leading, spacing: 12) {
                statusHeader

                Text(phase.name)
                    .font(CoachFonts.display(22, weight: .bold))
                    .foregroundStyle(.primary)

                Text(positionLine)
                    .font(CoachFonts.ui(12, weight: .medium))
                    .foregroundStyle(.secondary)

                if let philosophy = phase.philosophy, !philosophy.isEmpty {
                    Text(philosophy)
                        .font(CoachFonts.ui(13))
                        .foregroundStyle(.secondary)
                        .lineLimit(3)
                        .fixedSize(horizontal: false, vertical: true)
                        .multilineTextAlignment(.leading)
                }

                statsRow

                if status == .current {
                    phaseProgressBar
                }

                if let dist = phase.intensityDistribution {
                    IntensityBar(distribution: dist, size: .mini)
                }

                if let keyWorkouts = phase.keyWorkouts, !keyWorkouts.isEmpty {
                    keyWorkoutsPreview(keyWorkouts)
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
                    colors: [phase.accentColor.opacity(0.12), phase.accentColor.opacity(0.03)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(phase.accentColor.opacity(0.55), lineWidth: 1.5)
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: Header / position line

    private var statusHeader: some View {
        HStack(spacing: 8) {
            Text("PHASE \(phase.number) OF \(plan.phases.count)")
                .font(CoachFonts.ui(11, weight: .semibold))
                .tracking(0.8)
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(phase.accentColor.opacity(0.2))
                .foregroundStyle(phase.accentColor)
                .clipShape(Capsule())

            statusBadge

            Spacer()

            if status == .current, let days = plan.daysRemainingInPhase(phase) {
                Text(days < 7 ? "\(days) days left" : "\(days / 7) weeks left")
                    .font(CoachFonts.mono(12))
                    .foregroundStyle(.secondary)
            }
        }
    }

    @ViewBuilder
    private var statusBadge: some View {
        switch status {
        case .current:
            Text("CURRENT")
                .font(CoachFonts.ui(10, weight: .semibold))
                .tracking(0.8)
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(phase.accentColor)
                .foregroundStyle(.white)
                .clipShape(Capsule())
        case .upcoming:
            Text("UPCOMING")
                .font(CoachFonts.ui(10, weight: .semibold))
                .tracking(0.8)
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(phase.accentColor.opacity(0.18))
                .foregroundStyle(phase.accentColor)
                .clipShape(Capsule())
        case .completed:
            Text("COMPLETED")
                .font(CoachFonts.ui(10, weight: .semibold))
                .tracking(0.8)
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(Color.secondary.opacity(0.18))
                .foregroundStyle(.secondary)
                .clipShape(Capsule())
        }
    }

    private var positionLine: String {
        switch status {
        case .current:
            return "Week \(plan.weekIndexInPhase(phase)) of \(phase.weeks) in this phase"
        case .completed:
            return "Weeks \(plan.startWeek(for: phase))–\(plan.endWeek(for: phase)) · Done"
        case .upcoming:
            let startWeek = plan.startWeek(for: phase)
            return "Starts week \(startWeek) · \(phase.weeks) weeks long"
        }
    }

    // MARK: Body sections (shared with the old PhaseCard)

    @ViewBuilder
    private var statsRow: some View {
        HStack(spacing: 18) {
            if let v = phase.weeklyVolumeRange {
                miniStat(label: "Volume", value: "\(formatVol(v.min))–\(formatVol(v.max)) \(v.unit)")
            }
            if let s = phase.sessionsPerWeek {
                miniStat(label: "Sessions", value: "\(s)/wk")
            }
            if let n = phase.keyWorkouts?.count, n > 0 {
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
                .foregroundStyle(.primary)
        }
    }

    private func formatVol(_ v: Double) -> String {
        v == v.rounded() ? "\(Int(v))" : String(format: "%.1f", v)
    }

    private var phaseProgressBar: some View {
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

    private func keyWorkoutsPreview(_ workouts: [KeyWorkout]) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("KEY WORKOUTS")
                .font(CoachFonts.ui(9, weight: .semibold))
                .tracking(0.5)
                .foregroundStyle(.secondary)
            ForEach(Array(workouts.prefix(3)), id: \.name) { w in
                HStack(alignment: .top, spacing: 6) {
                    Circle()
                        .fill(phase.accentColor.opacity(0.5))
                        .frame(width: 4, height: 4)
                        .padding(.top, 6)
                    VStack(alignment: .leading, spacing: 1) {
                        Text(w.name)
                            .font(CoachFonts.ui(12, weight: .semibold))
                            .foregroundStyle(.primary)
                        Text(w.description)
                            .font(CoachFonts.ui(11))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
            }
        }
    }
}

// MARK: - Week Card

private struct WeekCard: View {
    let plan: TrainingPlan
    let weeklyPlan: WeeklyPlan

    @Environment(DataService.self) var data
    @Environment(\.colorScheme) var colorScheme
    @State private var isGenerating = false
    @State private var generationError: String?

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

            if weeklyPlan.isStub {
                stubBody
            } else {
                populatedBody
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

    @ViewBuilder
    private var populatedBody: some View {
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

    @ViewBuilder
    private var stubBody: some View {
        if let focus = weeklyPlan.focusOfWeek, !focus.isEmpty {
            Text(focus)
                .font(CoachFonts.ui(13))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }

        Divider()

        HStack(spacing: 10) {
            Image(systemName: "calendar.badge.clock")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.secondary)
            Text("Details will be shaped closer to this week, based on how the prior weeks go.")
                .font(CoachFonts.ui(11))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }

        Button {
            Task { await generate() }
        } label: {
            HStack(spacing: 6) {
                if isGenerating {
                    ProgressView().controlSize(.small)
                } else {
                    Image(systemName: "sparkles")
                        .font(.system(size: 12, weight: .semibold))
                }
                Text(isGenerating ? "Generating…" : "Generate this week now")
                    .font(CoachFonts.ui(13, weight: .semibold))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(CoachColors.accent.opacity(isGenerating ? 0.5 : 1.0))
            .foregroundStyle(.white)
            .clipShape(RoundedRectangle(cornerRadius: 10))
        }
        .buttonStyle(.plain)
        .disabled(isGenerating)

        if let err = generationError {
            Text(err)
                .font(CoachFonts.ui(11))
                .foregroundStyle(.red)
        }
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

    private var allSessions: [PrescribedSession] { weeklyPlan.sessions.flatMap(\.sessions) }
    private var totalSessions: Int { allSessions.count }
    private var completedSessions: Int { allSessions.filter(\.isResolved).count }
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

                    statusIcon(for: session)
                        .frame(width: 14, height: 14)

                    Text(session.label)
                        .font(CoachFonts.ui(13))
                        .lineLimit(1)
                        .strikethrough(strikethrough(for: session.displayState), color: .secondary)
                        .foregroundStyle(labelColor(for: session.displayState))

                    Spacer()

                    Text(metricString(session))
                        .font(CoachFonts.mono(12))
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    @ViewBuilder
    private func statusIcon(for session: PrescribedSession) -> some View {
        switch session.displayState {
        case .upcoming:
            Circle()
                .fill(session.effortCategory?.color ?? Color.gray.opacity(0.5))
                .frame(width: 10, height: 10)
        case .completed:
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 14))
                .foregroundStyle(CoachColors.teal)
        case .needsReview:
            Image(systemName: "questionmark.circle.fill")
                .font(.system(size: 14))
                .foregroundStyle(Color.orange)
        case .modified:
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 14))
                .foregroundStyle(Color.yellow)
        case .swapped:
            Image(systemName: "arrow.triangle.2.circlepath.circle.fill")
                .font(.system(size: 14))
                .foregroundStyle(Color.purple)
        case .skipped:
            Image(systemName: "xmark.circle.fill")
                .font(.system(size: 14))
                .foregroundStyle(.secondary)
        }
    }

    private func strikethrough(for state: PrescribedSessionDisplayState) -> Bool {
        switch state {
        case .completed, .modified, .swapped, .skipped: return true
        case .upcoming, .needsReview: return false
        }
    }

    private func labelColor(for state: PrescribedSessionDisplayState) -> Color {
        switch state {
        case .upcoming, .needsReview: return .primary
        case .completed, .modified, .swapped, .skipped: return .secondary
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
