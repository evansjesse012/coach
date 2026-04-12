import SwiftUI

struct AthleteMemoryView: View {
    @Environment(DataService.self) var data
    @Environment(\.dismiss) var dismiss

    @State private var equipment: [String] = []
    @State private var facilities: [String] = []
    @State private var availableDays: Int = 0
    @State private var preferredTimes: String = ""
    @State private var scheduleConstraints: [String] = []
    @State private var medicalHistory: [String] = []
    @State private var dietaryConstraints: [String] = []
    @State private var communicationPrefs: String = ""

    @State private var newEquipment = ""
    @State private var newFacility = ""
    @State private var newConstraint = ""
    @State private var newMedical = ""
    @State private var newDietary = ""

    @State private var loaded = false
    @State private var saving = false

    var body: some View {
        Form {
            Section("Schedule") {
                Stepper("Available days/week: \(availableDays)", value: $availableDays, in: 0...7)
                TextField("Preferred times (e.g. mornings)", text: $preferredTimes)
                editableList(
                    title: "Constraints",
                    items: $scheduleConstraints,
                    draft: $newConstraint,
                    placeholder: "e.g. no Tuesdays"
                )
            }

            Section("Equipment") {
                editableList(
                    title: nil,
                    items: $equipment,
                    draft: $newEquipment,
                    placeholder: "e.g. dumbbells, bike trainer"
                )
            }

            Section("Facilities") {
                editableList(
                    title: nil,
                    items: $facilities,
                    draft: $newFacility,
                    placeholder: "e.g. gym, pool, track"
                )
            }

            Section("Medical History") {
                editableList(
                    title: nil,
                    items: $medicalHistory,
                    draft: $newMedical,
                    placeholder: "e.g. prior ACL repair"
                )
            }

            Section("Dietary Constraints") {
                editableList(
                    title: nil,
                    items: $dietaryConstraints,
                    draft: $newDietary,
                    placeholder: "e.g. vegetarian"
                )
            }

            Section("Communication Preferences") {
                TextField("How should your coach talk to you?", text: $communicationPrefs, axis: .vertical)
                    .lineLimit(2...5)
            }

            // Read-only AI-curated sections

            if !data.memory.observations.currentFocus.isEmpty
                || !data.memory.observations.patterns.isEmpty
                || !data.memory.observations.motivators.isEmpty
                || !data.memory.observations.consistency.isEmpty
                || !data.memory.observations.openItems.isEmpty
                || !data.memory.observations.coachingNotes.isEmpty {
                Section {
                    let obs = data.memory.observations
                    if !obs.currentFocus.isEmpty {
                        labeledRow("Current focus", obs.currentFocus)
                    }
                    if !obs.consistency.isEmpty {
                        labeledRow("Consistency", obs.consistency)
                    }
                    readOnlyList("Patterns", obs.patterns)
                    readOnlyList("Motivators", obs.motivators)
                    readOnlyList("Open items", obs.openItems)
                    readOnlyList("Coaching notes", obs.coachingNotes)
                } header: {
                    Text("Observations (AI)")
                } footer: {
                    Text("Maintained by your coach. Read-only here.")
                }
            }

            let rp = data.memory.responseProfile
            if !rp.volumeVsIntensity.isEmpty
                || !rp.recoveryRate.isEmpty
                || !rp.easyDayDiscipline.isEmpty
                || !rp.sessionPreferences.isEmpty
                || !rp.skipPatterns.isEmpty
                || !rp.communicationNeeds.isEmpty {
                Section {
                    if !rp.volumeVsIntensity.isEmpty { labeledRow("Volume vs intensity", rp.volumeVsIntensity) }
                    if !rp.recoveryRate.isEmpty { labeledRow("Recovery rate", rp.recoveryRate) }
                    if !rp.easyDayDiscipline.isEmpty { labeledRow("Easy day discipline", rp.easyDayDiscipline) }
                    if !rp.sessionPreferences.isEmpty { labeledRow("Session preferences", rp.sessionPreferences) }
                    if !rp.communicationNeeds.isEmpty { labeledRow("Communication needs", rp.communicationNeeds) }
                    readOnlyList("Skip patterns", rp.skipPatterns)
                } header: {
                    Text("Response Profile (AI)")
                }
            }

            if !data.memory.injuries.isEmpty {
                Section("Injuries (AI)") {
                    ForEach(data.memory.injuries) { injury in
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text(injury.area)
                                    .font(CoachFonts.ui(14, weight: .semibold))
                                Spacer()
                                CoachPill(text: injury.status, color: injuryColor(injury.status))
                            }
                            Text("Severity: \(injury.severity)")
                                .font(CoachFonts.ui(12))
                                .foregroundStyle(.secondary)
                            if !injury.triggers.isEmpty {
                                Text("Triggers: \(injury.triggers.joined(separator: ", "))")
                                    .font(CoachFonts.ui(12))
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .padding(.vertical, 2)
                    }
                }
            }

            if !data.memory.benchmarks.isEmpty {
                Section("Benchmarks (AI)") {
                    ForEach(data.memory.benchmarks, id: \.metric) { b in
                        HStack {
                            Text(b.metric).font(CoachFonts.ui(14))
                            Spacer()
                            Text(b.value)
                                .font(CoachFonts.mono(13))
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
        .navigationTitle("Athlete Memory")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") {
                    Task { await save() }
                }
                .disabled(saving)
            }
        }
        .onAppear {
            guard !loaded else { return }
            let p = data.memory.permanent
            equipment = p.equipment
            facilities = p.facilities
            availableDays = p.schedule.availableDays
            preferredTimes = p.schedule.preferredTimes
            scheduleConstraints = p.schedule.constraints
            medicalHistory = p.medicalHistory
            dietaryConstraints = p.dietaryConstraints
            communicationPrefs = p.communicationPrefs
            loaded = true
        }
    }

    @ViewBuilder
    private func editableList(
        title: String?,
        items: Binding<[String]>,
        draft: Binding<String>,
        placeholder: String
    ) -> some View {
        if let title {
            Text(title)
                .font(CoachFonts.ui(13, weight: .medium))
                .foregroundStyle(.secondary)
        }
        ForEach(items.wrappedValue.indices, id: \.self) { idx in
            Text(items.wrappedValue[idx])
        }
        .onDelete { offsets in
            items.wrappedValue.remove(atOffsets: offsets)
        }
        HStack {
            TextField(placeholder, text: draft)
            Button {
                let trimmed = draft.wrappedValue.trimmingCharacters(in: .whitespaces)
                guard !trimmed.isEmpty else { return }
                items.wrappedValue.append(trimmed)
                draft.wrappedValue = ""
            } label: {
                Image(systemName: "plus.circle.fill")
                    .foregroundStyle(CoachColors.accent)
            }
            .buttonStyle(.plain)
            .disabled(draft.wrappedValue.trimmingCharacters(in: .whitespaces).isEmpty)
        }
    }

    @ViewBuilder
    private func labeledRow(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(CoachFonts.ui(11, weight: .semibold))
                .foregroundStyle(.secondary)
            Text(value)
                .font(CoachFonts.ui(14))
        }
        .padding(.vertical, 2)
    }

    @ViewBuilder
    private func readOnlyList(_ label: String, _ items: [String]) -> some View {
        if !items.isEmpty {
            VStack(alignment: .leading, spacing: 4) {
                Text(label)
                    .font(CoachFonts.ui(11, weight: .semibold))
                    .foregroundStyle(.secondary)
                ForEach(items, id: \.self) { item in
                    Text("• \(item)").font(CoachFonts.ui(13))
                }
            }
            .padding(.vertical, 2)
        }
    }

    private func injuryColor(_ status: String) -> Color {
        switch status.lowercased() {
        case "active": return .red
        case "monitoring": return .orange
        case "resolved": return .green
        default: return CoachColors.accent
        }
    }

    private func save() async {
        saving = true
        var mem = data.memory
        mem.permanent.equipment = equipment
        mem.permanent.facilities = facilities
        mem.permanent.schedule.availableDays = availableDays
        mem.permanent.schedule.preferredTimes = preferredTimes
        mem.permanent.schedule.constraints = scheduleConstraints
        mem.permanent.medicalHistory = medicalHistory
        mem.permanent.dietaryConstraints = dietaryConstraints
        mem.permanent.communicationPrefs = communicationPrefs
        let formatter = ISO8601DateFormatter()
        mem.lastUpdated = formatter.string(from: Date())
        try? await data.saveMemory(mem)
        saving = false
        dismiss()
    }
}
