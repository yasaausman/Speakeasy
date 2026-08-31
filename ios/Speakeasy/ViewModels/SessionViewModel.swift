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
    @Published var errorMessage: String?
    @Published var draftText: String = ""

    /// Demo language pair is locked to Spanish for the hackathon (build-plan §1).
    let userLang = "es"

    private let api: SpeakeasyAPI
    private var sessionId: String?
    private var pollTask: Task<Void, Never>?

    init(api: SpeakeasyAPI = MockSpeakeasyAPI()) {
        self.api = api
    }

    // MARK: Intents

    /// Submit a typed goal. (Voice input rejoins here after STT — Phase M3.)
    func submitGoal(_ text: String) {
        let goal = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !goal.isEmpty else { return }
        run {
            self.phase = .collecting
            let sid = try await self.ensureSession()
            let u = try await self.api.submitGoal(sessionId: sid, text: goal, lang: self.userLang)
            self.understanding = u
            self.phase = .confirming   // WAIT for the user — no call goes out yet.
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
        phase = .idle
        understanding = nil
        statusLine = nil
        result = nil
        errorMessage = nil
        draftText = ""
        sessionId = nil
    }

    // MARK: Machinery

    private func ensureSession() async throws -> String {
        if let sid = sessionId { return sid }
        let sid = try await api.createSession()
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
                        if let r = s.result { self.result = r }
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
                // TODO(Phase M1): match the backend's 5–10s cadence for real runs.
                try? await Task.sleep(nanoseconds: 1_000_000_000)
            }
            // TODO(Phase M3): speak result.outcomeUserLang via SpeechManager here.
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
