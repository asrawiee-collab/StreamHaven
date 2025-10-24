import XCTest

class ProfileSelectionUITests: XCTestCase {
    let app = XCUIApplication()

    override func setUpWithError() throws {
        continueAfterFailure = false
        app.launch()
    }

    func testProfileSelection() throws {
        // Assumes profile selection is available on launch or via HomeView
        let profileButton = app.buttons["No Profile"]
        if profileButton.exists {
            profileButton.tap()
        }
        let profileCell = app.cells["ProfileCell"]
        XCTAssertTrue(profileCell.waitForExistence(timeout: 5))
        profileCell.tap()
        // Verify HomeView loads for selected profile
        let homeTitle = app.navigationBars["Home"]
        XCTAssertTrue(homeTitle.waitForExistence(timeout: 5))
    }
}
