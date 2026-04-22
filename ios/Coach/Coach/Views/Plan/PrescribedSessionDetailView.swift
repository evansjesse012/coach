import SwiftUI

struct PrescribedSessionDetailView: View {
    let session: PrescribedSession
    let dateString: String?

    @Environment(DataService.self) private var data
    @Environment(\.colorScheme) var colorScheme
    @State private var showNotes = false
    @State private var showNutrition = false
    @State private var showWorkoutLogger = false
    @State private var showResumeConfirm = false

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
                    startWorkoutCTA
                    exerciseListCard(exercises)
                }

                if let notes = session.notes, !notes.isEmpty {
                    coachNotesSection(notes)
                }

                if let fuel = session.fuel, hasAnyFuel(fuel) {
                    nutritionSection(fuel)
                }

                recordedWorkoutCard
            }
            .padding()
        }
        .background((colorScheme == .dark ? CoachColors.darkBg : CoachColors.lightBg).ignoresSafeArea())
        .navigationTitle(session.label)
        .navigationBarTitleDisplayMode(.inline)
        .fullScreenCover(isPresented: $showWorkoutLogger) {
            NavigationStack {
                WorkoutLoggingView()
            }
        }
        .confirmationDialog(
            "Workout already in progress",
            isPresented: $showResumeConfirm,
            titleVisibility: .visible
        ) {
            Button("Resume") {
                showWorkoutLogger = true
            }
            Button("Discard and start new", role: .destructive) {
                data.cancelActiveWorkout()
                data.startStrengthWorkout(StrengthSession.fromPrescribed(session))
                showWorkoutLogger = true
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            if let active = data.activeStrengthSession {
                Text("You have “\(active.name)” in progress. Resume it or start a new one?")
            }
        }
    }

    // MARK: - Start Workout CTA

    @ViewBuilder
    private var startWorkoutCTA: some View {
        Button {
            if data.activeStrengthSession != nil {
                showResumeConfirm = true
            } else {
                data.startStrengthWorkout(StrengthSession.fromPrescribed(session))
                showWorkoutLogger = true
            }
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "play.fill")
                    .font(.system(size: 14, weight: .bold))
                Text(startButtonLabel)
                    .font(CoachFonts.ui(15, weight: .bold))
                Spacer()
                Image(systemName: "arrow.right")
                    .font(.system(size: 13, weight: .bold))
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 18)
            .padding(.vertical, 14)
            .background(
                LinearGradient(
                    colors: [CoachColors.accent, CoachColors.accent.opacity(0.85)],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .shadow(color: CoachColors.accent.opacity(0.25), radius: 8, y: 3)
        }
        .buttonStyle(.plain)
    }

    private var startButtonLabel: String {
        if let active = data.activeStrengthSession, active.templateId == session.templateId {
            return "Resume Workout"
        }
        if data.activeStrengthSession != nil {
            return "Start Workout"
        }
        return "Start Workout"
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
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                CoachLabel(text: "Exercises")
                Spacer()
                Text("\(exercises.count) · \(totalSets(exercises)) sets")
                    .font(CoachFonts.ui(11))
                    .foregroundStyle(.secondary)
            }
            ForEach(Array(exercises.enumerated()), id: \.offset) { idx, exercise in
                exerciseCard(exercise, index: idx)
            }
        }
    }

    private func exerciseCard(_ exercise: PrescribedExercise, index: Int) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .center, spacing: 10) {
                ZStack {
                    Circle()
                        .fill(CoachColors.yellow.opacity(0.18))
                        .frame(width: 32, height: 32)
                    Text("\(index + 1)")
                        .font(CoachFonts.mono(13, weight: .bold))
                        .foregroundStyle(CoachColors.yellow)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(exercise.name)
                        .font(CoachFonts.ui(15, weight: .semibold))
                        .foregroundStyle(.primary)
                    HStack(spacing: 6) {
                        CoachPill(text: exercise.exerciseType.label, color: CoachColors.yellow)
                        if let rest = exercise.rest, rest > 0 {
                            Text("Rest \(formatRest(rest))")
                                .font(CoachFonts.ui(11))
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                Spacer()
            }

            VStack(spacing: 4) {
                ForEach(0..<(exercise.sets ?? 0), id: \.self) { setIdx in
                    HStack {
                        Text("Set \(setIdx + 1)")
                            .font(CoachFonts.mono(12, weight: .semibold))
                            .foregroundStyle(.secondary)
                            .frame(width: 58, alignment: .leading)
                        Text(setTargetText(exercise))
                            .font(CoachFonts.mono(13, weight: .medium))
                            .foregroundStyle(.primary)
                        Spacer()
                        Image(systemName: "circle")
                            .font(.system(size: 14))
                            .foregroundStyle(.tertiary)
                    }
                    .padding(.vertical, 2)
                }
                if (exercise.sets ?? 0) == 0 {
                    HStack {
                        Text(setsRepsText(exercise))
                            .font(CoachFonts.mono(13, weight: .medium))
                            .foregroundStyle(.secondary)
                        Spacer()
                    }
                }
            }

            if let cue = exercise.notes, !cue.isEmpty {
                Text(cue)
                    .font(CoachFonts.ui(12))
                    .italic()
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(colorScheme == .dark ? CoachColors.darkCard : CoachColors.lightCard)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(colorScheme == .dark ? CoachColors.darkBorder : CoachColors.lightBorder, lineWidth: 1)
        )
    }

    private func totalSets(_ exercises: [PrescribedExercise]) -> Int {
        exercises.reduce(0) { $0 + ($1.sets ?? 0) }
    }

    private func setTargetText(_ exercise: PrescribedExercise) -> String {
        if let reps = exercise.reps, reps > 0 {
            if let weight = exercise.weight, weight > 0 {
                let w = weight == weight.rounded() ? "\(Int(weight))" : String(format: "%.1f", weight)
                return "\(w) lb × \(reps)"
            }
            return "\(reps) reps"
        }
        if let d = exercise.duration, d > 0 {
            return "\(Int(d))s"
        }
        if let band = exercise.band, !band.isEmpty {
            return "\(band.capitalized) band"
        }
        return "—"
    }

    private func formatRest(_ seconds: Int) -> String {
        if seconds >= 60 {
            let m = seconds / 60
            let s = seconds % 60
            return s == 0 ? "\(m)m" : "\(m)m \(s)s"
        }
        return "\(seconds)s"
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
            VStack(spacing: 8) {
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

    // MARK: - Recorded Workout Card

    /// Finds a CardioWorkout that was auto-matched to this prescribed session.
    private var matchedWorkout: CardioWorkout? {
        guard session.completionStatus != nil,
              let dateStr = dateString else { return nil }
        let sportStr = session.type.lowercased()
        return data.cardio.first { w in
            w.date == dateStr && w.sport.rawValue == sportStr
        } ?? data.cardio.first { w in
            // Swapped: different sport but matched by date + actual_sport
            w.date == dateStr && session.actualSport?.lowercased() == w.sport.rawValue
        }
    }

    @ViewBuilder
    private var recordedWorkoutCard: some View {
        if let workout = matchedWorkout, session.completionStatus != nil {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 6) {
                    Image(systemName: "applewatch")
                        .font(.system(size: 12, weight: .semibold))
                    Text("RECORDED WORKOUT")
                        .font(CoachFonts.mono(10, weight: .semibold))
                    Spacer()
                    statusBadge
                }
                .foregroundStyle(statusColor)

                NavigationLink {
                    WorkoutDetailView(workout: workout)
                } label: {
                    HStack(spacing: 14) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("DURATION")
                                .font(CoachFonts.mono(9, weight: .semibold))
                                .foregroundStyle(.secondary)
                            Text(formatDuration(workout.duration))
                                .font(CoachFonts.mono(15, weight: .bold))
                                .foregroundStyle(.primary)
                        }
                        if let dist = workout.distance, !dist.isEmpty {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("DISTANCE")
                                    .font(CoachFonts.mono(9, weight: .semibold))
                                    .foregroundStyle(.secondary)
                                Text(dist)
                                    .font(CoachFonts.mono(15, weight: .bold))
                                    .foregroundStyle(.primary)
                            }
                        }
                        if let hr = workout.avgHR {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("AVG HR")
                                    .font(CoachFonts.mono(9, weight: .semibold))
                                    .foregroundStyle(.secondary)
                                Text("\(hr) bpm")
                                    .font(CoachFonts.mono(15, weight: .bold))
                                    .foregroundStyle(.primary)
                            }
                        }
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(.tertiary)
                    }
                }
                .buttonStyle(.plain)
            }
            .padding(14)
            .background(statusColor.opacity(0.06))
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(statusColor.opacity(0.2), lineWidth: 1)
            )
        }
    }

    @ViewBuilder
    private var statusBadge: some View {
        switch session.completionStatus {
        case .completed:
            CoachPill(text: "MATCHED", color: CoachColors.green)
        case .modified:
            CoachPill(text: "MODIFIED", color: CoachColors.yellow)
        case .swapped:
            CoachPill(text: "SWAPPED", color: CoachColors.blue)
        default:
            EmptyView()
        }
    }

    private var statusColor: Color {
        switch session.completionStatus {
        case .completed: return CoachColors.green
        case .modified: return CoachColors.yellow
        case .swapped: return CoachColors.blue
        default: return .secondary
        }
    }
}
