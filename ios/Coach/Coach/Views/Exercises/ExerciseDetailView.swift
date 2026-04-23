import SwiftUI
import Charts

struct ExerciseDetailView: View {
    let slug: String

    @Environment(DataService.self) var data
    @Environment(\.colorScheme) var colorScheme

    private var libraryItem: ExerciseLibraryItem? {
        data.allExercises().first { $0.slug == slug }
    }

    private var history: ExerciseHistory {
        data.exerciseHistory(slug: slug)
    }

    private var chartPoints: [ChartPoint] {
        ChartPoint.build(from: history)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                header
                if let pr = history.personalRecord {
                    prCard(pr)
                } else {
                    emptyPRCard
                }
                chartSection
                historySection
            }
            .padding()
        }
        .clearsTabBar()
        .background((colorScheme == .dark ? CoachColors.darkBg : CoachColors.lightBg).ignoresSafeArea())
        .navigationTitle(libraryItem?.name ?? "Exercise")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Header

    private var header: some View {
        CoachCard(accentColor: CoachColors.yellow) {
            VStack(alignment: .leading, spacing: 8) {
                if let item = libraryItem {
                    HStack {
                        Text(item.name)
                            .font(CoachFonts.display(22, weight: .bold))
                        Spacer()
                        CoachPill(text: item.exerciseType.label, color: CoachColors.yellow)
                    }
                    Text("\(item.bodyPart) · \(item.category)")
                        .font(CoachFonts.ui(12))
                        .foregroundStyle(.secondary)
                    if item.isCustom || item.isFromHistory {
                        HStack(spacing: 6) {
                            if item.isCustom {
                                CoachPill(text: "Custom", color: CoachColors.purple)
                            }
                            if item.isFromHistory {
                                CoachPill(text: "From History", color: CoachColors.cyan)
                            }
                        }
                    }
                } else {
                    Text(slug)
                        .font(CoachFonts.display(22, weight: .bold))
                    Text("Unknown exercise")
                        .font(CoachFonts.ui(12))
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    // MARK: - PR Card

    private func prCard(_ pr: PersonalRecord) -> some View {
        CoachCard {
            VStack(alignment: .leading, spacing: 10) {
                CoachLabel(text: "Personal Records")

                switch pr.exerciseType {
                case .weighted:
                    HStack(spacing: 16) {
                        statBlock("HEAVIEST", value: heaviestSetText(pr))
                        if let est = pr.estimated1RM, est > 0 {
                            statBlock("EST. 1RM", value: "\(Int(est)) lb")
                        }
                    }
                    if let volume = heaviestVolumeText(pr) {
                        statBlock("BEST SET VOLUME", value: volume)
                    }
                case .bodyweight, .cardioDrill:
                    if let r = pr.bestReps {
                        statBlock("BEST REPS", value: "\(r)")
                    }
                case .timed:
                    if let d = pr.bestDuration {
                        statBlock("BEST TIME", value: formatSeconds(d))
                    }
                case .banded:
                    if let band = pr.band, let r = pr.bestReps {
                        HStack(spacing: 16) {
                            statBlock("BEST BAND", value: band.capitalized)
                            statBlock("BEST REPS", value: "\(r)")
                        }
                    }
                }
            }
        }
    }

    private var emptyPRCard: some View {
        CoachCard {
            VStack(alignment: .leading, spacing: 6) {
                CoachLabel(text: "Personal Records")
                Text("No records yet. Log a session with this exercise to start tracking PRs.")
                    .font(CoachFonts.ui(12))
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func statBlock(_ label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(CoachFonts.ui(10, weight: .semibold))
                .foregroundStyle(.secondary)
                .tracking(0.5)
            Text(value)
                .font(CoachFonts.mono(18, weight: .semibold))
        }
    }

    private func heaviestSetText(_ pr: PersonalRecord) -> String {
        if let w = pr.weight, let r = pr.reps {
            return "\(Int(w)) lb × \(r)"
        }
        return "—"
    }

    private func heaviestVolumeText(_ pr: PersonalRecord) -> String? {
        if let w = pr.weight, let r = pr.reps, w > 0, r > 0 {
            return "\(Int(w * Double(r))) lb"
        }
        return nil
    }

    private func formatSeconds(_ seconds: Double) -> String {
        let total = Int(seconds)
        let mins = total / 60
        let secs = total % 60
        return mins > 0 ? "\(mins):\(String(format: "%02d", secs))" : "\(total)s"
    }

    // MARK: - Chart

    private var chartSection: some View {
        CoachCard {
            VStack(alignment: .leading, spacing: 12) {
                CoachLabel(text: "Progression")
                if chartPoints.count < 2 {
                    Text("Log at least two sessions to see a progression chart.")
                        .font(CoachFonts.ui(12))
                        .foregroundStyle(.secondary)
                } else {
                    Chart(chartPoints) { point in
                        LineMark(
                            x: .value("Date", point.date),
                            y: .value(metricLabel, point.value)
                        )
                        .foregroundStyle(CoachColors.accent)
                        .interpolationMethod(.monotone)

                        PointMark(
                            x: .value("Date", point.date),
                            y: .value(metricLabel, point.value)
                        )
                        .foregroundStyle(point.isPR ? CoachColors.yellow : CoachColors.accent)
                        .symbolSize(point.isPR ? 80 : 30)
                    }
                    .frame(height: 180)
                    .chartYAxis {
                        AxisMarks(position: .leading)
                    }
                }
            }
        }
    }

    private var metricLabel: String {
        let type = libraryItem?.exerciseType ?? history.entries.first?.exerciseType ?? .weighted
        switch type {
        case .weighted: return "Est. 1RM"
        case .bodyweight, .cardioDrill: return "Max Reps"
        case .timed: return "Duration (s)"
        case .banded: return "Reps"
        }
    }

    // MARK: - History

    private var historySection: some View {
        VStack(alignment: .leading, spacing: 8) {
            CoachLabel(text: "History")
                .padding(.bottom, 2)
            if history.entries.isEmpty {
                CoachCard {
                    Text("No logged sessions with this exercise yet.")
                        .font(CoachFonts.ui(12))
                        .foregroundStyle(.secondary)
                }
            } else {
                ForEach(history.entries) { entry in
                    NavigationLink {
                        StrengthDetailView(session: entry.session)
                    } label: {
                        historyRow(entry)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private func historyRow(_ entry: ExerciseHistoryEntry) -> some View {
        CoachCard(padding: 12) {
            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .firstTextBaseline) {
                    Text(entry.session.name)
                        .font(CoachFonts.ui(13, weight: .semibold))
                    Spacer()
                    if entry.wasPR {
                        CoachPill(text: "PR", color: CoachColors.accent)
                    }
                    Text(formatDateRelative(entry.session.date))
                        .font(CoachFonts.ui(11))
                        .foregroundStyle(.secondary)
                }
                Text(setsSummary(entry))
                    .font(CoachFonts.mono(12))
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
        }
    }

    private func setsSummary(_ entry: ExerciseHistoryEntry) -> String {
        let completed = entry.sets.filter(\.completed)
        guard !completed.isEmpty else { return "No completed sets" }
        let parts = completed.map { set -> String in
            switch entry.exerciseType {
            case .weighted:
                if let w = set.weight, let r = set.reps { return "\(Int(w))×\(r)" }
            case .bodyweight, .cardioDrill:
                if let r = set.reps { return "\(r)" }
            case .timed:
                if let d = set.duration { return "\(Int(d))s" }
            case .banded:
                if let b = set.band, let r = set.reps { return "\(b) \(r)" }
            }
            return "—"
        }
        return "\(completed.count) × (\(parts.joined(separator: ", ")))"
    }
}

// MARK: - Chart Point

private struct ChartPoint: Identifiable {
    let id = UUID()
    let date: Date
    let value: Double
    let isPR: Bool

    static func build(from history: ExerciseHistory) -> [ChartPoint] {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = TimeZone(identifier: "UTC")

        // Build in chronological order so the line draws left-to-right
        let chrono = history.entries.reversed()
        return chrono.compactMap { entry -> ChartPoint? in
            guard let date = formatter.date(from: entry.session.date) else { return nil }
            let value = bestMetric(for: entry)
            guard value > 0 else { return nil }
            return ChartPoint(date: date, value: value, isPR: entry.wasPR)
        }
    }

    private static func bestMetric(for entry: ExerciseHistoryEntry) -> Double {
        let completed = entry.sets.filter(\.completed)
        switch entry.exerciseType {
        case .weighted:
            return completed.compactMap { set -> Double? in
                guard let w = set.weight, let r = set.reps, w > 0, r > 0 else { return nil }
                return epley1RM(weight: w, reps: r)
            }.max() ?? 0
        case .bodyweight, .cardioDrill, .banded:
            return Double(completed.compactMap(\.reps).max() ?? 0)
        case .timed:
            return completed.compactMap(\.duration).max() ?? 0
        }
    }
}
