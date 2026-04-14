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
    @Environment(\.colorScheme) var colorScheme

    @State private var selectedPreset: EventPreset?
    @State private var name: String = ""
    @State private var isRace: Bool = true
    @State private var prAttempt: Bool = false
    @State private var hasDate: Bool = true
    @State private var date: Date = Date().addingTimeInterval(60 * 60 * 24 * 60)
    @State private var location: String = ""
    @State private var distance: String = ""
    @State private var swimDistance: String = ""
    @State private var bikeDistance: String = ""
    @State private var runDistance: String = ""
    @State private var goal: String = ""
    @State private var stretchGoal: String = ""
    @State private var baseline: String = ""
    @State private var bibNumber: String = ""
    @State private var url: String = ""
    @State private var showOptional = false
    @State private var showPresetPicker = false
    @State private var showDeleteConfirm = false
    @State private var loaded = false

    private var isEditing: Bool { editingEventId != nil }
    private var currentPresetId: String { selectedPreset?.id ?? "custom" }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    eventTypeRow
                    nameField
                    detailsCard
                    targetsCard
                    optionalDetailsCard
                    if isEditing {
                        dangerZone
                    }
                }
                .padding()
            }
            .background((colorScheme == .dark ? CoachColors.darkBg : CoachColors.lightBg).ignoresSafeArea())
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
            .sheet(isPresented: $showPresetPicker) {
                EventTypePickerSheet(current: selectedPreset) { newPreset in
                    didSelectPreset(newPreset)
                }
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
            }
            .onAppear(perform: populateOnAppear)
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

    // MARK: - Sections

    private var eventTypeRow: some View {
        Button {
            showPresetPicker = true
        } label: {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(CoachColors.accent.opacity(0.15))
                        .frame(width: 38, height: 38)
                    Image(systemName: selectedPreset?.icon ?? "target")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(CoachColors.accent)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text("EVENT TYPE")
                        .font(CoachFonts.ui(10, weight: .semibold))
                        .tracking(0.6)
                        .foregroundStyle(.secondary)
                    Text(selectedPreset?.name ?? "Select event type")
                        .font(CoachFonts.ui(15, weight: .semibold))
                        .foregroundStyle(.primary)
                }
                Spacer(minLength: 8)
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.tertiary)
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(cardBorder, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    private var nameField: some View {
        VStack(alignment: .leading, spacing: 6) {
            sectionLabel("NAME")
            TextField("e.g. Boston Marathon 2026", text: $name)
                .font(CoachFonts.ui(15))
                .padding(14)
                .background(cardBackground)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(cardBorder, lineWidth: 1)
                )
        }
    }

    private var detailsCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionLabel("DETAILS")
            CoachCard {
                VStack(alignment: .leading, spacing: 14) {
                    Picker("Type", selection: $isRace) {
                        Text("Race").tag(true)
                        Text("Goal").tag(false)
                    }
                    .pickerStyle(.segmented)

                    if isRace {
                        Toggle("PR Attempt", isOn: $prAttempt)
                            .font(CoachFonts.ui(14, weight: .medium))
                    }

                    dateRow

                    if isRace {
                        locationRow
                    }

                    distanceSection

                    if isRace && prAttempt {
                        labeledField(
                            label: "Current PR",
                            placeholder: "e.g. 3:45:00",
                            text: $baseline
                        )
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var dateRow: some View {
        if isRace {
            HStack(spacing: 10) {
                Image(systemName: "calendar")
                    .foregroundStyle(.secondary)
                    .font(.system(size: 13))
                Text("Date")
                    .font(CoachFonts.ui(14, weight: .medium))
                Spacer()
                DatePicker("", selection: $date, displayedComponents: .date)
                    .labelsHidden()
            }
        } else {
            VStack(alignment: .leading, spacing: 10) {
                Toggle("Has a date", isOn: $hasDate)
                    .font(CoachFonts.ui(14, weight: .medium))
                if hasDate {
                    HStack(spacing: 10) {
                        Image(systemName: "calendar")
                            .foregroundStyle(.secondary)
                            .font(.system(size: 13))
                        Text("Date")
                            .font(CoachFonts.ui(14, weight: .medium))
                        Spacer()
                        DatePicker("", selection: $date, displayedComponents: .date)
                            .labelsHidden()
                    }
                }
            }
        }
    }

    private var locationRow: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("LOCATION")
                .font(CoachFonts.ui(10, weight: .semibold))
                .tracking(0.5)
                .foregroundStyle(.secondary)
            HStack(spacing: 8) {
                Image(systemName: "mappin")
                    .foregroundStyle(.secondary)
                    .font(.system(size: 13))
                TextField("City, venue", text: $location)
                    .font(CoachFonts.ui(14))
            }
            .padding(10)
            .background(fieldBackground)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(fieldBorder, lineWidth: 1)
            )
        }
    }

    @ViewBuilder
    private var distanceSection: some View {
        if isFixedDistance(currentPresetId) {
            VStack(alignment: .leading, spacing: 4) {
                Text("DISTANCE")
                    .font(CoachFonts.ui(10, weight: .semibold))
                    .tracking(0.5)
                    .foregroundStyle(.secondary)
                HStack {
                    Text(distance)
                        .font(CoachFonts.mono(14, weight: .semibold))
                        .foregroundStyle(.primary)
                    Spacer()
                    Image(systemName: "lock.fill")
                        .font(.system(size: 10))
                        .foregroundStyle(.tertiary)
                }
                .padding(10)
                .background(fieldBackground.opacity(0.5))
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(fieldBorder.opacity(0.5), lineWidth: 1)
                )
            }
        } else if isTriathlon(currentPresetId) {
            VStack(alignment: .leading, spacing: 6) {
                Text("DISTANCE")
                    .font(CoachFonts.ui(10, weight: .semibold))
                    .tracking(0.5)
                    .foregroundStyle(.secondary)
                triSubField(label: "Swim", value: $swimDistance)
                triSubField(label: "Bike", value: $bikeDistance)
                triSubField(label: "Run", value: $runDistance)
            }
        } else {
            VStack(alignment: .leading, spacing: 4) {
                Text("DISTANCE")
                    .font(CoachFonts.ui(10, weight: .semibold))
                    .tracking(0.5)
                    .foregroundStyle(.secondary)
                TextField("e.g. 50K, 100mi, 5km swim", text: $distance)
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

    private func triSubField(label: String, value: Binding<String>) -> some View {
        HStack(spacing: 10) {
            Text(label)
                .font(CoachFonts.ui(13, weight: .semibold))
                .foregroundStyle(.secondary)
                .frame(width: 40, alignment: .leading)
            TextField("", text: value)
                .font(CoachFonts.ui(14))
        }
        .padding(10)
        .background(fieldBackground)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(fieldBorder, lineWidth: 1)
        )
    }

    private var targetsCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionLabel("TARGETS")
            CoachCard {
                VStack(alignment: .leading, spacing: 12) {
                    labeledField(
                        label: "Goal Time",
                        placeholder: "e.g. 3:45:00",
                        text: $goal
                    )
                    labeledField(
                        label: "Stretch Goal",
                        placeholder: "e.g. 3:30:00",
                        text: $stretchGoal,
                        helperText: "(optional)"
                    )
                    if !(isRace && prAttempt) {
                        labeledField(
                            label: "Current PR",
                            placeholder: "e.g. 3:58:00",
                            text: $baseline,
                            helperText: "(optional)"
                        )
                    }
                }
            }
        }
    }

    private var optionalDetailsCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionLabel("OPTIONAL DETAILS")
            CoachCard {
                DisclosureGroup(isExpanded: $showOptional) {
                    VStack(alignment: .leading, spacing: 12) {
                        labeledField(
                            label: "Bib Number",
                            placeholder: "e.g. 1234",
                            text: $bibNumber
                        )
                        VStack(alignment: .leading, spacing: 4) {
                            Text("OFFICIAL WEBSITE")
                                .font(CoachFonts.ui(10, weight: .semibold))
                                .tracking(0.5)
                                .foregroundStyle(.secondary)
                            TextField("https://...", text: $url)
                                .font(CoachFonts.ui(14))
                                .textInputAutocapitalization(.never)
                                .autocorrectionDisabled()
                                .keyboardType(.URL)
                                .padding(10)
                                .background(fieldBackground)
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(fieldBorder, lineWidth: 1)
                                )
                        }
                    }
                    .padding(.top, 10)
                } label: {
                    Label("More details", systemImage: "ellipsis.circle")
                        .font(CoachFonts.ui(14, weight: .medium))
                        .foregroundStyle(.primary)
                }
            }
        }
    }

    private var dangerZone: some View {
        Button(role: .destructive) {
            showDeleteConfirm = true
        } label: {
            Label("Delete this goal", systemImage: "trash")
                .font(CoachFonts.ui(14, weight: .semibold))
                .foregroundStyle(CoachColors.red)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
        }
        .buttonStyle(.plain)
        .padding(.top, 12)
    }

    // MARK: - Shared helper views

    private func sectionLabel(_ text: String) -> some View {
        Text(text)
            .font(CoachFonts.ui(10, weight: .semibold))
            .tracking(0.6)
            .foregroundStyle(.secondary)
            .padding(.leading, 4)
    }

    private func labeledField(
        label: String,
        placeholder: String,
        text: Binding<String>,
        helperText: String? = nil
    ) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                Text(label.uppercased())
                    .font(CoachFonts.ui(10, weight: .semibold))
                    .tracking(0.5)
                    .foregroundStyle(.secondary)
                if let helperText {
                    Text(helperText)
                        .font(CoachFonts.ui(10))
                        .foregroundStyle(.tertiary)
                }
            }
            TextField(placeholder, text: text)
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

    // MARK: - Chrome

    private var cardBackground: Color {
        colorScheme == .dark ? CoachColors.darkCard : CoachColors.lightCard
    }
    private var cardBorder: Color {
        colorScheme == .dark ? CoachColors.darkBorder : CoachColors.lightBorder
    }
    private var fieldBackground: Color {
        colorScheme == .dark ? CoachColors.darkElevated : CoachColors.lightElevated
    }
    private var fieldBorder: Color {
        colorScheme == .dark ? CoachColors.darkBorder : CoachColors.lightBorder
    }

    // MARK: - Actions

    private func populateOnAppear() {
        guard !loaded else { return }
        if let id = editingEventId,
           let event = data.events.first(where: { $0.id == id }) {
            populate(from: event)
        } else {
            // New goal defaults
            if let marathon = EventPreset.all.first(where: { $0.id == "marathon" }) {
                selectedPreset = marathon
                autoFillDistance(for: marathon)
                isRace = marathon.defaultMode != .goal
                prAttempt = marathon.defaultMode == .pr
            }
        }
        loaded = true
    }

    private func populate(from event: Event) {
        selectedPreset = EventPreset.all.first { $0.id == event.presetId }
        isRace = event.mode != .goal
        prAttempt = event.mode == .pr
        name = event.name
        if let dateStr = event.date, let parsed = parseDate(dateStr) {
            date = parsed
            hasDate = true
        } else {
            hasDate = false
        }
        location = event.location ?? ""
        if isTriathlon(event.presetId) {
            let (s, b, r) = parseTriDistance(event.distance, presetId: event.presetId)
            swimDistance = s
            bikeDistance = b
            runDistance = r
        } else if isFixedDistance(event.presetId) {
            distance = event.distance ?? fixedDistanceString(for: event.presetId) ?? ""
        } else {
            distance = event.distance ?? ""
        }
        goal = event.goal ?? ""
        stretchGoal = event.stretchGoal ?? ""
        baseline = event.baseline ?? ""
        bibNumber = event.bibNumber ?? ""
        url = event.url ?? ""
        if !bibNumber.isEmpty || !url.isEmpty { showOptional = true }
    }

    private func didSelectPreset(_ newPreset: EventPreset) {
        selectedPreset = newPreset
        if name.isEmpty {
            name = newPreset.name
        }
        if !isEditing {
            isRace = newPreset.defaultMode != .goal
            prAttempt = newPreset.defaultMode == .pr
        }
        autoFillDistance(for: newPreset)
    }

    private func autoFillDistance(for preset: EventPreset) {
        switch preset.id {
        case "marathon":
            distance = "26.2 mi"
        case "half-marathon":
            distance = "13.1 mi"
        case "10k":
            distance = "6.2 mi"
        case "5k":
            distance = "3.1 mi"
        case "full-tri":
            swimDistance = "2.4 mi"
            bikeDistance = "112 mi"
            runDistance = "26.2 mi"
        case "half-tri":
            swimDistance = "1.2 mi"
            bikeDistance = "56 mi"
            runDistance = "13.1 mi"
        case "olympic-tri":
            swimDistance = "1.5 km"
            bikeDistance = "40 km"
            runDistance = "10 km"
        case "sprint-tri":
            swimDistance = "750 m"
            bikeDistance = "20 km"
            runDistance = "5 km"
        default:
            // Leave user-editable distances alone for ultra/trail/century/
            // gran-fondo/swim-race/custom.
            break
        }
    }

    private func save() async {
        let currentMode: EventMode = isRace ? (prAttempt ? .pr : .race) : .goal

        if let id = editingEventId, var event = data.events.first(where: { $0.id == id }) {
            apply(to: &event, mode: currentMode)
            try? await data.updateEvent(event)
            onFinish(.saved(event))
        } else {
            var event = Event.create(
                presetId: currentPresetId,
                name: name,
                mode: currentMode
            )
            apply(to: &event, mode: currentMode)
            try? await data.addEvent(event)
            onFinish(.saved(event))
        }
        dismiss()
    }

    private func apply(to event: inout Event, mode: EventMode) {
        event.presetId = currentPresetId
        event.name = name
        event.mode = mode

        // Races always have a date; goals respect the hasDate toggle.
        if isRace {
            event.date = formatDate(date)
        } else {
            event.date = hasDate ? formatDate(date) : nil
        }

        // Location only stored for races.
        event.location = isRace ? location.trimmedOrNil : nil

        // Distance: triathlons join three sub-fields; everything else uses
        // the single distance string.
        if isTriathlon(currentPresetId) {
            let parts = [swimDistance, bikeDistance, runDistance]
                .map { $0.trimmingCharacters(in: .whitespaces) }
                .filter { !$0.isEmpty }
            event.distance = parts.isEmpty ? nil : parts.joined(separator: " / ")
        } else {
            event.distance = distance.trimmedOrNil
        }

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

    private func isFixedDistance(_ presetId: String) -> Bool {
        ["marathon", "half-marathon", "10k", "5k"].contains(presetId)
    }

    private func isTriathlon(_ presetId: String) -> Bool {
        presetId.hasSuffix("-tri")
    }

    private func fixedDistanceString(for presetId: String) -> String? {
        switch presetId {
        case "marathon":      return "26.2 mi"
        case "half-marathon": return "13.1 mi"
        case "10k":           return "6.2 mi"
        case "5k":            return "3.1 mi"
        default:              return nil
        }
    }

    private func parseTriDistance(_ s: String?, presetId: String) -> (String, String, String) {
        if let s, !s.isEmpty {
            let parts = s.split(separator: "/").map { $0.trimmingCharacters(in: .whitespaces) }
            if parts.count == 3 {
                return (parts[0], parts[1], parts[2])
            }
        }
        switch presetId {
        case "full-tri":    return ("2.4 mi", "112 mi", "26.2 mi")
        case "half-tri":    return ("1.2 mi", "56 mi", "13.1 mi")
        case "olympic-tri": return ("1.5 km", "40 km", "10 km")
        case "sprint-tri":  return ("750 m", "20 km", "5 km")
        default:            return ("", "", "")
        }
    }
}

// MARK: - Event type picker sheet

private struct EventTypePickerSheet: View {
    let current: EventPreset?
    let onPick: (EventPreset) -> Void

    @Environment(\.dismiss) var dismiss
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 6) {
                    ForEach(EventPreset.all) { preset in
                        Button {
                            onPick(preset)
                            dismiss()
                        } label: {
                            HStack(spacing: 14) {
                                ZStack {
                                    Circle()
                                        .fill(CoachColors.accent.opacity(0.15))
                                        .frame(width: 34, height: 34)
                                    Image(systemName: preset.icon)
                                        .font(.system(size: 16, weight: .semibold))
                                        .foregroundStyle(CoachColors.accent)
                                }
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(preset.name)
                                        .font(CoachFonts.ui(15, weight: .semibold))
                                        .foregroundStyle(.primary)
                                    Text(preset.category)
                                        .font(CoachFonts.ui(11))
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                if current?.id == preset.id {
                                    Image(systemName: "checkmark")
                                        .font(.system(size: 14, weight: .bold))
                                        .foregroundStyle(CoachColors.accent)
                                }
                            }
                            .padding(12)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(colorScheme == .dark ? CoachColors.darkCard : CoachColors.lightCard)
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                            .overlay(
                                RoundedRectangle(cornerRadius: 10)
                                    .stroke(
                                        current?.id == preset.id
                                            ? CoachColors.accent.opacity(0.5)
                                            : (colorScheme == .dark ? CoachColors.darkBorder : CoachColors.lightBorder),
                                        lineWidth: current?.id == preset.id ? 1.5 : 1
                                    )
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding()
            }
            .background((colorScheme == .dark ? CoachColors.darkBg : CoachColors.lightBg).ignoresSafeArea())
            .navigationTitle("Event Type")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
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
