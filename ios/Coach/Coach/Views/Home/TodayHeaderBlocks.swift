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

// MARK: - Shared kicker
//
// "Training for ›" / "Training phase ›" — accent-colored mono uppercase
// label with an inline chevron. Used as the kicker on both header blocks.

private struct BlockKicker: View {
    let title: String

    var body: some View {
        HStack(spacing: 5) {
            Text(title)
                .font(.system(size: 9, weight: .semibold, design: .monospaced))
                .textCase(.uppercase)
                .tracking(0.18 * 9) // 0.18em on 9pt
                .foregroundStyle(Theme.accent)
            Image(systemName: "chevron.right")
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(Theme.accent)
        }
    }
}

// MARK: - Race block ("Training for")

/// Two-column header pinned to the top of the Today page:
/// kicker + serif race name + location + mono date on the left,
/// big serif countdown number + unit on the right. Bottom-aligned so the
/// number's bottom sits on the date line, with the unit hanging below.
struct RaceBlockView: View {
    let raceName: String
    let location: String?
    let date: String       // formatted "Sun · Sep 27 · 2026"
    let count: Int
    let unit: String       // "Weeks out", "Day out", "Today", etc.

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Last-baseline alignment puts the unit ("Weeks out") on the
            // same line as the date, with the big number sitting above.
            // The row's bottom is the shared baseline + descent, so the
            // hairline ends up tight under the date/unit row.
            HStack(alignment: .lastTextBaseline, spacing: 16) {
                VStack(alignment: .leading, spacing: 0) {
                    BlockKicker(title: "Training for")
                        .padding(.bottom, 8)

                    Text(raceName)
                        .font(.system(size: 26, weight: .medium, design: .serif))
                        .tracking(-0.015 * 26) // -0.015em
                        .lineSpacing(26 * 0.05) // 1.05 line-height
                        .foregroundStyle(Theme.ink)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.bottom, 6)

                    if let location, !location.isEmpty {
                        Text(location)
                            .font(.system(size: 16, weight: .medium))
                            .foregroundStyle(Theme.ink2)
                            .lineSpacing(16 * 0.3)
                            .padding(.bottom, 4)
                    }

                    Text(date)
                        .font(.system(size: 11, weight: .regular, design: .monospaced))
                        .tracking(0.06 * 11)
                        .foregroundStyle(Theme.ink3)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                // Right column — big number on top, unit beneath. The
                // VStack's lastTextBaseline is the unit's baseline, so
                // unit lines up horizontally with the date in the left
                // column.
                VStack(alignment: .trailing, spacing: 6) {
                    Text("\(count)")
                        .font(.system(size: 64, weight: .regular, design: .serif))
                        .tracking(-0.04 * 64)
                        .foregroundStyle(Theme.ink)
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)

                    Text(unit)
                        .font(.system(size: 9, weight: .semibold, design: .monospaced))
                        .textCase(.uppercase)
                        .tracking(0.2 * 9)
                        .foregroundStyle(Theme.ink3)
                }
                .fixedSize()
            }
            .padding(.top, 4)
            .padding(.bottom, 14)

            Hairline()
        }
        .contentShape(Rectangle())
    }
}

// MARK: - Training phase block

/// Compact header block sitting beneath the race block: kicker on top,
/// then a single line of "Plain phase description · N wks left".
struct TrainingPhaseBlockView: View {
    let phaseDescription: String
    let weeksLeft: Int   // remaining whole weeks in the phase, 0 = last week

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            BlockKicker(title: "Training phase")
                .padding(.bottom, 8)

            HStack(spacing: 0) {
                Text(phaseDescription)
                    .font(.system(size: 13, weight: .semibold))
                    .tracking(-0.005 * 13)
                    .foregroundStyle(Theme.ink)

                Text(" · ")
                    .font(.system(size: 13, weight: .regular))
                    .foregroundStyle(Theme.ink3)
                    .padding(.horizontal, 6)

                Text(weeksLeftText)
                    .font(.system(size: 11, weight: .regular, design: .monospaced))
                    .tracking(0.02 * 11)
                    .foregroundStyle(Theme.ink2)
            }
            .lineLimit(1)
            .padding(.top, 0)

            Spacer().frame(height: 14)

            Hairline()
        }
        .padding(.top, 4)
        .contentShape(Rectangle())
    }

    private var weeksLeftText: String {
        switch weeksLeft {
        case ..<1:  return "last week"
        case 1:     return "1 wk left"
        default:    return "\(weeksLeft) wks left"
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

#Preview("Today header — Light") {
    ScrollView {
        VStack(alignment: .leading, spacing: 16) {
            RaceBlockView(
                raceName: "IRONMAN 70.3",
                location: "Cozumel, Mexico",
                date: "Sun · Sep 27 · 2026",
                count: 22,
                unit: "Weeks out"
            )
            TrainingPhaseBlockView(
                phaseDescription: "Building your aerobic base",
                weeksLeft: 2
            )
        }
        .padding(.horizontal, Theme.Spacing.screenH)
        .padding(.top, 16)
    }
    .background(Theme.bg)
    .preferredColorScheme(.light)
}

#Preview("Today header — Dark") {
    ScrollView {
        VStack(alignment: .leading, spacing: 16) {
            RaceBlockView(
                raceName: "IRONMAN 70.3",
                location: "Cozumel, Mexico",
                date: "Sun · Sep 27 · 2026",
                count: 22,
                unit: "Weeks out"
            )
            TrainingPhaseBlockView(
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

#Preview("Race block — long name & race week") {
    VStack(alignment: .leading, spacing: 16) {
        RaceBlockView(
            raceName: "Boston Marathon Qualifier — Anchorage",
            location: "Anchorage, Alaska",
            date: "Sat · Jun 14 · 2026",
            count: 1,
            unit: "Day out"
        )
        RaceBlockView(
            raceName: "Race Day",
            location: nil,
            date: "Sun · Sep 27 · 2026",
            count: 0,
            unit: "Today"
        )
        TrainingPhaseBlockView(
            phaseDescription: "Tapering for race day",
            weeksLeft: 0
        )
        TrainingPhaseBlockView(
            phaseDescription: "Growing your weekly volume",
            weeksLeft: 1
        )
    }
    .padding(.horizontal, Theme.Spacing.screenH)
    .padding(.top, 16)
    .background(Theme.bg)
}
