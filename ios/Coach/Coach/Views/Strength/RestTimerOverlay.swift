import SwiftUI
import UIKit

/// Compact floating banner shown at the bottom of WorkoutLoggingView while
/// the between-set rest timer is ticking. Taps work on +15 / -15 / skip
/// buttons; the body of the bar displays "mm:ss" and a thin progress line.
struct RestTimerOverlay: View {
    @Environment(DataService.self) private var data
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        let remaining = data.restTimerSecondsRemaining ?? 0
        let total = max(1, data.restTimerTotalSeconds ?? remaining)
        let progress = max(0, min(1, Double(remaining) / Double(total)))

        return VStack(spacing: 6) {
            HStack(alignment: .center, spacing: 10) {
                ZStack {
                    Circle()
                        .fill(CoachColors.accent.opacity(0.18))
                        .frame(width: 34, height: 34)
                    Image(systemName: "timer")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(CoachColors.accent)
                }

                VStack(alignment: .leading, spacing: 1) {
                    Text("REST")
                        .font(CoachFonts.ui(9, weight: .bold))
                        .tracking(0.8)
                        .foregroundStyle(.secondary)
                    Text(formatTime(remaining))
                        .font(CoachFonts.mono(18, weight: .bold))
                        .foregroundStyle(.primary)
                        .monospacedDigit()
                }

                Spacer(minLength: 4)

                Button {
                    data.adjustRestTimer(by: -15)
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                } label: {
                    Text("−15")
                        .font(CoachFonts.ui(12, weight: .bold))
                        .foregroundStyle(.primary)
                        .frame(width: 44, height: 32)
                        .background(Capsule().fill(Color.secondary.opacity(0.15)))
                }
                .buttonStyle(.plain)

                Button {
                    data.adjustRestTimer(by: 15)
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                } label: {
                    Text("+15")
                        .font(CoachFonts.ui(12, weight: .bold))
                        .foregroundStyle(.primary)
                        .frame(width: 44, height: 32)
                        .background(Capsule().fill(Color.secondary.opacity(0.15)))
                }
                .buttonStyle(.plain)

                Button {
                    data.stopRestTimer()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: 32, height: 32)
                        .background(Circle().fill(CoachColors.accent))
                }
                .buttonStyle(.plain)
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.secondary.opacity(0.12))
                    Capsule()
                        .fill(CoachColors.accent)
                        .frame(width: geo.size.width * CGFloat(progress))
                        .animation(.linear(duration: 1), value: progress)
                }
            }
            .frame(height: 3)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(
            (colorScheme == .dark ? CoachColors.darkCard : CoachColors.lightCard)
                .opacity(0.97)
        )
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(CoachColors.accent.opacity(0.35), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.15), radius: 12, y: 6)
    }

    private func formatTime(_ seconds: Int) -> String {
        let m = seconds / 60
        let s = seconds % 60
        return String(format: "%d:%02d", m, s)
    }
}
