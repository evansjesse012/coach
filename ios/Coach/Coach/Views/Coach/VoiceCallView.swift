import SwiftUI

/// Full-screen voice conversation mode with the AI coach.
/// Hands-free: user speaks, coach responds with voice.
/// The coach can still use all its tools (log workouts, update plans, etc.) during the call.
struct VoiceCallView: View {
    @Environment(DataService.self) var data
    @Environment(\.dismiss) var dismiss

    @State private var speechService = SpeechService()
    @State private var voiceService = VoiceService()
    @State private var callState: CallState = .idle
    @State private var isProcessing = false
    @State private var lastTranscript = ""
    @State private var lastResponse = ""
    @State private var callDuration: TimeInterval = 0
    @State private var timer: Timer?
    @State private var sideEffects: [String] = []

    enum CallState {
        case idle
        case listening
        case processing
        case speaking
    }

    var body: some View {
        ZStack {
            // Background gradient
            backgroundGradient

            VStack(spacing: 0) {
                // Top bar
                topBar

                Spacer()

                // Coach avatar and status
                coachAvatar

                Spacer()

                // Transcript area
                transcriptArea

                Spacer()

                // Side effects
                if !sideEffects.isEmpty {
                    sideEffectsBar
                }

                // Controls
                controlBar
            }
        }
        .onAppear {
            voiceService.voiceOutputEnabled = true
            startCall()
        }
        .onDisappear {
            endCall()
        }
    }

    // MARK: - Background

    private var backgroundGradient: some View {
        LinearGradient(
            colors: personalityGradient,
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()
    }

    private var personalityGradient: [Color] {
        switch data.settings.personality {
        case .goggins:
            return [Color(hex: "0A0A0A"), Color(hex: "1A0A0A"), Color(hex: "0A0A0A")]
        case .hype:
            return [Color(hex: "0A0A1A"), Color(hex: "1A0A2A"), Color(hex: "0A0A1A")]
        case .normal, .custom:
            return [Color(hex: "0A0E1A"), Color(hex: "0A1A2A"), Color(hex: "0A0E1A")]
        }
    }

    // MARK: - Top Bar

    private var topBar: some View {
        HStack {
            Button {
                endCall()
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.7))
                    .frame(width: 36, height: 36)
                    .background(.white.opacity(0.1))
                    .clipShape(Circle())
            }

            Spacer()

            // Call duration
            VStack(spacing: 2) {
                Text(personalityLabel)
                    .font(CoachFonts.ui(11, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.5))
                    .textCase(.uppercase)
                    .tracking(1)
                Text(formatDuration(callDuration))
                    .font(CoachFonts.mono(13))
                    .foregroundStyle(.white.opacity(0.7))
            }

            Spacer()

            // Placeholder for symmetry
            Color.clear.frame(width: 36, height: 36)
        }
        .padding(.horizontal, 20)
        .padding(.top, 8)
    }

    private var personalityLabel: String {
        switch data.settings.personality {
        case .goggins: return "Goggins Mode"
        case .hype: return "Hype Coach"
        case .normal: return "Head Coach"
        case .custom: return "Coach"
        }
    }

    // MARK: - Coach Avatar

    private var coachAvatar: some View {
        VStack(spacing: 16) {
            ZStack {
                // Animated rings
                if callState == .listening || callState == .speaking {
                    ForEach(0..<3, id: \.self) { ring in
                        Circle()
                            .stroke(personalityAccent.opacity(0.15 - Double(ring) * 0.04), lineWidth: 2)
                            .frame(width: CGFloat(120 + ring * 30), height: CGFloat(120 + ring * 30))
                            .modifier(RingPulse(delay: Double(ring) * 0.3))
                    }
                }

                // Avatar circle
                Circle()
                    .fill(personalityAccent.opacity(0.2))
                    .frame(width: 100, height: 100)
                    .overlay(
                        Image(systemName: avatarIcon)
                            .font(.system(size: 40))
                            .foregroundStyle(personalityAccent)
                    )
            }
            .frame(height: 180)

            Text(statusText)
                .font(CoachFonts.ui(15, weight: .medium))
                .foregroundStyle(.white.opacity(0.8))
        }
    }

    private var personalityAccent: Color {
        switch data.settings.personality {
        case .goggins: return CoachColors.accent
        case .hype: return CoachColors.purple
        case .normal, .custom: return CoachColors.cyan
        }
    }

    private var avatarIcon: String {
        switch data.settings.personality {
        case .goggins: return "flame.fill"
        case .hype: return "bolt.fill"
        case .normal, .custom: return "waveform"
        }
    }

    private var statusText: String {
        switch callState {
        case .idle: return "Tap to start"
        case .listening: return "Listening..."
        case .processing: return "Thinking..."
        case .speaking: return "Speaking..."
        }
    }

    // MARK: - Transcript Area

    private var transcriptArea: some View {
        VStack(spacing: 12) {
            if !lastTranscript.isEmpty {
                HStack {
                    Text("You")
                        .font(CoachFonts.ui(11, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.4))
                    Spacer()
                }
                Text(lastTranscript)
                    .font(CoachFonts.ui(14))
                    .foregroundStyle(.white.opacity(0.7))
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            if !lastResponse.isEmpty {
                HStack {
                    Text("Coach")
                        .font(CoachFonts.ui(11, weight: .semibold))
                        .foregroundStyle(personalityAccent.opacity(0.7))
                    Spacer()
                }
                Text(lastResponse)
                    .font(CoachFonts.ui(14))
                    .foregroundStyle(.white.opacity(0.9))
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            if speechService.isListening && !speechService.transcript.isEmpty {
                HStack {
                    Text("You")
                        .font(CoachFonts.ui(11, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.4))
                    Spacer()
                }
                Text(speechService.transcript)
                    .font(CoachFonts.ui(14))
                    .foregroundStyle(.white.opacity(0.5))
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(.horizontal, 24)
        .frame(maxHeight: 180)
    }

    // MARK: - Side Effects Bar

    private var sideEffectsBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(sideEffects, id: \.self) { effect in
                    HStack(spacing: 4) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 10))
                        Text(effect)
                            .font(CoachFonts.ui(11))
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(.white.opacity(0.1))
                    .foregroundStyle(CoachColors.green)
                    .clipShape(Capsule())
                }
            }
            .padding(.horizontal, 24)
        }
        .padding(.bottom, 8)
    }

    // MARK: - Control Bar

    private var controlBar: some View {
        HStack(spacing: 40) {
            // Mute toggle (placeholder)
            Button {
                // Toggle mute
            } label: {
                VStack(spacing: 4) {
                    Image(systemName: "speaker.wave.2.fill")
                        .font(.system(size: 22))
                        .frame(width: 52, height: 52)
                        .background(.white.opacity(0.1))
                        .clipShape(Circle())
                    Text("Speaker")
                        .font(CoachFonts.ui(10))
                }
                .foregroundStyle(.white.opacity(0.7))
            }

            // Main mic button
            Button {
                handleMicTap()
            } label: {
                Image(systemName: callState == .listening ? "mic.fill" : "mic")
                    .font(.system(size: 28))
                    .frame(width: 72, height: 72)
                    .background(
                        callState == .listening
                            ? personalityAccent
                            : .white.opacity(0.15)
                    )
                    .foregroundStyle(.white)
                    .clipShape(Circle())
            }
            .disabled(isProcessing)

            // End call
            Button {
                endCall()
                dismiss()
            } label: {
                VStack(spacing: 4) {
                    Image(systemName: "phone.down.fill")
                        .font(.system(size: 22))
                        .frame(width: 52, height: 52)
                        .background(CoachColors.red)
                        .clipShape(Circle())
                    Text("End")
                        .font(CoachFonts.ui(10))
                }
                .foregroundStyle(.white)
            }
        }
        .padding(.bottom, 40)
    }

    // MARK: - Actions

    private func startCall() {
        callState = .idle
        callDuration = 0
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
            Task { @MainActor in
                callDuration += 1
            }
        }
    }

    private func endCall() {
        timer?.invalidate()
        timer = nil
        speechService.stopListening()
        voiceService.stop()
        callState = .idle
    }

    private func handleMicTap() {
        if speechService.isListening {
            // Stop listening and send
            speechService.stopListening()
            let transcript = speechService.transcript
            guard !transcript.isEmpty else {
                callState = .idle
                return
            }
            lastTranscript = transcript
            Task { await processVoiceInput(transcript) }
        } else {
            // Start listening
            callState = .listening
            Task { await speechService.startListening() }
        }
    }

    private func processVoiceInput(_ text: String) async {
        callState = .processing
        isProcessing = true

        let userMsg = ChatMessage.user(text)
        try? await data.addMessage(userMsg)

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

            // Track side effects for UI
            if !result.workoutsLogged.isEmpty { sideEffects.append("Workout logged") }
            if !result.nutritionLogged.isEmpty { sideEffects.append("Nutrition logged") }
            if !result.planChanges.isEmpty { sideEffects.append("Plan updated") }

            lastResponse = result.response

            // Speak the response
            callState = .speaking
            await voiceService.speak(result.response, personality: data.settings.personality)

            // Background memory extraction
            Task {
                await extractMemory(
                    messages: data.messages,
                    existingMemory: data.memory,
                    dataService: data
                )
            }
        } catch {
            lastResponse = "Sorry, I had trouble processing that. Try again."
            callState = .speaking
            await voiceService.speak(lastResponse, personality: data.settings.personality)
        }

        callState = .idle
        isProcessing = false
    }

    // MARK: - Helpers

    private func formatDuration(_ seconds: TimeInterval) -> String {
        let mins = Int(seconds) / 60
        let secs = Int(seconds) % 60
        return String(format: "%02d:%02d", mins, secs)
    }
}

// MARK: - Ring Pulse Animation

struct RingPulse: ViewModifier {
    let delay: Double
    @State private var isPulsing = false

    func body(content: Content) -> some View {
        content
            .scaleEffect(isPulsing ? 1.1 : 0.95)
            .opacity(isPulsing ? 0.6 : 0.3)
            .animation(
                .easeInOut(duration: 1.2)
                    .repeatForever(autoreverses: true)
                    .delay(delay),
                value: isPulsing
            )
            .onAppear { isPulsing = true }
    }
}
