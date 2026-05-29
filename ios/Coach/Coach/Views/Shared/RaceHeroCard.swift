import SwiftUI

// MARK: - Race hero card

/// Containerized race countdown — the single race-hero card shared by the
/// Today and Plan tabs. Race type as the title, location and date beneath it,
/// and a big serif countdown number + mono unit on the right.
struct RaceHeroCard: View {
    /// Race type, e.g. "IRONMAN 70.3" — location is rendered separately below.
    let name: String
    let location: String?
    /// Formatted date line, e.g. "Sun · Sep 27 · 2026".
    let date: String
    let count: Int
    /// Mono uppercase unit, e.g. "Weeks out", "Day out", "Today".
    let unit: String

    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            VStack(alignment: .leading, spacing: 6) {
                Text(name)
                    .font(Theme.Typography.serifRace)
                    .foregroundStyle(Theme.ink)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
                    .minimumScaleFactor(0.8)
                if let location, !location.isEmpty {
                    Text(location)
                        .font(Theme.Typography.body)
                        .foregroundStyle(Theme.ink2)
                }
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
                    .font(Theme.Typography.monoLabelS)
                    .foregroundStyle(Theme.ink3)
                    .textCase(.uppercase)
                    .tracking(Theme.Tracking.monoLabel)
                    .padding(.top, 2)
            }
        }
        .padding(Theme.Spacing.cardP)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.surface1)
        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.card))
        .overlay(
            RoundedRectangle(cornerRadius: Theme.Radius.card)
                .strokeBorder(Theme.line, lineWidth: 1)
        )
    }
}

// MARK: - Race type extraction

/// Strips a trailing location/city off a freeform race name so the card title
/// shows just the race type. Plans store `raceName` as the full event name
/// (e.g. "IRONMAN 70.3 Cozumel"), while the location lives on the linked event
/// ("Cozumel, Mexico"), so the city tends to be duplicated at the end of the
/// name. Falls back to the full name when nothing can be stripped.
func raceTypeTitle(name: String, location: String?) -> String {
    let trimmed = name.trimmingCharacters(in: .whitespaces)
    guard let location, !location.isEmpty else { return trimmed }

    // City = first comma-separated component of the location ("Cozumel" from
    // "Cozumel, Mexico"). Try the full location first, then the city alone.
    let city = location.split(separator: ",").first
        .map { $0.trimmingCharacters(in: .whitespaces) } ?? location

    var result = trimmed
    for candidate in [location, city] where !candidate.isEmpty {
        if result.lowercased().hasSuffix(candidate.lowercased()) {
            result = String(result.dropLast(candidate.count))
            break
        }
    }

    // Trim separators/whitespace left dangling after removal.
    result = result.replacingOccurrences(of: #"[\s—–\-,:]+$"#, with: "", options: .regularExpression)
    result = result.trimmingCharacters(in: .whitespaces)
    return result.isEmpty ? trimmed : result
}

#Preview("RaceHeroCard") {
    VStack(spacing: 16) {
        RaceHeroCard(
            name: "IRONMAN 70.3",
            location: "Cozumel, Mexico",
            date: "Sun · Sep 27 · 2026",
            count: 17,
            unit: "Weeks out"
        )
        RaceHeroCard(
            name: "Big Sur Marathon",
            location: nil,
            date: "Sat · Jun 14 · 2026",
            count: 1,
            unit: "Day out"
        )
    }
    .padding(Theme.Spacing.screenH)
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(Theme.bg)
    .preferredColorScheme(.dark)
}
