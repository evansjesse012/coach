import SwiftUI
import UIKit

/// Full-screen live strength workout logging view.
///
/// Modeled after the Strong app: the athlete sees every exercise with
/// editable weight/reps inputs, checks off each set as they complete it, and
/// a between-set rest timer auto-starts when a set is marked done. State
/// lives in `DataService.activeStrengthSession` so the view can be dismissed
/// and resumed, and the workout survives app kills via UserDefaults.
struct WorkoutLoggingView: View {
    @Environment(DataService.self) private var data
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dismiss) private var dismiss

    @State private var showCancelConfirm = false
    @State private var showFinishConfirm = false
    @State private var showExercisePicker = false

    var body: some View {
        ZStack(alignment: .bottom) {
            (colorScheme == .dark ? CoachColors.darkBg : CoachColors.lightBg)
                .ignoresSafeArea()

            if let session = data.activeStrengthSession {
                content(for: session)
            } else {
                emptyState
            }

            // Floating rest timer pinned above the finish bar.
            if data.restTimerSecondsRemaining != nil {
                RestTimerOverlay()
                    .padding(.horizontal, 16)
                    .padding(.bottom, 96)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        // Only animate the overlay insert/remove, not every tick.
        .animation(.easeInOut(duration: 0.25), value: data.restTimerSecondsRemaining == nil)
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button {
                    showCancelConfirm = true
                } label: {
                    Image(systemName: "chevron.down")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(.primary)
                        .padding(8)
                        .background(Circle().fill(Color.secondary.opacity(0.15)))
                }
            }
            ToolbarItem(placement: .principal) {
                ElapsedTimeView(startedAt: data.activeWorkoutStartedAt)
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showFinishConfirm = true
                } label: {
                    Text("Finish")
                        .font(CoachFonts.ui(14, weight: .bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 7)
                        .background(Capsule().fill(CoachColors.green))
                }
                .disabled((data.activeStrengthSession?.completedSetCount ?? 0) == 0)
                .opacity((data.activeStrengthSession?.completedSetCount ?? 0) == 0 ? 0.4 : 1)
            }
        }
        .confirmationDialog(
            "Discard workout?",
            isPresented: $showCancelConfirm,
            titleVisibility: .visible
        ) {
            Button("Keep logging", role: .cancel) {}
            Button("Minimize") {
                // Just dismiss the sheet; the workout keeps running in the
                // background and can be resumed from the ActiveWorkoutBar.
                dismiss()
            }
            Button("Discard workout", role: .destructive) {
                data.cancelActiveWorkout()
                dismiss()
            }
        } message: {
            Text("Minimize keeps your sets. Discard deletes this workout.")
        }
        .confirmationDialog(
            "Finish this workout?",
            isPresented: $showFinishConfirm,
            titleVisibility: .visible
        ) {
            Button("Finish workout", role: .none) {
                Task {
                    do {
                        try await data.finishActiveWorkout()
                        UINotificationFeedbackGenerator().notificationOccurred(.success)
                        dismiss()
                    } catch {
                        // Stay in the workout so the athlete doesn't lose it.
                    }
                }
            }
            Button("Keep logging", role: .cancel) {}
        } message: {
            if let s = data.activeStrengthSession {
                Text("\(s.completedSetCount) sets completed across \(s.exercises.count) exercises.")
            }
        }
        .sheet(isPresented: $showExercisePicker) {
            NavigationStack {
                ExercisePickerSheet { item in
                    addExercise(item)
                    showExercisePicker = false
                }
            }
        }
    }

    // MARK: - Main content

    @ViewBuilder
    private func content(for session: StrengthSession) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                header(for: session)

                if session.exercises.isEmpty {
                    addFirstExercisePrompt
                        .padding(.top, 40)
                } else {
                    ForEach(Array(session.exercises.enumerated()), id: \.offset) { idx, exercise in
                        WorkoutExerciseCard(
                            exerciseIndex: idx,
                            exercise: exercise,
                            previousBest: data.previousBest(forExerciseName: exercise.name),
                            onUpdateSet: { setIdx, mutation in
                                updateSet(exerciseIdx: idx, setIdx: setIdx, mutation)
                            },
                            onToggleCompleted: { setIdx in
                                toggleCompleted(exerciseIdx: idx, setIdx: setIdx)
                            },
                            onAddSet: { addSet(exerciseIdx: idx) },
                            onRemoveSet: { setIdx in removeSet(exerciseIdx: idx, setIdx: setIdx) },
                            onRemoveExercise: { removeExercise(idx: idx) },
                            onUpdateRest: { seconds in updateRest(exerciseIdx: idx, seconds: seconds) },
                            onUpdateNotes: { notes in updateNotes(exerciseIdx: idx, notes: notes) }
                        )
                    }

                    addMoreButton
                }

                // Bottom spacing so the finish bar never overlaps content.
                Spacer(minLength: 140)
            }
            .padding(.horizontal, 14)
            .padding(.top, 8)
        }
        .scrollDismissesKeyboard(.interactively)
    }

    // MARK: - Header

    private func header(for session: StrengthSession) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                ZStack {
                    Circle()
                        .fill(CoachColors.yellow.opacity(0.18))
                        .frame(width: 42, height: 42)
                    Image(systemName: "dumbbell.fill")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(CoachColors.yellow)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(session.name)
                        .font(CoachFonts.display(20, weight: .bold))
                        .lineLimit(2)
                    Text("\(session.completedSetCount)/\(max(session.totalSetCount, session.completedSetCount)) sets · \(session.exercises.count) exercises")
                        .font(CoachFonts.ui(12))
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }

            // Progress bar across the top of the workout
            let total = max(1, session.totalSetCount)
            let done = session.completedSetCount
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.secondary.opacity(0.15))
                    Capsule()
                        .fill(CoachColors.green)
                        .frame(width: geo.size.width * CGFloat(Double(done) / Double(total)))
                }
            }
            .frame(height: 4)
        }
        .padding(14)
        .background(colorScheme == .dark ? CoachColors.darkCard : CoachColors.lightCard)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(colorScheme == .dark ? CoachColors.darkBorder : CoachColors.lightBorder, lineWidth: 1)
        )
    }

    private var addMoreButton: some View {
        Button {
            showExercisePicker = true
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 16, weight: .semibold))
                Text("Add Exercise")
                    .font(CoachFonts.ui(14, weight: .semibold))
            }
            .foregroundStyle(CoachColors.accent)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity)
            .background(CoachColors.accent.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(CoachColors.accent.opacity(0.3), style: StrokeStyle(lineWidth: 1, dash: [6, 4]))
            )
        }
        .buttonStyle(.plain)
    }

    private var addFirstExercisePrompt: some View {
        VStack(spacing: 14) {
            Image(systemName: "dumbbell.fill")
                .font(.system(size: 42, weight: .semibold))
                .foregroundStyle(CoachColors.yellow.opacity(0.6))
            Text("No exercises yet")
                .font(CoachFonts.display(18, weight: .bold))
            Text("Add your first exercise to start logging sets.")
                .font(CoachFonts.ui(13))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Button {
                showExercisePicker = true
            } label: {
                Text("Add Exercise")
                    .font(CoachFonts.ui(14, weight: .semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    .background(Capsule().fill(CoachColors.accent))
            }
            .buttonStyle(.plain)
            .padding(.top, 4)
        }
        .frame(maxWidth: .infinity)
        .padding()
    }

    private var emptyState: some View {
        VStack(spacing: 10) {
            Text("No active workout")
                .font(CoachFonts.display(18, weight: .bold))
            Text("Start a workout from the Activities or Plan tab.")
                .font(CoachFonts.ui(13))
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Mutations

    private func updateSet(exerciseIdx: Int, setIdx: Int, _ mutation: (inout ExerciseSet) -> Void) {
        data.mutateActiveWorkout { session in
            guard exerciseIdx < session.exercises.count,
                  setIdx < session.exercises[exerciseIdx].sets.count else { return }
            mutation(&session.exercises[exerciseIdx].sets[setIdx])
        }
    }

    private func toggleCompleted(exerciseIdx: Int, setIdx: Int) {
        var justCompleted = false
        var restSeconds: Int?

        data.mutateActiveWorkout { session in
            guard exerciseIdx < session.exercises.count,
                  setIdx < session.exercises[exerciseIdx].sets.count else { return }
            let wasCompleted = session.exercises[exerciseIdx].sets[setIdx].completed
            session.exercises[exerciseIdx].sets[setIdx].completed.toggle()
            session.exercises[exerciseIdx].sets[setIdx].setNum = setIdx + 1
            justCompleted = !wasCompleted
            restSeconds = session.exercises[exerciseIdx].rest
        }

        if justCompleted {
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            if let rest = restSeconds, rest > 0 {
                data.startRestTimer(seconds: rest)
            }
        } else {
            UISelectionFeedbackGenerator().selectionChanged()
        }
    }

    private func addSet(exerciseIdx: Int) {
        data.mutateActiveWorkout { session in
            guard exerciseIdx < session.exercises.count else { return }
            let existing = session.exercises[exerciseIdx].sets
            let previous = existing.last
            let newSet = Exercise.blankSet(
                setNum: existing.count + 1,
                type: session.exercises[exerciseIdx].exerciseType,
                previous: previous
            )
            session.exercises[exerciseIdx].sets.append(newSet)
        }
        UISelectionFeedbackGenerator().selectionChanged()
    }

    private func removeSet(exerciseIdx: Int, setIdx: Int) {
        data.mutateActiveWorkout { session in
            guard exerciseIdx < session.exercises.count,
                  setIdx < session.exercises[exerciseIdx].sets.count else { return }
            session.exercises[exerciseIdx].sets.remove(at: setIdx)
            for i in session.exercises[exerciseIdx].sets.indices {
                session.exercises[exerciseIdx].sets[i].setNum = i + 1
            }
        }
    }

    private func removeExercise(idx: Int) {
        data.mutateActiveWorkout { session in
            guard idx < session.exercises.count else { return }
            session.exercises.remove(at: idx)
        }
    }

    private func updateRest(exerciseIdx: Int, seconds: Int) {
        data.mutateActiveWorkout { session in
            guard exerciseIdx < session.exercises.count else { return }
            session.exercises[exerciseIdx].rest = seconds > 0 ? seconds : nil
        }
    }

    private func updateNotes(exerciseIdx: Int, notes: String) {
        data.mutateActiveWorkout { session in
            guard exerciseIdx < session.exercises.count else { return }
            session.exercises[exerciseIdx].notes = notes.isEmpty ? nil : notes
        }
    }

    private func addExercise(_ item: ExerciseLibraryItem) {
        data.mutateActiveWorkout { session in
            let previous = data.previousBest(forExerciseName: item.name)
            let starterSets: [ExerciseSet] = (1...3).map { idx in
                Exercise.blankSet(setNum: idx, type: item.exerciseType, previous: previous)
            }
            let exercise = Exercise(
                name: item.name,
                exerciseType: item.exerciseType,
                sets: starterSets,
                rest: 90,
                notes: nil
            )
            session.exercises.append(exercise)
        }
    }
}

// MARK: - Elapsed Time

/// Self-updating "mm:ss" timer shown in the nav bar while the workout runs.
/// Uses a TimelineView so SwiftUI handles the tick without a manual Timer.
struct ElapsedTimeView: View {
    let startedAt: Date?

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            Text(format(startedAt: startedAt, now: context.date))
                .font(CoachFonts.mono(14, weight: .semibold))
                .monospacedDigit()
        }
    }

    private func format(startedAt: Date?, now: Date) -> String {
        guard let startedAt else { return "00:00" }
        let seconds = max(0, Int(now.timeIntervalSince(startedAt)))
        let h = seconds / 3600
        let m = (seconds % 3600) / 60
        let s = seconds % 60
        if h > 0 {
            return String(format: "%d:%02d:%02d", h, m, s)
        }
        return String(format: "%02d:%02d", m, s)
    }
}
