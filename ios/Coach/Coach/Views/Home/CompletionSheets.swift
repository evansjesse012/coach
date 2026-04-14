import SwiftUI

// MARK: - Shared input payloads

struct ModifiedActualInput {
    var duration: Int?
    var distance: Double?
    var note: String
}

struct SwappedActualInput {
    var sport: String
    var duration: Int?
    var note: String
}

// MARK: - Modified sheet

struct ModifiedCompletionSheet: View {
    let session: PrescribedSession
    let onSave: (ModifiedActualInput) -> Void

    @Environment(\.dismiss) var dismiss
    @Environment(\.colorScheme) var colorScheme

    @State private var durationText: String
    @State private var distanceText: String
    @State private var note: String = ""

    init(session: PrescribedSession, onSave: @escaping (ModifiedActualInput) -> Void) {
        self.session = session
        self.onSave = onSave
        _durationText = State(initialValue: session.duration.map(String.init) ?? "")
        _distanceText = State(initialValue: session.distanceMiles.map { String(format: "%.1f", $0) } ?? "")
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    header

                    VStack(alignment: .leading, spacing: 12) {
                        sectionLabel("WHAT DID YOU DO?")
                        labeledField(label: "Duration (min)", text: $durationText, keyboard: .numberPad, placeholder: "e.g. 42")
                        labeledField(label: "Distance (mi)", text: $distanceText, keyboard: .decimalPad, placeholder: "optional")
                    }

                    VStack(alignment: .leading, spacing: 12) {
                        sectionLabel("NOTES")
                        TextField("e.g. cut short due to rain", text: $note)
                            .font(CoachFonts.ui(14))
                            .padding(12)
                            .background(fieldBackground)
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                            .overlay(
                                RoundedRectangle(cornerRadius: 10)
                                    .stroke(fieldBorder, lineWidth: 1)
                            )
                    }
                }
                .padding()
            }
            .background((colorScheme == .dark ? CoachColors.darkBg : CoachColors.lightBg).ignoresSafeArea())
            .navigationTitle("Modified Workout")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        let actual = ModifiedActualInput(
                            duration: Int(durationText),
                            distance: Double(distanceText),
                            note: note.trimmingCharacters(in: .whitespaces)
                        )
                        onSave(actual)
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(session.label)
                .font(CoachFonts.display(18, weight: .bold))
            if let purpose = session.purpose {
                Text(purpose)
                    .font(CoachFonts.ui(12))
                    .italic()
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func sectionLabel(_ text: String) -> some View {
        Text(text)
            .font(CoachFonts.ui(10, weight: .semibold))
            .tracking(0.6)
            .foregroundStyle(.secondary)
    }

    private func labeledField(
        label: String,
        text: Binding<String>,
        keyboard: UIKeyboardType,
        placeholder: String
    ) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label.uppercased())
                .font(CoachFonts.ui(10, weight: .semibold))
                .tracking(0.5)
                .foregroundStyle(.tertiary)
            TextField(placeholder, text: text)
                .font(CoachFonts.ui(14))
                .keyboardType(keyboard)
                .padding(10)
                .background(fieldBackground)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(fieldBorder, lineWidth: 1)
                )
        }
    }

    private var fieldBackground: Color {
        colorScheme == .dark ? CoachColors.darkElevated : CoachColors.lightElevated
    }
    private var fieldBorder: Color {
        colorScheme == .dark ? CoachColors.darkBorder : CoachColors.lightBorder
    }
}

// MARK: - Swapped sheet

struct SwappedCompletionSheet: View {
    let session: PrescribedSession
    let otherSessions: [PrescribedSession]
    let onSave: (SwappedActualInput) -> Void

    @Environment(\.dismiss) var dismiss
    @Environment(\.colorScheme) var colorScheme

    @State private var customSport: String = "run"
    @State private var customDurationText: String = ""
    @State private var note: String = ""
    @State private var useCustom: Bool = false

    private let sports: [(String, String)] = [
        ("run", "Run"),
        ("bike", "Bike"),
        ("swim", "Swim"),
        ("strength", "Strength"),
        ("other", "Other"),
    ]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    header

                    if !otherSessions.isEmpty && !useCustom {
                        VStack(alignment: .leading, spacing: 10) {
                            sectionLabel("DID YOU DO ONE OF THESE INSTEAD?")
                            ForEach(otherSessions, id: \.id) { other in
                                Button {
                                    let actual = SwappedActualInput(
                                        sport: other.type,
                                        duration: other.duration,
                                        note: "Did \(other.label) instead"
                                    )
                                    onSave(actual)
                                    dismiss()
                                } label: {
                                    HStack {
                                        if let sport = Sport(rawValue: other.type.lowercased()) {
                                            SportBadge(sport: sport)
                                        }
                                        Text(other.label)
                                            .font(CoachFonts.ui(14, weight: .semibold))
                                            .foregroundStyle(.primary)
                                        Spacer()
                                        Image(systemName: "chevron.right")
                                            .font(.system(size: 12, weight: .semibold))
                                            .foregroundStyle(.tertiary)
                                    }
                                    .padding(12)
                                    .background(fieldBackground)
                                    .clipShape(RoundedRectangle(cornerRadius: 10))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 10)
                                            .stroke(fieldBorder, lineWidth: 1)
                                    )
                                }
                                .buttonStyle(.plain)
                            }
                            Button {
                                useCustom = true
                            } label: {
                                Text("Something else →")
                                    .font(CoachFonts.ui(13, weight: .semibold))
                                    .foregroundStyle(CoachColors.accent)
                                    .padding(.vertical, 4)
                            }
                            .buttonStyle(.plain)
                        }
                    }

                    if useCustom || otherSessions.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            sectionLabel("WHAT DID YOU DO INSTEAD?")
                            VStack(alignment: .leading, spacing: 4) {
                                Text("SPORT")
                                    .font(CoachFonts.ui(10, weight: .semibold))
                                    .tracking(0.5)
                                    .foregroundStyle(.tertiary)
                                Picker("", selection: $customSport) {
                                    ForEach(sports, id: \.0) { pair in
                                        Text(pair.1).tag(pair.0)
                                    }
                                }
                                .pickerStyle(.segmented)
                            }
                            labeledField(
                                label: "Duration (min)",
                                text: $customDurationText,
                                keyboard: .numberPad,
                                placeholder: "e.g. 45"
                            )
                            VStack(alignment: .leading, spacing: 4) {
                                Text("NOTES")
                                    .font(CoachFonts.ui(10, weight: .semibold))
                                    .tracking(0.5)
                                    .foregroundStyle(.tertiary)
                                TextField("optional", text: $note)
                                    .font(CoachFonts.ui(14))
                                    .padding(10)
                                    .background(fieldBackground)
                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 8)
                                            .stroke(fieldBorder, lineWidth: 1)
                                    )
                            }
                        }
                    }
                }
                .padding()
            }
            .background((colorScheme == .dark ? CoachColors.darkBg : CoachColors.lightBg).ignoresSafeArea())
            .navigationTitle("Swapped Workout")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                if useCustom || otherSessions.isEmpty {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Save") {
                            let actual = SwappedActualInput(
                                sport: customSport,
                                duration: Int(customDurationText),
                                note: note.trimmingCharacters(in: .whitespaces)
                            )
                            onSave(actual)
                            dismiss()
                        }
                        .fontWeight(.semibold)
                        .disabled(customSport.isEmpty)
                    }
                }
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(session.label)
                .font(CoachFonts.display(18, weight: .bold))
                .strikethrough()
                .foregroundStyle(.secondary)
            Text("Instead of this session")
                .font(CoachFonts.ui(12))
                .foregroundStyle(.secondary)
        }
    }

    private func sectionLabel(_ text: String) -> some View {
        Text(text)
            .font(CoachFonts.ui(10, weight: .semibold))
            .tracking(0.6)
            .foregroundStyle(.secondary)
    }

    private func labeledField(
        label: String,
        text: Binding<String>,
        keyboard: UIKeyboardType,
        placeholder: String
    ) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label.uppercased())
                .font(CoachFonts.ui(10, weight: .semibold))
                .tracking(0.5)
                .foregroundStyle(.tertiary)
            TextField(placeholder, text: text)
                .font(CoachFonts.ui(14))
                .keyboardType(keyboard)
                .padding(10)
                .background(fieldBackground)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(fieldBorder, lineWidth: 1)
                )
        }
    }

    private var fieldBackground: Color {
        colorScheme == .dark ? CoachColors.darkElevated : CoachColors.lightElevated
    }
    private var fieldBorder: Color {
        colorScheme == .dark ? CoachColors.darkBorder : CoachColors.lightBorder
    }
}

// MARK: - Skipped sheet

struct SkippedCompletionSheet: View {
    let onSave: (SkipReason, String) -> Void

    @Environment(\.dismiss) var dismiss
    @Environment(\.colorScheme) var colorScheme

    @State private var note: String = ""

    private let reasons: [(SkipReason, String, String)] = [
        (.fatigue, "Fatigue", "bed.double.fill"),
        (.time, "Time", "clock.fill"),
        (.soreness, "Soreness", "bandage.fill"),
        (.life, "Life", "figure.wave"),
    ]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    Text("Skip Reason")
                        .font(CoachFonts.display(18, weight: .bold))
                    Text("No judgment — just pick what fits.")
                        .font(CoachFonts.ui(12))
                        .foregroundStyle(.secondary)

                    LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10) {
                        ForEach(reasons, id: \.0) { reason, label, icon in
                            Button {
                                onSave(reason, note.trimmingCharacters(in: .whitespaces))
                                dismiss()
                            } label: {
                                VStack(spacing: 8) {
                                    Image(systemName: icon)
                                        .font(.system(size: 22, weight: .semibold))
                                        .foregroundStyle(CoachColors.accent)
                                    Text(label)
                                        .font(CoachFonts.ui(13, weight: .semibold))
                                        .foregroundStyle(.primary)
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 18)
                                .background(fieldBackground)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(fieldBorder, lineWidth: 1)
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text("NOTES")
                            .font(CoachFonts.ui(10, weight: .semibold))
                            .tracking(0.5)
                            .foregroundStyle(.tertiary)
                        TextField("optional", text: $note)
                            .font(CoachFonts.ui(14))
                            .padding(10)
                            .background(fieldBackground)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(fieldBorder, lineWidth: 1)
                            )
                    }
                }
                .padding()
            }
            .background((colorScheme == .dark ? CoachColors.darkBg : CoachColors.lightBg).ignoresSafeArea())
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }

    private var fieldBackground: Color {
        colorScheme == .dark ? CoachColors.darkElevated : CoachColors.lightElevated
    }
    private var fieldBorder: Color {
        colorScheme == .dark ? CoachColors.darkBorder : CoachColors.lightBorder
    }
}
