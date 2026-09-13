#if DEBUG
import Foundation

/// Deterministic UI rehearsal, explicitly labeled in the app. No network or CALL-E.
actor DemoSpeakeasyAPI: SpeakeasyAPI {
    private let scenario: String
    private var phase: SessionPhase = .collecting
    private var lang = "hi"
    private var understanding: GoalUnderstanding?
    private var ticks = 0
    private var answered = false
    init(scenario: String) { self.scenario = scenario }

    func createSession(lang: String) async throws -> String { self.lang = lang; return "demo-session" }
    func submitGoal(sessionId: String, _ req: GoalRequest) async throws -> GoalUnderstanding {
        lang = req.lang
        answered = !(req.facts?["name"] ?? "").isEmpty
        let english = "Book a dental checkup on Tuesday afternoon. If 3pm is unavailable, 3:30pm is acceptable."
        let readback = lang == "hi"
            ? "आप मंगलवार दोपहर दाँतों की जाँच का अपॉइंटमेंट चाहते हैं। अगर 3 बजे समय नहीं मिला, तो 3:30 बजे ठीक है। क्या मैं डेमो क्लिनिक को कॉल करूँ?"
            : "You want a dental checkup Tuesday afternoon. If 3pm is unavailable, 3:30pm works. May I call the demo clinic?"
        let u = GoalUnderstanding(understoodGoalEnglish: english, readbackUserLang: readback, targetNumber: "+13125550123",
            businesses: [FoundBusiness(name: "Demo Dental · fictional", phone: "+13125550123", address: "100 Example Street · fictional")])
        understanding = u; phase = .confirming; ticks = 0
        try await Task.sleep(nanoseconds: 250_000_000)
        return u
    }
    func confirm(sessionId: String) async throws { phase = .calling }
    func checkStatus(sessionId: String) async throws { phase = .done }
    func fetchSession(sessionId: String) async throws -> SessionState {
        ticks += 1
        if phase == .calling || phase == .polling { phase = ticks >= 3 ? (scenario == "pending" ? .pending : .done) : .polling }
        let needsName = scenario == "gap" && !answered
        let pending = phase == .pending
        let english = pending ? "The outcome is still unknown. Check the existing call."
            : needsName ? "They need your name before they can book. No appointment has been booked."
            : "Booked Tuesday at 3:30pm at Demo Dental. The 3pm slot was unavailable, so your approved fallback was used. Confirmation 4471."
        let hindi = pending ? "कॉल का नतीजा अभी पता नहीं है। मौजूदा कॉल की स्थिति देखें।"
            : needsName ? "बुकिंग के लिए उन्हें आपका नाम चाहिए। अभी कोई अपॉइंटमेंट बुक नहीं हुआ है।"
            : "डेमो डेंटल में मंगलवार दोपहर 3:30 बजे आपका अपॉइंटमेंट पक्का हो गया। 3 बजे समय नहीं था, इसलिए आपकी पसंद का दूसरा समय लिया गया। पुष्टि नंबर 4471 है।"
        let script = ["Bot: Hi, I'm an AI assistant calling on behalf of a user. Can you book a dental checkup Tuesday at 3pm?",
            "Rep: 3pm is taken. We have 3:30pm.", "Bot: 3:30pm is an approved alternative. Please book it.", "Rep: Confirmed. Reference 4471."]
        let result = CallResult(status: pending ? .pending : .completed, rawStatus: pending ? "IN_PROGRESS" : "COMPLETED",
            outcome: english, outcomeUserLang: lang == "hi" ? hindi : english,
            confirmationNumbers: needsName || pending ? [] : ["4471"],
            transcript: needsName ? "Rep: What is the patient's name?\nBot: I will check and call back." : pending ? "Bot: Hello." : script.joined(separator: "\n"),
            appointmentText: needsName || pending ? nil : "Tuesday 3:30pm", provider: "Demo Dental",
            confidence: nil, evidence: needsName || pending ? nil : ["The receptionist confirmed the appointment and reference."],
            gaps: needsName ? ["name"] : nil, taskCompleted: pending ? nil : !needsName,
            appointmentUserLang: lang == "hi" ? "मंगलवार · दोपहर 3:30 बजे" : "Tuesday 3:30pm",
            runId: "demo-run", evidenceUserLang: needsName || pending ? nil : [lang == "hi" ? "रिसेप्शनिस्ट ने समय और पुष्टि नंबर बताया।" : "Receptionist confirmed the time and reference."],
            gapsUserLang: needsName ? [lang == "hi" ? "नाम" : "name"] : nil)
        return SessionState(sessionId: "demo-session", phase: phase, mode: "single", intent: "book", statusLine: nil,
            activity: phase == .polling ? Array(script.prefix(ticks)) : nil, understanding: understanding,
            result: phase == .done || phase == .pending ? result : nil, ranked: nil, winnerReason: nil, options: nil, errorMessage: nil)
    }
}
#endif
