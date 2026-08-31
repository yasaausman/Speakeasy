import Foundation
import AVFoundation
// import Speech  // (Phase M3) SFSpeechRecognizer for on-device STT

/// Voice layer for the USER's side only (never the phone call — that's CALL-E).
/// Phase M3 fills these in with SFSpeechRecognizer (STT) + AVSpeechSynthesizer (TTS).
///
/// Info.plist keys required before shipping voice:
///   NSMicrophoneUsageDescription, NSSpeechRecognitionUsageDescription
@MainActor
final class SpeechManager: NSObject, ObservableObject {
    @Published var isListening = false
    private let synthesizer = AVSpeechSynthesizer()

    /// Speak text in the user's language (readback confirmation + result narration).
    func speak(_ text: String, lang: String = "es-ES") {
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = AVSpeechSynthesisVoice(language: lang)
        synthesizer.speak(utterance)
    }

    /// Read a confirmation number digit by digit (build-plan §8).
    func speakDigits(_ digits: String, lang: String = "es-ES") {
        let spaced = digits.map { String($0) }.joined(separator: " ")
        speak(spaced, lang: lang)
    }

    // TODO(Phase M3): startListening()/stopListening() via SFSpeechRecognizer,
    // returning the transcribed text to SessionViewModel.submitGoal(_:).
    func startListening() { isListening = true }
    func stopListening() { isListening = false }
}
