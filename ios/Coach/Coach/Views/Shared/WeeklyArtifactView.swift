import SwiftUI

/// Reusable card renderer for the two W1 artifacts — the prior week's
/// review (athlete check-in answers + AI response) and the current
/// week's preview (theme + framing + structured sections).
///
/// Used by:
///   * `WeekDetailView` — embeds the pair at the top of a week's plan
///     view so the AI's framing and the athlete's check-in sit
///     alongside the daily sessions.
///   * `WeeklyArtifactSheet` (below) — full-screen presentation when
///     the athlete taps the Today "This week" theme line.
///
/// The two artifact shapes diverge enough (review prose-led; preview
/// structured-led) that we render them with different bodies under a
/// shared chrome.
struct WeeklyArtifactView: View {
    enum Source: Identifiable, Hashable {
        case review(WeeklyReview)
        case preview(WeeklyPreview)

        /// Stable id derived from the underlying artifact UUID — required
        /// for SwiftUI `sheet(item:)` presentations.
        var id: UUID {
            switch self {
            case .review(let r):  return r.id
            case .preview(let p): return p.id
            }
        }
    }

    let source: Source

    var body: some View {
        switch source {
        case .review(let review):  reviewBody(review)
        case .preview(let preview): previewBody(preview)
        }
    }

    // MARK: - Review body

    @ViewBuilder
    private func reviewBody(_ r: WeeklyReview) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header — week dates + "review" kicker
            VStack(alignment: .leading, spacing: 4) {
                kicker("WEEK REVIEW")
                Text(weekRangeText(start: r.weekStartDate, end: r.weekEndDate))
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(Theme.ink)
                if let pct = r.adherencePct {
                    Text("Adherence \(Int(pct))%")
                        .font(.system(size: 12, weight: .regular, design: .monospaced))
                        .foregroundStyle(Theme.ink3)
                }
            }

            // Coach's response prose (what the athlete reads)
            if let prose = r.aiResponseText, !prose.isEmpty {
                Divider().background(Theme.line)
                Text(prose)
                    .font(.system(size: 15, weight: .regular))
                    .foregroundStyle(Theme.ink)
                    .fixedSize(horizontal: false, vertical: true)
                    .lineSpacing(3)
            }

            // Athlete's check-in answers — structured + free text. Read-only.
            if hasCheckInContent(r) {
                Divider().background(Theme.line)
                VStack(alignment: .leading, spacing: 8) {
                    kicker("YOUR CHECK-IN")
                    checkInGrid(r)
                    checkInFreeText(r)
                }
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.surface1)
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .strokeBorder(Theme.line, lineWidth: 1)
        )
    }

    private func hasCheckInContent(_ r: WeeklyReview) -> Bool {
        r.energyRating != nil || r.motivationRating != nil
            || r.sleepAvgHours != nil || r.lifeStressRating != nil
            || r.sorenessLevel != nil || r.painFlag
            || nonEmpty(r.bestSessionText) || nonEmpty(r.worstSessionText)
            || nonEmpty(r.lifeContext) || nonEmpty(r.questions)
            || nonEmpty(r.nextWeekFocus)
    }

    @ViewBuilder
    private func checkInGrid(_ r: WeeklyReview) -> some View {
        let cells: [(label: String, value: String)] = [
            ("Energy",     r.energyRating.map { "\($0)/10" } ?? ""),
            ("Motivation", r.motivationRating.map { "\($0)/10" } ?? ""),
            ("Sleep",      r.sleepAvgHours.map { String(format: "%.1fh", $0) } ?? ""),
            ("Life stress",r.lifeStressRating.map { "\($0)/10" } ?? ""),
            ("Soreness",   r.sorenessLevel?.rawValue ?? ""),
            ("Pain",       r.painFlag ? (r.painDescription ?? "yes") : "none"),
        ].filter { !$0.value.isEmpty }

        if !cells.isEmpty {
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], alignment: .leading, spacing: 8) {
                ForEach(cells, id: \.label) { cell in
                    HStack(spacing: 6) {
                        Text(cell.label)
                            .font(.system(size: 11, weight: .regular, design: .monospaced))
                            .foregroundStyle(Theme.ink3)
                        Text(cell.value)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(Theme.ink)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func checkInFreeText(_ r: WeeklyReview) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            freeTextRow("Best session",  r.bestSessionText)
            freeTextRow("Worst session", r.worstSessionText)
            freeTextRow("Life context",  r.lifeContext)
            freeTextRow("Questions",     r.questions)
            freeTextRow("Next-week focus", r.nextWeekFocus)
        }
    }

    @ViewBuilder
    private func freeTextRow(_ label: String, _ value: String?) -> some View {
        if let value, !value.trimmingCharacters(in: .whitespaces).isEmpty {
            VStack(alignment: .leading, spacing: 2) {
                Text(label.uppercased())
                    .font(.system(size: 9, weight: .semibold, design: .monospaced))
                    .tracking(0.18 * 9)
                    .foregroundStyle(Theme.ink3)
                Text(value)
                    .font(.system(size: 13, weight: .regular))
                    .foregroundStyle(Theme.ink)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    // MARK: - Preview body

    @ViewBuilder
    private func previewBody(_ p: WeeklyPreview) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            // Theme banner — large, accent treatment
            VStack(alignment: .leading, spacing: 6) {
                kicker("THIS WEEK")
                Text(p.theme)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(Theme.accent)
                    .fixedSize(horizontal: false, vertical: true)
                if let macro = p.macroPosition, !macro.isEmpty {
                    Text(macro)
                        .font(.system(size: 12, weight: .regular))
                        .foregroundStyle(Theme.ink2)
                }
            }

            // Volume strip — compact monospaced row of metrics
            let strip = volumeStripText(p)
            if !strip.isEmpty {
                Text(strip)
                    .font(.system(size: 11, weight: .regular, design: .monospaced))
                    .tracking(0.04 * 11)
                    .foregroundStyle(Theme.ink3)
            }

            // Rendered prose — main body the athlete reads
            if !p.renderedProse.isEmpty {
                Divider().background(Theme.line)
                Text(p.renderedProse)
                    .font(.system(size: 15, weight: .regular))
                    .foregroundStyle(Theme.ink)
                    .fixedSize(horizontal: false, vertical: true)
                    .lineSpacing(3)
            }

            // Key sessions
            if !p.keySessions.isEmpty {
                Divider().background(Theme.line)
                VStack(alignment: .leading, spacing: 10) {
                    kicker("KEY SESSIONS")
                    ForEach(p.keySessions, id: \.self) { ks in
                        keySessionRow(ks)
                    }
                }
            }

            // Watch-outs
            if !p.watchOuts.isEmpty {
                bulletSection(label: "WATCH FOR", items: p.watchOuts.map(\.description))
            }

            // Tactical notes
            if !p.tacticalNotes.isEmpty {
                bulletSection(label: "TACTICAL", items: p.tacticalNotes.map { "\($0.category): \($0.note)" })
            }

            // Life management notes
            if !p.lifeManagementNotes.isEmpty {
                bulletSection(label: "LIFE", items: p.lifeManagementNotes.map(\.note))
            }

            // Closing question
            if let q = p.closingQuestion, !q.isEmpty {
                Divider().background(Theme.line)
                Text(q)
                    .font(.system(size: 14, weight: .regular).italic())
                    .foregroundStyle(Theme.ink2)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.surface1)
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .strokeBorder(Theme.line, lineWidth: 1)
        )
    }

    private func keySessionRow(_ ks: WeeklyPreview.KeySession) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(spacing: 6) {
                Text(ks.dayOfWeek.capitalized)
                    .font(.system(size: 9, weight: .semibold, design: .monospaced))
                    .tracking(0.18 * 9)
                    .foregroundStyle(Theme.accent)
                Text(ks.name)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Theme.ink)
            }
            if !ks.whyItMatters.isEmpty {
                Text(ks.whyItMatters)
                    .font(.system(size: 13, weight: .regular))
                    .foregroundStyle(Theme.ink2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if !ks.successCriteria.isEmpty {
                miniRow(label: "Success", text: ks.successCriteria)
            }
            if !ks.watchFor.isEmpty {
                miniRow(label: "Watch", text: ks.watchFor)
            }
        }
    }

    private func miniRow(label: String, text: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            Text(label.uppercased())
                .font(.system(size: 9, weight: .semibold, design: .monospaced))
                .tracking(0.18 * 9)
                .foregroundStyle(Theme.ink3)
                .frame(width: 50, alignment: .leading)
            Text(text)
                .font(.system(size: 12, weight: .regular))
                .foregroundStyle(Theme.ink2)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func bulletSection(label: String, items: [String]) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            kicker(label)
            ForEach(items, id: \.self) { item in
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text("•").foregroundStyle(Theme.ink3)
                    Text(item)
                        .font(.system(size: 13, weight: .regular))
                        .foregroundStyle(Theme.ink)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    private func volumeStripText(_ p: WeeklyPreview) -> String {
        var parts: [String] = []
        if let h = p.totalPlannedHours    { parts.append(String(format: "%.1fh", h)) }
        if let d = p.totalPlannedDistance { parts.append(String(format: "%.1fmi", d)) }
        if let q = p.numQualitySessions   { parts.append("\(q) quality") }
        if let e = p.numEasySessions      { parts.append("\(e) easy") }
        if let delta = p.deltaFromPreviousWeekPct {
            let signed = delta >= 0 ? "+\(Int(delta))%" : "\(Int(delta))%"
            parts.append("Δ \(signed)")
        }
        return parts.joined(separator: " · ")
    }

    // MARK: - Shared bits

    private func kicker(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 9, weight: .semibold, design: .monospaced))
            .textCase(.uppercase)
            .tracking(0.18 * 9)
            .foregroundStyle(Theme.ink3)
    }

    private func weekRangeText(start: String, end: String) -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        let display = DateFormatter()
        display.dateFormat = "MMM d"
        let startDate = f.date(from: start)
        let endDate = f.date(from: end)
        if let s = startDate, let e = endDate {
            return "\(display.string(from: s)) – \(display.string(from: e))"
        }
        return "\(start) to \(end)"
    }

    private func nonEmpty(_ s: String?) -> Bool {
        guard let s else { return false }
        return !s.trimmingCharacters(in: .whitespaces).isEmpty
    }
}

// MARK: - Modal sheet wrapper

/// Full-screen presentation of a single artifact, used when the
/// athlete taps the Today "This week" theme line. Tracks engagement
/// (read_at / reread_count) on appear.
struct WeeklyArtifactSheet: View {
    let source: WeeklyArtifactView.Source
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                WeeklyArtifactView(source: source)
                    .padding(.horizontal, Theme.Spacing.screenH)
                    .padding(.vertical, 16)
            }
            .background(Theme.bg.ignoresSafeArea())
            .scrollContentBackground(.hidden)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .task {
            // Engagement is best-effort and only meaningful for previews.
            if case .preview(let p) = source {
                await WeeklyArtifactsService.markPreviewOpened(
                    id: p.id,
                    currentReadAt: p.readAt,
                    currentRereadCount: p.rereadCount
                )
            }
        }
    }
}
