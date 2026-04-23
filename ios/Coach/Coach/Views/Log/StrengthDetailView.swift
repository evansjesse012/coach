import SwiftUI

struct StrengthDetailView: View {
    let session: StrengthSession
    @Environment(DataService.self) private var data
    @Environment(\.colorScheme) var colorScheme
    @State private var showWorkoutLogger = false
    @State private var showRepeatConfirm = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                CoachCard(accentColor: CoachColors.yellow) {
                    VStack(alignment: .leading, spacing: 8) {
                        SportBadge(sport: .strength)
                        Text(session.name)
                            .font(CoachFonts.display(20, weight: .bold))
                        HStack(spacing: 12) {
                            Label(formatDateRelative(session.date), systemImage: "calendar")
                            if let dur = session.duration {
                                Label(formatDuration(dur), systemImage: "clock")
                            }
                            let setCount = session.exercises.reduce(0) { $0 + $1.sets.filter(\.completed).count }
                            Label("\(setCount) sets", systemImage: "checkmark.circle.fill")
                        }
                        .font(CoachFonts.ui(12))
                        .foregroundStyle(.secondary)
                    }
                }

                repeatWorkoutButton

                ForEach(session.exercises) { exercise in
                    exerciseCard(exercise)
                }
            }
            .padding()
        }
        .clearsTabBar()
        .background((colorScheme == .dark ? CoachColors.darkBg : CoachColors.lightBg).ignoresSafeArea())
        .navigationTitle("Strength")
        .navigationBarTitleDisplayMode(.inline)
        .fullScreenCover(isPresented: $showWorkoutLogger) {
            NavigationStack {
                WorkoutLoggingView()
            }
        }
        .confirmationDialog(
            "Workout already in progress",
            isPresented: $showRepeatConfirm,
            titleVisibility: .visible
        ) {
            Button("Resume current workout") {
                showWorkoutLogger = true
            }
            Button("Discard and repeat this", role: .destructive) {
                data.cancelActiveWorkout()
                data.startStrengthWorkout(session.cloneForRepeat())
                showWorkoutLogger = true
            }
            Button("Cancel", role: .cancel) {}
        }
    }

    private var repeatWorkoutButton: some View {
        Button {
            if data.activeStrengthSession != nil {
                showRepeatConfirm = true
            } else {
                data.startStrengthWorkout(session.cloneForRepeat())
                showWorkoutLogger = true
            }
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "arrow.clockwise.circle.fill")
                    .font(.system(size: 16, weight: .bold))
                Text("Repeat Workout")
                    .font(CoachFonts.ui(14, weight: .bold))
                Spacer()
                Image(systemName: "arrow.right")
                    .font(.system(size: 12, weight: .bold))
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(
                LinearGradient(
                    colors: [CoachColors.accent, CoachColors.accent.opacity(0.85)],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
    }

    private func exerciseCard(_ exercise: Exercise) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(exercise.name)
                    .font(CoachFonts.ui(15, weight: .semibold))
                Spacer()
                CoachPill(text: exercise.exerciseType.label, color: CoachColors.yellow)
                NavigationLink {
                    ExerciseDetailView(slug: exercise.name.slugified)
                } label: {
                    Image(systemName: "clock.arrow.circlepath")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(CoachColors.accent)
                }
                .buttonStyle(.plain)
            }

            VStack(spacing: 4) {
                ForEach(exercise.sets.indices, id: \.self) { idx in
                    let s = exercise.sets[idx]
                    HStack {
                        Text("Set \(s.setNum)")
                            .font(CoachFonts.mono(12, weight: .semibold))
                            .foregroundStyle(.secondary)
                            .frame(width: 50, alignment: .leading)

                        if let w = s.weight, let r = s.reps {
                            Text("\(formatWeight(w)) × \(r)")
                                .font(CoachFonts.mono(13))
                        } else if let r = s.reps {
                            Text("\(r) reps").font(CoachFonts.mono(13))
                        } else if let d = s.duration {
                            Text("\(Int(d))s").font(CoachFonts.mono(13))
                        } else if let band = s.band {
                            Text(band).font(CoachFonts.mono(13))
                        }

                        Spacer()

                        if s.completed {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(CoachColors.green)
                        } else {
                            Image(systemName: "circle")
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }

            if let rest = exercise.rest {
                Text("Rest: \(rest)s")
                    .font(CoachFonts.ui(11))
                    .foregroundStyle(.secondary)
            }
            if let notes = exercise.notes, !notes.isEmpty {
                Text(notes)
                    .font(CoachFonts.ui(12))
                    .foregroundStyle(.secondary)
            }
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

    private func formatWeight(_ w: Double) -> String {
        if w == w.rounded() { return "\(Int(w))lb" }
        return String(format: "%.1flb", w)
    }
}
