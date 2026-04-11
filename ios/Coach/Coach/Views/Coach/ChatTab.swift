import SwiftUI

struct ChatTab: View {
    @Environment(DataService.self) var data
    @State private var inputText = ""
    @State private var isLoading = false
    @State private var showVoiceCall = false
    @FocusState private var isInputFocused: Bool

    @State private var speechService = SpeechService()
    @State private var voiceService = VoiceService()

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Messages
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 12) {
                            ForEach(Array(data.messages.enumerated()), id: \.offset) { index, message in
                                MessageBubble(
                                    message: message,
                                    voiceService: voiceService,
                                    personality: data.settings.personality
                                )
                                .id(index)
                            }
                            if isLoading {
                                HStack(spacing: 8) {
                                    DotsLoader()
                                    Text("Thinking...")
                                        .font(CoachFonts.ui(13))
                                        .foregroundStyle(.secondary)
                                }
                                .padding(.horizontal)
                                .id("loading")
                            }
                        }
                        .padding()
                    }
                    .onChange(of: data.messages.count) {
                        withAnimation {
                            proxy.scrollTo(data.messages.count - 1, anchor: .bottom)
                        }
                    }
                }

                Divider()

                // Voice transcription preview
                if speechService.isListening {
                    VoiceTranscriptionBar(
                        transcript: speechService.transcript,
                        onStop: {
                            speechService.stopListening()
                            if !speechService.transcript.isEmpty {
                                inputText = speechService.transcript
                            }
                        }
                    )
                }

                // Input bar
                HStack(spacing: 8) {
                    // Microphone button
                    Button {
                        if speechService.isListening {
                            speechService.stopListening()
                            if !speechService.transcript.isEmpty {
                                inputText = speechService.transcript
                            }
                        } else {
                            Task { await speechService.startListening() }
                        }
                    } label: {
                        Image(systemName: speechService.isListening ? "mic.fill" : "mic")
                            .font(.system(size: 20))
                            .foregroundStyle(speechService.isListening ? CoachColors.accent : .secondary)
                            .frame(width: 36, height: 36)
                    }

                    TextField("Message your coach...", text: $inputText, axis: .vertical)
                        .font(CoachFonts.ui(15))
                        .lineLimit(1...5)
                        .focused($isInputFocused)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(Color(.secondarySystemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 20))

                    Button {
                        Task { await sendMessage() }
                    } label: {
                        Image(systemName: "arrow.up.circle.fill")
                            .font(.system(size: 32))
                            .foregroundStyle(inputText.trimmingCharacters(in: .whitespaces).isEmpty ? .quaternary : CoachColors.accent)
                    }
                    .disabled(inputText.trimmingCharacters(in: .whitespaces).isEmpty || isLoading)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
            }
            .navigationTitle("Coach")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    // Voice output toggle
                    Button {
                        voiceService.voiceOutputEnabled.toggle()
                        if !voiceService.voiceOutputEnabled {
                            voiceService.stop()
                        }
                    } label: {
                        Image(systemName: voiceService.voiceOutputEnabled ? "speaker.wave.2.fill" : "speaker.slash")
                            .font(.system(size: 14))
                            .foregroundStyle(voiceService.voiceOutputEnabled ? CoachColors.accent : .secondary)
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    // Voice call button
                    Button {
                        showVoiceCall = true
                    } label: {
                        Image(systemName: "phone.fill")
                            .font(.system(size: 14))
                            .foregroundStyle(CoachColors.green)
                    }
                }
            }
            .fullScreenCover(isPresented: $showVoiceCall) {
                VoiceCallView()
                    .environment(data)
            }
            .onAppear {
                voiceService.voiceOutputEnabled = data.settings.voiceOutputEnabled
            }
        }
    }

    // MARK: - Send Message

    private func sendMessage() async {
        let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        inputText = ""
        isInputFocused = false

        let userMsg = ChatMessage.user(text)
        try? await data.addMessage(userMsg)

        isLoading = true
        do {
            let result = try await runAgentLoop(
                personality: data.settings.personality,
                customText: data.settings.customPrompt,
                messages: data.messages,
                dataService: data
            )

            let assistantMsg = ChatMessage.assistant(result.response, metadata: ChatMessageMetadata(
                logged: !result.workoutsLogged.isEmpty,
                nutritionLogged: !result.nutritionLogged.isEmpty,
                planChanged: !result.planChanges.isEmpty,
                appActionTaken: !result.appActions.isEmpty
            ))
            try? await data.addMessage(assistantMsg)

            // Process side effects
            for workout in result.workoutsLogged {
                try? await data.addCardio(workout)
            }
            for entry in result.nutritionLogged {
                try? await data.addNutrition(entry)
            }

            // Speak the response if voice output is enabled
            if voiceService.voiceOutputEnabled {
                await voiceService.speak(result.response, personality: data.settings.personality)
            }

            // Background memory extraction
            Task {
                await extractMemory(
                    messages: data.messages,
                    existingMemory: data.memory,
                    dataService: data
                )
            }
        } catch {
            let errorMsg = ChatMessage.assistant(
                "Sorry, I ran into an error. Please try again.",
                metadata: ChatMessageMetadata(isError: true)
            )
            try? await data.addMessage(errorMsg)
        }
        isLoading = false
    }
}

// MARK: - Voice Transcription Bar

struct VoiceTranscriptionBar: View {
    let transcript: String
    let onStop: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            // Pulsing mic indicator
            Circle()
                .fill(CoachColors.accent)
                .frame(width: 8, height: 8)
                .modifier(PulseAnimation())

            Text(transcript.isEmpty ? "Listening..." : transcript)
                .font(CoachFonts.ui(13))
                .foregroundStyle(transcript.isEmpty ? .secondary : .primary)
                .lineLimit(2)
                .frame(maxWidth: .infinity, alignment: .leading)

            Button("Done", action: onStop)
                .font(CoachFonts.ui(13, weight: .semibold))
                .foregroundStyle(CoachColors.accent)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Color(.secondarySystemBackground))
    }
}

// MARK: - Pulse Animation

struct PulseAnimation: ViewModifier {
    @State private var isPulsing = false

    func body(content: Content) -> some View {
        content
            .scaleEffect(isPulsing ? 1.3 : 1.0)
            .opacity(isPulsing ? 0.7 : 1.0)
            .animation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true), value: isPulsing)
            .onAppear { isPulsing = true }
    }
}

// MARK: - Message Bubble

struct MessageBubble: View {
    let message: ChatMessage
    var voiceService: VoiceService?
    var personality: Personality = .normal

    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            if message.role == "user" { Spacer(minLength: 48) }

            VStack(alignment: message.role == "user" ? .trailing : .leading, spacing: 4) {
                Text(message.content)
                    .font(CoachFonts.ui(14))
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(
                        message.role == "user"
                            ? CoachColors.accent
                            : (colorScheme == .dark ? CoachColors.darkCard : CoachColors.lightElevated)
                    )
                    .foregroundStyle(message.role == "user" ? .white : .primary)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .contextMenu {
                        if message.role == "assistant", let voiceService {
                            Button {
                                Task {
                                    await voiceService.speak(message.content, personality: personality)
                                }
                            } label: {
                                Label("Play Voice", systemImage: "speaker.wave.2")
                            }
                        }
                    }

                // Side-effect indicators
                if let meta = message.metadata {
                    HStack(spacing: 6) {
                        if meta.logged == true {
                            Label("Logged", systemImage: "checkmark.circle.fill")
                                .foregroundStyle(CoachColors.green)
                        }
                        if meta.planChanged == true {
                            Label("Plan updated", systemImage: "calendar.badge.checkmark")
                                .foregroundStyle(CoachColors.cyan)
                        }
                    }
                    .font(CoachFonts.ui(11))
                }
            }

            if message.role == "assistant" { Spacer(minLength: 48) }
        }
    }
}
