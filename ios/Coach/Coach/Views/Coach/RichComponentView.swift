import SwiftUI

// MARK: - Rich Component Renderer

/// Routes a `RichComponent` to its specialized view. Used inside
/// `MessageBubble` to render structured content inline in chat.
struct RichComponentView: View {
    let component: RichComponent
    var onCompletion: ((CompletionAction) -> Void)?

    var body: some View {
        switch component.kind {
        case .workoutCard(let data):
            ChatWorkoutCard(data: data, onCompletion: onCompletion)
        case .weekSummary(let data):
            ChatWeekSummary(data: data)
        case .statHighlight(let data):
            ChatStatHighlight(data: data)
        case .raceCountdown(let data):
            ChatRaceCountdown(data: data)
        case .phaseProgress(let data):
            ChatPhaseProgress(data: data)
        }
    }
}

/// The action a user takes on a workout card's completion buttons.
enum CompletionAction {
    case didIt(weekNum: Int, dayIdx: Int, sessionIdx: Int)
    case modified(weekNum: Int, dayIdx: Int, sessionIdx: Int)
    case swapped(weekNum: Int, dayIdx: Int, sessionIdx: Int)
    case skipped(weekNum: Int, dayIdx: Int, sessionIdx: Int)
}

// MARK: - Workout Card

/// Compact workout card for chat — mirrors the Home tab's TodaySessionCard
/// but sized for inline chat width.
struct ChatWorkoutCard: View {
    let data: WorkoutCardData
    var onCompletion: ((CompletionAction) -> Void)?

    @Environment(\.colorScheme) var colorScheme

    private var session: PrescribedSession { data.session }

    private var isResolved: Bool {
        session.completionStatus != nil || session.completed == true
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                leftBar
                cardContent
            }

            if !isResolved {
                actionBar
            }
        }
        .background(colorScheme == .dark ? CoachColors.darkCard : CoachColors.lightCard)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(colorScheme == .dark ? CoachColors.darkBorder : CoachColors.lightBorder, lineWidth: 1)
        )
        .opacity(session.completionStatus == .skipped ? 0.6 : 1.0)
    }

    // MARK: - Left bar

    @ViewBuilder
    private var leftBar: some View {
        if let status = session.completionStatus {
            switch status {
            case .completed:
                Rectangle().fill(CoachColors.green).frame(width: 6)
            case .modified:
                Rectangle().fill(CoachColors.yellow).frame(width: 6)
            case .swapped:
                Rectangle().fill(CoachColors.blue).frame(width: 6)
            case .skipped:
                Rectangle().fill(Color.gray.opacity(0.6)).frame(width: 6)
            }
        } else {
            (session.effortCategory ?? .easy).gradient
                .frame(width: 6)
        }
    }

    // MARK: - Content

    private var cardContent: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Sport badge + priority
            HStack(spacing: 8) {
                if let sport = Sport(rawValue: session.type.lowercased()) {
                    SportBadge(sport: sport)
                }
                if session.priority == .red && !isResolved {
                    CoachPill(text: "KEY", color: CoachColors.accent)
                }
                if session.completionStatus == .modified {
                    CoachPill(text: "MODIFIED", color: CoachColors.yellow)
                }
                if session.completionStatus == .swapped {
                    CoachPill(text: "SWAPPED", color: CoachColors.blue)
                }
                Spacer()
                if isResolved {
                    resolvedIcon
                }
            }

            // Title
            Text(session.label)
                .font(CoachFonts.display(17, weight: .bold))
                .foregroundStyle(.primary)
                .lineLimit(2)
                .multilineTextAlignment(.leading)
                .strikethrough(session.completionStatus == .skipped)

            // Purpose
            if let purpose = session.purpose, !purpose.isEmpty, !isResolved {
                Text(purpose)
                    .font(CoachFonts.ui(12))
                    .italic()
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }

            // Stats row
            if !isResolved {
                statsRow
                effortFuelRow
            } else {
                completionRow
            }

            // Warning
            if let warning = session.warning, !warning.isEmpty, !isResolved {
                warningRow(warning)
            }
        }
        .padding(.leading, 12)
        .padding(.vertical, 12)
        .padding(.trailing, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Stats

    @ViewBuilder
    private var statsRow: some View {
        HStack(spacing: 16) {
            if let time = timeValue {
                statItem(label: "TIME", value: time)
            }
            if let dist = distValue {
                statItem(label: "DIST", value: dist)
            }
            if let pz = paceOrZone {
                statItem(label: pz.0, value: pz.1)
            }
            Spacer()
        }
    }

    @ViewBuilder
    private var effortFuelRow: some View {
        HStack(spacing: 8) {
            let effort = session.effortCategory ?? .easy
            CoachPill(text: effort.label.uppercased(), color: effort.color)
            if let pre = session.fuel?.pre, !pre.isEmpty {
                HStack(spacing: 4) {
                    Image(systemName: "fork.knife")
                        .font(.system(size: 10, weight: .semibold))
                    Text(pre)
                        .font(CoachFonts.ui(11))
                        .lineLimit(1)
                }
                .foregroundStyle(.secondary)
            }
            Spacer()
        }
    }

    @ViewBuilder
    private var completionRow: some View {
        if let status = session.completionStatus {
            switch status {
            case .completed, .modified, .swapped:
                HStack(spacing: 6) {
                    Image(systemName: "checkmark")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(statusColor(status))
                    Text(completionText)
                        .font(CoachFonts.mono(12, weight: .medium))
                        .foregroundStyle(.secondary)
                }
            case .skipped:
                HStack(spacing: 6) {
                    if let reason = session.skipReason {
                        Text("Skipped \u{00B7} \(reason.rawValue.capitalized)")
                            .font(CoachFonts.ui(12, weight: .medium))
                            .foregroundStyle(.secondary)
                    } else {
                        Text("Skipped")
                            .font(CoachFonts.ui(12, weight: .medium))
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }

    // MARK: - Action bar

    private var actionBar: some View {
        HStack(spacing: 6) {
            completionButton(label: "Did it", icon: "checkmark", color: CoachColors.green, prominent: true) {
                onCompletion?(.didIt(weekNum: data.weekNum, dayIdx: data.dayIdx, sessionIdx: data.sessionIdx))
            }
            completionButton(label: "Modified", icon: "pencil", color: CoachColors.yellow) {
                onCompletion?(.modified(weekNum: data.weekNum, dayIdx: data.dayIdx, sessionIdx: data.sessionIdx))
            }
            completionButton(label: "Swapped", icon: "arrow.triangle.2.circlepath", color: CoachColors.blue) {
                onCompletion?(.swapped(weekNum: data.weekNum, dayIdx: data.dayIdx, sessionIdx: data.sessionIdx))
            }
            completionButton(label: "Skipped", icon: "xmark", color: .secondary) {
                onCompletion?(.skipped(weekNum: data.weekNum, dayIdx: data.dayIdx, sessionIdx: data.sessionIdx))
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
    }

    private func completionButton(label: String, icon: String, color: Color, prominent: Bool = false, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 10, weight: .bold))
                Text(label)
                    .font(CoachFonts.ui(11, weight: .semibold))
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(prominent ? color.opacity(0.2) : Color.clear)
            .foregroundStyle(color)
            .clipShape(Capsule())
            .overlay(
                Capsule().stroke(color.opacity(prominent ? 0 : 0.3), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Resolved icon

    @ViewBuilder
    private var resolvedIcon: some View {
        if let status = session.completionStatus {
            switch status {
            case .completed:
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 22))
                    .foregroundStyle(CoachColors.green)
            case .modified:
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 22))
                    .foregroundStyle(CoachColors.yellow)
            case .swapped:
                Image(systemName: "arrow.triangle.2.circlepath.circle.fill")
                    .font(.system(size: 22))
                    .foregroundStyle(CoachColors.blue)
            case .skipped:
                Image(systemName: "minus.circle")
                    .font(.system(size: 22))
                    .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - Helpers

    private var timeValue: String? {
        if let lo = session.estimatedDurationMin, let hi = session.estimatedDurationMax {
            return "\(lo)\u{2013}\(hi)m"
        }
        if let d = session.duration, d > 0 {
            return formatDuration(d)
        }
        return nil
    }

    private var distValue: String? {
        if let mi = session.distanceMiles, mi > 0 {
            return String(format: "%.1f mi", mi)
        }
        return nil
    }

    private var paceOrZone: (String, String)? {
        if let pace = session.paceRange, !pace.isEmpty {
            return ("PACE", pace)
        }
        if let zone = session.zone, !zone.isEmpty {
            return ("ZONE", zone)
        }
        return nil
    }

    private var completionText: String {
        var parts: [String] = []
        if let d = session.actualDuration, d > 0 {
            parts.append("\(d) min")
        } else if let d = session.duration, d > 0 {
            parts.append("\(d) min")
        }
        if let dist = session.actualDistance, dist > 0 {
            parts.append(String(format: "%.1f mi", dist))
        }
        return parts.isEmpty ? "Completed" : parts.joined(separator: " \u{00B7} ")
    }

    private func statusColor(_ status: CompletionStatus) -> Color {
        switch status {
        case .completed: return CoachColors.green
        case .modified: return CoachColors.yellow
        case .swapped: return CoachColors.blue
        case .skipped: return .secondary
        }
    }

    private func statItem(label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(CoachFonts.mono(10, weight: .semibold))
                .foregroundStyle(.secondary)
            Text(value)
                .font(CoachFonts.mono(14, weight: .bold))
                .foregroundStyle(.primary)
        }
    }

    private func warningRow(_ warning: String) -> some View {
        HStack(alignment: .top, spacing: 6) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(CoachColors.yellow)
            Text(warning)
                .font(CoachFonts.ui(11, weight: .medium))
                .foregroundStyle(.primary)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(CoachColors.yellow.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

// MARK: - Week Summary

private struct ChatWeekSummary: View {
    let data: WeekSummaryData

    var body: some View {
        CoachCard {
            VStack(alignment: .leading, spacing: 10) {
                // Day dots
                HStack(spacing: 8) {
                    ForEach(Array(zip(dayLabels.indices, dayLabels)), id: \.0) { idx, label in
                        VStack(spacing: 4) {
                            Text(label)
                                .font(CoachFonts.mono(10, weight: .semibold))
                                .foregroundStyle(.secondary)
                            dotView(for: idx < data.dots.count ? data.dots[idx] : .pending)
                        }
                    }
                    Spacer()
                }

                // Stats row
                HStack(spacing: 16) {
                    Text("SESSIONS \(data.sessionsCompleted)/\(data.total)")
                        .font(CoachFonts.mono(11, weight: .semibold))
                        .foregroundStyle(.secondary)
                    Text("ADHERENCE \(Int(data.adherence * 100))%")
                        .font(CoachFonts.mono(11, weight: .semibold))
                        .foregroundStyle(.secondary)
                    Spacer()
                }
            }
        }
    }

    private let dayLabels = ["M", "T", "W", "T", "F", "S", "S"]

    @ViewBuilder
    private func dotView(for status: DotStatus) -> some View {
        switch status {
        case .rest:
            Image(systemName: "moon.fill")
                .font(.system(size: 12))
                .foregroundStyle(CoachColors.purple)
                .frame(width: 24, height: 24)
        case .pending:
            Circle()
                .stroke(Color.gray.opacity(0.4), lineWidth: 1.5)
                .frame(width: 24, height: 24)
        case .completed:
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 20))
                .foregroundStyle(CoachColors.green)
                .frame(width: 24, height: 24)
        case .modified:
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 20))
                .foregroundStyle(CoachColors.yellow)
                .frame(width: 24, height: 24)
        case .swapped:
            Image(systemName: "arrow.triangle.2.circlepath.circle.fill")
                .font(.system(size: 20))
                .foregroundStyle(CoachColors.blue)
                .frame(width: 24, height: 24)
        case .skipped:
            Image(systemName: "xmark.circle.fill")
                .font(.system(size: 20))
                .foregroundStyle(CoachColors.red)
                .frame(width: 24, height: 24)
        case .needsReview:
            Image(systemName: "questionmark.circle.fill")
                .font(.system(size: 20))
                .foregroundStyle(CoachColors.yellow)
                .frame(width: 24, height: 24)
        case .today:
            Circle()
                .stroke(CoachColors.accent, lineWidth: 2)
                .frame(width: 24, height: 24)
                .overlay(
                    Circle()
                        .fill(CoachColors.accent)
                        .frame(width: 8, height: 8)
                )
        }
    }
}

// MARK: - Stat Highlight

private struct ChatStatHighlight: View {
    let data: StatHighlightData

    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(data.label.uppercased())
                    .font(CoachFonts.mono(10, weight: .semibold))
                    .foregroundStyle(.secondary)
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text(data.value)
                        .font(CoachFonts.display(22, weight: .bold))
                        .foregroundStyle(.primary)
                    if let trend = data.trend {
                        Text(trend)
                            .font(CoachFonts.ui(12, weight: .semibold))
                            .foregroundStyle(data.trendUp == true ? CoachColors.green : (data.trendUp == false ? CoachColors.red : .secondary))
                    }
                }
            }
            Spacer()
        }
        .padding(14)
        .background(colorScheme == .dark ? CoachColors.darkCard : CoachColors.lightCard)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(colorScheme == .dark ? CoachColors.darkBorder : CoachColors.lightBorder, lineWidth: 1)
        )
    }
}

// MARK: - Race Countdown

private struct ChatRaceCountdown: View {
    let data: RaceCountdownData

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("RACE DAY")
                    .font(CoachFonts.mono(10, weight: .semibold))
                    .foregroundStyle(.secondary)
                Text(data.name)
                    .font(CoachFonts.display(16, weight: .bold))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
            }
            Spacer()
            VStack(spacing: 0) {
                Text("\(data.weeksOut)")
                    .font(CoachFonts.display(28, weight: .bold))
                    .foregroundStyle(CoachColors.accent)
                Text("weeks")
                    .font(CoachFonts.mono(10, weight: .semibold))
                    .foregroundStyle(CoachColors.accent)
            }
        }
        .padding(14)
        .background(
            LinearGradient(
                colors: [CoachColors.accent.opacity(0.08), Color.clear],
                startPoint: .leading,
                endPoint: .trailing
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(CoachColors.accent.opacity(0.2), lineWidth: 1)
        )
    }
}

// MARK: - Phase Progress

private struct ChatPhaseProgress: View {
    let data: PhaseProgressData

    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        HStack(spacing: 12) {
            // Phase indicator
            ZStack {
                Circle()
                    .fill(CoachColors.green.opacity(0.15))
                    .frame(width: 36, height: 36)
                Text("\(data.phaseNumber)")
                    .font(CoachFonts.display(16, weight: .bold))
                    .foregroundStyle(CoachColors.green)
            }

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text("PHASE \(data.phaseNumber) OF \(data.totalPhases)")
                        .font(CoachFonts.mono(10, weight: .semibold))
                        .foregroundStyle(CoachColors.green)
                    Text("\u{00B7}")
                        .foregroundStyle(.secondary)
                    Text("\(data.weeksLeft)w left")
                        .font(CoachFonts.mono(10, weight: .semibold))
                        .foregroundStyle(.secondary)
                }
                Text(data.phaseName)
                    .font(CoachFonts.ui(14, weight: .semibold))
                    .foregroundStyle(.primary)
            }

            Spacer()

            // Mini progress bar
            GeometryReader { geo in
                let progress = Double(data.phaseNumber) / Double(data.totalPhases)
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color.gray.opacity(0.2))
                    RoundedRectangle(cornerRadius: 3)
                        .fill(CoachColors.green)
                        .frame(width: geo.size.width * progress)
                }
            }
            .frame(width: 60, height: 6)
        }
        .padding(14)
        .background(colorScheme == .dark ? CoachColors.darkCard : CoachColors.lightCard)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(colorScheme == .dark ? CoachColors.darkBorder : CoachColors.lightBorder, lineWidth: 1)
        )
    }
}
