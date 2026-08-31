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
            lastError = "Microphone and speech permission are needed to talk."
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
            lastError = "Speech recognition isn't available for \(localeId)."
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
            lastError = "Couldn't start the microphone."
            return
        }

        let input = audioEngine.inputNode
        let format = input.outputFormat(forBus: 0)
        input.installTap(onBus: 0, bufferSize: 1024, format: format) { [weak self] buffer, _ in
            self?.request?.append(buffer)
        }
        audioEngine.prepare()
        do {
            try audioEngine.start()
        } catch {
            lastError = "Couldn't start audio."
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
                Task { @MainActor in self.teardownAudio() }
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
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
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
