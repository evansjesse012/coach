import SwiftUI
import Supabase
import Auth

struct SettingsView: View {
    @Environment(DataService.self) var data
    @Environment(\.dismiss) var dismiss
    @State private var personality: Personality = .normal
    @State private var customPrompt = ""

    var body: some View {
        NavigationStack {
            Form {
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

                Section("Account") {
                    Button("Sign Out", role: .destructive) {
                        Task {
                            try? await SupabaseService.shared.client.auth.signOut()
                        }
                    }
                }
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
            }
        }
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
