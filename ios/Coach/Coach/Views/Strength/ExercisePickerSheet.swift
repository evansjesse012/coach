import SwiftUI

/// Lightweight "tap to pick" version of ExerciseLibraryView used during an
/// active workout. Reuses the same merged catalog (`DataService.allExercises`)
/// but replaces the NavigationLink behavior with a selection closure, so
/// WorkoutLoggingView can drop the chosen exercise into the session.
struct ExercisePickerSheet: View {
    @Environment(DataService.self) private var data
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme

    let onPick: (ExerciseLibraryItem) -> Void

    @State private var searchText = ""
    @State private var selectedBodyPart: String?

    private let bodyParts = ["Chest", "Back", "Legs", "Shoulders", "Arms", "Core", "Full Body"]

    var body: some View {
        let items = filteredItems()

        ScrollView {
            LazyVStack(alignment: .leading, spacing: 10) {
                searchField
                    .padding(.horizontal)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        pickerChip(label: "All", isSelected: selectedBodyPart == nil) {
                            selectedBodyPart = nil
                        }
                        ForEach(bodyParts, id: \.self) { bp in
                            pickerChip(label: bp, isSelected: selectedBodyPart == bp) {
                                selectedBodyPart = selectedBodyPart == bp ? nil : bp
                            }
                        }
                    }
                    .padding(.horizontal)
                }

                if items.isEmpty {
                    ContentUnavailableView(
                        "No exercises",
                        systemImage: "magnifyingglass",
                        description: Text("Try a different search or filter.")
                    )
                    .padding(.top, 40)
                } else {
                    ForEach(items) { item in
                        Button {
                            onPick(item)
                        } label: {
                            row(item)
                        }
                        .buttonStyle(.plain)
                        .padding(.horizontal)
                    }
                }

                Spacer(minLength: 24)
            }
            .padding(.vertical, 12)
        }
        .background((colorScheme == .dark ? CoachColors.darkBg : CoachColors.lightBg).ignoresSafeArea())
        .navigationTitle("Add Exercise")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button("Cancel") { dismiss() }
            }
        }
    }

    // MARK: - Subviews

    private var searchField: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
            TextField("Search exercises", text: $searchText)
                .font(CoachFonts.ui(15))
                .textFieldStyle(.plain)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
            if !searchText.isEmpty {
                Button {
                    searchText = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(colorScheme == .dark ? CoachColors.darkElevated : CoachColors.lightElevated)
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(colorScheme == .dark ? CoachColors.darkBorder : CoachColors.lightBorder, lineWidth: 1)
        )
    }

    private func pickerChip(label: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(CoachFonts.ui(12, weight: isSelected ? .semibold : .regular))
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(isSelected ? CoachColors.accent.opacity(0.15) : Color(.secondarySystemBackground))
                .foregroundStyle(isSelected ? CoachColors.accent : .primary)
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }

    private func row(_ item: ExerciseLibraryItem) -> some View {
        CoachCard(padding: 12) {
            HStack(spacing: 10) {
                ZStack {
                    Circle()
                        .fill(CoachColors.yellow.opacity(0.15))
                        .frame(width: 34, height: 34)
                    Image(systemName: "dumbbell.fill")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(CoachColors.yellow)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(item.name)
                        .font(CoachFonts.ui(14, weight: .semibold))
                        .foregroundStyle(.primary)
                        .multilineTextAlignment(.leading)
                    Text("\(item.bodyPart) · \(item.category)")
                        .font(CoachFonts.ui(11))
                        .foregroundStyle(.secondary)
                }

                Spacer()

                if item.isCustom {
                    CoachPill(text: "Custom", color: CoachColors.purple)
                }
                if item.isFromHistory {
                    CoachPill(text: "History", color: CoachColors.cyan)
                }
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 20))
                    .foregroundStyle(CoachColors.accent)
            }
        }
    }

    // MARK: - Filtering

    private func filteredItems() -> [ExerciseLibraryItem] {
        let q = searchText.trimmingCharacters(in: .whitespaces).lowercased()
        return data.allExercises().filter { item in
            if !q.isEmpty {
                let matchesName = item.name.lowercased().contains(q)
                let matchesBody = item.bodyPart.lowercased().contains(q)
                if !matchesName && !matchesBody { return false }
            }
            if let bp = selectedBodyPart, item.bodyPart != bp { return false }
            return true
        }
    }
}
