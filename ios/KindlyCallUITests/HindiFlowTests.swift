import XCTest

final class HindiFlowTests: XCTestCase {
    override func setUp() { continueAfterFailure = false }

    private func start(_ scenario: String) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchEnvironment["KINDLYCALL_DEMO_SCENARIO"] = scenario
        app.launchEnvironment["KINDLYCALL_DEMO_LANGUAGE"] = "hi"
        app.launch()
        XCTAssertTrue(app.textFields.firstMatch.waitForExistence(timeout: 10))
        let field = app.textFields.firstMatch
        field.tap(); field.typeText("Book a dental checkup Tuesday afternoon")
        // Send uses the arrow icon; give it a stable accessibility identifier in HomeView.
        app.buttons["send-goal"].tap()
        XCTAssertTrue(app.buttons["हाँ, कॉल करें"].waitForExistence(timeout: 10))
        let confirmation = XCTAttachment(screenshot: app.screenshot())
        confirmation.name = "Hindi confirmation — SIMULATED"; confirmation.lifetime = .keepAlways; add(confirmation)
        app.buttons["हाँ, कॉल करें"].tap()
        return app
    }

    func testHindiSuccessfulBookingAndCalendarReview() {
        let app = start("success")
        XCTAssertTrue(app.staticTexts["आपका अपॉइंटमेंट पक्का हो गया"].waitForExistence(timeout: 15))
        XCTAssertTrue(app.staticTexts["4471"].exists)
        XCTAssertFalse(app.buttons["फिर से कोशिश करें"].exists)
        let shot = XCTAttachment(screenshot: app.screenshot()); shot.name = "Hindi result — SIMULATED"; shot.lifetime = .keepAlways; add(shot)
        let calendar = app.buttons["तारीख और समय जाँचें"]
        if !calendar.isHittable { app.swipeUp() }
        XCTAssertTrue(calendar.waitForExistence(timeout: 3)); calendar.tap()
        XCTAssertTrue(app.buttons["अपॉइंटमेंट सेव करें"].waitForExistence(timeout: 5))
        app.buttons["रद्द करें"].tap()
    }

    func testHindiMissingNameIsNotPresentedAsSuccess() {
        let app = start("gap")
        XCTAssertTrue(app.staticTexts["आपकी जानकारी चाहिए"].waitForExistence(timeout: 15))
        XCTAssertFalse(app.staticTexts["4471"].exists)
        XCTAssertFalse(app.staticTexts["आपका अपॉइंटमेंट पक्का हो गया"].exists)
        let shot = XCTAttachment(screenshot: app.screenshot()); shot.name = "Hindi recovery — SIMULATED"; shot.lifetime = .keepAlways; add(shot)
    }

    func testPendingOutcomeOffersStatusCheckInsteadOfRedial() {
        let app = start("pending")
        XCTAssertTrue(app.staticTexts["कॉल का नतीजा अभी बाकी है"].waitForExistence(timeout: 15))
        XCTAssertFalse(app.buttons["फिर से कोशिश करें"].exists)
        XCTAssertFalse(app.buttons["नया अनुरोध"].exists)
        let check = app.buttons["कॉल की स्थिति देखें"]
        if !check.isHittable { app.swipeUp() }
        XCTAssertTrue(check.exists); check.tap()
        XCTAssertTrue(app.staticTexts["आपका अपॉइंटमेंट पक्का हो गया"].waitForExistence(timeout: 15))
    }
}
