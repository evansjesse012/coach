import SwiftUI

/// One row inside WorkoutExerciseCard representing a single set.
///
/// Columns (left → right):
/// - Set number ("1", "2", ...)
/// - Previous value ("185 × 5" from last time the athlete hit this lift)
/// - Input pair: weight × reps / reps / time / band
/// - Checkmark to mark the set complete
///
/// The inputs are `TextField` with decimal / number-pad keyboards so they
/// round-trip cleanly to `Double?` / `Int?` on the model.
struct WorkoutSetRow: View {
    let setIndex: Int
    let set: ExerciseSet
    let type: ExerciseType
    let previousBest: ExerciseSet?

    let onUpdateWeight: (Double?) -> Void
    let onUpdateReps: (Int?) -> Void
    let onUpdateDuration: (Double?) -> Void
    let onUpdateBand: (String?) -> Void
    let onToggleCompleted: () -> Void
    let onDelete: () -> Void

    @Environment(\.colorScheme) private var colorScheme
    @FocusState private var focusedField: Field?

    private enum Field: Hashable {
        case weight, reps, duration, band
    }

    var body: some View {
        HStack(spacing: 8) {
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    onDelete()
                }
            } label: {
                Image(systemName: "minus.circle.fill")
                    .font(.system(size: 18))
                    .foregroundStyle(.red)
            }
            .buttonStyle(.plain)

            Text("\(setIndex + 1)")
                .font(CoachFonts.mono(14, weight: .bold))
                .frame(width: 32, height: 32)
                .background(
                    Circle()
                        .fill(set.completed ? CoachColors.green.opacity(0.2) : Color.secondary.opacity(0.12))
                )
                .foregroundStyle(set.completed ? CoachColors.green : .primary)

            Text(previousText)
                .font(CoachFonts.mono(12))
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .frame(maxWidth: .infinity, alignment: .center)

            inputs
                .frame(width: 140)

            Button(action: onToggleCompleted) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(set.completed ? CoachColors.green : Color.secondary.opacity(0.15))
                    Image(systemName: "checkmark")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(set.completed ? .white : .secondary)
                }
                .frame(width: 36, height: 36)
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 6)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(rowBackground)
        )
        .contextMenu {
            Button(role: .destructive) {
                onDelete()
            } label: {
                Label("Delete Set", systemImage: "trash")
            }
        }
    }

    // MARK: - Row background

    private var rowBackground: Color {
        if set.completed {
            return CoachColors.green.opacity(0.08)
        }
        return colorScheme == .dark ? Color.white.opacity(0.02) : Color.black.opacity(0.02)
    }

    // MARK: - Previous value

    private var previousText: String {
        guard let previous = previousBest else { return "—" }
        switch type {
        case .weighted:
            if let w = previous.weight, let r = previous.reps {
                return "\(formatWeight(w)) × \(r)"
            }
            return "—"
        case .bodyweight, .cardioDrill:
            if let r = previous.reps { return "\(r) reps" }
            return "—"
        case .timed:
            if let d = previous.duration { return "\(Int(d))s" }
            return "—"
        case .banded:
            if let b = previous.band, let r = previous.reps { return "\(b) × \(r)" }
            return "—"
        }
    }

    private func formatWeight(_ w: Double) -> String {
        if w == w.rounded() { return "\(Int(w))" }
        return String(format: "%.1f", w)
    }

    // MARK: - Inputs (varies by exercise type)

    @ViewBuilder
    private var inputs: some View {
        switch type {
        case .weighted:
            HStack(spacing: 6) {
                NumericField(
                    value: Binding(
                        get: { set.weight },
                        set: { onUpdateWeight($0) }
                    ),
                    placeholder: "lbs",
                    isInt: false
                )
                .focused($focusedField, equals: .weight)

                Text("×")
                    .font(CoachFonts.mono(12, weight: .semibold))
                    .foregroundStyle(.secondary)

                IntField(
                    value: Binding(
                        get: { set.reps },
                        set: { onUpdateReps($0) }
                    ),
                    placeholder: "reps"
                )
                .focused($focusedField, equals: .reps)
            }

        case .bodyweight, .cardioDrill:
            IntField(
                value: Binding(
                    get: { set.reps },
                    set: { onUpdateReps($0) }
                ),
                placeholder: "reps"
            )
            .focused($focusedField, equals: .reps)

        case .timed:
            NumericField(
                value: Binding(
                    get: { set.duration },
                    set: { onUpdateDuration($0) }
                ),
                placeholder: "sec",
                isInt: true
            )
            .focused($focusedField, equals: .duration)

        case .banded:
            HStack(spacing: 6) {
                Menu {
                    ForEach(["light", "medium", "heavy"], id: \.self) { option in
                        Button(option.capitalized) {
                            onUpdateBand(option)
                        }
                    }
                } label: {
                    Text(set.band?.capitalized ?? "Band")
                        .font(CoachFonts.mono(12, weight: .semibold))
                        .foregroundStyle(.primary)
                        .frame(minWidth: 56, minHeight: 32)
                        .padding(.horizontal, 8)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color.secondary.opacity(0.12))
                        )
                }
                .menuStyle(.borderlessButton)

                Text("×")
                    .font(CoachFonts.mono(12, weight: .semibold))
                    .foregroundStyle(.secondary)

                IntField(
                    value: Binding(
                        get: { set.reps },
                        set: { onUpdateReps($0) }
                    ),
                    placeholder: "reps"
                )
                .focused($focusedField, equals: .reps)
            }
        }
    }
}

// MARK: - NumericField

/// Decimal input bound to an optional Double. Empty string → nil.
private struct NumericField: View {
    @Binding var value: Double?
    let placeholder: String
    var isInt: Bool

    @State private var text: String = ""
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        TextField(placeholder, text: $text)
            .font(CoachFonts.mono(14, weight: .semibold))
            .keyboardType(isInt ? .numberPad : .decimalPad)
            .multilineTextAlignment(.center)
            .frame(minHeight: 32)
            .padding(.horizontal, 6)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(colorScheme == .dark ? Color.white.opacity(0.05) : Color.black.opacity(0.04))
            )
            .onAppear {
                text = format(value)
            }
            .onChange(of: text) { _, newValue in
                if newValue.isEmpty {
                    value = nil
                } else if let d = Double(newValue) {
                    value = isInt ? Double(Int(d)) : d
                }
            }
            .onChange(of: value) { _, newValue in
                // Only sync the incoming model value into the text field when
                // the field is empty — otherwise we'd clobber in-progress edits.
                if text.isEmpty {
                    text = format(newValue)
                }
            }
    }

    private func format(_ value: Double?) -> String {
        guard let v = value else { return "" }
        if isInt {
            return "\(Int(v))"
        }
        if v == v.rounded() {
            return "\(Int(v))"
        }
        return String(format: "%.1f", v)
    }
}

// MARK: - IntField

/// Number-pad input bound to an optional Int. Empty string → nil.
private struct IntField: View {
    @Binding var value: Int?
    let placeholder: String

    @State private var text: String = ""
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        TextField(placeholder, text: $text)
            .font(CoachFonts.mono(14, weight: .semibold))
            .keyboardType(.numberPad)
            .multilineTextAlignment(.center)
            .frame(minHeight: 32)
            .padding(.horizontal, 6)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(colorScheme == .dark ? Color.white.opacity(0.05) : Color.black.opacity(0.04))
            )
            .onAppear {
                text = value.map(String.init) ?? ""
            }
            .onChange(of: text) { _, newValue in
                if newValue.isEmpty {
                    value = nil
                } else if let i = Int(newValue) {
                    value = i
                }
            }
            .onChange(of: value) { _, newValue in
                if text.isEmpty {
                    text = newValue.map(String.init) ?? ""
                }
            }
    }
}
