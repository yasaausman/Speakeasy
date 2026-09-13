import Foundation
import SwiftUI
import Combine
import NaturalLanguage

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
    @Published var options: [SlotOption]?       // speculative discover: pick a slot (C4)
    @Published var activity: [String] = []      // live call transcript feed
    @Published var errorMessage: String?
    @Published var draftText: String = ""

    /// True from the moment a goal is submitted until the readback arrives (or it
    /// fails). Drives the "Understanding…" state and blocks a second submit — which
    /// was double-sending the goal and queuing two spoken readbacks.
    @Published var isSubmitting = false

    /// The latest thing the assistant "said" to the user, in their own language —
    /// shown as text on the home screen and spoken aloud (see `announce`). Every
    /// agent answer flows through here so it's available in both text and audio.
    @Published var assistantMessage: String?

    /// Specific number to call (from the confirm screen / Contacts). nil → the
    /// backend infers the mode and looks up the number(s) from the goal + location.
    @Published var targetNumber: String?
    private var selectedBusiness: FoundBusiness?
    private(set) var lastGoalText = ""

    /// User-selected language (English/Spanish/Hindi/Arabic). The call stays English.
    /// Persisted so a manual pick — or the last auto-detected language — survives
    /// relaunch, instead of snapping back to the device default every launch.
    @Published var language: AppLanguage = .spanish {
        didSet { UserDefaults.standard.set(language.code, forKey: "speakeasy.language") }
    }
    let languages = AppLanguage.all

    /// Native on-device voice (STT in, TTS out).
    let speech = SpeechManager()

    /// Coarse "near me" location for business lookups (city + region only).
    let location = LocationManager()

    private let api: SpeakeasyAPI
    let store: AppStore
    private var sessionId: String?
    private var pollTask: Task<Void, Never>?
    private var cancellables = Set<AnyCancellable>()

    var canAcceptInput: Bool { phase == .idle || phase == .collecting || phase == .failed }

    /// Defaults to the live Node backend. Pass MockSpeakeasyAPI() to run offline.
    init(store: AppStore, api: SpeakeasyAPI = LiveSpeakeasyAPI()) {
        self.store = store
        self.api = api
        // Restore the last-used language if the user has ever picked or spoken one;
        // otherwise start in the device's language. (didSet doesn't fire in init.)
        if let saved = UserDefaults.standard.string(forKey: "speakeasy.language") {
            self.language = AppLanguage.byCode(saved)
        } else {
            self.language = AppLanguage.deviceDefault
        }

        // The speech layer is a nested ObservableObject; SwiftUI won't see its
        // changes through `vm` on its own. Forward them so the orb and caption
        // update live, and lift any speech error into the on-screen banner.
        speech.objectWillChange
            .sink { [weak self] in self?.objectWillChange.send() }
            .store(in: &cancellables)
        speech.$lastError
            .compactMap { $0 }
            .receive(on: RunLoop.main)
            .sink { [weak self] message in self?.errorMessage = F.t(message, self?.language.code ?? "en") }
            .store(in: &cancellables)

        // Location is requested in-context — on the first goal submit (see launch),
        // never on cold launch. Prompting before the user has done anything reads as
        // invasive and gets denied more often (Apple HIG: request in context).
    }

    // MARK: Voice input (press-to-talk)

    /// True between finger-down and finger-up on the mic — used so the async
    /// permission request can't strand us if the user releases early, and so a
    /// gesture that fires onChanged repeatedly only starts listening once.
    private var wantsListening = false

    /// Begin capturing speech in the user's language. Requests permission first.
    func startVoiceInput() {
        guard canAcceptInput, !isSubmitting, !speech.isListening, !wantsListening else { return }
        wantsListening = true
        errorMessage = nil   // clear any stale notice — this is a fresh attempt
        speech.stopSpeaking()
        Task {
            let granted = await self.speech.requestPermissions()
            guard self.wantsListening else { return }   // released before permission resolved
            if granted {
                self.speech.startListening(localeId: self.language.sttLocale)
                // If the mic/engine couldn't start, `isListening` stays false and
                // `speech.lastError` (surfaced to the banner) explains why.
                if !self.speech.isListening { self.wantsListening = false }
            } else {
                self.wantsListening = false
            }
        }
    }

    /// Stop capturing and submit whatever was transcribed.
    func endVoiceInput() {
        wantsListening = false
        guard speech.isListening else { return }
        let text = speech.stopListening()
        autoDetectLanguage(from: text)   // respond in the language they actually spoke
        draftText = text
        submitGoal(text)
    }

    /// Best-effort language auto-detect from the transcript, so the readback,
    /// translation, and voice match what the user spoke — no manual picker needed.
    /// (Transcription itself still uses a locale, so the biggest gains are on the
    /// user's device language and on the turn after a switch.)
    private func autoDetectLanguage(from text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count >= 4 else { return }   // too short to detect confidently
        let recognizer = NLLanguageRecognizer()
        recognizer.processString(trimmed)
        let hypotheses = recognizer.languageHypotheses(withMaximum: 1)
        guard let lang = recognizer.dominantLanguage, (hypotheses[lang] ?? 0) >= 0.80 else { return }
        let base = String(lang.rawValue.split(separator: "-").first ?? "")   // "zh-Hans" → "zh"
        if let detected = AppLanguage.supported(base), detected.code != language.code {
            language = detected
        }
    }

    // MARK: Intents

    /// Submit a goal (typed, or transcribed from voice). Both rejoin here. The
    /// backend infers the mode (book / compare / discover) and looks up the
    /// number(s) — unless the user pinned a specific number from Contacts.
    func submitGoal(_ text: String) {
        let goal = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !goal.isEmpty else { return }
        launch(goal: goal)
    }

    /// Compose the full request (facts + preferences + calendar availability + a
    /// coarse location for lookups) and run.
    private func launch(goal: String) {
        guard !isSubmitting else { return }   // ignore a second Send while one is in flight
        isSubmitting = true
        lastGoalText = goal   // single source of truth — retry/amend build on this
        let numbers: [String]? = targetNumber.map { [$0] }   // only when pinned from Contacts
        // In-context location: only when we'll actually look a place up ("near me"),
        // i.e. the user hasn't pinned a specific number. Prompts at most once.
        if numbers == nil { location.requestIfNeeded() }
        let facts = store.details.asFacts
        let prefs = store.details.asPreferences      // front-loaded preferences
        let wantAvailability = store.useCalendarAvailability
        run {
            self.phase = .collecting
            self.activity = []
            self.result = nil; self.ranked = nil; self.winnerReason = nil; self.options = nil
            let availability = wantAvailability ? await AvailabilityService.summary() : nil
            let place = numbers == nil ? await self.location.resolvePlace() : nil
            let sid = try await self.ensureSession()
            let req = GoalRequest(
                text: goal, lang: self.language.code,
                numbers: numbers,
                facts: facts.isEmpty ? nil : facts,
                preferences: prefs, availability: availability, location: place)
            var u = try await self.api.submitGoal(sessionId: sid, req)
            if u.businesses == nil, let business = self.selectedBusiness, business.phone == self.targetNumber {
                u.businesses = [business]
            }
            self.understanding = u
            self.phase = .confirming   // WAIT for the user — no call goes out yet.
            self.isSubmitting = false
            self.announce(u.readbackUserLang)   // show + read the goal back (unless text-forward)
        }
    }

    /// Discover result: user picked an available slot → place call 2 to book it.
    func pickSlot(_ option: SlotOption) {
        let base = understanding?.understoodGoalEnglish ?? lastGoalText
        let goal = "\(base). Book the \(option.label) appointment specifically."
        let business = understanding?.businesses?.first
        let number = targetNumber ?? business?.phone ?? understanding?.targetNumber
        reset()
        selectedBusiness = business
        targetNumber = number
        launch(goal: goal)
    }

    /// Refine the request before calling (editable brief) — re-runs with the note.
    func amend(_ note: String) {
        let n = note.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !n.isEmpty, !lastGoalText.isEmpty else { return }
        submitGoal("\(lastGoalText). Also: \(n)")
    }

    /// Defer + call back (#5): the rep needed info we didn't have. Save the answer
    /// to the vault (so it's shared next time) and call back.
    func answerGap(_ label: String, value: String) {
        let v = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !v.isEmpty else { return }
        let l = label.lowercased()
        if l.contains("insurance") { store.details.insurance = v }
        else if l.contains("birth") || l.contains("dob") { store.details.dateOfBirth = v }
        else if l.contains("address") { store.details.address = v }
        else if l.contains("name") { store.details.fullName = v }
        else if l.contains("callback") || l.contains("phone") || l.contains("number") { store.details.callbackNumber = v }
        else if !lastGoalText.isEmpty { lastGoalText = "\(lastGoalText). \(label): \(v)" }
        retry()
    }

    /// Re-run the same request (after no-answer, a gap, or a failure).
    func retry() {
        guard phase != .pending else { return }
        let goal = lastGoalText
        let number = targetNumber ?? understanding?.businesses?.first?.phone ?? understanding?.targetNumber
        guard !goal.isEmpty else { return }
        let business = understanding?.businesses?.first
        reset()
        selectedBusiness = business
        targetNumber = number
        submitGoal(goal)
    }

    /// After a comparison, call the winning place to actually book it.
    func bookWinner(number: String) {
        let business = ranked?.first(where: { $0.number == number })?.business
        let goal = lastGoalText.isEmpty ? "Book an appointment" : "Book an appointment. \(lastGoalText)"
        reset()
        selectedBusiness = business
        targetNumber = number
        submitGoal(goal)
    }

    /// Surface an agent answer to the user in BOTH channels: on-screen text (in
    /// their language) and spoken audio. Text always shows; audio respects
    /// text-forward (Deaf/HoH) mode.
    private func announce(_ text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        assistantMessage = trimmed
        narrate(trimmed)
    }

    /// Toggle the assistant's latest message aloud — tap to play, tap again to stop.
    func replayAssistant() {
        if speech.isSpeaking { speech.stopSpeaking(); return }
        guard let msg = assistantMessage else { return }
        speech.speak(msg, localeId: language.ttsLocale)
    }

    /// Toggle the result narration — tap to play, tap again to stop.
    func toggleNarration() {
        if speech.isSpeaking { speech.stopSpeaking() } else { speakResult() }
    }

    /// Speak only when not in text-forward (Deaf/HoH) mode.
    private func narrate(_ text: String) {
        guard !store.textForward else { return }
        speech.stopSpeaking()   // never let a readback stack on top of earlier speech
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
        speech.stopSpeaking()
        phase = .calling
        Task {
            do {
                try await self.api.confirm(sessionId: sid)
                self.startPolling(sessionId: sid)
            } catch {
                self.errorMessage = F.t("The connection was interrupted. Check the existing call before trying again.", self.language.code)
                self.phase = .pending
            }
        }
    }

    /// Resume observing the existing session. This never starts a new phone call.
    func checkStatus() {
        guard let sid = sessionId else { return }
        errorMessage = nil
        Task {
            do {
                let s = try await api.fetchSession(sessionId: sid)
                if s.phase == .pending { try await api.checkStatus(sessionId: sid) }
                phase = .polling
                startPolling(sessionId: sid)
            } catch { errorMessage = F.t(error.localizedDescription, language.code); phase = .pending }
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
        assistantMessage = nil
        isSubmitting = false
        phase = .idle
        understanding = nil
        statusLine = nil
        activity = []
        result = nil
        ranked = nil
        winnerReason = nil
        options = nil
        errorMessage = nil
        draftText = ""
        targetNumber = nil
        selectedBusiness = nil
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
                        if let o = s.options { self.options = o }
                        if let e = s.errorMessage { self.errorMessage = e }
                    }
                    if s.phase == .done || s.phase == .failed || s.phase == .pending { break }
                } catch {
                    await MainActor.run {
                        self.errorMessage = F.t(error.localizedDescription, self.language.code)
                        self.phase = .pending
                    }
                    break
                }
                try? await Task.sleep(nanoseconds: 1_000_000_000)
            }
            // Surface the outcome as text (home screen) + audio, and save to history.
            await MainActor.run {
                if self.phase == .done {
                    self.assistantMessage = self.winnerReason
                        ?? self.result?.outcomeUserLang ?? self.result?.outcome
                    self.speakResult(force: false)   // auto-narrate (respects text-forward)
                    self.saveToHistory()
                }
            }
        }
    }

    private func saveToHistory() {
        // Discovery calls are an intermediate step — don't log them as a booking.
        if let options, !options.isEmpty { return }
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
                self.isSubmitting = false
                self.errorMessage = F.t(error.localizedDescription, self.language.code)
                self.phase = .failed
            }
        }
    }
}
