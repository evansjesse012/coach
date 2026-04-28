import SwiftUI

// MARK: - FinishWorkoutSheet
//
// Captures session RPE (1–10 Borg CR-10) at workout end. The number drives
// the session-RPE TSS estimate (Foster: TSS ≈ RPE × duration_min / 10),
// which is the validated method for resistance work — volume-load and
// HR-based methods don't translate well to strength training.
//
// Skipping is one tap. When skipped, the TSS ladder falls back to a
// sport-default estimate so the athlete isn't penalized for opting out.

struct FinishWorkoutSheet: View {
    let completedSets: Int
    let exerciseCount: Int
    let onFinish: (Int?) -> Void   // RPE 1–10, or nil for "skip"
    let onCancel: () -> Void

    @State private var rpe: Int? = nil

    var body: some View {
        VStack(spacing: 0) {
            header
            ratingScale
                .padding(.top, 24)
            descriptor
                .padding(.top, 16)
                .frame(minHeight: 36)
            Spacer(minLength: 0)
            actions
                .padding(.horizontal, 22)
                .padding(.bottom, 20)
        }
        .padding(.top, 12)
    }

    // MARK: - Subviews

    private var header: some View {
        VStack(spacing: 4) {
            Text("How hard was it?")
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(Theme.ink)
            Text("\(completedSets) sets · \(exerciseCount) exercises")
                .font(.system(size: 13, weight: .regular, design: .monospaced))
                .foregroundStyle(Theme.ink3)
        }
        .padding(.horizontal, 22)
    }

    /// 1–10 pill row. Tapping a number selects it; selected pill fills
    /// with accent. The full row is one decision.
    private var ratingScale: some View {
        HStack(spacing: 6) {
            ForEach(1...10, id: \.self) { n in
                Button {
                    rpe = n
                } label: {
                    Text("\(n)")
                        .font(.system(size: 14, weight: .semibold, design: .monospaced))
                        .frame(maxWidth: .infinity)
                        .frame(height: 44)
                        .background(
                            RoundedRectangle(cornerRadius: 10)
                                .fill(rpe == n ? Theme.accent : Theme.surface1)
                        )
                        .foregroundStyle(rpe == n ? Theme.accentInk : Theme.ink)
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(rpe == n ? Color.clear : Theme.line, lineWidth: 1)
                        )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 14)
    }

    /// Short label under the scale that updates as the athlete picks. Keeps
    /// a fixed height so the layout doesn't jump.
    @ViewBuilder
    private var descriptor: some View {
        if let n = rpe {
            Text(label(for: n))
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(Theme.ink2)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 22)
        } else {
            Text("Tap a number — 1 (very easy) to 10 (max effort).")
                .font(.system(size: 13, weight: .regular))
                .foregroundStyle(Theme.ink3)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 22)
        }
    }

    private var actions: some View {
        VStack(spacing: 10) {
            Button {
                onFinish(rpe)
            } label: {
                Text("Finish workout")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Theme.accentInk)
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(Capsule().fill(Theme.accent))
            }
            .buttonStyle(.plain)

            HStack(spacing: 8) {
                Button("Skip RPE") { onFinish(nil) }
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(Theme.ink2)
                Spacer()
                Button("Keep logging") { onCancel() }
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(Theme.ink3)
            }
            .padding(.horizontal, 4)
        }
    }

    /// Borg CR-10 anchors. Athlete-readable phrasing — no jargon.
    private func label(for n: Int) -> String {
        switch n {
        case 1:  return "Very easy — could go all day."
        case 2:  return "Easy — light effort."
        case 3:  return "Moderate — comfortable."
        case 4:  return "Somewhat hard — talking is easy."
        case 5:  return "Hard — talking is harder."
        case 6:  return "Hard+ — focused effort."
        case 7:  return "Very hard — short sentences only."
        case 8:  return "Very hard+ — borderline maximal."
        case 9:  return "Extremely hard — near max."
        case 10: return "Maximal — couldn't have done more."
        default: return ""
        }
    }
}

#Preview("Finish — Light") {
    FinishWorkoutSheet(
        completedSets: 18,
        exerciseCount: 5,
        onFinish: { _ in },
        onCancel: {}
    )
    .background(Theme.bg)
    .preferredColorScheme(.light)
}

#Preview("Finish — Dark") {
    FinishWorkoutSheet(
        completedSets: 18,
        exerciseCount: 5,
        onFinish: { _ in },
        onCancel: {}
    )
    .background(Theme.bg)
    .preferredColorScheme(.dark)
}
