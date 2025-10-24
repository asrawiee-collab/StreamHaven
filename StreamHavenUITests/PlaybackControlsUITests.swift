import XCTest

class PlaybackControlsUITests: XCTestCase {
    let app = XCUIApplication()

    override func setUpWithError() throws {
        continueAfterFailure = false
        app.launch()
    }

    func testPlaybackControls() throws {
        // Assumes a channel/movie is available to play
        let liveTVLabel = app.staticTexts["Live TV"]
        XCTAssertTrue(liveTVLabel.waitForExistence(timeout: 10))
        let channelCard = app.buttons.element(boundBy: 0)
        channelCard.tap()

        // Wait for playback view
        let playButton = app.buttons["Play"]
        XCTAssertTrue(playButton.waitForExistence(timeout: 10))
        playButton.tap()

        let pauseButton = app.buttons["Pause"]
        XCTAssertTrue(pauseButton.waitForExistence(timeout: 10))
        pauseButton.tap()

        // Seek and overlays
        let seekForwardButton = app.buttons["Seek Forward"]
        if seekForwardButton.exists {
            seekForwardButton.tap()
        }
        let nowOverlay = app.staticTexts["Now:"]
        XCTAssertTrue(nowOverlay.exists)
    }
}
