import SwiftUI

struct PrescribedSessionDetailView: View {
    let session: PrescribedSession
    let dateString: String?

    @Environment(\.colorScheme) var colorScheme
    @State private var showNotes = false
    @State private var showNutrition = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                header

                if let purpose = session.purpose, !purpose.isEmpty {
                    Text(purpose)
                        .font(CoachFonts.ui(13))
                        .italic()
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                if session.zone != nil || session.paceRange != nil {
                    zonePaceRow
                }

                if let workout = session.workout, !workout.isEmpty {
                    prescriptionBlock(workout)
                }

                if let warning = session.warning, !warning.isEmpty {
                    warningCallout(warning)
                }

                if session.type.lowercased() == "strength",
                   let exercises = session.exercises, !exercises.isEmpty {
                    exerciseListCard(exercises)
                }

                if let notes = session.notes, !notes.isEmpty {
                    coachNotesSection(notes)
                }

                if let fuel = session.fuel, hasAnyFuel(fuel) {
                    nutritionSection(fuel)
                }
            }
            .padding()
        }
        .background((colorScheme == .dark ? CoachColors.darkBg : CoachColors.lightBg).ignoresSafeArea())
        .navigationTitle(session.label)
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Header

    private var header: some View {
        HStack(alignment: .center, spacing: 12) {
            ZStack {
                Circle()
                    .fill(sportColor.opacity(0.15))
                    .frame(width: 52, height: 52)
                Image(systemName: sportIcon)
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(sportColor)
            }

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Text(session.label)
                        .font(CoachFonts.display(20, weight: .bold))
                        .lineLimit(2)
                    if let priority = session.priority {
                        Circle()
                            .fill(priorityColor(priority))
                            .frame(width: 10, height: 10)
                    }
                }
                if let dateString, !dateString.isEmpty {
                    Text(formatDayLong(dateString))
                        .font(CoachFonts.ui(12))
                        .foregroundStyle(.secondary)
                }
            }

            Spacer(minLength: 8)

            if !headerDuration.isEmpty {
                Text(headerDuration)
                    .font(CoachFonts.mono(15, weight: .semibold))
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var sport: Sport? { Sport(rawValue: session.type.lowercased()) }
    private var sportColor: Color { sport?.swiftUIColor ?? CoachColors.accent }
    private var sportIcon: String { sport?.sfSymbol ?? "figure.run" }

    private func priorityColor(_ p: SessionPriority) -> Color {
        switch p {
        case .red: return CoachColors.red
        case .yellow: return CoachColors.yellow
        }
    }

    private var headerDuration: String {
        if let d = session.duration, d > 0 {
            return formatDuration(d)
        }
        if let lo = session.estimatedDurationMin, let hi = session.estimatedDurationMax {
            return "\(lo)-\(hi)m"
        }
        return ""
    }

    // MARK: - Zone + pace

    private var zonePaceRow: some View {
        HStack(spacing: 10) {
            if let zone = session.zone, !zone.isEmpty {
                HStack(spacing: 4) {
                    Image(systemName: "heart.fill")
                        .font(.system(size: 11, weight: .semibold))
                    Text(zone)
                        .font(CoachFonts.ui(12, weight: .semibold))
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(CoachColors.accent.opacity(0.15))
                .foregroundStyle(CoachColors.accent)
                .clipShape(Capsule())
            }
            if let pace = session.paceRange, !pace.isEmpty {
                Text("\(pace) pace")
                    .font(CoachFonts.ui(13, weight: .semibold))
                    .foregroundStyle(CoachColors.accent)
            }
            Spacer()
        }
    }

    // MARK: - Workout prescription

    private func prescriptionBlock(_ workout: String) -> some View {
        Text(workout)
            .font(CoachFonts.mono(13))
            .foregroundStyle(.primary)
            .fixedSize(horizontal: false, vertical: true)
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(CoachColors.accent.opacity(0.06))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(CoachColors.accent.opacity(0.18), lineWidth: 1)
            )
    }

    // MARK: - Warning callout

    private func warningCallout(_ warning: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(CoachColors.yellow)
            Text(warning)
                .font(CoachFonts.ui(13, weight: .medium))
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(CoachColors.yellow.opacity(0.12))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(CoachColors.yellow.opacity(0.4), lineWidth: 1)
        )
    }

    // MARK: - Exercise list

    private func exerciseListCard(_ exercises: [PrescribedExercise]) -> some View {
        CoachCard {
            VStack(alignment: .leading, spacing: 14) {
                CoachLabel(text: "Exercises")
                ForEach(Array(exercises.enumerated()), id: \.offset) { _, exercise in
                    exerciseRow(exercise)
                }
            }
        }
    }

    private func exerciseRow(_ exercise: PrescribedExercise) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .firstTextBaseline) {
                Text(exercise.name)
                    .font(CoachFonts.ui(14, weight: .semibold))
                Spacer()
                Text(setsRepsText(exercise))
                    .font(CoachFonts.mono(13, weight: .semibold))
                    .foregroundStyle(CoachColors.accent)
            }
            if let cue = exercise.notes, !cue.isEmpty {
                Text(cue)
                    .font(CoachFonts.ui(12))
                    .italic()
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if let rest = exercise.rest, rest > 0 {
                Text("\(rest)s rest")
                    .font(CoachFonts.ui(11))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }

    private func setsRepsText(_ exercise: PrescribedExercise) -> String {
        let sets = exercise.sets ?? 0
        if let reps = exercise.reps, reps > 0 {
            return "\(sets)×\(reps)"
        }
        if let d = exercise.duration, d > 0 {
            return "\(sets)×\(Int(d))s"
        }
        if let band = exercise.band, !band.isEmpty {
            return "\(sets) \(band)"
        }
        return sets > 0 ? "\(sets) sets" : "—"
    }

    // MARK: - Collapsible: Coach notes

    private func coachNotesSection(_ notes: String) -> some View {
        let hasWarning = session.warning?.isEmpty == false
        return CollapsibleCard(
            icon: "sparkles",
            iconColor: CoachColors.purple,
            title: "Coach notes",
            isExpanded: showNotes,
            toggle: { showNotes.toggle() },
            accessoryIcon: hasWarning ? "exclamationmark.triangle.fill" : nil,
            accessoryColor: CoachColors.yellow
        ) {
            HStack(spacing: 0) {
                Rectangle()
                    .fill(CoachColors.purple)
                    .frame(width: 3)
                Text(notes)
                    .font(CoachFonts.ui(13))
                    .foregroundStyle(.primary)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .background(CoachColors.purple.opacity(0.06))
            .clipShape(RoundedRectangle(cornerRadius: 10))
        }
    }

    // MARK: - Collapsible: Nutrition

    private func nutritionSection(_ fuel: SessionFuel) -> some View {
        CollapsibleCard(
            icon: "fork.knife",
            iconColor: CoachColors.accent,
            title: "Nutrition",
            isExpanded: showNutrition,
            toggle: { showNutrition.toggle() }
        ) {
            HStack(alignment: .top, spacing: 8) {
                nutritionCard(label: "BEFORE", color: CoachColors.accent, text: fuel.pre)
                nutritionCard(label: "DURING", color: CoachColors.teal, text: fuel.during)
                nutritionCard(label: "AFTER", color: CoachColors.purple, text: fuel.post)
            }
        }
    }

    private func nutritionCard(label: String, color: Color, text: String?) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(CoachFonts.ui(10, weight: .bold))
                .tracking(0.8)
                .foregroundStyle(color)
            Text(text?.isEmpty == false ? text! : "—")
                .font(CoachFonts.ui(11))
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .padding(10)
        .background(color.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    private func hasAnyFuel(_ fuel: SessionFuel) -> Bool {
        (fuel.pre?.isEmpty == false) ||
            (fuel.during?.isEmpty == false) ||
            (fuel.post?.isEmpty == false)
    }

}
