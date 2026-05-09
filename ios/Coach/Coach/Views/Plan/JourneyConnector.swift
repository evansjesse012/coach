import SwiftUI

/// Vertical hairline that bridges the journey timeline and the phase
/// detail card. Sits between the two in the page's vertical layout and
/// drops down from the selected phase's center on the line above to
/// the top of the card below — a visual cue that "this is the segment
/// that produced this content."
///
/// Geometry mirrors `JourneyTimeline` so the x-coordinate of the
/// selected phase's center matches between the two views; the constants
/// are duplicated here intentionally rather than coupling the two
/// components, since the connector's job is only x-positioning.
///
/// Color follows the selected phase's status:
/// - current → solid accent
/// - completed / upcoming → soft gradient from line color (top) fading
///   to clear (bottom), so the connector reads as a quiet attachment
///   rather than a hard rule
///
/// Position animates on selection change. The tap handler in
/// `JourneyTimeline` already wraps the `selectedId` mutation in a
/// `withAnimation(.spring(response: 0.35, …))`, so the slide here
/// happens automatically — no per-component animation modifier needed.
struct JourneyConnector: View {
    let phases: [SeasonPhase]
    let totalWeeks: Int
    let selectedId: Int?

    private let leftInset: CGFloat = 6
    private let rightInset: CGFloat = 14
    private let height: CGFloat = 22
    private let thickness: CGFloat = 1.5

    var body: some View {
        GeometryReader { geo in
            let lineLength = max(0, geo.size.width - leftInset - rightInset)
            // Render the connector unconditionally and toggle visibility
            // via opacity. SwiftUI only animates `.position()` on views
            // it considers persistent across renders — wrapping in
            // `if let` makes the connector a fresh view on every
            // selection change, so `.position()` would teleport instead
            // of slide. Using a default x + opacity preserves identity
            // and lets the spring transaction in `JourneyTimeline`'s
            // tap handler propagate cleanly.
            let centerX = selectedCenterX(lineLength: lineLength) ?? 0
            connectorLine
                .frame(width: thickness, height: height)
                .position(x: leftInset + centerX, y: height / 2)
                .opacity(selectedId == nil ? 0 : 1)
        }
        .frame(height: height)
    }

    @ViewBuilder
    private var connectorLine: some View {
        if isSelectedCurrent() {
            Rectangle().fill(Theme.accent)
        } else {
            // Soft gradient from line color (top) to transparent (bottom)
            // so the connector "fades into" the card below.
            Rectangle().fill(
                LinearGradient(
                    colors: [Theme.line, Theme.line.opacity(0)],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
        }
    }

    /// X-offset of the selected phase's center, measured from the left
    /// edge of the line track (not the view). Returns nil if there's no
    /// selection or the id can't be matched.
    private func selectedCenterX(lineLength: CGFloat) -> CGFloat? {
        guard let sid = selectedId, !phases.isEmpty else { return nil }
        let totalW = max(1, totalWeeks)
        var cum = 0
        for phase in phases {
            let startFrac = CGFloat(cum) / CGFloat(totalW)
            cum += phase.weeks
            let endFrac = CGFloat(cum) / CGFloat(totalW)
            if phase.id == sid {
                let mid = (startFrac + endFrac) / 2
                return mid * lineLength
            }
        }
        return nil
    }

    private func isSelectedCurrent() -> Bool {
        guard let sid = selectedId else { return false }
        return phases.first(where: { $0.id == sid })?.status == .current
    }
}
