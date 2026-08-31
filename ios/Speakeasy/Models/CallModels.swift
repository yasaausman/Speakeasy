import Foundation

// MARK: - Supported user languages (mirrors server/language/languages.ts)
// The phone call is always English; this is the language the USER uses.
struct AppLanguage: Identifiable, Hashable {
    let code: String      // "en" | "es" | "hi" | "ar"
    let name: String      // English name
    let endonym: String   // name in its own script
    let rtl: Bool
    let sttLocale: String // SFSpeechRecognizer locale
    let ttsLocale: String // AVSpeechSynthesizer voice
    var id: String { code }

    static let all: [AppLanguage] = [
        AppLanguage(code: "en", name: "English", endonym: "English", rtl: false, sttLocale: "en-US", ttsLocale: "en-US"),
        AppLanguage(code: "es", name: "Spanish", endonym: "Español", rtl: false, sttLocale: "es-ES", ttsLocale: "es-ES"),
        AppLanguage(code: "hi", name: "Hindi", endonym: "हिन्दी", rtl: false, sttLocale: "hi-IN", ttsLocale: "hi-IN"),
        AppLanguage(code: "ar", name: "Arabic", endonym: "العربية", rtl: true, sttLocale: "ar-SA", ttsLocale: "ar-SA"),
    ]

    static let spanish = all[1]
}

// MARK: - Session phase (mirrors the backend orchestrator state machine)
// IDLE → COLLECTING → CONFIRMING → CALLING → POLLING → NARRATING → DONE, plus FAILED.
enum SessionPhase: String, Codable {
    case idle
    case collecting
    case confirming   // goal understood, waiting for the user's yes  ← the hard gate
    case calling
    case polling
    case narrating
    case done
    case failed
}

// MARK: - What the app shows the user after we understand their goal
// The backend transcribes (if voice), translates to English, drafts the brief,
// and returns a plain-language readback IN THE USER'S LANGUAGE to confirm.
struct GoalUnderstanding: Codable, Equatable {
    let understoodGoalEnglish: String   // for debugging / the transcript panel
    let readbackUserLang: String        // spoken + shown to the user for confirmation
    let targetNumber: String            // the number we'll call (E.164)
}

// MARK: - Normalized call result (mirrors server/calle/types.ts::CallResult)
enum CallOutcomeStatus: String, Codable {
    case completed, failed, no_answer, voicemail, declined, busy, canceled, expired
}

struct CallResult: Codable, Equatable {
    let status: CallOutcomeStatus
    let rawStatus: String
    let outcome: String                 // English summary
    let outcomeUserLang: String?        // translated narration (Phase 2+)
    let confirmationNumbers: [String]
    let transcript: String              // English, for the collapsible debug panel
}

// MARK: - One place's result in a multi-call comparison (C1)
struct RankedResult: Codable, Equatable, Identifiable {
    let number: String
    let result: CallResult
    var id: String { number }
}

// MARK: - The polled session state from the backend
struct SessionState: Codable, Equatable {
    let sessionId: String
    let phase: SessionPhase
    let mode: String?                   // "single" | "multi"
    let statusLine: String?             // "Calling…", "On hold…", "Comparing the results…"
    let understanding: GoalUnderstanding?
    let result: CallResult?             // single mode
    let ranked: [RankedResult]?         // multi mode, best-first
    let winnerReason: String?           // multi mode, in the user's language
    let errorMessage: String?
}
