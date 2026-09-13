import Foundation

/// The backend contract the app talks to. The CALL-E logic (OAuth, MCP, polling)
/// lives on the Node server behind these endpoints — never in the app.
///
/// Two implementations:
///   - MockKindlyCallAPI: canned data, no network. Lets the app run in the
///     simulator today, before the backend or Xcode auth exists.
///   - LiveKindlyCallAPI: real HTTP calls to the Node backend (Phase M1+).
/// Everything sent with a goal (grows over time — bundled to keep call sites clean).
struct GoalRequest: Encodable {
    let text: String
    let lang: String
    var numbers: [String]? = nil
    var facts: [String: String]? = nil
    var preferences: CallPreferences? = nil
    var availability: String? = nil
    var location: String? = nil     // "City, ST" for near-me business lookups
}

protocol KindlyCallAPI {
    func createSession(lang: String) async throws -> String
    func submitGoal(sessionId: String, _ req: GoalRequest) async throws -> GoalUnderstanding
    func confirm(sessionId: String) async throws
    func checkStatus(sessionId: String) async throws
    func fetchSession(sessionId: String) async throws -> SessionState
}

// MARK: - Mock (runs standalone in the simulator; zero backend, zero calls)
actor MockKindlyCallAPI: KindlyCallAPI {
    private var phase: SessionPhase = .idle
    private var understanding: GoalUnderstanding?
    private var pollTicks = 0

    func createSession(lang: String) async throws -> String {
        phase = .collecting
        return "mock-session-1"
    }

    func submitGoal(sessionId: String, _ req: GoalRequest) async throws -> GoalUnderstanding {
        try await Task.sleep(nanoseconds: 500_000_000)
        let lang = req.lang
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

    func checkStatus(sessionId: String) async throws {}

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
            mode: "single",
            intent: "book",
            statusLine: status,
            activity: nil,
            understanding: understanding,
            result: result,
            ranked: nil,
            winnerReason: nil,
            options: nil,
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
            transcript: "AGENT: Hi, this is an automated test call. Can you hear me clearly?\nREP: Yes, loud and clear.\nAGENT: Great, thank you. Goodbye.",
            appointmentText: nil,
            provider: nil,
            confidence: nil,
            evidence: nil,
            gaps: nil,
            taskCompleted: true
        )
    }
}

// MARK: - Live (Phase M1+: talks to the Node backend)
struct LiveKindlyCallAPI: KindlyCallAPI {
    /// Where the Node backend lives. Resolved at runtime so it never needs a Swift
    /// edit: set `KINDLYCALL_BACKEND_URL` (scheme env var) or the `KindlyCallBackendURL`
    /// Info.plist key to override; otherwise fall back to the per-platform default.
    var baseURL: URL = LiveKindlyCallAPI.resolveBaseURL()

    static func resolveBaseURL() -> URL {
        if let s = ProcessInfo.processInfo.environment["KINDLYCALL_BACKEND_URL"],
           let u = URL(string: s.trimmingCharacters(in: .whitespaces)), !s.isEmpty { return u }
        if let s = Bundle.main.object(forInfoDictionaryKey: "KindlyCallBackendURL") as? String,
           !s.trimmingCharacters(in: .whitespaces).isEmpty,
           let u = URL(string: s.trimmingCharacters(in: .whitespaces)) { return u }
#if targetEnvironment(simulator)
        // The simulator shares the Mac's network, so localhost is the backend.
        return URL(string: "http://localhost:3000")!
#else
        // On a physical device "localhost" is the phone itself, so point at the Mac's
        // LAN IP (same Wi-Fi). Prefer overriding via Info.plist / env over editing this.
        return URL(string: "http://10.213.203.101:3000")!
#endif
    }

    func createSession(lang: String) async throws -> String {
        struct Body: Codable { let lang: String }
        struct Resp: Codable { let sessionId: String }
        let r: Resp = try await post("/api/sessions", body: Body(lang: lang))
        return r.sessionId
    }

    func submitGoal(sessionId: String, _ req: GoalRequest) async throws -> GoalUnderstanding {
        return try await post("/api/sessions/\(sessionId)/goal", body: req)
    }

    func confirm(sessionId: String) async throws {
        let _: EmptyBody = try await post("/api/sessions/\(sessionId)/confirm", body: EmptyBody())
    }

    func checkStatus(sessionId: String) async throws {
        let _: EmptyBody = try await post("/api/sessions/\(sessionId)/check", body: EmptyBody())
    }

    func fetchSession(sessionId: String) async throws -> SessionState {
        try await get("/api/sessions/\(sessionId)")
    }

    // MARK: HTTP helpers
    private struct EmptyBody: Codable {}

    private func get<T: Decodable>(_ path: String) async throws -> T {
        let (data, resp) = try await URLSession.shared.data(from: baseURL.appendingPathComponent(path))
        try Self.check(data, resp)
        return try JSONDecoder().decode(T.self, from: data)
    }

    private func post<T: Decodable, B: Encodable>(_ path: String, body: B) async throws -> T {
        var req = URLRequest(url: baseURL.appendingPathComponent(path))
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try JSONEncoder().encode(body)
        let (data, resp) = try await URLSession.shared.data(for: req)
        try Self.check(data, resp)
        if data.isEmpty, let empty = EmptyBody() as? T { return empty }
        return try JSONDecoder().decode(T.self, from: data)
    }

    /// A backend error whose message we can show the user verbatim.
    struct APIError: LocalizedError {
        let message: String
        var errorDescription: String? { message }
    }
    private struct ServerError: Decodable { let error: String }

    /// Validate the response; on a non-2xx, surface the backend's `{ "error": … }`
    /// message (so the user sees "I couldn't find a phone number…" instead of a
    /// raw URLError).
    private static func check(_ data: Data, _ resp: URLResponse) throws {
        guard let http = resp as? HTTPURLResponse else {
            throw APIError(message: "No response from the server.")
        }
        guard (200..<300).contains(http.statusCode) else {
            let serverMessage = (try? JSONDecoder().decode(ServerError.self, from: data))?.error
            throw APIError(message: serverMessage ?? "The server returned an error (\(http.statusCode)).")
        }
    }
}
