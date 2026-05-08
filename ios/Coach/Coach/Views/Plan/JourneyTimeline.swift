import SwiftUI

/// Horizontal "journey" line that visualizes phase progression across the
/// season. Built incrementally per the redesign brief; this iteration
/// (step 4) layers phase labels above the bare line shipped in step 3.
/// Tappability (step 5) and the connector to the detail card (step 7)
/// follow.
///
/// Coordinate system. The view is laid out as two stacked rows inside
/// one `GeometryReader`:
///
///   ┌──── label area (height = labelAreaHeight) ────┐
///   │      Foundation     Base    Build · Threshold │
///   │                                  Build · Peak │
///   ├── gap ──┤
///   │  ─────────────● ─────|────|────|────|─────|◣  │   ← line row
///   └────────────────────────────────────────────────┘
///
/// Labels are absolute-positioned at each phase's geometric center on
/// the line below. Their containing frame is fixed-height (one and a
/// half typical lines tall) and bottom-aligns its text so single-line
/// and two-line labels share the same baseline. Width is constrained
/// to the phase's proportional slice of the line so a wide label can't
/// bleed onto a neighbor; `minimumScaleFactor` prevents truncation when
/// a name happens to overflow a narrow phase.
struct JourneyTimeline: View {
    let phases: [SeasonPhase]
    let currentWeek: Int
    let totalWeeks: Int
    /// Two-way binding for the currently-selected phase id. Tapping a
    /// phase updates this; the parent uses it to drive the detail card.
    @Binding var selectedId: Int?

    // Layout constants tuned in one place so the same numbers don't drift
    // across the line, ticks, dot, flag, and label row.
    private let leftInset: CGFloat = 6
    private let rightInset: CGFloat = 14
    private let trackHeight: CGFloat = 1.5
    private let ringThickness: CGFloat = 3
    private let tickHeight: CGFloat = 8
    private let dotOuter: CGFloat = 10
    private let dotInner: CGFloat = 4

    private let labelAreaHeight: CGFloat = 30
    private let labelLineGap: CGFloat = 8
    private let lineRowHeight: CGFloat = 16

    private var totalHeight: CGFloat {
        labelAreaHeight + labelLineGap + lineRowHeight
    }

    var body: some View {
        GeometryReader { geo in
            let labelCenterY = labelAreaHeight / 2
            let lineY = labelAreaHeight + labelLineGap + lineRowHeight / 2
            let lineStartX = leftInset
            let lineLength = max(0, geo.size.width - leftInset - rightInset)
            let totalW = max(1, totalWeeks)
            let todayFraction = min(1, max(0, CGFloat(currentWeek) / CGFloat(totalW)))
            let todayX = lineStartX + todayFraction * lineLength
            let ranges = phaseRanges(lineStartX: lineStartX, lineLength: lineLength, totalW: totalW)

            ZStack(alignment: .topLeading) {
                // Phase labels — bottom-aligned in a fixed-height frame so
                // single-line "Foundation" and two-line "Build · Threshold"
                // share a baseline regardless of line count.
                ForEach(Array(phases.enumerated()), id: \.offset) { idx, phase in
                    let range = ranges[idx]
                    Text(phase.displayName)
                        .font(labelFont(for: phase))
                        .foregroundStyle(labelColor(for: phase))
                        .multilineTextAlignment(.center)
                        .lineSpacing(0)
                        .lineLimit(2)
                        .minimumScaleFactor(0.7)
                        .frame(width: range.width, height: labelAreaHeight, alignment: .bottom)
                        .position(x: range.center, y: labelCenterY)
                }

                // Base track — full-length thin line.
                Rectangle()
                    .fill(Theme.line)
                    .frame(width: lineLength, height: trackHeight)
                    .position(x: lineStartX + lineLength / 2, y: lineY)

                // Filled progress track from start to today.
                Rectangle()
                    .fill(Theme.accent)
                    .frame(width: max(0, todayX - lineStartX), height: trackHeight)
                    .position(x: lineStartX + (todayX - lineStartX) / 2, y: lineY)

                // Selected phase ring — thicker stroke over the segment of
                // the line corresponding to the selected phase. Accent (50%)
                // when the selected phase is the current phase; otherwise
                // primary text color (35%) so completed/upcoming selections
                // read as a quieter neutral highlight.
                if let sid = selectedId, let idx = phases.firstIndex(where: { $0.id == sid }) {
                    let range = ranges[idx]
                    let isCurrent = phases[idx].status == .current
                    Rectangle()
                        .fill(isCurrent ? Theme.accent.opacity(0.5) : Theme.ink.opacity(0.35))
                        .frame(width: range.width, height: ringThickness)
                        .position(x: range.center, y: lineY)
                }

                // Phase boundary ticks. Color flips at today: accent (60%
                // alpha) for boundaries already crossed, neutral line2 for
                // boundaries ahead.
                ForEach(Array(boundaryXs(lineStartX: lineStartX, lineLength: lineLength).enumerated()), id: \.offset) { _, x in
                    Rectangle()
                        .fill(x <= todayX ? Theme.accent.opacity(0.6) : Theme.line2)
                        .frame(width: 1, height: tickHeight)
                        .position(x: x, y: lineY)
                }

                // Today donut: outer accent dot with a soft accent-tinted
                // glow; inner background-color dot punches the donut.
                Circle()
                    .fill(Theme.accent)
                    .frame(width: dotOuter, height: dotOuter)
                    .shadow(color: Theme.accent.opacity(0.5), radius: 4)
                    .overlay(
                        Circle()
                            .fill(Theme.bg)
                            .frame(width: dotInner, height: dotInner)
                    )
                    .position(x: todayX, y: lineY)

                // Race-day flag at the right end — small mast with a
                // right-pointing triangular flag on top.
                raceFlag(x: lineStartX + lineLength, y: lineY)

                // Per-phase tap targets — transparent rectangles spanning
                // the full vertical extent of the timeline so a tap
                // anywhere in a phase's column (label or line area)
                // selects it. Drawn last so they sit on top of all visual
                // layers; Color.clear has no fill, so nothing is obscured.
                ForEach(Array(phases.enumerated()), id: \.offset) { idx, phase in
                    let range = ranges[idx]
                    Color.clear
                        .contentShape(Rectangle())
                        .frame(width: range.width, height: totalHeight)
                        .position(x: range.center, y: totalHeight / 2)
                        .onTapGesture {
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                                selectedId = phase.id
                            }
                        }
                }
            }
            .frame(width: geo.size.width, height: totalHeight, alignment: .topLeading)
        }
        .frame(height: totalHeight)
    }

    // MARK: - Sub-views

    @ViewBuilder
    private func raceFlag(x: CGFloat, y: CGFloat) -> some View {
        let color = Theme.ink2.opacity(0.7)
        ZStack(alignment: .topLeading) {
            Rectangle()
                .fill(color)
                .frame(width: 1.5, height: 12)
                .position(x: x, y: y)
            Path { p in
                p.move(to: CGPoint(x: x, y: y - 6))
                p.addLine(to: CGPoint(x: x + 6, y: y - 3))
                p.addLine(to: CGPoint(x: x, y: y))
                p.closeSubpath()
            }
            .fill(color)
        }
    }

    // MARK: - Geometry

    /// Per-phase center x-coordinate and slot width on the line. Used
    /// both to position labels above the line and (in step 5) to build
    /// the per-phase tap targets across the same x-spans.
    private func phaseRanges(lineStartX: CGFloat, lineLength: CGFloat, totalW: Int) -> [(center: CGFloat, width: CGFloat)] {
        var cum = 0
        var out: [(CGFloat, CGFloat)] = []
        out.reserveCapacity(phases.count)
        for p in phases {
            let startFrac = CGFloat(cum) / CGFloat(totalW)
            cum += p.weeks
            let endFrac = CGFloat(cum) / CGFloat(totalW)
            let startX = lineStartX + startFrac * lineLength
            let endX = lineStartX + endFrac * lineLength
            out.append((center: (startX + endX) / 2, width: max(0, endX - startX)))
        }
        return out
    }

    /// Right-edge x-coordinates for every phase — used to draw boundary
    /// ticks at each cumulative-weeks position.
    private func boundaryXs(lineStartX: CGFloat, lineLength: CGFloat) -> [CGFloat] {
        let totalW = max(1, totalWeeks)
        var cum = 0
        return phases.map { p in
            cum += p.weeks
            let frac = CGFloat(cum) / CGFloat(totalW)
            return lineStartX + frac * lineLength
        }
    }

    // MARK: - Label styling

    private func labelFont(for phase: SeasonPhase) -> Font {
        switch phase.status {
        case .current:   return .system(size: 11.5, weight: .bold)
        case .completed: return .system(size: 10.5, weight: .semibold)
        case .upcoming:  return .system(size: 10.5, weight: .semibold)
        }
    }

    /// Label color follows status, then lifts on selection: a selected
    /// completed/upcoming label moves to primary ink so it reads as
    /// active; a selected current label stays in accent so the "you are
    /// here" cue isn't lost when the user taps it.
    private func labelColor(for phase: SeasonPhase) -> Color {
        let isSelected = (selectedId == phase.id)
        switch phase.status {
        case .current:   return Theme.accent
        case .completed: return isSelected ? Theme.ink : Theme.ink2
        case .upcoming:  return isSelected ? Theme.ink : Theme.ink3
        }
    }
}
