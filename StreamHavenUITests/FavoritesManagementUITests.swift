import XCTest

class FavoritesManagementUITests: XCTestCase {
    let app = XCUIApplication()

    override func setUpWithError() throws {
        continueAfterFailure = false
        app.launch()
    }

    func testAddAndRemoveFavorite() throws {
        // Assumes HomeView and FavoritesView are accessible
        let liveTVLabel = app.staticTexts["Live TV"]
        XCTAssertTrue(liveTVLabel.waitForExistence(timeout: 10))
        let channelCard = app.buttons.element(boundBy: 0)
        channelCard.tap()

        let favoriteButton = app.buttons["Favorite"]
        XCTAssertTrue(favoriteButton.waitForExistence(timeout: 5))
        favoriteButton.tap()

        // Go to FavoritesView
        let favoritesTab = app.tabBars.buttons["Favorites"]
        XCTAssertTrue(favoritesTab.waitForExistence(timeout: 5))
        favoritesTab.tap()

        let favoriteChannel = app.staticTexts[channelCard.label]
        XCTAssertTrue(favoriteChannel.exists)

        // Remove favorite
        let removeButton = app.buttons["Remove Favorite"]
        if removeButton.exists {
            removeButton.tap()
        }
    }
}
