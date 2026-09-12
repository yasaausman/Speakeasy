import XCTest

/// A minimal UI smoke test: the app launches cleanly (no cold-launch permission
/// wall) and the Home screen renders its greeting and at least one starter chip.
/// Deliberately small and resilient — it guards the first-impression surface, not
/// every screen. Device default on the simulator is English, so it asserts English.
final class HomeSmokeTests: XCTestCase {
    override func setUp() { continueAfterFailure = false }

    func testHomeShowsGreetingAndStarterChip() {
        let app = XCUIApplication()
        app.launch()

        let greeting = app.staticTexts["What can I help with?"]
        XCTAssertTrue(greeting.waitForExistence(timeout: 15), "Home greeting should render on launch")

        // The starter chip is a Button whose label is its text; accept either exposure.
        let chipButton = app.buttons["Book a haircut"]
        let chipText = app.staticTexts["Book a haircut"]
        XCTAssertTrue(chipButton.exists || chipText.exists, "A starter chip should be visible")
    }

    /// Switching language localizes the Home surface and the choice survives relaunch.
    func testLanguageSwitchLocalizesHomeAndPersists() {
        let app = XCUIApplication()
        app.launch()

        XCTAssertTrue(app.staticTexts["What can I help with?"].waitForExistence(timeout: 15))

        // Open the picker from the pill (shows the current language) and choose Spanish.
        let pill = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "English")).firstMatch
        XCTAssertTrue(pill.waitForExistence(timeout: 5))
        pill.tap()
        let spanishRow = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "Español")).firstMatch
        XCTAssertTrue(spanishRow.waitForExistence(timeout: 5))
        spanishRow.tap()

        // Home is now Spanish.
        let esGreeting = app.staticTexts["¿En qué puedo ayudarte?"]
        XCTAssertTrue(esGreeting.waitForExistence(timeout: 5), "Home greeting should be Spanish after switching")

        // …and the choice persists across a relaunch.
        app.terminate()
        app.launch()
        XCTAssertTrue(app.staticTexts["¿En qué puedo ayudarte?"].waitForExistence(timeout: 15),
                      "Language choice should persist across relaunch")
    }
}
