import SwiftUI
import Supabase
import Auth

struct SettingsView: View {
    @Environment(DataService.self) var data
    @Environment(\.dismiss) var dismiss
    @State private var personality: Personality = .normal
    @State private var customPrompt = ""
    @State private var appearance: Appearance = .system
    @State private var seeding = false
    @State private var seedError: String?
    @State private var showClearConfirm = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    AppearancePicker(selection: $appearance)
                        .listRowInsets(EdgeInsets(top: 8, leading: 12, bottom: 8, trailing: 12))
                        .listRowBackground(Color.clear)
                        .onChange(of: appearance) { _, newValue in
                            Task {
                                var s = data.settings
                                s.appearance = newValue
                                s.darkMode = newValue == .dark
                                try? await data.saveSettings(s)
                            }
                        }
                } header: {
                    Text("Appearance")
                }

                Section("Coaching Personality") {
                    ForEach(Personality.allCases) { p in
                        Button {
                            personality = p
                        } label: {
                            HStack {
                                VStack(alignment: .leading) {
                                    Text(p.label)
                                        .font(CoachFonts.ui(15, weight: .medium))
                                    Text(personalityDescription(p))
                                        .font(CoachFonts.ui(12))
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                if personality == p {
                                    Image(systemName: "checkmark")
                                        .foregroundStyle(CoachColors.accent)
                                }
                            }
                        }
                        .tint(.primary)
                    }

                    if personality == .custom {
                        TextField("Describe your ideal coach...", text: $customPrompt, axis: .vertical)
                            .lineLimit(3...6)
                    }
                }

                Section("Athlete") {
                    NavigationLink {
                        AthleteMemoryView()
                    } label: {
                        Label("Athlete Memory", systemImage: "person.text.rectangle")
                    }
                }

                Section("Account") {
                    Button("Sign Out", role: .destructive) {
                        Task {
                            try? await SupabaseService.shared.client.auth.signOut()
                        }
                    }
                }

                Section {
                    Button {
                        Task { await runSeed() }
                    } label: {
                        HStack {
                            Label("Load Sample Data", systemImage: "tray.and.arrow.down")
                            Spacer()
                            if seeding { ProgressView() }
                        }
                    }
                    .disabled(seeding)

                    Button(role: .destructive) {
                        showClearConfirm = true
                    } label: {
                        Label("Clear Sample Data", systemImage: "trash")
                    }
                    .disabled(seeding)

                    if let err = seedError {
                        Text(err)
                            .font(CoachFonts.ui(12))
                            .foregroundStyle(.red)
                    }
                } header: {
                    Text("Dev Tools")
                } footer: {
                    Text("Sample data covers workouts, plan, goals, and athlete memory. Clear deletes all of that for the signed-in user.")
                }
            }
            .confirmationDialog(
                "Delete all workouts, strength sessions, events, training plan, and coaching memory?",
                isPresented: $showClearConfirm,
                titleVisibility: .visible
            ) {
                Button("Delete Everything", role: .destructive) {
                    Task { await runClear() }
                }
                Button("Cancel", role: .cancel) { }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        Task {
                            var s = data.settings
                            s.personality = personality
                            s.customPrompt = customPrompt
                            try? await data.saveSettings(s)
                            dismiss()
                        }
                    }
                }
            }
            .onAppear {
                personality = data.settings.personality
                customPrompt = data.settings.customPrompt
                appearance = data.settings.effectiveAppearance
            }
        }
        .preferredColorScheme(schemeFor(appearance))
    }

    private func schemeFor(_ a: Appearance) -> ColorScheme? {
        switch a {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }

    private func runSeed() async {
        seeding = true
        seedError = nil
        do {
            try await SeedData.load(into: data)
            await data.loadAll()
        } catch {
            seedError = error.localizedDescription
        }
        seeding = false
    }

    private func runClear() async {
        seeding = true
        seedError = nil
        do {
            try await SeedData.clear(in: data)
            await data.loadAll()
        } catch {
            seedError = error.localizedDescription
        }
        seeding = false
    }

    private func personalityDescription(_ p: Personality) -> String {
        switch p {
        case .normal: return "Direct, professional, data-backed"
        case .goggins: return "Brutal accountability, no excuses"
        case .hype: return "Positive energy grounded in real data"
        case .custom: return "Define your own coaching style"
        }
    }
}
