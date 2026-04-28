import SwiftUI

// MARK: - ReadinessChip
//
// Small one-line pill that surfaces today's TSB ("form") on the Today
// header. Tapping switches to the Stats tab so the athlete can dig
// into the chart. When there's no load data yet (new install, empty
// table), renders a "still calibrating" placeholder.

struct ReadinessChip: View {
    let tsb: Double?
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 8) {
                Circle()
                    .fill(dotColor)
                    .frame(width: 7, height: 7)

                Text(kicker)
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                    .textCase(.uppercase)
                    .tracking(1.4)
                    .foregroundStyle(Theme.ink3)

                if let tsb {
                    Text(String(format: "%+.0f", tsb))
                        .font(.system(size: 13, weight: .semibold, design: .monospaced))
                        .foregroundStyle(Theme.ink)
                    Text(label(for: tsb))
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(Theme.ink2)
                } else {
                    Text("Still calibrating")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(Theme.ink3)
                }

                Spacer(minLength: 0)

                Image(systemName: "chevron.right")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(Theme.ink3)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(
                Capsule()
                    .fill(Theme.surface1)
            )
            .overlay(
                Capsule()
                    .stroke(Theme.line, lineWidth: 1)
            )
        }
        .buttonStyle(ChipPress())
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityText)
    }

    private var kicker: String { "Form" }

    private var dotColor: Color {
        guard let tsb else { return Theme.ink3 }
        switch tsb {
        case 25...:                 return Theme.ink2          // detraining
        case 5..<25:                return Theme.accent        // fresh
        case -10..<5:               return Theme.ink2          // neutral
        case -30..<(-10):           return Theme.accentDark    // optimal training
        case -50..<(-30):           return Theme.modifiedAccent // overreaching
        default:                    return Theme.warn          // high risk
        }
    }

    /// Athlete-facing form label. Friendlier than the dry TrainingPeaks
    /// names — Race-Ready/Optimal/Buried plays better than Transitional/
    /// Optimal training/High risk.
    private func label(for tsb: Double) -> String {
        switch tsb {
        case 25...:        return "Overtapered"
        case 10..<25:      return "Race-ready"
        case 5..<10:       return "Fresh"
        case -10..<5:      return "Balanced"
        case -20..<(-10):  return "Absorbing"
        case -30..<(-20):  return "Digging"
        case -50..<(-30):  return "Overreaching"
        default:           return "Buried"
        }
    }

    private var accessibilityText: String {
        guard let tsb else { return "Form is still calibrating. Double tap to open Stats." }
        return "Form \(Int(tsb.rounded())), \(label(for: tsb)). Double tap to open Stats."
    }
}

private struct ChipPress: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .opacity(configuration.isPressed ? 0.75 : 1.0)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

#Preview("Readiness chip — Light") {
    VStack(spacing: 12) {
        ReadinessChip(tsb: 14, onTap: {})
        ReadinessChip(tsb: -3, onTap: {})
        ReadinessChip(tsb: -22, onTap: {})
        ReadinessChip(tsb: -38, onTap: {})
        ReadinessChip(tsb: -55, onTap: {})
        ReadinessChip(tsb: nil, onTap: {})
    }
    .padding(20)
    .background(Theme.bg)
    .preferredColorScheme(.light)
}

#Preview("Readiness chip — Dark") {
    VStack(spacing: 12) {
        ReadinessChip(tsb: 14, onTap: {})
        ReadinessChip(tsb: -3, onTap: {})
        ReadinessChip(tsb: -22, onTap: {})
        ReadinessChip(tsb: -38, onTap: {})
        ReadinessChip(tsb: -55, onTap: {})
        ReadinessChip(tsb: nil, onTap: {})
    }
    .padding(20)
    .background(Theme.bg)
    .preferredColorScheme(.dark)
}
