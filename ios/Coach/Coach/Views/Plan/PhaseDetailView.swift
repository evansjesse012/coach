import SwiftUI

// MARK: - Standalone screen wrapper

struct PhaseDetailView: View {
    let plan: TrainingPlan
    let phase: TrainingPhase

    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                PhaseDetailContent(plan: plan, phase: phase)
            }
            .padding()
        }
        .background((colorScheme == .dark ? CoachColors.darkBg : CoachColors.lightBg).ignoresSafeArea())
        .navigationTitle(phase.name)
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Reusable content (used by PhaseDetailView and PlanReviewView)

struct PhaseDetailContent: View {
    let plan: TrainingPlan
    let phase: TrainingPhase
    /// When true, renders the phase header (badge + name + dates). Set to
    /// false when embedding inside an `ExpandablePhaseSection`, which draws
    /// its own collapsible header.
    var showHeader: Bool = true

    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            if showHeader {
                header
            }

            // THE GOAL — why this phase exists
            if hasGoalContent {
                groupLabel("The goal")
                if let philosophy = phase.philosophy, !philosophy.isEmpty {
                    paragraphBlock(title: "Philosophy", body: philosophy)
                }
                if let goals = phase.physiologicalGoals, !goals.isEmpty {
                    bulletBlock(title: "What we're targeting", items: goals)
                }
            }

            // THE WORK — what you'll actually do
            groupLabel("The work")
            volumeIntensityBlock
            if let workouts = phase.keyWorkouts, !workouts.isEmpty {
                keyWorkoutsBlock(workouts: workouts)
            }
            if let strength = phase.strengthFocus, !strength.isEmpty {
                paragraphBlock(title: "Strength focus", body: strength)
            }

            // THE ARC — how it progresses + race specifics
            if hasArcContent {
                groupLabel("The arc")
                if let progression = phase.progressionRules, !progression.isEmpty {
                    paragraphBlock(title: "Progression", body: progression)
                }
                if let race = phase.raceSpecificNotes, !race.isEmpty {
                    paragraphBlock(title: "Race-specific notes", body: race)
                }
            }
        }
    }

    private var hasGoalContent: Bool {
        let hasPhilosophy = (phase.philosophy?.isEmpty == false)
        let hasGoals = (phase.physiologicalGoals?.isEmpty == false)
        return hasPhilosophy || hasGoals
    }

    private var hasArcContent: Bool {
        let hasProgression = (phase.progressionRules?.isEmpty == false)
        let hasRace = (phase.raceSpecificNotes?.isEmpty == false)
        return hasProgression || hasRace
    }

    // MARK: header

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Text("PHASE \(phase.number) OF \(plan.phases.count)")
                    .font(CoachFonts.ui(11, weight: .semibold))
                    .tracking(0.8)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(phase.accentColor.opacity(0.15))
                    .foregroundStyle(phase.accentColor)
                    .clipShape(Capsule())
                Spacer()
                Text("Weeks \(plan.startWeek(for: phase))-\(plan.endWeek(for: phase))")
                    .font(CoachFonts.mono(12))
                    .foregroundStyle(.secondary)
            }
            Text(phase.name)
                .font(CoachFonts.display(24, weight: .bold))
            if let start = phase.startDate, let end = phase.endDate {
                Text("\(formatDateShort(start)) – \(formatDateShort(end))")
                    .font(CoachFonts.ui(13))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.bottom, 4)
    }

    // MARK: group divider

    @ViewBuilder
    private func groupLabel(_ text: String) -> some View {
        HStack(spacing: 8) {
            Rectangle()
                .fill(phase.accentColor.opacity(0.35))
                .frame(width: 12, height: 2)
            Text(text.uppercased())
                .font(CoachFonts.ui(10, weight: .semibold))
                .foregroundStyle(.secondary)
                .tracking(1.0)
            Rectangle()
                .fill((colorScheme == .dark ? CoachColors.darkBorder : CoachColors.lightBorder))
                .frame(height: 1)
        }
        .padding(.top, 4)
    }

    // MARK: volume + intensity

    private var volumeIntensityBlock: some View {
        sectionCard(title: "Volume + intensity") {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 24) {
                    if let v = phase.weeklyVolumeRange {
                        statColumn(label: "Weekly volume", value: "\(formatVolumeValue(v.min))–\(formatVolumeValue(v.max))", unit: v.unit)
                    }
                    if let s = phase.sessionsPerWeek {
                        statColumn(label: "Sessions/wk", value: "\(s)", unit: nil)
                    }
                }
                if let dist = phase.intensityDistribution {
                    VStack(alignment: .leading, spacing: 6) {
                        IntensityBar(distribution: dist)
                        IntensityLegend(distribution: dist)
                    }
                }
            }
        }
    }

    private func statColumn(label: String, value: String, unit: String?) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label.uppercased())
                .font(CoachFonts.ui(10, weight: .semibold))
                .foregroundStyle(.secondary)
                .tracking(0.5)
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(value)
                    .font(CoachFonts.display(18, weight: .bold))
                if let unit { Text(unit).font(CoachFonts.ui(11)).foregroundStyle(.secondary) }
            }
        }
    }

    // MARK: key workouts

    private func keyWorkoutsBlock(workouts: [KeyWorkout]) -> some View {
        sectionCard(title: "Key workouts") {
            VStack(alignment: .leading, spacing: 10) {
                ForEach(workouts) { w in
                    VStack(alignment: .leading, spacing: 2) {
                        Text(w.name)
                            .font(CoachFonts.ui(14, weight: .semibold))
                        Text(w.description)
                            .font(CoachFonts.ui(13))
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
    }

    // MARK: text + bullet blocks

    private func paragraphBlock(title: String, body: String) -> some View {
        let sentences = splitSentences(body)
        return sectionCard(title: title) {
            if sentences.count > 1 {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(Array(sentences.enumerated()), id: \.offset) { _, sentence in
                        HStack(alignment: .firstTextBaseline, spacing: 8) {
                            Circle()
                                .fill(phase.accentColor.opacity(0.4))
                                .frame(width: 4, height: 4)
                            Text(sentence)
                                .font(CoachFonts.ui(13))
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
            } else {
                Text(body)
                    .font(CoachFonts.ui(13))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    /// Splits a block of text into individual sentences for easier scanning.
    private func splitSentences(_ text: String) -> [String] {
        var sentences: [String] = []
        var current = ""
        let chars = Array(text)
        var i = 0
        while i < chars.count {
            current.append(chars[i])
            // Split on ". " followed by an uppercase letter (new sentence)
            if chars[i] == "." && i + 2 < chars.count && chars[i + 1] == " " && chars[i + 2].isUppercase {
                let trimmed = current.trimmingCharacters(in: .whitespaces)
                if !trimmed.isEmpty { sentences.append(trimmed) }
                current = ""
                i += 2 // skip the space, loop will pick up the uppercase char
                continue
            }
            i += 1
        }
        let trimmed = current.trimmingCharacters(in: .whitespaces)
        if !trimmed.isEmpty { sentences.append(trimmed) }
        return sentences
    }

    private func bulletBlock(title: String, items: [String]) -> some View {
        sectionCard(title: title) {
            VStack(alignment: .leading, spacing: 4) {
                ForEach(items, id: \.self) { item in
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text("•").font(CoachFonts.ui(13)).foregroundStyle(phase.accentColor)
                        Text(item)
                            .font(CoachFonts.ui(13))
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
        }
    }

    // MARK: card chrome

    @ViewBuilder
    private func sectionCard<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title.uppercased())
                .font(CoachFonts.ui(11, weight: .semibold))
                .foregroundStyle(.secondary)
                .tracking(0.5)
            content()
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(colorScheme == .dark ? CoachColors.darkCard : CoachColors.lightCard)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(colorScheme == .dark ? CoachColors.darkBorder : CoachColors.lightBorder, lineWidth: 1)
        )
    }
}

// MARK: - Helpers used by PhaseDetailContent and PlanReviewView

func formatVolumeValue(_ v: Double) -> String {
    v == v.rounded() ? "\(Int(v))" : String(format: "%.1f", v)
}
