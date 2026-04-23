import SwiftUI

struct PlanReviewView: View {
    let plan: TrainingPlan

    @Environment(\.colorScheme) var colorScheme
    @State private var expandedPhases: Set<Int>

    init(plan: TrainingPlan) {
        self.plan = plan
        // Auto-expand the current phase so opening this screen always lands
        // on "what matters now". All other phases start collapsed.
        _expandedPhases = State(initialValue: [plan.currentPhase])
    }

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    header
                    overviewStrip(scrollProxy: proxy)

                    CoachLabel(text: "Phases in detail")
                        .padding(.top, 4)

                    VStack(spacing: 12) {
                        ForEach(sortedPhases) { phase in
                            ExpandablePhaseSection(
                                plan: plan,
                                phase: phase,
                                isCurrent: phase.number == plan.currentPhase,
                                isExpanded: expandedPhases.contains(phase.number),
                                toggle: { toggle(phase) }
                            )
                            .id("phase-\(phase.number)")
                        }
                    }
                }
                .padding()
            }
            .clearsTabBar()
            .background((colorScheme == .dark ? CoachColors.darkBg : CoachColors.lightBg).ignoresSafeArea())
            .navigationTitle("Plan Review")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private var sortedPhases: [TrainingPhase] {
        plan.phases.sorted(by: { $0.number < $1.number })
    }

    private func toggle(_ phase: TrainingPhase) {
        if expandedPhases.contains(phase.number) {
            expandedPhases.remove(phase.number)
        } else {
            expandedPhases.insert(phase.number)
        }
    }

    // MARK: - Header

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("PLAN REVIEW")
                .font(CoachFonts.ui(11, weight: .semibold))
                .tracking(0.8)
                .foregroundStyle(.secondary)
            Text(plan.raceName ?? "Training Plan")
                .font(CoachFonts.display(22, weight: .bold))
            HStack(spacing: 12) {
                Text("\(plan.totalWeeks) weeks")
                    .font(CoachFonts.ui(13))
                    .foregroundStyle(.secondary)
                if let raceDate = plan.raceDate {
                    Text("Race: \(formatDateLong(raceDate))")
                        .font(CoachFonts.ui(13))
                        .foregroundStyle(CoachColors.accent)
                }
            }
            // "You are here" line
            HStack(spacing: 8) {
                if let current = plan.current {
                    HStack(spacing: 4) {
                        Circle()
                            .fill(current.accentColor)
                            .frame(width: 6, height: 6)
                        Text("Week \(plan.currentWeek) of \(plan.totalWeeks) · In \(current.name)")
                            .font(CoachFonts.ui(12, weight: .semibold))
                            .foregroundStyle(current.accentColor)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(current.accentColor.opacity(0.12))
                    .clipShape(Capsule())
                }
                if let weeks = plan.weeksUntilRace() {
                    Text("\(weeks) wk to race")
                        .font(CoachFonts.ui(12))
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.top, 4)
        }
    }

    // MARK: - Phase overview strip

    private func overviewStrip(scrollProxy: ScrollViewProxy) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            CoachLabel(text: "All phases at a glance")
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(sortedPhases) { phase in
                        PhaseSummaryCard(
                            plan: plan,
                            phase: phase,
                            isCurrent: phase.number == plan.currentPhase
                        )
                        .onTapGesture {
                            withAnimation(.easeInOut(duration: 0.3)) {
                                expandedPhases.insert(phase.number)
                                scrollProxy.scrollTo("phase-\(phase.number)", anchor: .top)
                            }
                        }
                    }
                }
                .padding(.horizontal, 2)
                .padding(.vertical, 2)
            }
        }
    }
}

// MARK: - Phase Summary Card (used in the horizontal overview strip)

private struct PhaseSummaryCard: View {
    let plan: TrainingPlan
    let phase: TrainingPhase
    let isCurrent: Bool

    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Text("PHASE \(phase.number)")
                    .font(CoachFonts.ui(10, weight: .semibold))
                    .tracking(0.6)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(phase.accentColor.opacity(0.15))
                    .foregroundStyle(phase.accentColor)
                    .clipShape(Capsule())
                Spacer(minLength: 0)
                if isCurrent {
                    HStack(spacing: 3) {
                        Circle().fill(phase.accentColor).frame(width: 5, height: 5)
                        Text("CURRENT")
                            .font(CoachFonts.ui(9, weight: .bold))
                            .tracking(0.4)
                            .foregroundStyle(phase.accentColor)
                    }
                }
            }

            Text(phase.name)
                .font(CoachFonts.display(18, weight: .bold))

            Text("Wks \(plan.startWeek(for: phase))–\(plan.endWeek(for: phase))")
                .font(CoachFonts.mono(11))
                .foregroundStyle(.secondary)

            if let v = phase.weeklyVolumeRange {
                HStack(alignment: .firstTextBaseline, spacing: 3) {
                    Text("\(formatVolumeValue(v.min))–\(formatVolumeValue(v.max))")
                        .font(CoachFonts.display(15, weight: .bold))
                    Text(v.unit)
                        .font(CoachFonts.ui(10))
                        .foregroundStyle(.secondary)
                    if let s = phase.sessionsPerWeek {
                        Text("· \(s)/wk")
                            .font(CoachFonts.ui(10))
                            .foregroundStyle(.secondary)
                    }
                }
            }

            if let dist = phase.intensityDistribution {
                IntensityBar(distribution: dist, size: .mini)
            }
        }
        .padding(12)
        .frame(width: 170, alignment: .leading)
        .background(colorScheme == .dark ? CoachColors.darkCard : CoachColors.lightCard)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(
                    isCurrent ? phase.accentColor : (colorScheme == .dark ? CoachColors.darkBorder : CoachColors.lightBorder),
                    lineWidth: isCurrent ? 1.5 : 1
                )
        )
        .overlay(alignment: .leading) {
            RoundedRectangle(cornerRadius: 12)
                .fill(phase.accentColor)
                .frame(width: 3)
                .padding(.vertical, 8)
        }
    }
}

// MARK: - Expandable Phase Section

private struct ExpandablePhaseSection: View {
    let plan: TrainingPlan
    let phase: TrainingPhase
    let isCurrent: Bool
    let isExpanded: Bool
    let toggle: () -> Void

    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        CollapsibleCard(
            isExpanded: isExpanded,
            toggle: toggle,
            header: {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 8) {
                        Text("PHASE \(phase.number) OF \(plan.phases.count)")
                            .font(CoachFonts.ui(10, weight: .semibold))
                            .tracking(0.6)
                            .padding(.horizontal, 7)
                            .padding(.vertical, 2)
                            .background(phase.accentColor.opacity(0.15))
                            .foregroundStyle(phase.accentColor)
                            .clipShape(Capsule())
                        if isCurrent {
                            Text("CURRENT")
                                .font(CoachFonts.ui(9, weight: .bold))
                                .tracking(0.4)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(phase.accentColor)
                                .foregroundStyle(.white)
                                .clipShape(Capsule())
                        }
                        Spacer(minLength: 8)
                        Text("Wks \(plan.startWeek(for: phase))–\(plan.endWeek(for: phase))")
                            .font(CoachFonts.mono(11))
                            .foregroundStyle(.secondary)
                    }

                    HStack(alignment: .firstTextBaseline, spacing: 10) {
                        Text(phase.name)
                            .font(CoachFonts.display(20, weight: .bold))
                        if let start = phase.startDate, let end = phase.endDate {
                            Text("\(formatDateShort(start))–\(formatDateShort(end))")
                                .font(CoachFonts.ui(11))
                                .foregroundStyle(.secondary)
                        }
                    }

                    // Compact summary row — visible when collapsed so the user
                    // can compare phases without expanding them.
                    HStack(spacing: 12) {
                        if let v = phase.weeklyVolumeRange {
                            inlineStat(
                                value: "\(formatVolumeValue(v.min))–\(formatVolumeValue(v.max))",
                                unit: v.unit
                            )
                        }
                        if let s = phase.sessionsPerWeek {
                            inlineStat(value: "\(s)", unit: "/wk")
                        }
                        if let dist = phase.intensityDistribution {
                            IntensityBar(distribution: dist, size: .mini)
                                .frame(maxWidth: 70)
                        }
                    }
                }
            }
        ) {
            VStack(alignment: .leading, spacing: 16) {
                if isCurrent, let inPhaseLine = currentPhaseProgressLine {
                    Text(inPhaseLine)
                        .font(CoachFonts.ui(12, weight: .semibold))
                        .foregroundStyle(phase.accentColor)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(phase.accentColor.opacity(0.1))
                        .clipShape(Capsule())
                }
                PhaseDetailContent(plan: plan, phase: phase, showHeader: false)
            }
            .padding(.top, 4)
        }
        .overlay(alignment: .leading) {
            RoundedRectangle(cornerRadius: 12)
                .fill(phase.accentColor)
                .frame(width: 3)
                .padding(.vertical, 10)
        }
    }

    private func inlineStat(value: String, unit: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 2) {
            Text(value)
                .font(CoachFonts.ui(13, weight: .semibold))
                .foregroundStyle(.primary)
            Text(unit)
                .font(CoachFonts.ui(10))
                .foregroundStyle(.secondary)
        }
    }

    /// "Week 3 of 6 in this phase · 3 weeks remaining" — only when current.
    private var currentPhaseProgressLine: String? {
        let weekInPhase = plan.weekIndexInPhase(phase)
        guard weekInPhase > 0 else { return nil }
        var parts = ["Week \(weekInPhase) of \(phase.weeks) in this phase"]
        if let days = plan.daysRemainingInPhase(phase), days > 0 {
            let weeks = Int((Double(days) / 7.0).rounded())
            if weeks > 0 {
                parts.append("\(weeks) wk remaining")
            } else {
                parts.append("\(days) days remaining")
            }
        }
        return parts.joined(separator: " · ")
    }
}
