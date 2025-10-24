import XCTest

class SearchUITests: XCTestCase {
    let app = XCUIApplication()

    override func setUpWithError() throws {
        continueAfterFailure = false
        app.launch()
    }

    func testSearchFunctionality() throws {
        // Assumes search bar is available in HomeView or a dedicated SearchView
        let searchTab = app.tabBars.buttons["Search"]
        XCTAssertTrue(searchTab.waitForExistence(timeout: 5))
        searchTab.tap()

        let searchField = app.searchFields["Search channels, movies, series"]
        XCTAssertTrue(searchField.waitForExistence(timeout: 5))
        searchField.tap()
        searchField.typeText("News")

        let resultCell = app.cells.element(boundBy: 0)
        XCTAssertTrue(resultCell.waitForExistence(timeout: 5))
        resultCell.tap()
    }
}
