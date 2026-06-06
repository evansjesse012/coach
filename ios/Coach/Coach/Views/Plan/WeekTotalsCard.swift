import SwiftUI

/// Two-tier weekly totals card for the week-detail page.
///
/// Tier 1 — endurance: swim / bike / run progress rings (completed vs
/// scheduled time) plus a summary line that can toggle between time and
/// distance.
///
/// Tier 2 — support work (conditional): adherence chips for strength.
/// Rendered only when the week actually includes a support modality.
/// Mobility / yoga / functional are not yet in the data model — see TODO.
struct WeekTotalsCard: View {
    let weeklyPlan: WeeklyPlan

    /// Toggled by the ⇄ control in the endurance summary line.
    @State private var showDistance = false

    var body: some View {
        VStack(spacing: 0) {
            enduranceTier
            if hasSupportWork {
                supportTier
            }
        }
        .padding(Theme.Spacing.cardP)
        .frame(maxWidth: .infinity)
        .background(Theme.surface1)
        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.card))
        .overlay(
            RoundedRectangle(cornerRadius: Theme.Radius.card)
                .strokeBorder(Theme.line, lineWidth: 1)
        )
        .dsCardShadow()
    }

    // MARK: - Tier 1: endurance rings

    private var enduranceTier: some View {
        VStack(spacing: 0) {
            HStack(alignment: .top, spacing: 0) {
                ForEach(EnduranceDiscipline.allCases) { d in
                    ringColumn(d)
                        .frame(maxWidth: .infinity)
                }
            }

            // Solid separator above the summary line.
            Rectangle()
                .fill(Theme.line)
                .frame(height: 1)
                .padding(.top, 12)

            enduranceSummary
                .padding(.top, 12)
        }
    }

    private func ringColumn(_ d: EnduranceDiscipline) -> some View {
        let vol = volume(for: d)
        return VStack(spacing: 8) {
            ring(progress: vol.progress, color: d.color, icon: d.icon)
            durationStyled(minutes: vol.completed, bigSize: 19)
            Text("/ " + durationUpper(vol.planned))
                .font(Theme.Typography.mono(11))
                .foregroundStyle(Theme.ink3)
        }
    }

    private func ring(progress: Double, color: Color, icon: String) -> some View {
        ZStack {
            Circle()
                .stroke(Theme.surface2, lineWidth: 6)
            Circle()
                .trim(from: 0, to: max(0, min(1, progress)))
                .stroke(color, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                .rotationEffect(.degrees(-90))
            Image(systemName: icon)
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(color)
        }
        .frame(width: 72, height: 72)
    }

    private var enduranceSummary: some View {
        HStack(spacing: 6) {
            summaryText
            Spacer(minLength: 6)
            Button {
                showDistance.toggle()
            } label: {
                Image(systemName: "arrow.left.arrow.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Theme.ink3)
            }
            .buttonStyle(.plain)
        }
    }

    /// "🕐 ENDURANCE: <completed> / <planned>", with the completed portion
    /// emphasized. Switches between time and distance via `showDistance`.
    private var summaryText: Text {
        let mono = Theme.Typography.mono(11.5)
        let monoBold = Theme.Typography.mono(11.5, weight: .semibold)
        let label = Text("🕐 ENDURANCE: ").font(mono).foregroundColor(Theme.ink2)
        let completed: String
        let planned: String
        if showDistance {
            completed = milesText(totalCompletedMiles)
            planned = milesText(totalPlannedMiles)
        } else {
            completed = durationUpper(totalCompletedMin)
            planned = durationUpper(totalPlannedMin)
        }
        return label
            + Text(completed).font(monoBold).foregroundColor(Theme.ink)
            + Text(" / " + planned).font(mono).foregroundColor(Theme.ink2)
    }

    // MARK: - Tier 2: support work chips

    private var supportTier: some View {
        VStack(alignment: .leading, spacing: 10) {
            DashedLine()
                .padding(.top, 12)
            Text("SUPPORT WORK")
                .font(Theme.Typography.mono(10, weight: .medium))
                .tracking(1.4)   // ~0.14em on 10pt
                .foregroundStyle(Theme.ink3)
                .padding(.top, 2)
            LazyVGrid(
                columns: [GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8)],
                spacing: 8
            ) {
                ForEach(supportChips) { chip in
                    supportChipView(chip)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func supportChipView(_ c: SupportChip) -> some View {
        HStack(spacing: 10) {
            Text(c.icon)
                .font(.system(size: 16))
            VStack(alignment: .leading, spacing: 2) {
                Text(c.label)
                    .font(Theme.Typography.mono(10, weight: .medium))
                    .tracking(1.0)
                    .foregroundStyle(c.color)
                Text("\(c.completed) / \(c.scheduled)")
                    .font(Theme.Typography.mono(14, weight: .semibold))
                    .foregroundStyle(Theme.ink)
            }
            Spacer(minLength: 0)
            statusCircle(completed: c.completed, scheduled: c.scheduled)
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.surface2)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(Theme.line, lineWidth: 1)
        )
    }

    @ViewBuilder
    private func statusCircle(completed: Int, scheduled: Int) -> some View {
        let size: CGFloat = 20
        if scheduled > 0 && completed >= scheduled {
            // Complete — moss tint + check.
            ZStack {
                Circle().fill(Theme.accent.opacity(0.18))
                Image(systemName: "checkmark")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(Theme.accent)
            }
            .frame(width: size, height: size)
        } else if completed > 0 {
            // Partial — solid border + ½.
            ZStack {
                Circle().strokeBorder(Theme.line, lineWidth: 1.5)
                Text("\u{00BD}")
                    .font(.system(size: 9))
                    .foregroundStyle(Theme.ink3)
            }
            .frame(width: size, height: size)
        } else {
            // Pending — dashed border, empty.
            Circle()
                .strokeBorder(Theme.line, style: StrokeStyle(lineWidth: 1.5, dash: [2, 2]))
                .frame(width: size, height: size)
        }
    }

    private var supportChips: [SupportChip] {
        var out: [SupportChip] = []
        let strength = counts(forType: "strength")
        if strength.scheduled > 0 {
            out.append(SupportChip(
                id: "strength",
                icon: "\u{1F4AA}",          // 💪
                label: "STRENGTH",
                color: Theme.strengthBronze,
                completed: strength.completed,
                scheduled: strength.scheduled
            ))
        }
        // TODO: add mobility (🧘) / yoga / functional chips once those
        // disciplines exist in the Sport data model.
        return out
    }

    private var hasSupportWork: Bool { !supportChips.isEmpty }

    // MARK: - Aggregation

    /// Planned + completed time/distance for an endurance discipline,
    /// summed across every day in the week.
    private func volume(for d: EnduranceDiscipline) -> RingVolume {
        var planned = 0, completed = 0
        var plannedMi = 0.0, completedMi = 0.0
        for day in weeklyPlan.sessions {
            for s in day.sessions where s.type.lowercased() == d.rawValue {
                let pmin = plannedMinutes(s)
                planned += pmin
                plannedMi += s.distanceMiles ?? 0
                if isDone(s) {
                    completed += s.actualDuration ?? pmin
                    completedMi += s.actualDistance ?? (s.distanceMiles ?? 0)
                }
            }
        }
        let progress = planned > 0 ? Double(completed) / Double(planned) : 0
        return RingVolume(
            planned: planned, completed: completed,
            plannedMiles: plannedMi, completedMiles: completedMi,
            progress: progress
        )
    }

    /// Binary adherence counts for a support discipline: scheduled = number
    /// of sessions of that type this week, completed = number marked done.
    private func counts(forType type: String) -> (completed: Int, scheduled: Int) {
        var scheduled = 0, completed = 0
        for day in weeklyPlan.sessions {
            for s in day.sessions where s.type.lowercased() == type {
                scheduled += 1
                if isDone(s) { completed += 1 }
            }
        }
        return (completed, scheduled)
    }

    private func plannedMinutes(_ s: PrescribedSession) -> Int {
        if let d = s.duration, d > 0 { return d }
        if let lo = s.estimatedDurationMin, let hi = s.estimatedDurationMax { return (lo + hi) / 2 }
        return 0
    }

    private func isDone(_ s: PrescribedSession) -> Bool {
        switch s.completionStatus {
        case .completed, .modified, .swapped: return true
        default: return s.completed == true
        }
    }

    private var totalCompletedMin: Int {
        EnduranceDiscipline.allCases.reduce(0) { $0 + volume(for: $1).completed }
    }
    private var totalPlannedMin: Int {
        EnduranceDiscipline.allCases.reduce(0) { $0 + volume(for: $1).planned }
    }
    private var totalCompletedMiles: Double {
        EnduranceDiscipline.allCases.reduce(0) { $0 + volume(for: $1).completedMiles }
    }
    private var totalPlannedMiles: Double {
        EnduranceDiscipline.allCases.reduce(0) { $0 + volume(for: $1).plannedMiles }
    }

    // MARK: - Formatting

    /// Uppercase compact duration, e.g. "2 HR 11 MIN", "57 MIN", "1 HR".
    private func durationUpper(_ minutes: Int) -> String {
        let h = minutes / 60, m = minutes % 60
        if h > 0 && m > 0 { return "\(h) HR \(m) MIN" }
        if h > 0 { return "\(h) HR" }
        return "\(m) MIN"
    }

    private func milesText(_ miles: Double) -> String {
        String(format: "%.1f MI", miles)
    }

    /// Completed time rendered with large numerals and small mono units,
    /// e.g. **57** MIN or **1** HR **10** MIN.
    private func durationStyled(minutes: Int, bigSize: CGFloat) -> Text {
        let h = minutes / 60, m = minutes % 60
        func big(_ s: String) -> Text {
            Text(s).font(.system(size: bigSize, weight: .semibold)).foregroundColor(Theme.ink)
        }
        func unit(_ s: String) -> Text {
            Text(s).font(Theme.Typography.mono(11)).foregroundColor(Theme.ink2)
        }
        if h > 0 && m > 0 { return big("\(h)") + unit(" HR ") + big("\(m)") + unit(" MIN") }
        if h > 0 { return big("\(h)") + unit(" HR") }
        return big("\(m)") + unit(" MIN")
    }
}

// MARK: - Supporting types

private enum EnduranceDiscipline: String, CaseIterable, Identifiable {
    case swim, bike, run
    var id: String { rawValue }

    var color: Color {
        switch self {
        case .swim: return Theme.Discipline.swim.color
        case .bike: return Theme.Discipline.bike.color
        case .run:  return Theme.Discipline.run.color
        }
    }

    /// SF Symbol figure for the discipline, matching the rest of the app
    /// (and the design screenshot) rather than a flat emoji.
    var icon: String {
        switch self {
        case .swim: return "figure.pool.swim"
        case .bike: return "bicycle"
        case .run:  return "figure.run"
        }
    }
}

private struct RingVolume {
    let planned: Int
    let completed: Int
    let plannedMiles: Double
    let completedMiles: Double
    let progress: Double
}

private struct SupportChip: Identifiable {
    let id: String
    let icon: String
    let label: String
    let color: Color
    let completed: Int
    let scheduled: Int
}

/// 1pt dashed horizontal rule using `Theme.line` — the lighter divider that
/// separates the support tier from the endurance tier.
private struct DashedLine: View {
    var body: some View {
        GeometryReader { geo in
            Path { p in
                p.move(to: .zero)
                p.addLine(to: CGPoint(x: geo.size.width, y: 0))
            }
            .stroke(Theme.line, style: StrokeStyle(lineWidth: 1, dash: [4, 3]))
        }
        .frame(height: 1)
    }
}
