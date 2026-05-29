import SwiftUI

// MARK: - Pressable block style
//
// Subtle iOS-standard press dim for tappable header blocks. Matches the
// feel of a UITableViewCell highlight without altering layout.

private struct PressableBlockStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .opacity(configuration.isPressed ? 0.55 : 1.0)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

// MARK: - Training phase card

/// Card sitting beneath the shared `RaceHeroCard` on the Today page. Mirrors
/// the race card's container chrome (surface, border, radius) so the two read
/// as a matched pair: accent kicker, the current phase's plain-language
/// description, and weeks remaining, with a chevron for the tap-through to
/// `PhaseDetailView`.
struct PhaseHeroCard: View {
    let phaseDescription: String
    let weeksLeft: Int   // remaining whole weeks in the phase, 0 = last week

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Training phase")
                    .font(.system(size: 9, weight: .semibold, design: .monospaced))
                    .textCase(.uppercase)
                    .tracking(0.18 * 9)
                    .foregroundStyle(Theme.accent)

                Text(phaseDescription)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(Theme.ink)
                    .fixedSize(horizontal: false, vertical: true)

                Text(weeksLeftText)
                    .font(Theme.Typography.monoMeta)
                    .foregroundStyle(Theme.ink3)
            }

            Spacer(minLength: 8)

            Image(systemName: "chevron.right")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Theme.ink3)
        }
        .padding(Theme.Spacing.cardP)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.surface1)
        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.card))
        .overlay(
            RoundedRectangle(cornerRadius: Theme.Radius.card)
                .strokeBorder(Theme.line, lineWidth: 1)
        )
        .contentShape(Rectangle())
    }

    private var weeksLeftText: String {
        switch weeksLeft {
        case ..<1:  return "Last week of phase"
        case 1:     return "1 week left"
        default:    return "\(weeksLeft) weeks left"
        }
    }
}

// MARK: - Tappable wrappers
//
// The page composes these via NavigationLink so navigation state lives in
// the surrounding NavigationStack. Wrapping in PressableBlockStyle gives
// the blocks the iOS press-dim without dragging in NavigationLink's
// default link-blue tint.

extension View {
    /// Apply the standard pressable-block tap treatment.
    func pressableBlock() -> some View {
        buttonStyle(PressableBlockStyle())
    }
}

// MARK: - Previews

#Preview("Today header — Dark") {
    ScrollView {
        VStack(alignment: .leading, spacing: 16) {
            RaceHeroCard(
                name: "IRONMAN 70.3",
                location: "Cozumel, Mexico",
                date: "Sun · Sep 27 · 2026",
                count: 17,
                unit: "Weeks out"
            )
            PhaseHeroCard(
                phaseDescription: "Building your aerobic base",
                weeksLeft: 2
            )
        }
        .padding(.horizontal, Theme.Spacing.screenH)
        .padding(.top, 16)
    }
    .background(Theme.bg)
    .preferredColorScheme(.dark)
}

#Preview("Today header — Light") {
    ScrollView {
        VStack(alignment: .leading, spacing: 16) {
            RaceHeroCard(
                name: "IRONMAN 70.3",
                location: "Cozumel, Mexico",
                date: "Sun · Sep 27 · 2026",
                count: 17,
                unit: "Weeks out"
            )
            PhaseHeroCard(
                phaseDescription: "Tapering for race day",
                weeksLeft: 0
            )
        }
        .padding(.horizontal, Theme.Spacing.screenH)
        .padding(.top, 16)
    }
    .background(Theme.bg)
    .preferredColorScheme(.light)
}
