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

    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            header
            if let philosophy = phase.philosophy, !philosophy.isEmpty {
                paragraphBlock(title: "Philosophy", body: philosophy)
            }
            if let goals = phase.physiologicalGoals, !goals.isEmpty {
                bulletBlock(title: "What we're targeting", items: goals)
            }
            volumeIntensityBlock
            if let workouts = phase.keyWorkouts, !workouts.isEmpty {
                keyWorkoutsBlock(workouts: workouts)
            }
            if let strength = phase.strengthFocus, !strength.isEmpty {
                paragraphBlock(title: "Strength focus", body: strength)
            }
            if let progression = phase.progressionRules, !progression.isEmpty {
                paragraphBlock(title: "Progression", body: progression)
            }
            if let race = phase.raceSpecificNotes, !race.isEmpty {
                paragraphBlock(title: "Race-specific notes", body: race)
            }
        }
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

    // MARK: volume + intensity

    private var volumeIntensityBlock: some View {
        sectionCard(title: "Volume + intensity") {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 24) {
                    if let v = phase.weeklyVolumeRange {
                        statColumn(label: "Weekly volume", value: "\(formatVolume(v.min))–\(formatVolume(v.max))", unit: v.unit)
                    }
                    if let s = phase.sessionsPerWeek {
                        statColumn(label: "Sessions/wk", value: "\(s)", unit: nil)
                    }
                }
                if let dist = phase.intensityDistribution {
                    intensityBar(dist)
                }
            }
        }
    }

    private func intensityBar(_ d: IntensityDistribution) -> some View {
        let total = max(1, d.easy + d.tempo + d.threshold + d.vo2max)
        return VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 2) {
                segment(label: "Easy", pct: d.easy, total: total, color: CoachColors.green)
                segment(label: "Tempo", pct: d.tempo, total: total, color: CoachColors.yellow)
                segment(label: "Thresh", pct: d.threshold, total: total, color: CoachColors.accent)
                segment(label: "VO2", pct: d.vo2max, total: total, color: CoachColors.red)
            }
            .frame(height: 22)
            .clipShape(RoundedRectangle(cornerRadius: 4))

            HStack(spacing: 12) {
                legend("Easy", pct: d.easy, color: CoachColors.green)
                legend("Tempo", pct: d.tempo, color: CoachColors.yellow)
                legend("Thresh", pct: d.threshold, color: CoachColors.accent)
                legend("VO2", pct: d.vo2max, color: CoachColors.red)
            }
        }
    }

    private func segment(label: String, pct: Int, total: Int, color: Color) -> some View {
        let frac = Double(pct) / Double(total)
        return Rectangle()
            .fill(color)
            .frame(maxWidth: .infinity)
            .layoutPriority(frac)
            .opacity(pct > 0 ? 1 : 0)
    }

    private func legend(_ label: String, pct: Int, color: Color) -> some View {
        HStack(spacing: 4) {
            Circle().fill(color).frame(width: 8, height: 8)
            Text("\(label) \(pct)%")
                .font(CoachFonts.ui(11))
                .foregroundStyle(.secondary)
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

    private func formatVolume(_ v: Double) -> String {
        v == v.rounded() ? "\(Int(v))" : String(format: "%.1f", v)
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
        sectionCard(title: title) {
            Text(body)
                .font(CoachFonts.ui(13))
                .fixedSize(horizontal: false, vertical: true)
        }
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
