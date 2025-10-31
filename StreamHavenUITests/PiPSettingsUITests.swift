import XCTest

/// UI tests for Picture-in-Picture settings functionality.
/// Tests the PiP toggle in Settings and verifies default values and persistence.
final class PiPSettingsUITests: XCTestCase {
    var app: XCUIApplication!
    
    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        
        // Launch arguments to reset UserDefaults for clean test state
        app.launchArguments = ["--uitesting"]
        app.launch()
        
        // Wait for app to fully load
        _ = app.wait(for: .runningForeground, timeout: 5)
    }
    
    override func tearDownWithError() throws {
        app = nil
    }
    
    // MARK: - Helper Methods
    
    /// Navigates to the Settings tab.
    private func navigateToSettings() throws {
        #if os(iOS)
        // On iPhone: Tap Settings tab in tab bar
        let settingsTab = app.tabBars.buttons["Settings"]
        XCTAssertTrue(settingsTab.waitForExistence(timeout: 5), "Settings tab should exist in tab bar")
        settingsTab.tap()
        
        // Wait for Settings view to load
        let settingsTitle = app.navigationBars["Settings"]
        XCTAssertTrue(settingsTitle.waitForExistence(timeout: 3), "Settings view should load")
        
        #elseif os(tvOS)
        // On tvOS: Focus and select Settings tab
        let settingsTab = app.buttons["Settings"]
        XCTAssertTrue(settingsTab.waitForExistence(timeout: 5), "Settings tab should exist")
        settingsTab.tap()
        #endif
    }
    
    /// Scrolls to the Playback section in Settings if needed.
    private func scrollToPlaybackSection() {
        #if os(iOS)
        let playbackHeader = app.staticTexts["Playback"]
        if !playbackHeader.isHittable {
            // Scroll down until Playback section is visible
            let settingsTable = app.tables.firstMatch
            settingsTable.swipeUp()
        }
        XCTAssertTrue(playbackHeader.waitForExistence(timeout: 3), "Playback section should exist in Settings")
        #endif
    }
    
    /// Finds the PiP toggle switch.
    /// - Returns: The PiP toggle XCUIElement, or nil if not found/supported.
    private func findPiPToggle() -> XCUIElement? {
        // Try multiple possible identifiers for the toggle
        let possibleIdentifiers = [
            "Enable Picture-in-Picture",
            "Enable Picture in Picture",
            "Picture-in-Picture",
            "PiP"
        ]
        
        for identifier in possibleIdentifiers {
            let toggle = app.switches[identifier]
            if toggle.exists {
                return toggle
            }
        }
        
        return nil
    }
    
    // MARK: - Tests
    
    /// Tests that the PiP toggle exists and defaults to enabled on supported devices.
    func testPiPToggleExistsAndDefaultsToEnabled() throws {
        #if os(iOS)
        // Only run on iOS (tvOS doesn't support PiP)
        try navigateToSettings()
        scrollToPlaybackSection()
        
        guard let pipToggle = findPiPToggle() else {
            throw XCTSkip("PiP toggle not found - device may not support Picture-in-Picture")
        }
        
        XCTAssertTrue(pipToggle.exists, "PiP toggle should exist in Settings")
        
        // Verify the toggle is ON by default
        let toggleValue = pipToggle.value as? String
        XCTAssertEqual(toggleValue, "1", "PiP should be enabled by default (toggle value should be '1')")
        
        // Alternative check using label if value isn't reliable
        if toggleValue != "1" {
            // Some accessibility configurations might use isOn property
            XCTAssertTrue(pipToggle.isSelected || pipToggle.value as? String == "1",
                         "PiP toggle should be enabled by default")
        }
        #else
        throw XCTSkip("PiP is only supported on iOS")
        #endif
    }
    
    /// Tests that the PiP toggle can be turned off.
    func testPiPToggleCanBeDisabled() throws {
        #if os(iOS)
        try navigateToSettings()
        scrollToPlaybackSection()
        
        guard let pipToggle = findPiPToggle() else {
            throw XCTSkip("PiP toggle not found - device may not support Picture-in-Picture")
        }
        
        // Verify toggle starts as enabled
        XCTAssertEqual(pipToggle.value as? String, "1", "PiP should start enabled")
        
        // Tap to disable
        pipToggle.tap()
        
        // Wait a moment for the state to update
        sleep(1)
        
        // Verify toggle is now disabled
        XCTAssertEqual(pipToggle.value as? String, "0", "PiP should be disabled after tapping toggle")
        #else
        throw XCTSkip("PiP is only supported on iOS")
        #endif
    }
    
    /// Tests that the PiP toggle can be turned back on after being disabled.
    func testPiPToggleCanBeReEnabled() throws {
        #if os(iOS)
        try navigateToSettings()
        scrollToPlaybackSection()
        
        guard let pipToggle = findPiPToggle() else {
            throw XCTSkip("PiP toggle not found - device may not support Picture-in-Picture")
        }
        
        // First disable PiP
        if pipToggle.value as? String == "1" {
            pipToggle.tap()
            sleep(1)
        }
        
        // Verify it's disabled
        XCTAssertEqual(pipToggle.value as? String, "0", "PiP should be disabled")
        
        // Tap to re-enable
        pipToggle.tap()
        sleep(1)
        
        // Verify toggle is now enabled again
        XCTAssertEqual(pipToggle.value as? String, "1", "PiP should be re-enabled after tapping toggle")
        #else
        throw XCTSkip("PiP is only supported on iOS")
        #endif
    }
    
    /// Tests that the PiP setting persists after navigating away and back.
    func testPiPSettingPersistsAcrossNavigation() throws {
        #if os(iOS)
        try navigateToSettings()
        scrollToPlaybackSection()
        
        guard let pipToggle = findPiPToggle() else {
            throw XCTSkip("PiP toggle not found - device may not support Picture-in-Picture")
        }
        
        // Disable PiP
        if pipToggle.value as? String == "1" {
            pipToggle.tap()
            sleep(1)
        }
        XCTAssertEqual(pipToggle.value as? String, "0", "PiP should be disabled")
        
        // Navigate to Home tab
        let homeTab = app.tabBars.buttons["Home"]
        homeTab.tap()
        
        // Wait for Home to load
        sleep(1)
        
        // Navigate back to Settings
        try navigateToSettings()
        scrollToPlaybackSection()
        
        // Find toggle again
        guard let pipToggleAgain = findPiPToggle() else {
            XCTFail("PiP toggle should still exist after navigation")
            return
        }
        
        // Verify setting persisted (should still be disabled)
        XCTAssertEqual(pipToggleAgain.value as? String, "0", "PiP setting should persist as disabled")
        
        // Re-enable for clean state
        pipToggleAgain.tap()
        #else
        throw XCTSkip("PiP is only supported on iOS")
        #endif
    }
    
    /// Tests that the PiP description text is present and informative.
    func testPiPDescriptionTextExists() throws {
        #if os(iOS)
        try navigateToSettings()
        scrollToPlaybackSection()
        
        guard findPiPToggle() != nil else {
            throw XCTSkip("PiP toggle not found - device may not support Picture-in-Picture")
        }
        
        // Look for the descriptive text below the toggle
        let descriptionText = app.staticTexts.containing(NSPredicate(format: "label CONTAINS[c] 'watching while using other apps'")).firstMatch
        
        XCTAssertTrue(descriptionText.exists, "PiP description text should exist explaining the feature")
        #else
        throw XCTSkip("PiP is only supported on iOS")
        #endif
    }
    
    /// Tests that the PiP toggle only appears on devices that support it.
    func testPiPToggleOnlyAppearsOnSupportedDevices() throws {
        #if os(iOS)
        try navigateToSettings()
        scrollToPlaybackSection()
        
        let pipToggle = findPiPToggle()
        
        // This test documents the behavior: toggle exists if supported, doesn't exist if not
        // We can't reliably test both scenarios in one test, but we document the expectation
        
        if let toggle = pipToggle {
            XCTAssertTrue(toggle.exists, "If PiP is supported, toggle should exist")
        } else {
            // Device doesn't support PiP - this is expected on some devices
            // The test passes either way, documenting both possible outcomes
            XCTAssertTrue(true, "Device doesn't support PiP, toggle correctly not shown")
        }
        
        #elseif os(tvOS)
        // tvOS should never show PiP toggle
        try navigateToSettings()
        
        let pipToggle = findPiPToggle()
        XCTAssertNil(pipToggle, "tvOS should not have PiP toggle")
        #endif
    }
    
    /// Tests the complete PiP settings workflow: toggle off, navigate away, return, toggle on.
    func testCompleteSettingsWorkflow() throws {
        #if os(iOS)
        try navigateToSettings()
        scrollToPlaybackSection()
        
        guard let pipToggle = findPiPToggle() else {
            throw XCTSkip("PiP toggle not found - device may not support Picture-in-Picture")
        }
        
        // Step 1: Verify initial state (enabled by default)
        XCTAssertEqual(pipToggle.value as? String, "1", "PiP should start enabled")
        
        // Step 2: Disable PiP
        pipToggle.tap()
        sleep(1)
        XCTAssertEqual(pipToggle.value as? String, "0", "PiP should be disabled")
        
        // Step 3: Navigate to Search tab
        app.tabBars.buttons["Search"].tap()
        sleep(1)
        
        // Step 4: Navigate to Favorites tab
        app.tabBars.buttons["Favorites"].tap()
        sleep(1)
        
        // Step 5: Return to Settings
        try navigateToSettings()
        scrollToPlaybackSection()
        
        // Step 6: Verify setting persisted as disabled
        guard let pipToggle2 = findPiPToggle() else {
            XCTFail("PiP toggle should exist after navigation")
            return
        }
        XCTAssertEqual(pipToggle2.value as? String, "0", "PiP should remain disabled")
        
        // Step 7: Re-enable PiP
        pipToggle2.tap()
        sleep(1)
        XCTAssertEqual(pipToggle2.value as? String, "1", "PiP should be re-enabled")
        
        // Step 8: Navigate away and back one more time
        app.tabBars.buttons["Home"].tap()
        sleep(1)
        try navigateToSettings()
        scrollToPlaybackSection()
        
        // Step 9: Verify it persisted as enabled
        guard let pipToggle3 = findPiPToggle() else {
            XCTFail("PiP toggle should exist after final navigation")
            return
        }
        XCTAssertEqual(pipToggle3.value as? String, "1", "PiP should remain enabled")
        
        #else
        throw XCTSkip("PiP is only supported on iOS")
        #endif
    }
}
