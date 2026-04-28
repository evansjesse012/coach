import SwiftUI

// MARK: - Resolved status

/// One day's resolved presentation status in the Home week strip.
/// Multi-session days collapse upstream (`HomeTab.weekStripStatus(for:)`)
/// using the precedence skipped > modified > done > upcoming. Today is
/// orthogonal — `WeekStripCell.isToday` drives the column wrap and is
/// not folded into this enum so the today rules can't drift.
enum WeekStripStatus: Equatable {
    case done
    case modified
    case skipped
    case upcoming
}

// MARK: - Glyph

/// One discipline icon inside a week-strip cell. Multi-session days
/// supply one glyph per session, in prescribed order; the cell stacks
/// the first two vertically and rolls any remainder into a "+N" line.
struct DisciplineGlyph: Hashable {
    let symbolName: String
    /// Discipline's natural (full-opacity) color. Used only when the
    /// resolved style sets `useNaturalColors = true` (the upcoming-not-
    /// today case), so each scheduled sport previews in its own color.
    let naturalColor: Color
}

// MARK: - Cell style — single source of truth

/// Cell visual properties resolved from `(status, isToday)`. Every
/// fill / icon / slash decision in the week strip routes through
/// `resolve(...)` so the rules can't drift between call sites.
///
/// `useNaturalColors` is set only for the upcoming-not-today branch:
/// in that case the cell paints each glyph in its own discipline color
/// instead of the resolved `iconColor`, so a multi-sport day previews
/// each scheduled discipline distinctly.
struct WeekStripStyle {
    let fill: Color
    let iconColor: Color
    let iconOpacity: Double
    let showsSlash: Bool
    let useNaturalColors: Bool

    static func resolve(
        status: WeekStripStatus,
        isToday: Bool,
        upcomingOpacity: Double = 0.5
    ) -> WeekStripStyle {
        switch (status, isToday) {

        // Today, no logged status — surface-2 base + accent icon. The
        // surrounding column wrap supplies the dominant today signal;
        // the cell itself reads as a quiet "ready" surface.
        case (.upcoming, true):
            return .init(
                fill: Theme.surface2,
                iconColor: Theme.accent,
                iconOpacity: 1.0,
                showsSlash: false,
                useNaturalColors: false
            )

        // Done — past or today both render with the moss fill + ink
        // icon at 90%. For today + done the column wrap stays on top,
        // so both signals coexist (today emphasis + completion fill).
        case (.done, _):
            return .init(
                fill: Theme.accent.opacity(0.22),
                iconColor: Theme.ink,
                iconOpacity: 0.9,
                showsSlash: false,
                useNaturalColors: false
            )

        // Modified — same treatment as Done but in the amber family.
        case (.modified, _):
            return .init(
                fill: Theme.modifiedAccent.opacity(0.22),
                iconColor: Theme.ink,
                iconOpacity: 0.9,
                showsSlash: false,
                useNaturalColors: false
            )

        // Skipped — red tint, faded warn-colored icons, plus the
        // diagonal slash. Three redundant signals so the state reads
        // unambiguously even with color-only impairments.
        case (.skipped, _):
            return .init(
                fill: Theme.warn.opacity(0.18),
                iconColor: Theme.warn,
                iconOpacity: 0.55,
                showsSlash: true,
                useNaturalColors: false
            )

        // Upcoming (not today) — transparent cell, each icon faded to
        // its own discipline color (rest days drop to 0.4). The "+N"
        // overflow label uses ink3 instead of a discipline color since
        // it isn't tied to a specific sport.
        case (.upcoming, false):
            return .init(
                fill: .clear,
                iconColor: Theme.ink3,
                iconOpacity: upcomingOpacity,
                showsSlash: false,
                useNaturalColors: true
            )
        }
    }
}

// MARK: - Cell

/// One column in the Home week strip — a day-letter label stacked above
/// a 1:1 cell with the day's discipline icon(s). Today's column (letter
/// + cell) is wrapped together inside a 1.5pt accent-bordered container
/// so the eye lands on it immediately.
///
/// Multi-session days stack the first two glyphs vertically. Days with
/// three or more sessions show two glyphs plus a "+N" overflow line.
/// Tapping anywhere in the column triggers `onTap`; the day letter and
/// cell are parts of the same tap target.
struct WeekStripCell: View {
    let letter: String
    let isToday: Bool
    let status: WeekStripStatus
    /// One glyph per session, in prescribed order. The cell renders the
    /// first two and rolls any remainder into "+N". Rest / empty days
    /// supply a single moon glyph from `HomeTab.weekStripGlyphs(for:)`.
    let glyphs: [DisciplineGlyph]
    /// Opacity applied to icons in the upcoming state. Sports use 0.5;
    /// rest days drop to 0.4 so the moon reads quieter.
    var upcomingOpacity: Double = 0.5
    var accessibilityText: String? = nil
    var onTap: (() -> Void)? = nil

    var body: some View {
        let style = WeekStripStyle.resolve(
            status: status,
            isToday: isToday,
            upcomingOpacity: upcomingOpacity
        )

        Button {
            onTap?()
        } label: {
            column(style: style)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accessibilityText ?? letter)
    }

    @ViewBuilder
    private func column(style: WeekStripStyle) -> some View {
        let stack = VStack(spacing: 5) {
            Text(letter)
                .font(.system(size: 10, weight: isToday ? .bold : .medium))
                .foregroundStyle(isToday ? Theme.accent : Theme.ink3)

            cell(style: style)
        }

        if isToday {
            stack
                .padding(.vertical, 5)
                .padding(.horizontal, 2)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(Theme.accent.opacity(0.05))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .strokeBorder(Theme.accent, lineWidth: 1.5)
                )
                .frame(maxWidth: .infinity)
        } else {
            stack.frame(maxWidth: .infinity)
        }
    }

    @ViewBuilder
    private func cell(style: WeekStripStyle) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 7, style: .continuous)
                .fill(style.fill)

            iconStack(style: style)

            if style.showsSlash {
                // 20pt × 1.5pt warn-colored line, rotated -20°, centered
                // over the icon stack. Rounded ends so the stroke doesn't
                // read as a hard rectangle. Drawn last so it sits on top.
                RoundedRectangle(cornerRadius: 0.75, style: .continuous)
                    .fill(Theme.warn)
                    .frame(width: 20, height: 1.5)
                    .rotationEffect(.degrees(-20))
            }
        }
        .aspectRatio(1, contentMode: .fit)
    }

    @ViewBuilder
    private func iconStack(style: WeekStripStyle) -> some View {
        // Up to two glyphs stacked vertically (14pt each + 3pt gap fits
        // inside the ~38pt cell with breathing room). A third+ session
        // collapses into a "+N" line below the two visible icons.
        let visible = Array(glyphs.prefix(2))
        let overflow = max(0, glyphs.count - 2)
        VStack(spacing: 3) {
            ForEach(Array(visible.enumerated()), id: \.offset) { _, glyph in
                Image(systemName: glyph.symbolName)
                    .font(.system(size: 14, weight: .regular))
                    .foregroundStyle(
                        (style.useNaturalColors ? glyph.naturalColor : style.iconColor)
                            .opacity(style.iconOpacity)
                    )
            }
            if overflow > 0 {
                Text("+\(overflow)")
                    .font(.system(size: 8, weight: .semibold))
                    .foregroundStyle(style.iconColor.opacity(style.iconOpacity))
            }
        }
    }
}

// MARK: - Previews

private let weekLetters = ["M", "T", "W", "T", "F", "S", "S"]

private struct WeekStripPreviewCard: View {
    let title: String
    let cells: [WeekStripCell]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Theme.ink)
            HStack(spacing: 5) {
                ForEach(Array(cells.enumerated()), id: \.offset) { _, cell in
                    cell
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
    }
}

private func glyph(_ sport: Theme.Discipline) -> DisciplineGlyph {
    DisciplineGlyph(symbolName: sport.icon, naturalColor: sport.color)
}

private func previewCell(
    _ idx: Int,
    isToday: Bool,
    status: WeekStripStatus,
    sports: [Theme.Discipline]
) -> WeekStripCell {
    let isRestOnly = sports == [.recovery]
    return WeekStripCell(
        letter: weekLetters[idx],
        isToday: isToday,
        status: status,
        glyphs: sports.map(glyph),
        upcomingOpacity: isRestOnly ? 0.4 : 0.5
    )
}

#Preview("Mid-week — Fri today, mixed states") {
    let cells: [WeekStripCell] = [
        previewCell(0, isToday: false, status: .upcoming, sports: [.recovery]),
        previewCell(1, isToday: false, status: .done,     sports: [.swim]),
        previewCell(2, isToday: false, status: .modified, sports: [.bike]),
        previewCell(3, isToday: false, status: .done,     sports: [.run]),
        previewCell(4, isToday: true,  status: .upcoming, sports: [.swim]),
        previewCell(5, isToday: false, status: .upcoming, sports: [.bike]),
        previewCell(6, isToday: false, status: .upcoming, sports: [.run]),
    ]
    return VStack(spacing: 18) {
        WeekStripPreviewCard(title: "Mid-week · Fri is today (light)", cells: cells)
            .preferredColorScheme(.light)
        WeekStripPreviewCard(title: "Mid-week · Fri is today (dark)", cells: cells)
            .preferredColorScheme(.dark)
    }
    .padding(22)
    .background(Theme.bg)
}

#Preview("Two-session days — stacked icons") {
    let cells: [WeekStripCell] = [
        previewCell(0, isToday: false, status: .done,     sports: [.swim, .strength]),
        previewCell(1, isToday: false, status: .modified, sports: [.run, .strength]),
        previewCell(2, isToday: false, status: .done,     sports: [.bike, .swim]),
        previewCell(3, isToday: true,  status: .upcoming, sports: [.run, .strength]),
        previewCell(4, isToday: false, status: .upcoming, sports: [.bike, .swim]),
        previewCell(5, isToday: false, status: .upcoming, sports: [.run, .strength, .swim]), // 3 → +1
        previewCell(6, isToday: false, status: .upcoming, sports: [.recovery]),
    ]
    return VStack(spacing: 18) {
        WeekStripPreviewCard(title: "Two-session days (light)", cells: cells)
            .preferredColorScheme(.light)
        WeekStripPreviewCard(title: "Two-session days (dark)", cells: cells)
            .preferredColorScheme(.dark)
    }
    .padding(22)
    .background(Theme.bg)
}

#Preview("Start-of-week — Mon today, all upcoming") {
    let cells: [WeekStripCell] = [
        previewCell(0, isToday: true,  status: .upcoming, sports: [.swim]),
        previewCell(1, isToday: false, status: .upcoming, sports: [.bike]),
        previewCell(2, isToday: false, status: .upcoming, sports: [.run]),
        previewCell(3, isToday: false, status: .upcoming, sports: [.strength]),
        previewCell(4, isToday: false, status: .upcoming, sports: [.swim]),
        previewCell(5, isToday: false, status: .upcoming, sports: [.run]),
        previewCell(6, isToday: false, status: .upcoming, sports: [.recovery]),
    ]
    return VStack(spacing: 18) {
        WeekStripPreviewCard(title: "Mon today · all upcoming (light)", cells: cells)
            .preferredColorScheme(.light)
        WeekStripPreviewCard(title: "Mon today · all upcoming (dark)", cells: cells)
            .preferredColorScheme(.dark)
    }
    .padding(22)
    .background(Theme.bg)
}

#Preview("End-of-week — Sun today, others past") {
    let cells: [WeekStripCell] = [
        previewCell(0, isToday: false, status: .done,     sports: [.swim]),
        previewCell(1, isToday: false, status: .done,     sports: [.bike, .strength]),
        previewCell(2, isToday: false, status: .modified, sports: [.run]),
        previewCell(3, isToday: false, status: .done,     sports: [.strength]),
        previewCell(4, isToday: false, status: .skipped,  sports: [.swim]),
        previewCell(5, isToday: false, status: .done,     sports: [.run]),
        previewCell(6, isToday: true,  status: .upcoming, sports: [.recovery]),
    ]
    return VStack(spacing: 18) {
        WeekStripPreviewCard(title: "Sun today · others past (light)", cells: cells)
            .preferredColorScheme(.light)
        WeekStripPreviewCard(title: "Sun today · others past (dark)", cells: cells)
            .preferredColorScheme(.dark)
    }
    .padding(22)
    .background(Theme.bg)
}

#Preview("Skipped — slash overlay (incl. multi-session)") {
    let cells: [WeekStripCell] = [
        previewCell(0, isToday: false, status: .done,     sports: [.swim]),
        previewCell(1, isToday: false, status: .skipped,  sports: [.bike]),
        previewCell(2, isToday: false, status: .skipped,  sports: [.run, .strength]),
        previewCell(3, isToday: true,  status: .skipped,  sports: [.strength]),
        previewCell(4, isToday: false, status: .upcoming, sports: [.swim]),
        previewCell(5, isToday: false, status: .upcoming, sports: [.bike]),
        previewCell(6, isToday: false, status: .upcoming, sports: [.run]),
    ]
    return VStack(spacing: 18) {
        WeekStripPreviewCard(title: "Past skipped + today skipped (light)", cells: cells)
            .preferredColorScheme(.light)
        WeekStripPreviewCard(title: "Past skipped + today skipped (dark)", cells: cells)
            .preferredColorScheme(.dark)
    }
    .padding(22)
    .background(Theme.bg)
}

#Preview("Today + Done — wrap stays, moss fill inside") {
    let cells: [WeekStripCell] = [
        previewCell(0, isToday: false, status: .done,     sports: [.swim]),
        previewCell(1, isToday: false, status: .done,     sports: [.bike]),
        previewCell(2, isToday: false, status: .modified, sports: [.run]),
        previewCell(3, isToday: true,  status: .done,     sports: [.swim, .strength]), // today + done + 2 sessions
        previewCell(4, isToday: false, status: .upcoming, sports: [.run]),
        previewCell(5, isToday: false, status: .upcoming, sports: [.bike]),
        previewCell(6, isToday: false, status: .upcoming, sports: [.run]),
    ]
    return VStack(spacing: 18) {
        WeekStripPreviewCard(title: "Today logged as done (light)", cells: cells)
            .preferredColorScheme(.light)
        WeekStripPreviewCard(title: "Today logged as done (dark)", cells: cells)
            .preferredColorScheme(.dark)
    }
    .padding(22)
    .background(Theme.bg)
}
