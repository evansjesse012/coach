import SwiftUI

/// Presentation state of a WeekStripCell — the session story for a day,
/// independent of whether that day happens to be today. The "today"
/// override is handled as an orthogonal flag in `WeekStripCell` so the
/// today-wins-over-status rule is explicit at the call site.
enum WeekStripCellState: Equatable {
    case rest
    case upcoming
    case resolved(Theme.SessionStatusKind)
}

/// One day's cell in the Home week overview strip.
///
/// Rendered as three independent layers, each with its own color rule:
///
///   1. **Day letter** (M/T/W…) above the cell — color + weight depend
///      only on `isToday`.
///   2. **Cell fill + border** — `state` + `isToday`; today wins over
///      any session status (dark fill + accent ring) so the current day
///      is unmistakable even after it's been logged.
///   3. **Discipline icons** inside — the combination of `state`,
///      `isToday`, and each icon's own natural (discipline) color.
///
/// The three layers are resolved by three static helpers so the rules
/// can't drift between call sites and are trivially unit-testable.
struct WeekStripCell: View {
    /// One glyph rendered inside the cell. For multi-session days each
    /// session contributes a glyph; the cell stacks the first two and
    /// rolls any remainder into a "+N" line. Rest days supply a single
    /// moon glyph.
    struct Glyph: Hashable {
        let symbolName: String
        /// Natural color for this icon (its sport / discipline color).
        /// Used only when the cell resolves to `.upcoming`, where the
        /// grid previews what's scheduled. Resolved cells neutralize to
        /// `ink`; today forces the accent token.
        let naturalColor: Color
    }

    let letter: String
    let isToday: Bool
    let state: WeekStripCellState
    let glyphs: [Glyph]

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(spacing: 6) {
            Text(letter)
                .font(.system(size: 11, weight: Self.dayLetterWeight(isToday: isToday)))
                .tracking(0.8)
                .textCase(.uppercase)
                .foregroundStyle(Self.dayLetterColor(isToday: isToday))

            ZStack {
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .fill(Self.cellFill(state: state, isToday: isToday))
                if let border = Self.cellBorder(state: state, isToday: isToday) {
                    RoundedRectangle(cornerRadius: 9, style: .continuous)
                        .strokeBorder(border.color, lineWidth: border.width)
                }
                iconStack
            }
            .aspectRatio(1, contentMode: .fit)
        }
        .frame(maxWidth: .infinity)
    }

    @ViewBuilder
    private var iconStack: some View {
        // Uniform icon size: single-icon cells don't inflate and multi-icon
        // cells don't shrink to squeeze in. The 16pt size reads at a glance
        // and two still fit comfortably inside the ~40pt cell with 3pt gap
        // (35pt total, ~2.5pt breathing room top and bottom).
        let visible = Array(glyphs.prefix(2))
        let oversize = max(0, glyphs.count - 2)
        VStack(spacing: 3) {
            ForEach(Array(visible.enumerated()), id: \.offset) { _, g in
                Image(systemName: g.symbolName)
                    .font(.system(size: 16, weight: .regular))
                    .foregroundStyle(Self.iconColor(
                        state: state,
                        isToday: isToday,
                        naturalColor: g.naturalColor,
                        colorScheme: colorScheme
                    ))
            }
            if oversize > 0 {
                Text("+\(oversize)")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(Self.iconColor(
                        state: state,
                        isToday: isToday,
                        naturalColor: Theme.ink3,
                        colorScheme: colorScheme
                    ))
            }
        }
    }

    // MARK: - Layer 1 · Day letter

    /// "Which day is today?" — bold accent if today, muted gray otherwise.
    static func dayLetterColor(isToday: Bool) -> Color {
        isToday ? Theme.accent : Theme.ink3
    }

    static func dayLetterWeight(isToday: Bool) -> Font.Weight {
        // All letters render semibold so the row reads as a row of labels.
        // Today bumps to bold on top of the accent color + accent border +
        // accent icon, keeping it the most emphasized column.
        isToday ? .bold : .semibold
    }

    // MARK: - Layer 2 · Cell fill + border

    /// "What happened here?" — status fill for past, dark emphasis for
    /// today, quiet gray for upcoming. Today is a **visual override**:
    /// it wins even when the day has a resolved session status.
    static func cellFill(state: WeekStripCellState, isToday: Bool) -> Color {
        if isToday { return Theme.todayEmphFill }
        switch state {
        case .rest, .upcoming:
            return Theme.surface2
        case .resolved(let kind):
            return kind.fill
        }
    }

    /// `nil` means no border (upcoming / rest). Today: 1.5pt accent ring.
    /// Resolved statuses: 1pt in the canonical `kind.border`.
    static func cellBorder(
        state: WeekStripCellState,
        isToday: Bool
    ) -> (color: Color, width: CGFloat)? {
        if isToday { return (Theme.accent, 1.5) }
        switch state {
        case .rest, .upcoming:
            return nil
        case .resolved(let kind):
            guard let border = kind.border else { return nil }
            return (border, 1)
        }
    }

    // MARK: - Layer 3 · Icon color

    /// "What's scheduled / what was done?" Three distinct cases:
    ///
    /// - **Today** → accent token. Light mode uses the lifted moss
    ///   variant (`todayIconAccent`) because the standard olive doesn't
    ///   contrast enough against the near-black today fill. Wins over
    ///   any resolved status.
    /// - **Upcoming** → `naturalColor` (the icon's own sport color), so
    ///   the grid previews what's scheduled. Rest days pass `ink3` as
    ///   their natural color so the moon reads as a muted glyph.
    /// - **Resolved (done / modified / swapped / skipped)** → `ink`.
    ///   The status fill is the dominant at-a-glance signal on past
    ///   cells, so the icon neutralizes rather than fighting the fill
    ///   (moss-on-moss, amber-on-amber, etc.).
    static func iconColor(
        state: WeekStripCellState,
        isToday: Bool,
        naturalColor: Color,
        colorScheme: ColorScheme
    ) -> Color {
        if isToday {
            return colorScheme == .light ? Theme.todayIconAccent : Theme.accent
        }
        switch state {
        case .rest:
            return Theme.ink3
        case .upcoming:
            return naturalColor
        case .resolved:
            return Theme.ink
        }
    }
}

// MARK: - Previews

private struct WeekStripPreviewRow: View {
    let title: String
    let cells: [WeekStripCell]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Theme.ink)
            HStack(spacing: 6) {
                ForEach(Array(cells.enumerated()), id: \.offset) { _, cell in
                    cell
                }
            }
            .padding(14)
            .background(Theme.surface1)
            .clipShape(RoundedRectangle(cornerRadius: 18))
            .overlay(
                RoundedRectangle(cornerRadius: 18)
                    .strokeBorder(Theme.line, lineWidth: 1)
            )
        }
    }
}

private func swimGlyph() -> WeekStripCell.Glyph {
    .init(symbolName: "figure.pool.swim", naturalColor: Theme.Discipline.swim.color)
}
private func runGlyph() -> WeekStripCell.Glyph {
    .init(symbolName: "figure.run", naturalColor: Theme.Discipline.run.color)
}
private func bikeGlyph() -> WeekStripCell.Glyph {
    .init(symbolName: "bicycle", naturalColor: Theme.Discipline.bike.color)
}
private func restGlyph() -> WeekStripCell.Glyph {
    .init(symbolName: "moon.fill", naturalColor: Theme.ink3)
}

/// Standard week: Mon rest · Tue done swim · Wed modified run · Thu today
/// (swim scheduled, not yet logged) · Fri/Sat/Sun upcoming.
private func standardWeek(todayIdx: Int = 3) -> [WeekStripCell] {
    let letters = ["M", "T", "W", "T", "F", "S", "S"]
    let states: [(WeekStripCellState, [WeekStripCell.Glyph])] = [
        (.rest, [restGlyph()]),
        (.resolved(.done), [swimGlyph()]),
        (.resolved(.modified), [runGlyph()]),
        (.upcoming, [swimGlyph()]),
        (.upcoming, [runGlyph()]),
        (.upcoming, [bikeGlyph()]),
        (.upcoming, [runGlyph()]),
    ]
    return states.enumerated().map { idx, pair in
        WeekStripCell(
            letter: letters[idx],
            isToday: idx == todayIdx,
            state: pair.0,
            glyphs: pair.1
        )
    }
}

#Preview("Week strip — dark") {
    VStack(alignment: .leading, spacing: 20) {
        WeekStripPreviewRow(title: "Standard week · Thu is today", cells: standardWeek(todayIdx: 3))
        WeekStripPreviewRow(title: "Today as Monday (first day)",  cells: standardWeek(todayIdx: 0))
        WeekStripPreviewRow(title: "Today as Sunday (last day)",   cells: standardWeek(todayIdx: 6))
    }
    .padding(22)
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(Theme.bg)
    .preferredColorScheme(.dark)
}

#Preview("Week strip — light") {
    VStack(alignment: .leading, spacing: 20) {
        WeekStripPreviewRow(title: "Standard week · Thu is today", cells: standardWeek(todayIdx: 3))
        WeekStripPreviewRow(title: "Today as Monday (first day)",  cells: standardWeek(todayIdx: 0))
        WeekStripPreviewRow(title: "Today as Sunday (last day)",   cells: standardWeek(todayIdx: 6))
    }
    .padding(22)
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(Theme.bg)
    .preferredColorScheme(.light)
}

#Preview("Week strip — edge cases") {
    let letters = ["M", "T", "W", "T", "F", "S", "S"]
    let skippedWeek: [WeekStripCell] = [
        WeekStripCell(letter: letters[0], isToday: false, state: .resolved(.done),    glyphs: [runGlyph()]),
        WeekStripCell(letter: letters[1], isToday: false, state: .resolved(.skipped), glyphs: [bikeGlyph()]),
        WeekStripCell(letter: letters[2], isToday: false, state: .resolved(.done),    glyphs: [swimGlyph()]),
        WeekStripCell(letter: letters[3], isToday: true,  state: .upcoming,           glyphs: [runGlyph()]),
        WeekStripCell(letter: letters[4], isToday: false, state: .upcoming,           glyphs: [swimGlyph()]),
        WeekStripCell(letter: letters[5], isToday: false, state: .rest,               glyphs: [restGlyph()]),
        WeekStripCell(letter: letters[6], isToday: false, state: .upcoming,           glyphs: [bikeGlyph(), runGlyph()]),
    ]
    let todayLogged: [WeekStripCell] = [
        WeekStripCell(letter: letters[0], isToday: false, state: .resolved(.done),     glyphs: [runGlyph()]),
        WeekStripCell(letter: letters[1], isToday: false, state: .resolved(.done),     glyphs: [swimGlyph()]),
        WeekStripCell(letter: letters[2], isToday: false, state: .resolved(.modified), glyphs: [bikeGlyph()]),
        // Today AND the session logged as done — today treatment must win.
        WeekStripCell(letter: letters[3], isToday: true,  state: .resolved(.done),     glyphs: [swimGlyph()]),
        WeekStripCell(letter: letters[4], isToday: false, state: .upcoming,            glyphs: [runGlyph()]),
        WeekStripCell(letter: letters[5], isToday: false, state: .upcoming,            glyphs: [bikeGlyph()]),
        WeekStripCell(letter: letters[6], isToday: false, state: .upcoming,            glyphs: [runGlyph()]),
    ]
    return VStack(alignment: .leading, spacing: 20) {
        WeekStripPreviewRow(title: "Skipped Tuesday",             cells: skippedWeek)
        WeekStripPreviewRow(title: "Today (Thu) already logged — today wins", cells: todayLogged)
    }
    .padding(22)
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(Theme.bg)
}
