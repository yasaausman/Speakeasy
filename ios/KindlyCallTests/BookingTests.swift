import XCTest
@testable import KindlyCall

final class BookingTests: XCTestCase {
    func testRunCompletionDoesNotMeanTaskCompletion() throws {
        func result(_ task: String, gaps: String = "[]", status: String = "completed") throws -> CallResult {
            let data = Data("""
            {"status":"\(status)","rawStatus":"COMPLETED","outcome":"Ended","confirmationNumbers":[],"transcript":"","taskCompleted":\(task),"gaps":\(gaps)}
            """.utf8)
            return try JSONDecoder().decode(CallResult.self, from: data)
        }
        XCTAssertFalse(try result("false").isSuccessful)
        XCTAssertFalse(try result("null").isSuccessful)
        XCTAssertFalse(try result("true", gaps: "[\"name\"]").isSuccessful)
        XCTAssertTrue(try result("true").isSuccessful)
        XCTAssertFalse(try result("null", status: "pending").canRetry)
        XCTAssertFalse(try result("true").canRetry)
    }

    func testCalendarNeverGuessesRelativeOrMissingDates() {
        for text in ["Tuesday 3:30pm", "next Monday", "tomorrow", "Sept 15", "", "2026-09-15T15:30:00"] {
            XCTAssertNil(CalendarService.parseDate(text), text)
        }
        XCTAssertNotNil(CalendarService.parseDate("2026-09-15T15:30:00-05:00"))
        XCTAssertNotNil(CalendarService.parseDate("2026-09-15T20:30:00.000Z"))
    }

    @MainActor func testSlotSelectionRetainsTheOriginalBusiness() async throws {
        let api = RecordingAPI()
        let defaults = UserDefaults(suiteName: "booking-unit-tests")!
        defaults.removePersistentDomain(forName: "booking-unit-tests")
        let store = AppStore(defaults: defaults); store.textForward = true
        let vm = SessionViewModel(store: store, api: api)
        vm.understanding = GoalUnderstanding(understoodGoalEnglish: "Find a dental appointment", readbackUserLang: "", targetNumber: "+13125550123",
            businesses: [FoundBusiness(name: "Original Clinic", phone: "+13125550123")])
        vm.pickSlot(SlotOption(id: "slot", label: "Tuesday 3:30pm", labelUserLang: nil))
        for _ in 0..<100 {
            if await api.request != nil { break }
            try await Task.sleep(nanoseconds: 10_000_000)
        }
        let request = await api.request
        XCTAssertEqual(request?.numbers, ["+13125550123"])
        XCTAssertTrue(request?.text.contains("Tuesday 3:30pm") == true)
        XCTAssertEqual(vm.understanding?.businesses?.first?.name, "Original Clinic")
    }
}

actor RecordingAPI: KindlyCallAPI {
    var request: GoalRequest?
    func createSession(lang: String) async throws -> String { "test-session" }
    func submitGoal(sessionId: String, _ req: GoalRequest) async throws -> GoalUnderstanding {
        request = req
        return GoalUnderstanding(understoodGoalEnglish: req.text, readbackUserLang: "Review", targetNumber: req.numbers!.first!)
    }
    func confirm(sessionId: String) async throws { XCTFail("Selecting a slot must not call without confirmation") }
    func checkStatus(sessionId: String) async throws {}
    func fetchSession(sessionId: String) async throws -> SessionState { throw URLError(.notConnectedToInternet) }
}
