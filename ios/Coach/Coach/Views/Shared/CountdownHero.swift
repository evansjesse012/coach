import SwiftUI

/// Race-hero block: serif race name + mono date on the left,
/// big serif countdown number + mono unit on the right.
/// Hairline divider above and below.
struct CountdownHero: View {
    /// Mono uppercase kicker, e.g. "A-RACE", "RACE DAY".
    let kicker: String
    /// Race name rendered in serif.
    let name: String
    /// Subline under the name, e.g. "Sun · Sep 27 · 2026".
    let date: String
    /// Countdown value, e.g. 23.
    let count: Int
    /// Mono uppercase unit, e.g. "WEEKS OUT", "DAYS OUT".
    let unit: String
    /// Color of the kicker. Defaults to `accent` for brand moments.
    var kickerColor: Color = Theme.accent

    var body: some View {
        VStack(spacing: 0) {
            Hairline()

            HStack(alignment: .top, spacing: 16) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(kicker)
                        .font(Theme.Typography.monoLabel)
                        .foregroundStyle(kickerColor)
                        .textCase(.uppercase)
                        .tracking(Theme.Tracking.monoLabel)

                    Text(name)
                        .font(Theme.Typography.serifRace)
                        .foregroundStyle(Theme.ink)
                        .lineLimit(3)
                        .fixedSize(horizontal: false, vertical: true)
                        .minimumScaleFactor(0.85)

                    Text(date)
                        .font(Theme.Typography.monoData)
                        .foregroundStyle(Theme.ink3)
                        .padding(.top, 2)
                }

                Spacer(minLength: 12)

                VStack(alignment: .trailing, spacing: 0) {
                    Text("\(count)")
                        .font(Theme.Typography.serifNumber(72))
                        .foregroundStyle(Theme.ink)
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)

                    Text(unit)
                        .font(Theme.Typography.monoLabel)
                        .foregroundStyle(Theme.ink3)
                        .textCase(.uppercase)
                        .tracking(Theme.Tracking.monoLabel)
                        .padding(.top, 2)
                }
            }
            .padding(.vertical, 22)

            Hairline()
        }
    }
}

#Preview("CountdownHero — Light") {
    VStack {
        CountdownHero(
            kicker: "Race day",
            name: "IRONMAN 70.3 Cozumel",
            date: "Sun · Sep 27 · 2026",
            count: 23,
            unit: "Weeks out"
        )
    }
    .padding(.horizontal, Theme.Spacing.screenH)
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(Theme.bg)
    .preferredColorScheme(.light)
}

#Preview("CountdownHero — Dark") {
    VStack {
        CountdownHero(
            kicker: "Race day",
            name: "IRONMAN 70.3 Cozumel",
            date: "Sun · Sep 27 · 2026",
            count: 23,
            unit: "Weeks out"
        )
    }
    .padding(.horizontal, Theme.Spacing.screenH)
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(Theme.bg)
    .preferredColorScheme(.dark)
}
