import SwiftUI

struct AthleteMemoryView: View {
    @Environment(DataService.self) var data
    @Environment(\.dismiss) var dismiss
    @Environment(\.colorScheme) var colorScheme

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
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                scheduleSection
                equipmentSection
                facilitiesSection
                medicalSection
                dietarySection
                communicationSection
                observationsSection
                responseProfileSection
                injuriesSection
                benchmarksSection
            }
            .padding()
        }
        .background((colorScheme == .dark ? CoachColors.darkBg : CoachColors.lightBg).ignoresSafeArea())
        .navigationTitle("Athlete Profile")
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

    // MARK: - Editable Sections

    private var scheduleSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionLabel("SCHEDULE")
            CoachCard {
                VStack(alignment: .leading, spacing: 14) {
                    // Available days stepper
                    HStack(spacing: 10) {
                        Image(systemName: "calendar")
                            .foregroundStyle(.secondary)
                            .font(.system(size: 13))
                        Text("Days per week")
                            .font(CoachFonts.ui(14, weight: .medium))
                        Spacer()
                        Stepper("\(availableDays)", value: $availableDays, in: 0...7)
                            .labelsHidden()
                        Text("\(availableDays)")
                            .font(CoachFonts.mono(15, weight: .semibold))
                            .frame(width: 20)
                    }

                    // Preferred times
                    VStack(alignment: .leading, spacing: 4) {
                        Text("PREFERRED TIMES")
                            .font(CoachFonts.ui(10, weight: .semibold))
                            .tracking(0.5)
                            .foregroundStyle(.secondary)
                        HStack(spacing: 8) {
                            Image(systemName: "clock")
                                .foregroundStyle(.secondary)
                                .font(.system(size: 13))
                            TextField("e.g. mornings", text: $preferredTimes)
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

                    // Constraints
                    editableListCard(
                        label: "CONSTRAINTS",
                        items: $scheduleConstraints,
                        draft: $newConstraint,
                        placeholder: "e.g. no Tuesdays",
                        icon: "exclamationmark.triangle"
                    )
                }
            }
        }
    }

    private var equipmentSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionLabel("EQUIPMENT")
            CoachCard {
                editableListCard(
                    label: nil,
                    items: $equipment,
                    draft: $newEquipment,
                    placeholder: "e.g. dumbbells, bike trainer",
                    icon: "dumbbell"
                )
            }
        }
    }

    private var facilitiesSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionLabel("FACILITIES")
            CoachCard {
                editableListCard(
                    label: nil,
                    items: $facilities,
                    draft: $newFacility,
                    placeholder: "e.g. gym, pool, track",
                    icon: "building.2"
                )
            }
        }
    }

    private var medicalSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionLabel("MEDICAL HISTORY")
            CoachCard {
                editableListCard(
                    label: nil,
                    items: $medicalHistory,
                    draft: $newMedical,
                    placeholder: "e.g. prior ACL repair",
                    icon: "cross.case"
                )
            }
        }
    }

    private var dietarySection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionLabel("DIETARY CONSTRAINTS")
            CoachCard {
                editableListCard(
                    label: nil,
                    items: $dietaryConstraints,
                    draft: $newDietary,
                    placeholder: "e.g. vegetarian",
                    icon: "leaf"
                )
            }
        }
    }

    private var communicationSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionLabel("COMMUNICATION PREFERENCES")
            CoachCard {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Image(systemName: "bubble.left.and.bubble.right")
                            .foregroundStyle(.secondary)
                            .font(.system(size: 12))
                        Text("How should your coach talk to you?")
                            .font(CoachFonts.ui(12))
                            .foregroundStyle(.secondary)
                    }
                    TextField("Describe your preferences...", text: $communicationPrefs, axis: .vertical)
                        .font(CoachFonts.ui(14))
                        .lineLimit(2...5)
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

    // MARK: - AI-Curated Read-Only Sections

    @ViewBuilder
    private var observationsSection: some View {
        let obs = data.memory.observations
        if !obs.currentFocus.isEmpty
            || !obs.patterns.isEmpty
            || !obs.motivators.isEmpty
            || !obs.consistency.isEmpty
            || !obs.openItems.isEmpty
            || !obs.coachingNotes.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                sectionLabel("OBSERVATIONS")
                CoachCard(accentColor: CoachColors.purple) {
                    VStack(alignment: .leading, spacing: 12) {
                        aiSectionHeader(icon: "eye", title: "AI-Curated", subtitle: "Maintained by your coach")

                        if !obs.currentFocus.isEmpty {
                            readOnlyField("Current Focus", obs.currentFocus)
                        }
                        if !obs.consistency.isEmpty {
                            readOnlyField("Consistency", obs.consistency)
                        }
                        if !obs.patterns.isEmpty {
                            readOnlyBulletList("Patterns", obs.patterns)
                        }
                        if !obs.motivators.isEmpty {
                            readOnlyBulletList("Motivators", obs.motivators)
                        }
                        if !obs.openItems.isEmpty {
                            readOnlyBulletList("Open Items", obs.openItems)
                        }
                        if !obs.coachingNotes.isEmpty {
                            // Hidden coaching notes are AI-internal — only
                            // surface tracking entries (resolved ones stay
                            // hidden) and only the text. Status / topic /
                            // timestamp metadata is for the LLM, not the
                            // athlete-facing memory view.
                            let activeNotes = obs.coachingNotes
                                .filter { $0.status == .tracking }
                                .map(\.text)
                            if !activeNotes.isEmpty {
                                readOnlyBulletList("Coaching Notes", activeNotes)
                            }
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var responseProfileSection: some View {
        let rp = data.memory.responseProfile
        if !rp.volumeVsIntensity.isEmpty
            || !rp.recoveryRate.isEmpty
            || !rp.easyDayDiscipline.isEmpty
            || !rp.sessionPreferences.isEmpty
            || !rp.skipPatterns.isEmpty
            || !rp.communicationNeeds.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                sectionLabel("RESPONSE PROFILE")
                CoachCard(accentColor: CoachColors.cyan) {
                    VStack(alignment: .leading, spacing: 12) {
                        aiSectionHeader(icon: "waveform.path.ecg", title: "AI-Curated", subtitle: "How you respond to training")

                        if !rp.volumeVsIntensity.isEmpty {
                            readOnlyField("Volume vs Intensity", rp.volumeVsIntensity)
                        }
                        if !rp.recoveryRate.isEmpty {
                            readOnlyField("Recovery Rate", rp.recoveryRate)
                        }
                        if !rp.easyDayDiscipline.isEmpty {
                            readOnlyField("Easy Day Discipline", rp.easyDayDiscipline)
                        }
                        if !rp.sessionPreferences.isEmpty {
                            readOnlyField("Session Preferences", rp.sessionPreferences)
                        }
                        if !rp.communicationNeeds.isEmpty {
                            readOnlyField("Communication Needs", rp.communicationNeeds)
                        }
                        if !rp.skipPatterns.isEmpty {
                            readOnlyBulletList("Skip Patterns", rp.skipPatterns)
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var injuriesSection: some View {
        if !data.memory.injuries.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                sectionLabel("INJURIES")
                CoachCard(accentColor: CoachColors.red) {
                    VStack(alignment: .leading, spacing: 0) {
                        aiSectionHeader(icon: "bandage", title: "AI-Tracked", subtitle: "Injury history and status")
                            .padding(.bottom, 12)

                        ForEach(Array(data.memory.injuries.enumerated()), id: \.element.id) { index, injury in
                            if index > 0 {
                                Divider()
                                    .overlay(colorScheme == .dark ? CoachColors.darkBorder : CoachColors.lightBorder)
                            }
                            VStack(alignment: .leading, spacing: 6) {
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
                            .padding(.vertical, 10)
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var benchmarksSection: some View {
        if !data.memory.benchmarks.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                sectionLabel("BENCHMARKS")
                CoachCard(accentColor: CoachColors.green) {
                    VStack(alignment: .leading, spacing: 0) {
                        aiSectionHeader(icon: "chart.bar", title: "AI-Tracked", subtitle: "Performance baselines")
                            .padding(.bottom, 12)

                        ForEach(Array(data.memory.benchmarks.enumerated()), id: \.element.metric) { index, b in
                            if index > 0 {
                                Divider()
                                    .overlay(colorScheme == .dark ? CoachColors.darkBorder : CoachColors.lightBorder)
                            }
                            HStack {
                                Text(b.metric)
                                    .font(CoachFonts.ui(14))
                                Spacer()
                                Text(b.value)
                                    .font(CoachFonts.mono(14, weight: .semibold))
                                    .foregroundStyle(CoachColors.accent)
                            }
                            .padding(.vertical, 8)
                        }
                    }
                }
            }
        }
    }

    // MARK: - Shared Helper Views

    private func sectionLabel(_ text: String) -> some View {
        Text(text)
            .font(CoachFonts.ui(10, weight: .semibold))
            .tracking(0.6)
            .foregroundStyle(.secondary)
            .padding(.leading, 4)
    }

    private func aiSectionHeader(icon: String, title: String, subtitle: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.secondary)
            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(CoachFonts.ui(11, weight: .semibold))
                    .foregroundStyle(.secondary)
                Text(subtitle)
                    .font(CoachFonts.ui(10))
                    .foregroundStyle(.tertiary)
            }
            Spacer()
            Image(systemName: "lock.fill")
                .font(.system(size: 10))
                .foregroundStyle(.tertiary)
        }
    }

    @ViewBuilder
    private func editableListCard(
        label: String?,
        items: Binding<[String]>,
        draft: Binding<String>,
        placeholder: String,
        icon: String
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            if let label {
                Text(label)
                    .font(CoachFonts.ui(10, weight: .semibold))
                    .tracking(0.5)
                    .foregroundStyle(.secondary)
            }

            if !items.wrappedValue.isEmpty {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(Array(items.wrappedValue.enumerated()), id: \.offset) { index, item in
                        if index > 0 {
                            Divider()
                                .overlay(colorScheme == .dark ? CoachColors.darkBorder : CoachColors.lightBorder)
                        }
                        HStack(spacing: 10) {
                            Image(systemName: icon)
                                .font(.system(size: 12))
                                .foregroundStyle(CoachColors.accent.opacity(0.6))
                                .frame(width: 20)
                            Text(item)
                                .font(CoachFonts.ui(14))
                            Spacer()
                            Button {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    var arr = items.wrappedValue
                                    arr.remove(at: index)
                                    items.wrappedValue = arr
                                }
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.system(size: 16))
                                    .foregroundStyle(.tertiary)
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.vertical, 8)
                    }
                }
                .padding(.horizontal, 10)
                .background(fieldBackground)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(fieldBorder, lineWidth: 1)
                )
            }

            // Add new item row
            HStack(spacing: 8) {
                Image(systemName: "plus")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(CoachColors.accent)
                    .frame(width: 20)
                TextField(placeholder, text: draft)
                    .font(CoachFonts.ui(14))
                Button {
                    let trimmed = draft.wrappedValue.trimmingCharacters(in: .whitespaces)
                    guard !trimmed.isEmpty else { return }
                    withAnimation(.easeInOut(duration: 0.2)) {
                        items.wrappedValue.append(trimmed)
                    }
                    draft.wrappedValue = ""
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 20))
                        .foregroundStyle(
                            draft.wrappedValue.trimmingCharacters(in: .whitespaces).isEmpty
                            ? Color.secondary.opacity(0.3)
                            : CoachColors.accent
                        )
                }
                .buttonStyle(.plain)
                .disabled(draft.wrappedValue.trimmingCharacters(in: .whitespaces).isEmpty)
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

    private func readOnlyField(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label.uppercased())
                .font(CoachFonts.ui(10, weight: .semibold))
                .tracking(0.5)
                .foregroundStyle(.secondary)
            Text(value)
                .font(CoachFonts.ui(14))
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(fieldBackground.opacity(0.5))
                .clipShape(RoundedRectangle(cornerRadius: 8))
        }
    }

    private func readOnlyBulletList(_ label: String, _ items: [String]) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label.uppercased())
                .font(CoachFonts.ui(10, weight: .semibold))
                .tracking(0.5)
                .foregroundStyle(.secondary)
            VStack(alignment: .leading, spacing: 6) {
                ForEach(items, id: \.self) { item in
                    HStack(alignment: .top, spacing: 8) {
                        Circle()
                            .fill(CoachColors.accent.opacity(0.5))
                            .frame(width: 5, height: 5)
                            .padding(.top, 6)
                        Text(item)
                            .font(CoachFonts.ui(13))
                    }
                }
            }
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(fieldBackground.opacity(0.5))
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
    }

    // MARK: - Chrome

    private var fieldBackground: Color {
        colorScheme == .dark ? CoachColors.darkElevated : CoachColors.lightElevated
    }
    private var fieldBorder: Color {
        colorScheme == .dark ? CoachColors.darkBorder : CoachColors.lightBorder
    }

    // MARK: - Helpers

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
