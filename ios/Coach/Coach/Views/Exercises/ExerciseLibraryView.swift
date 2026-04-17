import SwiftUI

struct ExerciseLibraryView: View {
    @Environment(DataService.self) var data
    @Environment(\.colorScheme) var colorScheme

    @State private var searchText = ""
    @State private var bodyPartFilter: String?
    @State private var equipmentFilter: String?
    @State private var showAddSheet = false

    private let bodyParts = ["Chest", "Back", "Legs", "Shoulders", "Arms", "Core", "Full Body"]
    private let categories = ["Barbell", "Dumbbell", "Machine", "Cable", "Bodyweight", "Band", "Kettlebell"]

    var body: some View {
        // Compute the filtered/grouped data and PR map once per body render
        // so the row helper can read them without re-scanning sessions.
        let allItems = data.allExercises()
        let prMap = data.sessionPRs()
        let filtered = applyFilters(to: allItems)
        let nonHistory = filtered.filter { !$0.isFromHistory }
        let sections = Dictionary(grouping: nonHistory) { String($0.name.uppercased().prefix(1)) }
            .map { (letter: $0.key, items: $0.value) }
            .sorted { $0.letter < $1.letter }
        let historyRows = filtered.filter { $0.isFromHistory }

        return ScrollView {
            LazyVStack(alignment: .leading, spacing: 14) {
                searchField
                    .padding(.horizontal)

                HStack(spacing: 10) {
                    Menu {
                        Button {
                            bodyPartFilter = nil
                        } label: {
                            if bodyPartFilter == nil {
                                Label("All Body Parts", systemImage: "checkmark")
                            } else {
                                Text("All Body Parts")
                            }
                        }
                        ForEach(bodyParts, id: \.self) { part in
                            Button {
                                bodyPartFilter = part
                            } label: {
                                if bodyPartFilter == part {
                                    Label(part, systemImage: "checkmark")
                                } else {
                                    Text(part)
                                }
                            }
                        }
                    } label: {
                        FilterDropdown(
                            label: bodyPartFilter ?? "Body Part",
                            icon: "figure.arms.open",
                            isActive: bodyPartFilter != nil
                        )
                    }

                    Menu {
                        Button {
                            equipmentFilter = nil
                        } label: {
                            if equipmentFilter == nil {
                                Label("All Equipment", systemImage: "checkmark")
                            } else {
                                Text("All Equipment")
                            }
                        }
                        ForEach(categories, id: \.self) { cat in
                            Button {
                                equipmentFilter = cat
                            } label: {
                                if equipmentFilter == cat {
                                    Label(cat, systemImage: "checkmark")
                                } else {
                                    Text(cat)
                                }
                            }
                        }
                    } label: {
                        FilterDropdown(
                            label: equipmentFilter ?? "Equipment",
                            icon: "dumbbell",
                            isActive: equipmentFilter != nil
                        )
                    }

                    Spacer()
                }
                .padding(.horizontal)

                if sections.isEmpty && historyRows.isEmpty {
                    ContentUnavailableView(
                        "No Exercises",
                        systemImage: "magnifyingglass",
                        description: Text("Try clearing filters or adding a custom exercise.")
                    )
                    .padding(.top, 40)
                } else {
                    ForEach(sections, id: \.letter) { section in
                        sectionHeader(section.letter)
                        ForEach(section.items) { item in
                            row(item, pr: prMap[item.slug] ?? data.prs[item.slug])
                        }
                    }

                    if !historyRows.isEmpty {
                        sectionHeader("From Your History")
                        ForEach(historyRows) { item in
                            row(item, pr: prMap[item.slug] ?? data.prs[item.slug])
                        }
                    }
                }

                Spacer(minLength: 24)
            }
            .padding(.vertical, 12)
        }
        .background((colorScheme == .dark ? CoachColors.darkBg : CoachColors.lightBg).ignoresSafeArea())
        .navigationTitle("Exercise Library")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showAddSheet = true
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 22))
                        .foregroundStyle(CoachColors.accent)
                }
            }
        }
        .sheet(isPresented: $showAddSheet) {
            NavigationStack {
                AddCustomExerciseView()
            }
        }
    }

    // MARK: - Search

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

    // Chip rows replaced by FilterDropdown menus above.

    // MARK: - Sections

    private func sectionHeader(_ text: String) -> some View {
        CoachLabel(text: text)
            .padding(.horizontal)
            .padding(.top, 8)
    }

    private func row(_ item: ExerciseLibraryItem, pr: PersonalRecord?) -> some View {
        NavigationLink {
            ExerciseDetailView(slug: item.slug)
        } label: {
            CoachCard(padding: 14) {
                HStack(spacing: 10) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(item.name)
                            .font(CoachFonts.ui(14, weight: .semibold))
                            .foregroundStyle(.primary)
                            .multilineTextAlignment(.leading)
                        Text("\(item.bodyPart) · \(item.category)")
                            .font(CoachFonts.ui(11))
                            .foregroundStyle(.secondary)
                    }
                    Spacer(minLength: 8)
                    if item.isCustom {
                        CoachPill(text: "Custom", color: CoachColors.purple)
                    }
                    if item.isFromHistory {
                        CoachPill(text: "History", color: CoachColors.cyan)
                    }
                    if let pr, let summary = Self.quickPRSummary(pr) {
                        Text(summary)
                            .font(CoachFonts.mono(12))
                            .foregroundStyle(.secondary)
                    }
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.tertiary)
                }
            }
            .padding(.horizontal)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Filtering

    private func applyFilters(to items: [ExerciseLibraryItem]) -> [ExerciseLibraryItem] {
        let q = searchText.trimmingCharacters(in: .whitespaces).lowercased()
        return items.filter { item in
            if !q.isEmpty {
                let inName = item.name.lowercased().contains(q)
                let inBody = item.bodyPart.lowercased().contains(q)
                if !inName && !inBody { return false }
            }
            if let bp = bodyPartFilter, item.bodyPart != bp {
                return false
            }
            if let eq = equipmentFilter, item.category != eq {
                return false
            }
            return true
        }
    }

    // MARK: - PR Formatting

    static func quickPRSummary(_ pr: PersonalRecord) -> String? {
        switch pr.exerciseType {
        case .weighted:
            if let w = pr.weight, let r = pr.reps {
                return "\(Int(w)) × \(r)"
            }
        case .bodyweight, .cardioDrill:
            if let r = pr.bestReps { return "\(r) reps" }
        case .timed:
            if let d = pr.bestDuration, d > 0 {
                let mins = Int(d) / 60
                let secs = Int(d) % 60
                return mins > 0 ? "\(mins):\(String(format: "%02d", secs))" : "\(Int(d))s"
            }
        case .banded:
            if let b = pr.band, let r = pr.bestReps {
                return "\(b) × \(r)"
            }
        }
        return nil
    }
}

