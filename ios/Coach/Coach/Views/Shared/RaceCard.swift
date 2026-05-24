import SwiftUI

/// Shared race card used at the top of both the Today (Home) and Plan
/// tabs. Replaces `RaceBlockView` (Home, hairline-block treatment) and
/// `CountdownHero` (Plan, hairline-bookended hero) with a single card
/// container — `surface1` fill, 1pt line border, rounded corners — so
/// both pages reach for the same component and the same visual language.
///
/// Two columns: race name + location + formatted date on the left, big
/// serif countdown number + mono unit on the right (last-text-baseline
/// aligned so the unit lines up with the date row).
///
/// `kicker` lets the caller stamp a small section label in the top-left
/// — Home passes "Training for"; Plan passes "A-Race" (the page already
/// says "Training Plan" so a "Training for" kicker would echo the
/// header). Pass nil to omit.
///
/// When `eventId` is non-nil the card wraps in a `NavigationLink` to
/// `RaceDetailView` and shows a drill chevron next to the kicker so the
/// tap affordance is legible. When nil, it renders flat.
struct RaceCard: View {
    let raceName: String
    let location: String?
    let dateString: String      // pre-formatted, e.g. "Sun · Sep 27 · 2026"
    let count: Int
    let unit: String            // "Weeks out", "Day out", "Today", etc.
    var kicker: String? = nil
    var eventId: String? = nil
    /// Whether to render a drill chevron in the top-right when the card
    /// is navigable. Defaults to true (Home, where the chevron advertises
    /// the tap among many other tap targets). Plan passes `false`: the
    /// race card is already the page's iconic header — the chrome plus
    /// the lack of a kicker is enough affordance, and dropping the
    /// chevron also removes the otherwise-empty top row that introduced
    /// excess space above the race name.
    var showChevron: Bool = true

    var body: some View {
        if let eventId {
            NavigationLink {
                RaceDetailView(eventId: eventId)
            } label: {
                cardBody(showChevron: showChevron)
            }
            .buttonStyle(PressDimmedButtonStyle())
        } else {
            cardBody(showChevron: false)
        }
    }

    private func cardBody(showChevron: Bool) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            if kicker != nil || showChevron {
                topRow(showChevron: showChevron)
                    .padding(.bottom, 4)
            }

            HStack(alignment: .lastTextBaseline, spacing: 16) {
                leftColumn
                    .frame(maxWidth: .infinity, alignment: .leading)
                rightColumn
                    .fixedSize()
            }
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

    private func topRow(showChevron: Bool) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            if let kicker {
                Text(kicker)
                    .font(.system(size: 9, weight: .semibold, design: .monospaced))
                    .textCase(.uppercase)
                    .tracking(0.18 * 9)
                    .foregroundStyle(Theme.accent)
            }
            Spacer(minLength: 0)
            if showChevron {
                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Theme.ink3)
            }
        }
    }

    private var leftColumn: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(raceName)
                .font(.system(size: 24, weight: .medium, design: .serif))
                .tracking(-0.015 * 24)
                .lineSpacing(24 * 0.05)
                .foregroundStyle(Theme.ink)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.bottom, 6)

            if let location, !location.isEmpty {
                Text(location)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(Theme.ink2)
                    .padding(.bottom, 4)
            }

            Text(dateString)
                .font(.system(size: 11, weight: .regular, design: .monospaced))
                .tracking(0.06 * 11)
                .foregroundStyle(Theme.ink3)
        }
    }

    private var rightColumn: some View {
        // last-text-baseline parent: the trailing unit lines up with the
        // date row in the left column; the big serif number sits above.
        VStack(alignment: .trailing, spacing: 4) {
            Text("\(count)")
                .font(.system(size: 56, weight: .regular, design: .serif))
                .tracking(-0.04 * 56)
                .foregroundStyle(Theme.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.6)

            Text(unit)
                .font(.system(size: 9, weight: .semibold, design: .monospaced))
                .textCase(.uppercase)
                .tracking(0.2 * 9)
                .foregroundStyle(Theme.ink3)
        }
    }
}

#Preview("RaceCard — Home (with kicker)") {
    VStack(spacing: 16) {
        RaceCard(
            raceName: "IRONMAN 70.3 Cozumel",
            location: "Cozumel, Mexico",
            dateString: "Sun · Sep 27 · 2026",
            count: 22,
            unit: "Weeks out",
            kicker: "Training for",
            eventId: "preview"
        )
        RaceCard(
            raceName: "Race Day",
            location: nil,
            dateString: "Sun · Sep 27 · 2026",
            count: 0,
            unit: "Today",
            kicker: "Training for",
            eventId: "preview"
        )
    }
    .padding()
    .background(Theme.bg)
}

#Preview("RaceCard — Plan (no kicker, A-Race)") {
    RaceCard(
        raceName: "IRONMAN 70.3 Cozumel",
        location: "Cozumel, Mexico",
        dateString: "Sun · Sep 27 · 2026",
        count: 22,
        unit: "Weeks out",
        kicker: "A-Race",
        eventId: "preview"
    )
    .padding()
    .background(Theme.bg)
}
