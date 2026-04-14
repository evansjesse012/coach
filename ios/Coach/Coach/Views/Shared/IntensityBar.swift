import SwiftUI

/// Proportional horizontal bar showing an IntensityDistribution
/// as four color-coded segments: Easy / Tempo / Threshold / VO2max.
///
/// Used in a few sizes:
/// - `.mini` (height 5): fits on the PlanOverviewCard timeline and PhaseSummaryCard.
/// - `.regular` (height 22): primary rendering inside PhaseDetailContent.
struct IntensityBar: View {
    enum Size {
        case mini
        case regular

        var height: CGFloat {
            switch self {
            case .mini: return 5
            case .regular: return 22
            }
        }

        var cornerRadius: CGFloat {
            switch self {
            case .mini: return 2
            case .regular: return 4
            }
        }
    }

    let distribution: IntensityDistribution
    var size: Size = .regular

    var body: some View {
        let total = max(1, distribution.easy + distribution.tempo + distribution.threshold + distribution.vo2max)
        HStack(spacing: 2) {
            segment(pct: distribution.easy, total: total, color: CoachColors.green)
            segment(pct: distribution.tempo, total: total, color: CoachColors.yellow)
            segment(pct: distribution.threshold, total: total, color: CoachColors.accent)
            segment(pct: distribution.vo2max, total: total, color: CoachColors.red)
        }
        .frame(height: size.height)
        .clipShape(RoundedRectangle(cornerRadius: size.cornerRadius))
    }

    private func segment(pct: Int, total: Int, color: Color) -> some View {
        let frac = Double(pct) / Double(total)
        return Rectangle()
            .fill(color)
            .frame(maxWidth: .infinity)
            .layoutPriority(frac)
            .opacity(pct > 0 ? 1 : 0)
    }
}

/// Legend row (colored dot + "Label pct%") for the four intensity zones.
struct IntensityLegend: View {
    let distribution: IntensityDistribution

    var body: some View {
        HStack(spacing: 12) {
            item("Easy", pct: distribution.easy, color: CoachColors.green)
            item("Tempo", pct: distribution.tempo, color: CoachColors.yellow)
            item("Thresh", pct: distribution.threshold, color: CoachColors.accent)
            item("VO2", pct: distribution.vo2max, color: CoachColors.red)
        }
    }

    private func item(_ label: String, pct: Int, color: Color) -> some View {
        HStack(spacing: 4) {
            Circle().fill(color).frame(width: 8, height: 8)
            Text("\(label) \(pct)%")
                .font(CoachFonts.ui(11))
                .foregroundStyle(.secondary)
        }
    }
}
