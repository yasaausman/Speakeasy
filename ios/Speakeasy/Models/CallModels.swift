import Foundation

// MARK: - Supported user languages (mirrors server/language/languages.ts)
// The phone call is always English; this is the language the USER uses.
struct AppLanguage: Identifiable, Hashable {
    let code: String    // "en" | "es" | "hi" | "ar"
    let name: String    // English name
    let endonym: String // name in its own script
    let rtl: Bool
    var id: String { code }

    static let all: [AppLanguage] = [
        AppLanguage(code: "en", name: "English", endonym: "English", rtl: false),
        AppLanguage(code: "es", name: "Spanish", endonym: "Español", rtl: false),
        AppLanguage(code: "hi", name: "Hindi", endonym: "हिन्दी", rtl: false),
        AppLanguage(code: "ar", name: "Arabic", endonym: "العربية", rtl: true),
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

// MARK: - The polled session state from the backend
struct SessionState: Codable, Equatable {
    let sessionId: String
    let phase: SessionPhase
    let statusLine: String?             // "Calling…", "On hold…", "Speaking with reception…"
    let understanding: GoalUnderstanding?
    let result: CallResult?
    let errorMessage: String?
}
