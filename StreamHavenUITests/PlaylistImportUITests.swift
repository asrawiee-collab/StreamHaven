import XCTest

class PlaylistImportUITests: XCTestCase {
    let app = XCUIApplication()

    override func setUpWithError() throws {
        continueAfterFailure = false
        app.launch()
    }

    func testAddPlaylistFlow() throws {
        // Assumes "Add Playlist" button is visible on HomeView
        let addPlaylistButton = app.buttons["Add Playlist"]
        XCTAssertTrue(addPlaylistButton.waitForExistence(timeout: 5))
        addPlaylistButton.tap()

        // Enter playlist URL
        let playlistTextField = app.textFields["https://example.com/playlist.m3u"]
        XCTAssertTrue(playlistTextField.waitForExistence(timeout: 5))
        playlistTextField.tap()
        playlistTextField.typeText("https://test-streams.mux.dev/x.m3u")

        // Enter EPG URL (optional)
        let epgTextField = app.textFields["https://example.com/epg.xml"]
        XCTAssertTrue(epgTextField.waitForExistence(timeout: 5))
        epgTextField.tap()
        epgTextField.typeText("https://test-streams.mux.dev/epg.xml")

        // Tap Add Playlist
        let confirmButton = app.buttons["Add Playlist"]
        XCTAssertTrue(confirmButton.waitForExistence(timeout: 5))
        confirmButton.tap()

        // Wait for HomeView to reload
        let liveTVLabel = app.staticTexts["Live TV"]
        XCTAssertTrue(liveTVLabel.waitForExistence(timeout: 10))
    }
}
