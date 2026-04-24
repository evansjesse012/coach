import SwiftUI

/// Renders a markdown string as a stack of SwiftUI views.
///
/// Why a custom renderer (instead of `Text(AttributedString(markdown:))`)?
/// SwiftUI's built-in markdown parser is inline-only — it handles
/// **bold**, *italic*, `code`, and [links](url), but leaves every block
/// construct (headings, bullet/ordered lists, code fences, blockquotes,
/// tables, horizontal rules) as literal characters. It also throws on
/// any fragment that fails to parse, which causes a whole message to
/// fall back to raw text (hence the `**` leaking through in chat).
///
/// This view splits the input into block-level elements via a small
/// parser, then renders each block with the right SwiftUI primitive.
/// Inline elements inside each block go through `AttributedString` with
/// a forgiving failure policy.
///
/// Supported: paragraphs, ATX headings (h1–h3), bullet/ordered lists,
/// fenced code blocks (``` … ```), blockquotes, tables (pipe syntax),
/// and horizontal rules. Nested lists and images are not supported —
/// they render in a simplified but non-broken form.
struct MarkdownView: View {
    let text: String
    var baseFont: Font = .system(size: 15.5, weight: .medium)
    var textColor: Color = Theme.ink

    var body: some View {
        let blocks = MarkdownParser.parse(text)
        VStack(alignment: .leading, spacing: 10) {
            ForEach(Array(blocks.enumerated()), id: \.offset) { _, block in
                render(block)
            }
        }
    }

    @ViewBuilder
    private func render(_ block: MarkdownBlock) -> some View {
        switch block {
        case .paragraph(let body):
            Text(inline(body))
                .font(baseFont)
                .foregroundStyle(textColor)
                .fixedSize(horizontal: false, vertical: true)

        case .heading(let level, let body):
            Text(inline(body))
                .font(headingFont(for: level))
                .foregroundStyle(textColor)
                .padding(.top, level == 1 ? 6 : 2)
                .fixedSize(horizontal: false, vertical: true)

        case .bulletList(let items):
            VStack(alignment: .leading, spacing: 4) {
                ForEach(Array(items.enumerated()), id: \.offset) { _, item in
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text("•")
                            .font(baseFont)
                            .foregroundStyle(Theme.ink3)
                            .frame(width: 10, alignment: .leading)
                        Text(inline(item))
                            .font(baseFont)
                            .foregroundStyle(textColor)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }

        case .orderedList(let items):
            VStack(alignment: .leading, spacing: 4) {
                ForEach(Array(items.enumerated()), id: \.offset) { idx, item in
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text("\(idx + 1).")
                            .font(baseFont)
                            .foregroundStyle(Theme.ink3)
                            .frame(width: 18, alignment: .trailing)
                        Text(inline(item))
                            .font(baseFont)
                            .foregroundStyle(textColor)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }

        case .codeBlock(let code, _):
            Text(code)
                .font(.system(size: 13, design: .monospaced))
                .foregroundStyle(Theme.ink)
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Theme.surface2)
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .strokeBorder(Theme.line, lineWidth: 1)
                )

        case .blockquote(let body):
            HStack(alignment: .top, spacing: 10) {
                Rectangle()
                    .fill(Theme.line2)
                    .frame(width: 2)
                Text(inline(body))
                    .font(baseFont)
                    .italic()
                    .foregroundStyle(Theme.ink2)
                    .fixedSize(horizontal: false, vertical: true)
            }

        case .table(let headers, let rows):
            tableView(headers: headers, rows: rows)

        case .horizontalRule:
            Rectangle()
                .fill(Theme.line)
                .frame(height: 1)
                .padding(.vertical, 6)
        }
    }

    // MARK: Table

    private func tableView(headers: [String], rows: [[String]]) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top, spacing: 0) {
                ForEach(Array(headers.enumerated()), id: \.offset) { _, h in
                    Text(inline(h))
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Theme.ink)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 8)
                }
            }
            .background(Theme.surface2)

            ForEach(Array(rows.enumerated()), id: \.offset) { idx, row in
                Rectangle()
                    .fill(Theme.line)
                    .frame(height: 1)
                HStack(alignment: .top, spacing: 0) {
                    let padded = row + Array(repeating: "", count: max(0, headers.count - row.count))
                    ForEach(Array(padded.prefix(headers.count).enumerated()), id: \.offset) { _, cell in
                        Text(inline(cell))
                            .font(.system(size: 13))
                            .foregroundStyle(Theme.ink)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 8)
                    }
                }
                .background(idx.isMultiple(of: 2) ? Color.clear : Theme.surface2.opacity(0.5))
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(Theme.line, lineWidth: 1)
        )
    }

    // MARK: Inline parsing

    private func inline(_ text: String) -> AttributedString {
        renderInlineMarkdown(text)
    }

    private func headingFont(for level: Int) -> Font {
        switch level {
        case 1: return .system(size: 20, weight: .bold)
        case 2: return .system(size: 17, weight: .bold)
        default: return .system(size: 15, weight: .semibold)
        }
    }
}

// MARK: - Block model

enum MarkdownBlock {
    case paragraph(String)
    case heading(Int, String)               // level 1..6, body
    case bulletList([String])
    case orderedList([String])
    case codeBlock(String, String?)         // code, optional language
    case blockquote(String)
    case table([String], [[String]])        // headers, rows
    case horizontalRule
}

// MARK: - Parser

/// Minimal block-level markdown parser. Walks a string line by line,
/// recognizing the handful of block constructs the coach LLM can emit.
/// Everything not recognized becomes a paragraph.
enum MarkdownParser {
    static func parse(_ input: String) -> [MarkdownBlock] {
        let lines = input.components(separatedBy: "\n")
        var blocks: [MarkdownBlock] = []
        var i = 0
        while i < lines.count {
            let raw = lines[i]
            let trimmed = raw.trimmingCharacters(in: .whitespaces)

            // Blank line: skip
            if trimmed.isEmpty {
                i += 1
                continue
            }

            // Fenced code block
            if trimmed.hasPrefix("```") {
                let lang = String(trimmed.dropFirst(3)).trimmingCharacters(in: .whitespaces)
                var codeLines: [String] = []
                i += 1
                while i < lines.count,
                      !lines[i].trimmingCharacters(in: .whitespaces).hasPrefix("```") {
                    codeLines.append(lines[i])
                    i += 1
                }
                if i < lines.count { i += 1 } // skip closing fence
                blocks.append(.codeBlock(codeLines.joined(separator: "\n"), lang.isEmpty ? nil : lang))
                continue
            }

            // ATX heading
            if let hashRange = trimmed.range(of: #"^(#{1,6})\s+"#, options: .regularExpression) {
                let hashes = trimmed[hashRange].trimmingCharacters(in: .whitespaces)
                let body = String(trimmed[hashRange.upperBound...])
                blocks.append(.heading(hashes.count, body))
                i += 1
                continue
            }

            // Horizontal rule (---, ***, ___ with at least 3)
            if trimmed.allSatisfy({ $0 == "-" }) && trimmed.count >= 3 ||
               trimmed.allSatisfy({ $0 == "*" }) && trimmed.count >= 3 ||
               trimmed.allSatisfy({ $0 == "_" }) && trimmed.count >= 3 {
                blocks.append(.horizontalRule)
                i += 1
                continue
            }

            // Blockquote run
            if trimmed.hasPrefix(">") {
                var quoteLines: [String] = []
                while i < lines.count {
                    let t = lines[i].trimmingCharacters(in: .whitespaces)
                    guard t.hasPrefix(">") else { break }
                    let stripped = t.dropFirst().trimmingCharacters(in: .whitespaces)
                    quoteLines.append(String(stripped))
                    i += 1
                }
                blocks.append(.blockquote(quoteLines.joined(separator: "\n")))
                continue
            }

            // Table: header line + separator line + rows
            if trimmed.hasPrefix("|"),
               i + 1 < lines.count {
                let next = lines[i + 1].trimmingCharacters(in: .whitespaces)
                if next.hasPrefix("|") && next.contains("---") {
                    let headers = parseTableRow(trimmed)
                    i += 2 // skip header + separator
                    var rows: [[String]] = []
                    while i < lines.count {
                        let t = lines[i].trimmingCharacters(in: .whitespaces)
                        guard t.hasPrefix("|") else { break }
                        rows.append(parseTableRow(t))
                        i += 1
                    }
                    blocks.append(.table(headers, rows))
                    continue
                }
            }

            // Bullet list run
            if isBullet(trimmed) {
                var items: [String] = []
                while i < lines.count {
                    let t = lines[i].trimmingCharacters(in: .whitespaces)
                    guard isBullet(t) else { break }
                    items.append(String(t.dropFirst(2)))
                    i += 1
                }
                blocks.append(.bulletList(items))
                continue
            }

            // Ordered list run
            if trimmed.range(of: #"^\d+\.\s"#, options: .regularExpression) != nil {
                var items: [String] = []
                while i < lines.count {
                    let t = lines[i].trimmingCharacters(in: .whitespaces)
                    guard let r = t.range(of: #"^\d+\.\s+"#, options: .regularExpression) else { break }
                    items.append(String(t[r.upperBound...]))
                    i += 1
                }
                blocks.append(.orderedList(items))
                continue
            }

            // Paragraph: accumulate until a blank line or next block starts
            var paraLines: [String] = []
            while i < lines.count {
                let t = lines[i].trimmingCharacters(in: .whitespaces)
                if t.isEmpty { break }
                if t.hasPrefix("#") || t.hasPrefix("```") || t.hasPrefix(">") ||
                   isBullet(t) || t.range(of: #"^\d+\.\s"#, options: .regularExpression) != nil {
                    break
                }
                // Table header detection mid-paragraph
                if t.hasPrefix("|"), i + 1 < lines.count,
                   lines[i + 1].trimmingCharacters(in: .whitespaces).hasPrefix("|") &&
                   lines[i + 1].contains("---") {
                    break
                }
                paraLines.append(t)
                i += 1
            }
            if !paraLines.isEmpty {
                blocks.append(.paragraph(paraLines.joined(separator: " ")))
            }
        }
        return blocks
    }

    private static func isBullet(_ t: String) -> Bool {
        // "- ", "* ", or "+ " at start (space required so "*italic*" isn't misread)
        guard t.count >= 2 else { return false }
        let first = t.first!
        let second = t[t.index(after: t.startIndex)]
        return (first == "-" || first == "*" || first == "+") && second == " "
    }

    private static func parseTableRow(_ line: String) -> [String] {
        var cells = line.components(separatedBy: "|")
        if cells.first?.trimmingCharacters(in: .whitespaces).isEmpty == true { cells.removeFirst() }
        if cells.last?.trimmingCharacters(in: .whitespaces).isEmpty == true { cells.removeLast() }
        return cells.map { $0.trimmingCharacters(in: .whitespaces) }
    }
}

// MARK: - Shared inline renderer

/// Renders a string of inline markdown (bold, italic, code, links) into
/// an `AttributedString`, with guards against the asterisk quirks LLMs
/// routinely emit:
///
///   1. `** Hello **` — inner whitespace, which CommonMark treats as
///       literal. Collapsed to `**Hello**`.
///   2. `**Hello`, `Hello**`, `*`, `**` — unbalanced or orphan markers
///       left by truncated output. Any `**` or lone `*` that survives
///       the stock parser is stripped so the user never sees raw
///       markdown syntax.
///
/// Both `MarkdownView` (assistant bubbles) and `ChatTab.rendered`
/// (user bubbles) go through this so the bold-fragment leak Coach was
/// showing can't come back on one surface while staying fixed on the
/// other.
func renderInlineMarkdown(_ text: String) -> AttributedString {
    let normalized = normalizeEmphasisWhitespace(text)
    let opts = AttributedString.MarkdownParsingOptions(
        interpretedSyntax: .inlineOnlyPreservingWhitespace,
        failurePolicy: .returnPartiallyParsedIfPossible
    )
    guard var attr = try? AttributedString(markdown: normalized, options: opts) else {
        return AttributedString(stripOrphanAsterisks(normalized))
    }
    // If literal `**` or a lone `*` surfaces in the parsed output, the
    // parser couldn't match it to emphasis bounds — strip those markers
    // so they don't leak through to the athlete. (Proper bold emphasis
    // from matched `**pairs**` already removed the syntax.)
    let rendered = String(attr.characters)
    if rendered.contains("**") || containsOrphanAsterisk(rendered) {
        attr = AttributedString(stripOrphanAsterisks(rendered))
    }
    return attr
}

/// Collapses whitespace immediately inside an emphasis pair. The stock
/// parser requires emphasis to hug its content (`**bold**` works,
/// `** bold **` doesn't), but LLMs occasionally emit the spaced form.
private func normalizeEmphasisWhitespace(_ text: String) -> String {
    var s = text
    s = s.replacingOccurrences(
        of: #"\*\*\s+([^*\n]+?)\s+\*\*"#,
        with: "**$1**",
        options: .regularExpression
    )
    s = s.replacingOccurrences(
        of: #"(?<!\*)\*\s+([^*\n]+?)\s+\*(?!\*)"#,
        with: "*$1*",
        options: .regularExpression
    )
    return s
}

/// True when `text` contains a solitary `*` that isn't part of a `**`
/// pair — i.e. orphan italic emphasis the parser left behind.
private func containsOrphanAsterisk(_ text: String) -> Bool {
    // After `**` pairs have been canonicalized (all of them are even
    // count here), any remaining single `*` is orphan by definition.
    let withoutDouble = text.replacingOccurrences(of: "**", with: "")
    return withoutDouble.contains("*")
}

/// Strips any remaining `**` or lone `*` from a string. Invoked only
/// on parser output that failed to consume the markers, so we're not
/// destroying intentional emphasis — just cleaning up leftover syntax.
private func stripOrphanAsterisks(_ text: String) -> String {
    text
        .replacingOccurrences(of: "**", with: "")
        .replacingOccurrences(of: "*", with: "")
}
