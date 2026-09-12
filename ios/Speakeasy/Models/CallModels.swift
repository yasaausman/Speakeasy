import Foundation

// MARK: - Supported user languages (mirrors server/language/languages.ts)
struct AppLanguage: Identifiable, Hashable {
    let code: String
    let name: String      // English name
    let endonym: String   // name in its own script
    let rtl: Bool
    let sttLocale: String
    let ttsLocale: String
    var id: String { code }

    static let all: [AppLanguage] = [
        AppLanguage(code: "en", name: "English", endonym: "English", rtl: false, sttLocale: "en-US", ttsLocale: "en-US"),
        AppLanguage(code: "es", name: "Spanish", endonym: "Español", rtl: false, sttLocale: "es-ES", ttsLocale: "es-ES"),
        AppLanguage(code: "zh", name: "Chinese", endonym: "中文", rtl: false, sttLocale: "zh-CN", ttsLocale: "zh-CN"),
        AppLanguage(code: "hi", name: "Hindi", endonym: "हिन्दी", rtl: false, sttLocale: "hi-IN", ttsLocale: "hi-IN"),
        AppLanguage(code: "ar", name: "Arabic", endonym: "العربية", rtl: true, sttLocale: "ar-SA", ttsLocale: "ar-SA"),
        AppLanguage(code: "vi", name: "Vietnamese", endonym: "Tiếng Việt", rtl: false, sttLocale: "vi-VN", ttsLocale: "vi-VN"),
        AppLanguage(code: "fr", name: "French", endonym: "Français", rtl: false, sttLocale: "fr-FR", ttsLocale: "fr-FR"),
        AppLanguage(code: "pt", name: "Portuguese", endonym: "Português", rtl: false, sttLocale: "pt-BR", ttsLocale: "pt-BR"),
        AppLanguage(code: "ko", name: "Korean", endonym: "한국어", rtl: false, sttLocale: "ko-KR", ttsLocale: "ko-KR"),
        AppLanguage(code: "tl", name: "Tagalog", endonym: "Tagalog", rtl: false, sttLocale: "fil-PH", ttsLocale: "fil-PH"),
        AppLanguage(code: "ru", name: "Russian", endonym: "Русский", rtl: false, sttLocale: "ru-RU", ttsLocale: "ru-RU"),
        AppLanguage(code: "ht", name: "Haitian Creole", endonym: "Kreyòl", rtl: false, sttLocale: "fr-FR", ttsLocale: "fr-FR"),
    ]

    static let spanish = all[1]
    static func byCode(_ code: String) -> AppLanguage { all.first { $0.code == code } ?? all[0] }
}

// MARK: - Orchestrator state machine phase
enum SessionPhase: String, Codable {
    case idle, collecting, confirming, calling, polling, narrating, done, failed
}

// MARK: - Understood goal shown to confirm before any call
struct GoalUnderstanding: Codable, Equatable {
    let understoodGoalEnglish: String
    let readbackUserLang: String
    let targetNumber: String
    /// Present when the backend looked up the number(s) — shown at the confirm gate.
    var businesses: [FoundBusiness]? = nil
}

/// A business the backend found for the goal (name + number + address).
struct FoundBusiness: Codable, Equatable, Identifiable {
    var id: String { phone }
    let name: String
    let phone: String
    var address: String? = nil
}

// MARK: - Normalized call result (mirrors server/calle/types.ts::CallResult)
enum CallOutcomeStatus: String, Codable {
    case completed, failed, no_answer, voicemail, declined, busy, canceled, expired
}

struct ConfidenceInfo: Codable, Equatable {
    let score: Double
    let label: String
}

struct CallResult: Codable, Equatable {
    let status: CallOutcomeStatus
    let rawStatus: String
    let outcome: String
    let outcomeUserLang: String?
    let confirmationNumbers: [String]
    let transcript: String
    let appointmentText: String?
    let provider: String?
    let confidence: ConfidenceInfo?
    let evidence: [String]?
    let gaps: [String]?
    let taskCompleted: Bool?
}

// MARK: - One place's result in a multi-call comparison (C1)
struct RankedResult: Codable, Equatable, Identifiable {
    let number: String
    let result: CallResult
    var id: String { number }
}

// MARK: - An available appointment slot from a "discover" call (C4)
struct SlotOption: Codable, Equatable, Identifiable {
    let id: String
    let label: String
    let labelUserLang: String?
    var display: String { labelUserLang ?? label }
}

// MARK: - The polled session state from the backend
struct SessionState: Codable, Equatable {
    let sessionId: String
    let phase: SessionPhase
    let mode: String?
    let intent: String?              // "book" | "discover"
    let statusLine: String?
    let activity: [String]?          // live transcript lines during the call
    let understanding: GoalUnderstanding?
    let result: CallResult?          // single mode
    let ranked: [RankedResult]?      // multi mode, best-first
    let winnerReason: String?
    let options: [SlotOption]?       // discover mode: pick a slot to book
    let errorMessage: String?
}

// MARK: - Front-loaded booking preferences (sent with the goal)
struct CallPreferences: Codable, Equatable {
    var preferredTimes: String?
    var fallbackTimes: String?
    var avoid: String?
    var budget: String?

    var isEmpty: Bool {
        [preferredTimes, fallbackTimes, avoid, budget]
            .allSatisfy { ($0 ?? "").trimmingCharacters(in: .whitespaces).isEmpty }
    }
}

// MARK: - Saved details (facts vault) the agent can share on calls
struct SavedDetails: Codable, Equatable {
    var fullName = ""
    var callbackNumber = ""
    var insurance = ""
    var dateOfBirth = ""
    var address = ""

    // Front-loaded booking preferences (so the agent decides without a hold).
    var preferredTimes = ""
    var fallbackTimes = ""
    var avoid = ""
    var budget = ""

    /// Non-empty fields as a facts dictionary for the call brief.
    var asFacts: [String: String] {
        var f: [String: String] = [:]
        func put(_ k: String, _ v: String) {
            let t = v.trimmingCharacters(in: .whitespacesAndNewlines)
            if !t.isEmpty { f[k] = t }
        }
        put("name", fullName)
        put("callback number", callbackNumber)
        put("insurance", insurance)
        put("date of birth", dateOfBirth)
        put("address", address)
        return f
    }

    /// Booking preferences for the call brief (nil if none set).
    var asPreferences: CallPreferences? {
        func t(_ v: String) -> String? {
            let s = v.trimmingCharacters(in: .whitespacesAndNewlines)
            return s.isEmpty ? nil : s
        }
        let p = CallPreferences(preferredTimes: t(preferredTimes), fallbackTimes: t(fallbackTimes),
                                avoid: t(avoid), budget: t(budget))
        return p.isEmpty ? nil : p
    }

    var filledCount: Int { asFacts.count }
}

// MARK: - A saved past call (call history)
struct StoredCall: Codable, Identifiable, Equatable {
    let id: String
    let date: Date
    let languageCode: String
    let goal: String
    let outcome: String
    let confirmations: [String]
    let transcript: String
    let isComparison: Bool
}
