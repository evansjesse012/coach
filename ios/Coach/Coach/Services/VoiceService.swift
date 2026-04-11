import Foundation
import AVFoundation

/// Voice output service supporting system TTS and ElevenLabs API for custom voices (Goggins mode).
/// Falls back to AVSpeechSynthesizer when ElevenLabs is not configured.
@MainActor
@Observable
final class VoiceService: NSObject {
    var isSpeaking = false
    var voiceOutputEnabled = false

    private let synthesizer = AVSpeechSynthesizer()
    private var audioPlayer: AVAudioPlayer?

    // ElevenLabs config — set via Supabase Edge Function
    private var elevenLabsVoiceId: String?

    override init() {
        super.init()
        synthesizer.delegate = self
    }

    // MARK: - Speak Text

    /// Speaks the given text using the appropriate voice for the personality.
    /// Goggins personality uses ElevenLabs cloned voice; others use system TTS.
    func speak(_ text: String, personality: Personality) async {
        guard voiceOutputEnabled else { return }

        stop()

        if personality == .goggins {
            await speakWithElevenLabs(text)
        } else {
            speakWithSystem(text, personality: personality)
        }
    }

    func stop() {
        synthesizer.stopSpeaking(at: .immediate)
        audioPlayer?.stop()
        audioPlayer = nil
        isSpeaking = false
    }

    // MARK: - System TTS

    private func speakWithSystem(_ text: String, personality: Personality) {
        let utterance = AVSpeechUtterance(string: text)
        utterance.rate = systemVoiceRate(for: personality)
        utterance.pitchMultiplier = systemVoicePitch(for: personality)
        utterance.volume = 1.0

        // Pick a voice that fits the personality
        if let voice = systemVoice(for: personality) {
            utterance.voice = voice
        }

        isSpeaking = true
        synthesizer.speak(utterance)
    }

    private func systemVoice(for personality: Personality) -> AVSpeechSynthesisVoice? {
        switch personality {
        case .goggins:
            // Deep male voice — fallback until ElevenLabs is configured
            return AVSpeechSynthesisVoice(language: "en-US")
        case .hype:
            // Energetic voice
            return AVSpeechSynthesisVoice(language: "en-US")
        case .normal, .custom:
            return AVSpeechSynthesisVoice(language: "en-US")
        }
    }

    private func systemVoiceRate(for personality: Personality) -> Float {
        switch personality {
        case .goggins: return 0.52  // Intense, deliberate
        case .hype: return 0.55     // Fast, energetic
        case .normal, .custom: return 0.50
        }
    }

    private func systemVoicePitch(for personality: Personality) -> Float {
        switch personality {
        case .goggins: return 0.9   // Lower pitch
        case .hype: return 1.1      // Higher energy
        case .normal, .custom: return 1.0
        }
    }

    // MARK: - ElevenLabs TTS (Goggins Voice Clone)

    /// Calls Supabase Edge Function which proxies to ElevenLabs TTS API.
    /// The Edge Function holds the ElevenLabs API key and voice ID securely.
    private func speakWithElevenLabs(_ text: String) async {
        isSpeaking = true
        do {
            let audioData = try await callElevenLabsEdgeFunction(text: text)
            try playAudioData(audioData)
        } catch {
            // Fallback to system TTS if ElevenLabs fails
            speakWithSystem(text, personality: .goggins)
        }
    }

    private func callElevenLabsEdgeFunction(text: String) async throws -> Data {
        let client = SupabaseService.shared.client

        let body: [String: Any] = [
            "text": text,
            "voice": "goggins",
            "model_id": "eleven_turbo_v2",
            "voice_settings": [
                "stability": 0.75,
                "similarity_boost": 0.85,
                "style": 0.4,
                "use_speaker_boost": true,
            ] as [String: Any],
        ]

        let bodyData = try JSONSerialization.data(withJSONObject: body)
        let response = try await client.functions.invoke(
            "tts",
            options: .init(body: bodyData)
        )

        return response.data
    }

    private func playAudioData(_ data: Data) throws {
        let audioSession = AVAudioSession.sharedInstance()
        try audioSession.setCategory(.playback, mode: .default)
        try audioSession.setActive(true)

        audioPlayer = try AVAudioPlayer(data: data)
        audioPlayer?.delegate = self
        audioPlayer?.play()
    }
}

// MARK: - AVSpeechSynthesizerDelegate

extension VoiceService: AVSpeechSynthesizerDelegate {
    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        Task { @MainActor in
            isSpeaking = false
        }
    }

    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        Task { @MainActor in
            isSpeaking = false
        }
    }
}

// MARK: - AVAudioPlayerDelegate

extension VoiceService: AVAudioPlayerDelegate {
    nonisolated func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        Task { @MainActor in
            isSpeaking = false
        }
    }
}
