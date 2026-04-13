import SwiftUI

struct AddCustomExerciseView: View {
    @Environment(DataService.self) var data
    @Environment(\.dismiss) var dismiss

    @State private var name: String = ""
    @State private var bodyPart: String = "Chest"
    @State private var category: String = "Barbell"
    @State private var exerciseType: ExerciseType = .weighted
    @State private var errorMessage: String?
    @State private var isSaving = false

    private let bodyParts = ["Chest", "Back", "Legs", "Shoulders", "Arms", "Core", "Full Body", "Other"]
    private let categories = ["Barbell", "Dumbbell", "Machine", "Cable", "Bodyweight", "Kettlebell", "Band", "Other"]

    var body: some View {
        Form {
            Section("Name") {
                TextField("Exercise name", text: $name)
                    .textInputAutocapitalization(.words)
                    .autocorrectionDisabled()
            }

            Section("Details") {
                Picker("Body part", selection: $bodyPart) {
                    ForEach(bodyParts, id: \.self) { Text($0).tag($0) }
                }
                Picker("Equipment", selection: $category) {
                    ForEach(categories, id: \.self) { Text($0).tag($0) }
                }
                Picker("Type", selection: $exerciseType) {
                    ForEach(ExerciseType.allCases) { type in
                        Text(type.label).tag(type)
                    }
                }
            }

            if let errorMessage {
                Section {
                    Text(errorMessage)
                        .font(CoachFonts.ui(12))
                        .foregroundStyle(CoachColors.red)
                }
            }
        }
        .navigationTitle("Add Exercise")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button("Cancel") { dismiss() }
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button("Save") {
                    Task { await save() }
                }
                .disabled(isSaving || name.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
    }

    private func save() async {
        isSaving = true
        errorMessage = nil
        do {
            try await data.addCustomExercise(
                name: name,
                bodyPart: bodyPart,
                category: category,
                type: exerciseType
            )
            dismiss()
        } catch let err as CustomExerciseError {
            errorMessage = err.errorDescription
        } catch {
            errorMessage = error.localizedDescription
        }
        isSaving = false
    }
}
