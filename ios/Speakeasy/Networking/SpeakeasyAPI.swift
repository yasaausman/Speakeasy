import Foundation

/// The backend contract the app talks to. The CALL-E logic (OAuth, MCP, polling)
/// lives on the Node server behind these endpoints — never in the app.
///
/// Two implementations:
///   - MockSpeakeasyAPI: canned data, no network. Lets the app run in the
///     simulator today, before the backend or Xcode auth exists.
///   - LiveSpeakeasyAPI: real HTTP calls to the Node backend (Phase M1+).
protocol SpeakeasyAPI {
    func createSession() async throws -> String
    func submitGoal(sessionId: String, text: String, lang: String) async throws -> GoalUnderstanding
    func confirm(sessionId: String) async throws
    func fetchSession(sessionId: String) async throws -> SessionState
}

// MARK: - Mock (runs standalone in the simulator; zero backend, zero calls)
actor MockSpeakeasyAPI: SpeakeasyAPI {
    private var phase: SessionPhase = .idle
    private var understanding: GoalUnderstanding?
    private var pollTicks = 0

    func createSession() async throws -> String {
        phase = .collecting
        return "mock-session-1"
    }

    func submitGoal(sessionId: String, text: String, lang: String) async throws -> GoalUnderstanding {
        try await Task.sleep(nanoseconds: 500_000_000)
        let u = GoalUnderstanding(
            understoodGoalEnglish: "Test call: greet the person and confirm they can hear the call clearly.",
            readbackUserLang: lang.hasPrefix("es")
                ? "Quieres una llamada de prueba: saludar y confirmar que se escucha bien. ¿Correcto?"
                : "You want a test call: greet the person and confirm they can hear clearly. Correct?",
            targetNumber: "+15555550123"
        )
        understanding = u
        phase = .confirming
        return u
    }

    func confirm(sessionId: String) async throws {
        phase = .calling
        pollTicks = 0
    }

    func fetchSession(sessionId: String) async throws -> SessionState {
        // Walk through a realistic sequence so the UI can be exercised end to end.
        switch phase {
        case .calling:
            phase = .polling
            return state(status: "Calling…")
        case .polling:
            pollTicks += 1
            if pollTicks < 3 {
                let lines = ["On hold…", "Speaking with reception…", "Wrapping up…"]
                return state(status: lines[min(pollTicks - 1, lines.count - 1)])
            }
            phase = .done
            return state(status: nil, result: mockResult)
        default:
            return state(status: nil, result: phase == .done ? mockResult : nil)
        }
    }

    private func state(status: String?, result: CallResult? = nil) -> SessionState {
        SessionState(
            sessionId: "mock-session-1",
            phase: phase,
            statusLine: status,
            understanding: understanding,
            result: result,
            errorMessage: nil
        )
    }

    private var mockResult: CallResult {
        CallResult(
            status: .completed,
            rawStatus: "COMPLETED",
            outcome: "The call connected and the person confirmed they could hear clearly.",
            outcomeUserLang: "La llamada se conectó y la persona confirmó que se escuchaba bien.",
            confirmationNumbers: [],
            transcript: "AGENT: Hi, this is an automated test call. Can you hear me clearly?\nREP: Yes, loud and clear.\nAGENT: Great, thank you. Goodbye."
        )
    }
}

// MARK: - Live (Phase M1+: talks to the Node backend)
struct LiveSpeakeasyAPI: SpeakeasyAPI {
    /// Simulator reaches the Mac's localhost directly. Override for a device/tunnel.
    var baseURL: URL = URL(string: "http://localhost:3000")!

    func createSession() async throws -> String {
        struct Resp: Codable { let sessionId: String }
        let r: Resp = try await post("/api/sessions", body: EmptyBody())
        return r.sessionId
    }

    func submitGoal(sessionId: String, text: String, lang: String) async throws -> GoalUnderstanding {
        struct Body: Codable { let text: String; let lang: String }
        return try await post("/api/sessions/\(sessionId)/goal", body: Body(text: text, lang: lang))
    }

    func confirm(sessionId: String) async throws {
        let _: EmptyBody = try await post("/api/sessions/\(sessionId)/confirm", body: EmptyBody())
    }

    func fetchSession(sessionId: String) async throws -> SessionState {
        try await get("/api/sessions/\(sessionId)")
    }

    // MARK: HTTP helpers
    private struct EmptyBody: Codable {}

    private func get<T: Decodable>(_ path: String) async throws -> T {
        let (data, resp) = try await URLSession.shared.data(from: baseURL.appendingPathComponent(path))
        try Self.check(resp)
        return try JSONDecoder().decode(T.self, from: data)
    }

    private func post<T: Decodable, B: Encodable>(_ path: String, body: B) async throws -> T {
        var req = URLRequest(url: baseURL.appendingPathComponent(path))
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try JSONEncoder().encode(body)
        let (data, resp) = try await URLSession.shared.data(for: req)
        try Self.check(resp)
        if data.isEmpty, let empty = EmptyBody() as? T { return empty }
        return try JSONDecoder().decode(T.self, from: data)
    }

    private static func check(_ resp: URLResponse) throws {
        guard let http = resp as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw URLError(.badServerResponse)
        }
    }
}
