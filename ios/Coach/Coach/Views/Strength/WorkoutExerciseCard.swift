import SwiftUI

/// A single exercise inside WorkoutLoggingView. Shows the exercise header,
/// a set grid the athlete fills in, inline rest-time config, and an
/// "Add Set" button. All mutations flow back to the parent via closures so
/// the parent owns the session state in DataService.
struct WorkoutExerciseCard: View {
    let exerciseIndex: Int
    let exercise: Exercise
    let previousBest: ExerciseSet?

    let onUpdateSet: (Int, (inout ExerciseSet) -> Void) -> Void
    let onToggleCompleted: (Int) -> Void
    let onAddSet: () -> Void
    let onRemoveSet: (Int) -> Void
    let onRemoveExercise: () -> Void
    let onMoveUp: () -> Void
    let onMoveDown: () -> Void
    let canMoveUp: Bool
    let canMoveDown: Bool
    let onUpdateRest: (Int) -> Void
    let onUpdateNotes: (String) -> Void

    @Environment(\.colorScheme) private var colorScheme
    @State private var showNotesEditor = false
    @State private var notesDraft = ""
    @State private var showRestPicker = false

    private let restOptions = [30, 45, 60, 75, 90, 120, 150, 180, 210, 240, 300]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            header

            if let notes = exercise.notes, !notes.isEmpty {
                Text(notes)
                    .font(CoachFonts.ui(12))
                    .italic()
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            setColumnHeader

            ForEach(Array(exercise.sets.enumerated()), id: \.offset) { idx, set in
                WorkoutSetRow(
                    setIndex: idx,
                    set: set,
                    type: exercise.exerciseType,
                    previousBest: previousBest,
                    onUpdateWeight: { newValue in
                        onUpdateSet(idx) { $0.weight = newValue }
                    },
                    onUpdateReps: { newValue in
                        onUpdateSet(idx) { $0.reps = newValue }
                    },
                    onUpdateDuration: { newValue in
                        onUpdateSet(idx) { $0.duration = newValue }
                    },
                    onUpdateBand: { newValue in
                        onUpdateSet(idx) { $0.band = newValue }
                    },
                    onToggleCompleted: { onToggleCompleted(idx) },
                    onDelete: { onRemoveSet(idx) }
                )
            }

            HStack(spacing: 10) {
                Button {
                    onAddSet()
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "plus")
                            .font(.system(size: 11, weight: .bold))
                        Text("Add Set")
                            .font(CoachFonts.ui(13, weight: .semibold))
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(Capsule().fill(Color.secondary.opacity(0.12)))
                    .foregroundStyle(.primary)
                }
                .buttonStyle(.plain)

                Spacer()

                Button {
                    showRestPicker = true
                } label: {
                    HStack(spacing: 5) {
                        Image(systemName: "timer")
                            .font(.system(size: 11, weight: .semibold))
                        Text(restLabel)
                            .font(CoachFonts.ui(12, weight: .semibold))
                    }
                    .foregroundStyle(CoachColors.accent)
                }
                .buttonStyle(.plain)
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
        .sheet(isPresented: $showNotesEditor) {
            NavigationStack {
                NotesEditorSheet(initial: exercise.notes ?? "") { newNotes in
                    onUpdateNotes(newNotes)
                    showNotesEditor = false
                }
            }
            .presentationDetents([.medium])
        }
        .confirmationDialog(
            "Rest timer",
            isPresented: $showRestPicker,
            titleVisibility: .visible
        ) {
            ForEach(restOptions, id: \.self) { sec in
                Button(formatRestOption(sec)) {
                    onUpdateRest(sec)
                }
            }
            Button("Off", role: .destructive) {
                onUpdateRest(0)
            }
            Button("Cancel", role: .cancel) {}
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack(alignment: .center, spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text(exercise.name)
                    .font(CoachFonts.ui(16, weight: .semibold))
                    .foregroundStyle(CoachColors.accent)
                    .lineLimit(2)
                HStack(spacing: 6) {
                    CoachPill(text: exercise.exerciseType.label, color: CoachColors.yellow)
                    if let completedCount = completedLabel {
                        Text(completedCount)
                            .font(CoachFonts.ui(11))
                            .foregroundStyle(.secondary)
                    }
                }
            }
            Spacer()

            HStack(spacing: 4) {
                Button {
                    withAnimation(.easeInOut(duration: 0.25)) { onMoveUp() }
                } label: {
                    Image(systemName: "chevron.up")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(canMoveUp ? .primary : .quaternary)
                        .frame(width: 30, height: 30)
                        .background(Circle().fill(Color.secondary.opacity(canMoveUp ? 0.12 : 0.05)))
                }
                .buttonStyle(.plain)
                .disabled(!canMoveUp)

                Button {
                    withAnimation(.easeInOut(duration: 0.25)) { onMoveDown() }
                } label: {
                    Image(systemName: "chevron.down")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(canMoveDown ? .primary : .quaternary)
                        .frame(width: 30, height: 30)
                        .background(Circle().fill(Color.secondary.opacity(canMoveDown ? 0.12 : 0.05)))
                }
                .buttonStyle(.plain)
                .disabled(!canMoveDown)
            }

            Menu {
                Button {
                    notesDraft = exercise.notes ?? ""
                    showNotesEditor = true
                } label: {
                    Label(exercise.notes?.isEmpty == false ? "Edit Note" : "Add Note",
                          systemImage: "note.text")
                }
                Button(role: .destructive) {
                    onRemoveExercise()
                } label: {
                    Label("Remove Exercise", systemImage: "trash")
                }
            } label: {
                Image(systemName: "ellipsis")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .frame(width: 32, height: 32)
                    .contentShape(Rectangle())
            }
        }
    }

    private var completedLabel: String? {
        let done = exercise.sets.filter(\.completed).count
        guard !exercise.sets.isEmpty else { return nil }
        return "\(done)/\(exercise.sets.count) done"
    }

    private var restLabel: String {
        guard let rest = exercise.rest, rest > 0 else { return "Rest: off" }
        return "Rest: \(formatRestOption(rest))"
    }

    private func formatRestOption(_ seconds: Int) -> String {
        if seconds >= 60 {
            let m = seconds / 60
            let s = seconds % 60
            return s == 0 ? "\(m)m" : "\(m)m \(s)s"
        }
        return "\(seconds)s"
    }

    // MARK: - Column header row

    @ViewBuilder
    private var setColumnHeader: some View {
        HStack(spacing: 8) {
            Text("SET")
                .frame(width: 32, alignment: .center)
            Text("PREVIOUS")
                .frame(maxWidth: .infinity, alignment: .center)
            columnLabel
                .frame(width: 140, alignment: .center)
            Image(systemName: "checkmark")
                .frame(width: 36, alignment: .center)
        }
        .font(CoachFonts.ui(10, weight: .semibold))
        .foregroundStyle(.secondary)
        .tracking(0.5)
        .padding(.top, 4)
    }

    @ViewBuilder
    private var columnLabel: some View {
        switch exercise.exerciseType {
        case .weighted:
            Text("LBS × REPS")
        case .bodyweight, .cardioDrill:
            Text("REPS")
        case .timed:
            Text("TIME (S)")
        case .banded:
            Text("BAND × REPS")
        }
    }
}

// MARK: - Notes Editor

private struct NotesEditorSheet: View {
    let initial: String
    let onSave: (String) -> Void

    @State private var text: String
    @Environment(\.dismiss) private var dismiss

    init(initial: String, onSave: @escaping (String) -> Void) {
        self.initial = initial
        self.onSave = onSave
        _text = State(initialValue: initial)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            CoachLabel(text: "Exercise Notes")
            TextEditor(text: $text)
                .font(CoachFonts.ui(14))
                .padding(8)
                .frame(minHeight: 140)
                .background(Color.secondary.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 10))
            Spacer()
        }
        .padding()
        .navigationTitle("Notes")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button("Cancel") { dismiss() }
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button("Save") {
                    onSave(text.trimmingCharacters(in: .whitespacesAndNewlines))
                }
                .fontWeight(.semibold)
            }
        }
    }
}
