import SwiftUI

struct SettingsView: View {
    @Environment(DataService.self) var data
    @Environment(\.dismiss) var dismiss
    @State private var personality: Personality = .normal
    @State private var customPrompt = ""

    // Voice & Messaging
    @State private var voiceOutputEnabled = false
    @State private var phoneNumber = ""
    @State private var smsEnabled = false
    @State private var callsEnabled = false
    @State private var showAddCheckIn = false

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

                // MARK: - Voice Settings

                Section {
                    Toggle(isOn: $voiceOutputEnabled) {
                        HStack(spacing: 12) {
                            Image(systemName: "speaker.wave.2.fill")
                                .foregroundStyle(CoachColors.accent)
                                .frame(width: 24)
                            VStack(alignment: .leading) {
                                Text("Voice Output")
                                    .font(CoachFonts.ui(15, weight: .medium))
                                Text("Coach speaks responses aloud")
                                    .font(CoachFonts.ui(12))
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .tint(CoachColors.accent)

                    if personality == .goggins && voiceOutputEnabled {
                        HStack(spacing: 12) {
                            Image(systemName: "waveform")
                                .foregroundStyle(CoachColors.accent)
                                .frame(width: 24)
                            VStack(alignment: .leading) {
                                Text("Goggins Voice Clone")
                                    .font(CoachFonts.ui(15, weight: .medium))
                                Text("AI-cloned voice from podcasts & audiobooks")
                                    .font(CoachFonts.ui(12))
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            CoachPill(text: "Active", color: CoachColors.green)
                        }
                    }
                } header: {
                    Text("Voice")
                } footer: {
                    if personality == .goggins && voiceOutputEnabled {
                        Text("Goggins mode uses a custom AI voice trained on public podcasts and audiobooks to match his speaking style.")
                    }
                }

                // MARK: - Messaging & Calls

                Section {
                    HStack(spacing: 12) {
                        Image(systemName: "phone.fill")
                            .foregroundStyle(CoachColors.green)
                            .frame(width: 24)
                        TextField("Phone number", text: $phoneNumber)
                            .font(CoachFonts.ui(15))
                            .keyboardType(.phonePad)
                    }

                    Toggle(isOn: $smsEnabled) {
                        HStack(spacing: 12) {
                            Image(systemName: "message.fill")
                                .foregroundStyle(CoachColors.green)
                                .frame(width: 24)
                            VStack(alignment: .leading) {
                                Text("Text Messages")
                                    .font(CoachFonts.ui(15, weight: .medium))
                                Text("Coach can text you reminders & updates")
                                    .font(CoachFonts.ui(12))
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .tint(CoachColors.green)

                    Toggle(isOn: $callsEnabled) {
                        HStack(spacing: 12) {
                            Image(systemName: "phone.arrow.down.left.fill")
                                .foregroundStyle(CoachColors.cyan)
                                .frame(width: 24)
                            VStack(alignment: .leading) {
                                Text("Coach Calls")
                                    .font(CoachFonts.ui(15, weight: .medium))
                                Text("Coach can call you for check-ins")
                                    .font(CoachFonts.ui(12))
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .tint(CoachColors.cyan)
                } header: {
                    Text("Messaging & Calls")
                } footer: {
                    Text("Your coach can reach out via text or phone call for scheduled check-ins, accountability, and real-time coaching.")
                }

                // MARK: - Scheduled Check-Ins

                if smsEnabled || callsEnabled {
                    Section {
                        if let checkIns = data.settings.scheduledCheckIns, !checkIns.isEmpty {
                            ForEach(checkIns) { checkIn in
                                HStack(spacing: 12) {
                                    if let type = CheckInType(rawValue: checkIn.type) {
                                        Image(systemName: type.sfSymbol)
                                            .foregroundStyle(CoachColors.accent)
                                            .frame(width: 24)
                                        VStack(alignment: .leading) {
                                            Text(type.label)
                                                .font(CoachFonts.ui(14, weight: .medium))
                                            Text("\(checkIn.time) \u{2022} \(checkIn.channel.capitalized)")
                                                .font(CoachFonts.ui(12))
                                                .foregroundStyle(.secondary)
                                        }
                                    }
                                    Spacer()
                                    Circle()
                                        .fill(checkIn.enabled ? CoachColors.green : Color.gray.opacity(0.3))
                                        .frame(width: 8, height: 8)
                                }
                            }
                        }

                        Button {
                            showAddCheckIn = true
                        } label: {
                            HStack {
                                Image(systemName: "plus.circle.fill")
                                    .foregroundStyle(CoachColors.accent)
                                Text("Add Check-In")
                                    .font(CoachFonts.ui(14, weight: .medium))
                            }
                        }
                    } header: {
                        Text("Scheduled Check-Ins")
                    } footer: {
                        Text("Your coach will reach out at these times to keep you on track.")
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
                            s.voiceOutputEnabled = voiceOutputEnabled
                            s.phoneNumber = phoneNumber
                            s.smsEnabled = smsEnabled
                            s.callsEnabled = callsEnabled
                            try? await data.saveSettings(s)
                            dismiss()
                        }
                    }
                }
            }
            .onAppear {
                personality = data.settings.personality
                customPrompt = data.settings.customPrompt
                voiceOutputEnabled = data.settings.voiceOutputEnabled
                phoneNumber = data.settings.phoneNumber
                smsEnabled = data.settings.smsEnabled
                callsEnabled = data.settings.callsEnabled
            }
            .sheet(isPresented: $showAddCheckIn) {
                AddCheckInSheet()
                    .environment(data)
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

// MARK: - Add Check-In Sheet

struct AddCheckInSheet: View {
    @Environment(DataService.self) var data
    @Environment(\.dismiss) var dismiss

    @State private var selectedType: CheckInType = .morningBrief
    @State private var selectedTime = Date()
    @State private var selectedChannel: MessagingChannel = .push

    var body: some View {
        NavigationStack {
            Form {
                Section("Check-In Type") {
                    ForEach(CheckInType.allCases) { type in
                        Button {
                            selectedType = type
                        } label: {
                            HStack(spacing: 12) {
                                Image(systemName: type.sfSymbol)
                                    .foregroundStyle(CoachColors.accent)
                                    .frame(width: 24)
                                VStack(alignment: .leading) {
                                    Text(type.label)
                                        .font(CoachFonts.ui(14, weight: .medium))
                                    Text(type.description)
                                        .font(CoachFonts.ui(12))
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                if selectedType == type {
                                    Image(systemName: "checkmark")
                                        .foregroundStyle(CoachColors.accent)
                                }
                            }
                        }
                        .tint(.primary)
                    }
                }

                Section("Time") {
                    DatePicker("Time", selection: $selectedTime, displayedComponents: .hourAndMinute)
                        .font(CoachFonts.ui(15))
                }

                Section("Delivery Method") {
                    ForEach(MessagingChannel.allCases) { channel in
                        Button {
                            selectedChannel = channel
                        } label: {
                            HStack {
                                Text(channel.label)
                                    .font(CoachFonts.ui(14, weight: .medium))
                                Spacer()
                                if selectedChannel == channel {
                                    Image(systemName: "checkmark")
                                        .foregroundStyle(CoachColors.accent)
                                }
                            }
                        }
                        .tint(.primary)
                        .disabled(channel == .sms && data.settings.phoneNumber.isEmpty)
                        .disabled(channel == .call && !data.settings.callsEnabled)
                    }
                }
            }
            .navigationTitle("Add Check-In")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        let formatter = DateFormatter()
                        formatter.dateFormat = "HH:mm"
                        let timeString = formatter.string(from: selectedTime)

                        let checkIn = ScheduledCheckIn.create(
                            type: selectedType,
                            time: timeString,
                            channel: selectedChannel
                        )

                        Task {
                            var s = data.settings
                            var existing = s.scheduledCheckIns ?? []
                            existing.append(checkIn)
                            s.scheduledCheckIns = existing
                            try? await data.saveSettings(s)
                            dismiss()
                        }
                    }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
}
