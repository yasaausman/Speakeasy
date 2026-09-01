import Foundation
import SwiftUI

/// Drives the app's copy of the state machine and talks to the backend via the
/// SpeakeasyAPI protocol. Swap MockSpeakeasyAPI ⇄ LiveSpeakeasyAPI with no UI change.
@MainActor
final class SessionViewModel: ObservableObject {
    @Published var phase: SessionPhase = .idle
    @Published var understanding: GoalUnderstanding?
    @Published var statusLine: String?
    @Published var result: CallResult?
    @Published var ranked: [RankedResult]?      // multi-call comparison (C1)
    @Published var winnerReason: String?
    @Published var activity: [String] = []      // live call transcript feed
    @Published var errorMessage: String?
    @Published var draftText: String = ""

    /// Multi-call comparison mode. Sends a preset set of demo numbers.
    @Published var compareMode: Bool = false
    let compareNumbers = ["+13120001111", "+13120002222", "+13120003333"]

    /// Specific number to call (from the confirm screen / Contacts). nil = default.
    @Published var targetNumber: String?
    private(set) var lastGoalText = ""

    /// User-selected language (English/Spanish/Hindi/Arabic). The call stays English.
    @Published var language: AppLanguage = .spanish
    let languages = AppLanguage.all

    /// Native on-device voice (STT in, TTS out).
    let speech = SpeechManager()

    private let api: SpeakeasyAPI
    private let store: AppStore
    private var sessionId: String?
    private var pollTask: Task<Void, Never>?

    var canAcceptInput: Bool { phase == .idle || phase == .collecting || phase == .failed }

    /// Defaults to the live Node backend. Pass MockSpeakeasyAPI() to run offline.
    init(store: AppStore, api: SpeakeasyAPI = LiveSpeakeasyAPI()) {
        self.store = store
        self.api = api
    }

    // MARK: Voice input (press-to-talk)

    /// Begin capturing speech in the user's language. Requests permission first.
    func startVoiceInput() {
        guard canAcceptInput, !speech.isListening else { return }
        speech.stopSpeaking()
        Task {
            guard await self.speech.requestPermissions() else {
                self.errorMessage = self.speech.lastError
                return
            }
            self.speech.startListening(localeId: self.language.sttLocale)
        }
    }

    /// Stop capturing and submit whatever was transcribed.
    func endVoiceInput() {
        guard speech.isListening else { return }
        let text = speech.stopListening()
        draftText = text
        submitGoal(text)
    }

    // MARK: Intents

    /// Submit a goal (typed, or transcribed from voice). Both rejoin here.
    func submitGoal(_ text: String) {
        let goal = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !goal.isEmpty else { return }
        lastGoalText = goal
        let numbers: [String]? = compareMode ? compareNumbers : (targetNumber.map { [$0] })
        let facts = compareMode ? nil : store.details.asFacts   // share saved details on single calls
        run {
            self.phase = .collecting
            self.activity = []
            self.result = nil; self.ranked = nil; self.winnerReason = nil
            let sid = try await self.ensureSession()
            let u = try await self.api.submitGoal(sessionId: sid, text: goal, lang: self.language.code, numbers: numbers, facts: facts?.isEmpty == true ? nil : facts)
            self.understanding = u
            self.phase = .confirming   // WAIT for the user — no call goes out yet.
            self.narrate(u.readbackUserLang)   // read the goal back (unless text-forward)
        }
    }

    /// Refine the request before calling (editable brief) — re-runs with the note.
    func amend(_ note: String) {
        let n = note.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !n.isEmpty, !lastGoalText.isEmpty else { return }
        submitGoal("\(lastGoalText). Also: \(n)")
    }

    /// Re-run the same request (after no-answer, a gap, or a failure).
    func retry() {
        let goal = lastGoalText
        let number = targetNumber
        guard !goal.isEmpty else { return }
        reset()
        targetNumber = number
        submitGoal(goal)
    }

    /// After a comparison, call the winning place to actually book it.
    func bookWinner(number: String) {
        let goal = lastGoalText.isEmpty ? "Book an appointment" : "Book an appointment. \(lastGoalText)"
        reset()
        compareMode = false
        targetNumber = number
        submitGoal(goal)
    }

    /// Speak only when not in text-forward (Deaf/HoH) mode.
    private func narrate(_ text: String) {
        guard !store.textForward else { return }
        speech.speak(text, localeId: language.ttsLocale)
    }

    /// Replay the narration. `force` (an explicit Play tap) speaks even in text-forward mode.
    func speakResult(force: Bool = true) {
        guard force || !store.textForward else { return }
        if let reason = winnerReason {
            speech.speak(reason, localeId: language.ttsLocale)
            return
        }
        guard let r = result else { return }
        speech.speak(r.outcomeUserLang ?? r.outcome, localeId: language.ttsLocale)
        for number in r.confirmationNumbers {
            speech.speakDigits(number, localeId: language.ttsLocale)
        }
    }

    /// The confirm gate. This is the ONLY path to a paid call. Never auto-advance.
    func confirmAndCall() {
        guard phase == .confirming, let sid = sessionId else { return }
        run {
            try await self.api.confirm(sessionId: sid)
            self.phase = .calling
            self.startPolling(sessionId: sid)
        }
    }

    /// User rejected the readback — go back and edit.
    func reject() {
        phase = .collecting
        understanding = nil
        statusLine = nil
    }

    func reset() {
        pollTask?.cancel()
        speech.stopSpeaking()
        phase = .idle
        understanding = nil
        statusLine = nil
        activity = []
        result = nil
        ranked = nil
        winnerReason = nil
        errorMessage = nil
        draftText = ""
        targetNumber = nil
        sessionId = nil
    }

    // MARK: Machinery

    private func ensureSession() async throws -> String {
        if let sid = sessionId { return sid }
        let sid = try await api.createSession(lang: language.code)
        sessionId = sid
        return sid
    }

    private func startPolling(sessionId sid: String) {
        pollTask?.cancel()
        pollTask = Task { [weak self] in
            guard let self else { return }
            while !Task.isCancelled {
                do {
                    let s = try await self.api.fetchSession(sessionId: sid)
                    await MainActor.run {
                        self.phase = s.phase
                        self.statusLine = s.statusLine
                        if let a = s.activity { self.activity = a }
                        if let r = s.result { self.result = r }
                        if let rk = s.ranked { self.ranked = rk }
                        if let w = s.winnerReason { self.winnerReason = w }
                        if let e = s.errorMessage { self.errorMessage = e }
                    }
                    if s.phase == .done || s.phase == .failed { break }
                } catch {
                    await MainActor.run {
                        self.errorMessage = error.localizedDescription
                        self.phase = .failed
                    }
                    break
                }
                try? await Task.sleep(nanoseconds: 1_000_000_000)
            }
            // Narrate the outcome aloud and save to history.
            await MainActor.run {
                if self.phase == .done {
                    self.speakResult(force: false)   // auto-narrate (respects text-forward)
                    self.saveToHistory()
                }
            }
        }
    }

    private func saveToHistory() {
        let goalText = understanding?.understoodGoalEnglish ?? draftText
        if let ranked, let winner = ranked.first {
            store.addCall(StoredCall(
                id: UUID().uuidString, date: Date(), languageCode: language.code,
                goal: goalText,
                outcome: winnerReason ?? winner.result.outcome,
                confirmations: winner.result.confirmationNumbers,
                transcript: "", isComparison: true))
        } else if let r = result {
            store.addCall(StoredCall(
                id: UUID().uuidString, date: Date(), languageCode: language.code,
                goal: goalText,
                outcome: r.outcomeUserLang ?? r.outcome,
                confirmations: r.confirmationNumbers,
                transcript: r.transcript, isComparison: false))
        }
    }

    private func run(_ work: @escaping () async throws -> Void) {
        errorMessage = nil
        Task {
            do { try await work() }
            catch {
                self.errorMessage = error.localizedDescription
                self.phase = .failed
            }
        }
    }
}
