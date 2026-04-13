import SwiftUI

// MARK: - Shared form

/// Shared create/edit form for Events. If `editingEventId` is nil the form
/// is in create mode; otherwise it pre-populates from the matching event
/// and on save calls updateEvent. Handles deletion in edit mode.
struct GoalFormView: View {
    let editingEventId: String?
    let onFinish: (GoalFormResult) -> Void

    @Environment(DataService.self) var data
    @Environment(\.dismiss) var dismiss

    @State private var selectedPreset: EventPreset?
    @State private var mode: EventMode = .goal
    @State private var name: String = ""
    @State private var hasDate: Bool = true
    @State private var date: Date = Date().addingTimeInterval(60 * 60 * 24 * 60)
    @State private var location: String = ""
    @State private var distance: String = ""
    @State private var goal: String = ""
    @State private var stretchGoal: String = ""
    @State private var baseline: String = ""
    @State private var bibNumber: String = ""
    @State private var url: String = ""
    @State private var showOptional = false
    @State private var showDeleteConfirm = false
    @State private var loaded = false

    private var isEditing: Bool { editingEventId != nil }

    var body: some View {
        NavigationStack {
            Form {
                Section("Event Type") {
                    ForEach(EventPreset.all) { preset in
                        Button {
                            selectedPreset = preset
                            if name.isEmpty { name = preset.name }
                            if !isEditing {
                                mode = preset.defaultMode
                            }
                            if distance.isEmpty {
                                distance = defaultDistance(for: preset.id) ?? ""
                            }
                        } label: {
                            HStack {
                                Image(systemName: preset.icon)
                                    .frame(width: 24)
                                    .foregroundStyle(CoachColors.accent)
                                Text(preset.name)
                                    .foregroundStyle(.primary)
                                Spacer()
                                if selectedPreset?.id == preset.id {
                                    Image(systemName: "checkmark")
                                        .foregroundStyle(CoachColors.accent)
                                }
                            }
                        }
                    }
                }

                Section("Basics") {
                    TextField("Name", text: $name)

                    Picker("Mode", selection: $mode) {
                        Text("Goal").tag(EventMode.goal)
                        Text("Race").tag(EventMode.race)
                        Text("PR Attempt").tag(EventMode.pr)
                    }
                    .pickerStyle(.segmented)

                    Toggle("Has a date", isOn: $hasDate)
                    if hasDate {
                        DatePicker("Date", selection: $date, displayedComponents: .date)
                    }

                    TextField("Location (city, venue)", text: $location)
                    TextField("Distance / length (e.g. 26.2mi, 10K, 70.3)", text: $distance)
                }

                Section("Targets") {
                    TextField("Goal time or target", text: $goal)
                    TextField("Stretch goal (optional)", text: $stretchGoal)
                    TextField("Current baseline or PR (optional)", text: $baseline)
                }

                Section {
                    DisclosureGroup(isExpanded: $showOptional) {
                        TextField("Bib number", text: $bibNumber)
                            .textInputAutocapitalization(.never)
                        TextField("Official website URL", text: $url)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .keyboardType(.URL)
                    } label: {
                        Label("Optional details", systemImage: "ellipsis.circle")
                    }
                }

                if isEditing {
                    Section {
                        Button(role: .destructive) {
                            showDeleteConfirm = true
                        } label: {
                            Label("Delete this goal", systemImage: "trash")
                        }
                    }
                }
            }
            .navigationTitle(isEditing ? "Edit Goal" : "New Goal")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(isEditing ? "Save" : "Create") {
                        Task { await save() }
                    }
                    .disabled(name.isEmpty)
                }
            }
            .onAppear(perform: populateIfEditing)
            .confirmationDialog(
                "Delete \"\(name)\"?",
                isPresented: $showDeleteConfirm,
                titleVisibility: .visible
            ) {
                Button("Delete", role: .destructive) {
                    Task { await deleteEvent() }
                }
                Button("Cancel", role: .cancel) { }
            } message: {
                Text("This can't be undone.")
            }
        }
    }

    // MARK: - Actions

    private func populateIfEditing() {
        guard !loaded, let id = editingEventId,
              let event = data.events.first(where: { $0.id == id }) else {
            loaded = true
            return
        }
        selectedPreset = EventPreset.all.first { $0.id == event.presetId }
        mode = event.mode
        name = event.name
        if let dateStr = event.date, let parsed = parseDate(dateStr) {
            date = parsed
            hasDate = true
        } else {
            hasDate = false
        }
        location = event.location ?? ""
        distance = event.distance ?? ""
        goal = event.goal ?? ""
        stretchGoal = event.stretchGoal ?? ""
        baseline = event.baseline ?? ""
        bibNumber = event.bibNumber ?? ""
        url = event.url ?? ""
        if !bibNumber.isEmpty || !url.isEmpty { showOptional = true }
        loaded = true
    }

    private func save() async {
        if let id = editingEventId, var event = data.events.first(where: { $0.id == id }) {
            apply(to: &event)
            try? await data.updateEvent(event)
            onFinish(.saved(event))
        } else {
            var event = Event.create(
                presetId: selectedPreset?.id ?? "custom",
                name: name,
                mode: mode
            )
            apply(to: &event)
            try? await data.addEvent(event)
            onFinish(.saved(event))
        }
        dismiss()
    }

    private func apply(to event: inout Event) {
        event.presetId = selectedPreset?.id ?? event.presetId
        event.name = name
        event.mode = mode
        event.date = hasDate ? formatDate(date) : nil
        event.location = location.trimmedOrNil
        event.distance = distance.trimmedOrNil
        event.goal = goal.trimmedOrNil
        event.stretchGoal = stretchGoal.trimmedOrNil
        event.baseline = baseline.trimmedOrNil
        event.bibNumber = bibNumber.trimmedOrNil
        event.url = url.trimmedOrNil
    }

    private func deleteEvent() async {
        guard let id = editingEventId else { return }
        try? await data.deleteEvent(id)
        onFinish(.deleted(id: id))
        dismiss()
    }

    // MARK: - Helpers

    private func parseDate(_ s: String) -> Date? {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.date(from: s)
    }

    private func formatDate(_ d: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: d)
    }

    private func defaultDistance(for presetId: String) -> String? {
        switch presetId {
        case "marathon": return "26.2mi"
        case "half-marathon": return "13.1mi"
        case "10k": return "10K"
        case "5k": return "5K"
        case "ultra": return "Ultra (50K+)"
        case "trail-race": return nil
        case "full-tri": return "Full (2.4mi / 112mi / 26.2mi)"
        case "half-tri": return "70.3 (1.2mi / 56mi / 13.1mi)"
        case "olympic-tri": return "Olympic (1.5K / 40K / 10K)"
        case "sprint-tri": return "Sprint (750m / 20K / 5K)"
        case "century": return "100mi"
        case "gran-fondo": return nil
        case "swim-race": return nil
        default: return nil
        }
    }
}

// MARK: - Result type

enum GoalFormResult {
    case saved(Event)
    case deleted(id: String)
}

// MARK: - Convenience sheet wrappers

struct CreateGoalSheet: View {
    @Binding var isPresented: Bool
    var onFinish: ((GoalFormResult) -> Void)? = nil

    var body: some View {
        GoalFormView(editingEventId: nil) { result in
            onFinish?(result)
            isPresented = false
        }
    }
}

struct EditGoalSheet: View {
    let eventId: String
    @Binding var isPresented: Bool
    var onFinish: ((GoalFormResult) -> Void)? = nil

    var body: some View {
        GoalFormView(editingEventId: eventId) { result in
            onFinish?(result)
            isPresented = false
        }
    }
}

// MARK: - Small string helper

private extension String {
    var trimmedOrNil: String? {
        let t = trimmingCharacters(in: .whitespacesAndNewlines)
        return t.isEmpty ? nil : t
    }
}
