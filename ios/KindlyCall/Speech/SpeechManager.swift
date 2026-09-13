import Foundation
import AVFoundation
import Speech

/// Voice layer for the USER's side only (never the phone call — that's CALL-E).
/// STT via SFSpeechRecognizer, TTS via AVSpeechSynthesizer — all on-device/native,
/// no API keys. Locales come from AppLanguage (e.g. es-ES, hi-IN, ar-SA).
///
/// Info.plist (set in project.yml): NSMicrophoneUsageDescription,
/// NSSpeechRecognitionUsageDescription.
@MainActor
final class SpeechManager: NSObject, ObservableObject {
    @Published var isListening = false
    @Published var isSpeaking = false
    @Published var partialText = ""
    @Published var lastError: String?
    /// Normalized 0…1 mic loudness while listening — drives the audio-reactive orb.
    @Published var audioLevel: Float = 0

    private let synthesizer = AVSpeechSynthesizer()
    private var recognizer: SFSpeechRecognizer?
    private var request: SFSpeechAudioBufferRecognitionRequest?
    private var task: SFSpeechRecognitionTask?
    private let audioEngine = AVAudioEngine()

    override init() {
        super.init()
        synthesizer.delegate = self
    }

    // MARK: - Permissions (requested lazily on first use)

    func requestPermissions() async -> Bool {
        let speechOK = await withCheckedContinuation { (cont: CheckedContinuation<Bool, Never>) in
            SFSpeechRecognizer.requestAuthorization { cont.resume(returning: $0 == .authorized) }
        }
        let micOK = await withCheckedContinuation { (cont: CheckedContinuation<Bool, Never>) in
            AVAudioApplication.requestRecordPermission { cont.resume(returning: $0) }
        }
        if !(speechOK && micOK) {
            lastError = "KindlyCall needs microphone and speech access to hear you. Turn it on in Settings, or type your request below."
        }
        return speechOK && micOK
    }

    // MARK: - Speech to text

    func startListening(localeId: String) {
        guard !isListening else { return }
        lastError = nil
        partialText = ""

        let rec = SFSpeechRecognizer(locale: Locale(identifier: localeId))
        guard let rec, rec.isAvailable else {
            lastError = "Voice input isn't available for this language yet — you can type your request below instead."
            return
        }
        recognizer = rec

        let req = SFSpeechAudioBufferRecognitionRequest()
        req.shouldReportPartialResults = true
        request = req

        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(.record, mode: .measurement, options: .duckOthers)
            try session.setActive(true, options: .notifyOthersOnDeactivation)
        } catch {
            lastError = "I couldn't reach the microphone. You can type your request below."
            return
        }

        let input = audioEngine.inputNode
        let format = input.outputFormat(forBus: 0)
        input.installTap(onBus: 0, bufferSize: 1024, format: format) { [weak self] buffer, _ in
            self?.request?.append(buffer)
            self?.publishLevel(from: buffer)
        }
        audioEngine.prepare()
        do {
            try audioEngine.start()
        } catch {
            lastError = "I couldn't start listening just now. You can type your request below."
            teardownAudio()
            return
        }
        isListening = true

        task = rec.recognitionTask(with: req) { [weak self] result, error in
            guard let self else { return }
            if let result {
                let text = result.bestTranscription.formattedString
                Task { @MainActor in self.partialText = text }
            }
            if error != nil || (result?.isFinal ?? false) {
                Task { @MainActor in
                    // Surface a failure only when it cut us off before any words
                    // landed — otherwise the partial text is a fine result.
                    if error != nil, self.isListening, self.partialText.isEmpty {
                        self.lastError = "I couldn't quite catch that. Hold to try again, or type below."
                    }
                    self.teardownAudio()
                }
            }
        }
    }

    /// Stop capturing and return the transcript so far.
    @discardableResult
    func stopListening() -> String {
        let text = partialText
        request?.endAudio()
        teardownAudio()
        return text
    }

    private func teardownAudio() {
        if audioEngine.isRunning {
            audioEngine.stop()
            audioEngine.inputNode.removeTap(onBus: 0)
        }
        task?.cancel()
        task = nil
        request = nil
        isListening = false
        audioLevel = 0
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    /// Turn a raw PCM buffer into a smoothed 0…1 loudness for the orb. Runs on the
    /// audio thread; the RMS→dB→normalized mapping is cheap, and we hop to the main
    /// actor only to publish. Kept off the recognition path entirely.
    nonisolated private func publishLevel(from buffer: AVAudioPCMBuffer) {
        guard let channel = buffer.floatChannelData?[0] else { return }
        let n = Int(buffer.frameLength)
        guard n > 0 else { return }
        var sum: Float = 0
        for i in 0..<n { let s = channel[i]; sum += s * s }
        let rms = (sum / Float(n)).squareRoot()
        // Map ~ -50 dB (quiet room) … -10 dB (speaking) onto 0…1.
        let db = 20 * log10(max(rms, 1e-7))
        let level = max(0, min(1, (db + 50) / 40))
        Task { @MainActor in
            // Ease toward the new level so the orb pulses smoothly, not jitterily.
            self.audioLevel += (level - self.audioLevel) * 0.35
        }
    }

    // MARK: - Text to speech

    /// Speak text in the given voice locale (e.g. "es-ES").
    func speak(_ text: String, localeId: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.playback, mode: .spokenAudio, options: .duckOthers)
        try? session.setActive(true)
        let utterance = AVSpeechUtterance(string: trimmed)
        utterance.voice = AVSpeechSynthesisVoice(language: localeId)
        synthesizer.speak(utterance)
    }

    /// Read a confirmation number digit by digit (build-plan §8). Queues after
    /// any current utterance.
    func speakDigits(_ digits: String, localeId: String) {
        let spaced = digits.map(String.init).joined(separator: " ")
        speak(spaced, localeId: localeId)
    }

    func stopSpeaking() {
        synthesizer.stopSpeaking(at: .immediate)
    }
}

extension SpeechManager: AVSpeechSynthesizerDelegate {
    nonisolated func speechSynthesizer(_ s: AVSpeechSynthesizer, didStart utterance: AVSpeechUtterance) {
        Task { @MainActor in self.isSpeaking = true }
    }
    nonisolated func speechSynthesizer(_ s: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        Task { @MainActor in self.isSpeaking = false }
    }
    nonisolated func speechSynthesizer(_ s: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        Task { @MainActor in self.isSpeaking = false }
    }
}
