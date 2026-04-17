import SwiftUI
import Supabase
import Auth

struct SettingsView: View {
    @Environment(DataService.self) var data
    @Environment(\.dismiss) var dismiss
    @Environment(\.colorScheme) var colorScheme
    @State private var personality: Personality = .normal
    @State private var customPrompt = ""
    @State private var appearance: Appearance = .system
    @State private var seeding = false
    @State private var seedError: String?
    @State private var showClearConfirm = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    appearanceSection
                    personalitySection
                    athleteSection
                    healthSection
                    accountSection
                    devToolsSection
                }
                .padding()
            }
            .background((colorScheme == .dark ? CoachColors.darkBg : CoachColors.lightBg).ignoresSafeArea())
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

    // MARK: - Sections

    private var appearanceSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionLabel("APPEARANCE")
            CoachCard {
                AppearancePicker(selection: $appearance)
                    .onChange(of: appearance) { _, newValue in
                        Task {
                            var s = data.settings
                            s.appearance = newValue
                            s.darkMode = newValue == .dark
                            try? await data.saveSettings(s)
                        }
                    }
            }
        }
    }

    private var personalitySection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionLabel("COACHING PERSONALITY")
            CoachCard {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(Array(Personality.allCases.enumerated()), id: \.element) { index, p in
                        if index > 0 {
                            Divider()
                                .overlay(colorScheme == .dark ? CoachColors.darkBorder : CoachColors.lightBorder)
                        }
                        Button {
                            withAnimation(.easeInOut(duration: 0.15)) {
                                personality = p
                            }
                        } label: {
                            HStack(spacing: 12) {
                                ZStack {
                                    Circle()
                                        .fill(personality == p
                                              ? CoachColors.accent.opacity(0.15)
                                              : (colorScheme == .dark ? CoachColors.darkElevated : CoachColors.lightElevated))
                                        .frame(width: 34, height: 34)
                                    Image(systemName: personalityIcon(p))
                                        .font(.system(size: 15, weight: .semibold))
                                        .foregroundStyle(personality == p ? CoachColors.accent : .secondary)
                                }
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(p.label)
                                        .font(CoachFonts.ui(15, weight: .medium))
                                        .foregroundStyle(.primary)
                                    Text(personalityDescription(p))
                                        .font(CoachFonts.ui(12))
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                if personality == p {
                                    Image(systemName: "checkmark")
                                        .font(.system(size: 14, weight: .bold))
                                        .foregroundStyle(CoachColors.accent)
                                }
                            }
                            .padding(.vertical, 12)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }

                    if personality == .custom {
                        Divider()
                            .overlay(colorScheme == .dark ? CoachColors.darkBorder : CoachColors.lightBorder)
                        VStack(alignment: .leading, spacing: 4) {
                            Text("CUSTOM PROMPT")
                                .font(CoachFonts.ui(10, weight: .semibold))
                                .tracking(0.5)
                                .foregroundStyle(.secondary)
                            TextField("Describe your ideal coach...", text: $customPrompt, axis: .vertical)
                                .font(CoachFonts.ui(14))
                                .lineLimit(3...6)
                                .padding(10)
                                .background(fieldBackground)
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(fieldBorder, lineWidth: 1)
                                )
                        }
                        .padding(.top, 12)
                    }
                }
            }
        }
    }

    private var athleteSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionLabel("ATHLETE")
            NavigationLink {
                AthleteMemoryView()
            } label: {
                HStack(spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(CoachColors.accent.opacity(0.15))
                            .frame(width: 38, height: 38)
                        Image(systemName: "person.text.rectangle")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(CoachColors.accent)
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        Text("VIEW ATHLETE PROFILE")
                            .font(CoachFonts.ui(10, weight: .semibold))
                            .tracking(0.6)
                            .foregroundStyle(.secondary)
                        Text("See what your coach knows about you")
                            .font(CoachFonts.ui(14))
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
    }

    private var healthSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionLabel("INTEGRATIONS")
            CoachCard {
                Button {
                    Task { await data.syncHealthKitWorkouts() }
                } label: {
                    HStack(spacing: 12) {
                        ZStack {
                            Circle()
                                .fill(CoachColors.green.opacity(0.15))
                                .frame(width: 34, height: 34)
                            Image(systemName: "heart.fill")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(CoachColors.green)
                        }
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Apple Health Sync")
                                .font(CoachFonts.ui(15, weight: .medium))
                                .foregroundStyle(.primary)
                            Text("Import recent workouts from Apple Health")
                                .font(CoachFonts.ui(11))
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        if data.isHealthKitSyncing {
                            ProgressView()
                                .controlSize(.small)
                        } else {
                            Image(systemName: "arrow.triangle.2.circlepath")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(.secondary)
                        }
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .disabled(data.isHealthKitSyncing)
            }
        }
    }

    private var accountSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionLabel("ACCOUNT")
            CoachCard {
                Button {
                    Task {
                        try? await SupabaseService.shared.client.auth.signOut()
                    }
                } label: {
                    HStack(spacing: 12) {
                        ZStack {
                            Circle()
                                .fill(CoachColors.red.opacity(0.15))
                                .frame(width: 34, height: 34)
                            Image(systemName: "rectangle.portrait.and.arrow.right")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(CoachColors.red)
                        }
                        Text("Sign Out")
                            .font(CoachFonts.ui(15, weight: .medium))
                            .foregroundStyle(CoachColors.red)
                        Spacer()
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var devToolsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionLabel("DEV TOOLS")
            CoachCard {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Sample data covers workouts, plan, goals, and athlete memory. Clear deletes all of that for the signed-in user.")
                        .font(CoachFonts.ui(12))
                        .foregroundStyle(.secondary)

                    Button {
                        Task { await runSeed() }
                    } label: {
                        HStack(spacing: 10) {
                            Image(systemName: "tray.and.arrow.down")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(CoachColors.accent)
                            Text("Load Sample Data")
                                .font(CoachFonts.ui(14, weight: .medium))
                                .foregroundStyle(.primary)
                            Spacer()
                            if seeding { ProgressView().controlSize(.small) }
                        }
                        .padding(10)
                        .background(fieldBackground)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(fieldBorder, lineWidth: 1)
                        )
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .disabled(seeding)
                    .opacity(seeding ? 0.5 : 1)

                    Button {
                        showClearConfirm = true
                    } label: {
                        HStack(spacing: 10) {
                            Image(systemName: "trash")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(CoachColors.red)
                            Text("Clear Sample Data")
                                .font(CoachFonts.ui(14, weight: .medium))
                                .foregroundStyle(CoachColors.red)
                            Spacer()
                        }
                        .padding(10)
                        .background(CoachColors.red.opacity(0.06))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(CoachColors.red.opacity(0.2), lineWidth: 1)
                        )
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .disabled(seeding)
                    .opacity(seeding ? 0.5 : 1)

                    if let err = seedError {
                        Text(err)
                            .font(CoachFonts.ui(12))
                            .foregroundStyle(CoachColors.red)
                    }
                }
            }
        }
    }

    // MARK: - Shared helpers

    private func sectionLabel(_ text: String) -> some View {
        Text(text)
            .font(CoachFonts.ui(10, weight: .semibold))
            .tracking(0.6)
            .foregroundStyle(.secondary)
            .padding(.leading, 4)
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

    // MARK: - Helpers

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

    private func personalityIcon(_ p: Personality) -> String {
        switch p {
        case .normal: return "chart.bar"
        case .goggins: return "flame"
        case .hype: return "bolt.fill"
        case .custom: return "slider.horizontal.3"
        }
    }
}
