import XCTest

class iPadSplitViewUITests: XCTestCase {
    let app = XCUIApplication()

    override func setUpWithError() throws {
        continueAfterFailure = false
        app.launchArguments.append("-UITest_iPad")
        app.launch()
    }

    func testSplitViewNavigation() throws {
        // Assumes split view is available on iPad
        let sidebar = app.tables["Sidebar"]
        XCTAssertTrue(sidebar.waitForExistence(timeout: 5))
        let firstItem = sidebar.cells.element(boundBy: 0)
        firstItem.tap()
        let detailView = app.otherElements["DetailView"]
        XCTAssertTrue(detailView.waitForExistence(timeout: 5))
    }
}
