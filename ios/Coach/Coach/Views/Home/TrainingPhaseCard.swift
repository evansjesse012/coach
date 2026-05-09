import SwiftUI

/// Compact training-phase card for the Today (Home) tab. Sits beneath
/// the race card and shares its visual chrome — `surface1` fill, 1pt
/// line border, rounded corners — so the two top-of-page cards read as
/// a matched pair.
///
/// Content stays minimal per the redesign brief: kicker on top
/// ("TRAINING PHASE ›"), then a single line that pairs the plain-language
/// phase description with the remaining-weeks count. The full phase
/// content (philosophy, stats, key sessions) lives in `PhaseDetailView`,
/// reached by tapping the card.
///
/// `TrainingPhaseCard` is intentionally separate from `PhaseJourneyCard`
/// (the data-rich phase card on the Plan tab). Both push to the same
/// `PhaseDetailView`, but the surfaces serve different goals: a quiet
/// "where are you" indicator on Today vs. a full phase summary on Plan.
struct TrainingPhaseCard: View {
    let plan: TrainingPlan
    let phase: TrainingPhase
    let phaseDescription: String
    let weeksLeft: Int

    var body: some View {
        NavigationLink {
            PhaseDetailView(plan: plan, phase: phase)
        } label: {
            cardBody
        }
        .buttonStyle(PressDimmedButtonStyle())
    }

    private var cardBody: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text("Training phase")
                    .font(.system(size: 9, weight: .semibold, design: .monospaced))
                    .textCase(.uppercase)
                    .tracking(0.18 * 9)
                    .foregroundStyle(Theme.accent)
                Spacer(minLength: 0)
                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Theme.ink3)
            }
            .padding(.bottom, 10)

            HStack(spacing: 0) {
                Text(phaseDescription)
                    .font(.system(size: 14, weight: .semibold))
                    .tracking(-0.005 * 14)
                    .foregroundStyle(Theme.ink)

                Text(" · ")
                    .font(.system(size: 14, weight: .regular))
                    .foregroundStyle(Theme.ink3)
                    .padding(.horizontal, 4)

                Text(weeksLeftText)
                    .font(.system(size: 11, weight: .regular, design: .monospaced))
                    .tracking(0.02 * 11)
                    .foregroundStyle(Theme.ink2)
            }
            .lineLimit(1)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.surface1)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(Theme.line, lineWidth: 1)
        )
    }

    private var weeksLeftText: String {
        switch weeksLeft {
        case ..<1:  return "last week"
        case 1:     return "1 wk left"
        default:    return "\(weeksLeft) wks left"
        }
    }
}
