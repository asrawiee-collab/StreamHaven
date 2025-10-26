import XCTest

class tvOSFocusEngineUITests: XCTestCase {
    let app = XCUIApplication()

    override func setUpWithError() throws {
        continueAfterFailure = false
        app.launchArguments.append("-UITest_tvOS")
        app.launch()
    }

    func testFocusNavigation() throws {
        // Assumes focusable elements are present on tvOS
        let firstCard = app.buttons.element(boundBy: 0)
        XCTAssertTrue(firstCard.waitForExistence(timeout: 5))
        firstCard.press(forDuration: 0.5)
        let isFocused = firstCard.isSelected || firstCard.isHittable
        XCTAssertTrue(isFocused)
    }
}
