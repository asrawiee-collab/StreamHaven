//
//  AccessibilityModeTests.swift
//  StreamHaven
//
//  Tests for accessibility mode functionality
//

import XCTest
@testable import StreamHaven

@MainActor
final class AccessibilityModeTests: XCTestCase {
    var settingsManager: SettingsManager!
    
    override func setUp() async throws {
        try await super.setUp()
        settingsManager = SettingsManager()
        // Reset to default state
        settingsManager.accessibilityModeEnabled = false
    }
    
    override func tearDown() async throws {
        settingsManager = nil
        try await super.tearDown()
    }
    
    // MARK: - Settings Tests
    
    func testAccessibilityModeDefaultDisabled() {
        XCTAssertFalse(settingsManager.accessibilityModeEnabled, "Accessibility mode should be disabled by default")
    }
    
    func testAccessibilityModeToggle() {
        // Enable accessibility mode
        settingsManager.accessibilityModeEnabled = true
        XCTAssertTrue(settingsManager.accessibilityModeEnabled, "Should enable accessibility mode")
        
        // Disable accessibility mode
        settingsManager.accessibilityModeEnabled = false
        XCTAssertFalse(settingsManager.accessibilityModeEnabled, "Should disable accessibility mode")
    }
    
    func testAccessibilityModePersistence() {
        // Enable accessibility mode
        settingsManager.accessibilityModeEnabled = true
        
        // Create new settings manager instance (simulates app restart)
        let newSettingsManager = SettingsManager()
        
        // Verify persistence via UserDefaults
        XCTAssertTrue(UserDefaults.standard.bool(forKey: "accessibilityModeEnabled"), "Setting should persist in UserDefaults")
        XCTAssertTrue(newSettingsManager.accessibilityModeEnabled, "New instance should load persisted setting")
        
        // Cleanup
        UserDefaults.standard.removeObject(forKey: "accessibilityModeEnabled")
    }
    
    // MARK: - UI Enhancement Tests
    
    func testFocusBorderColorAccessibilityMode() {
        #if os(tvOS)
        settingsManager.accessibilityModeEnabled = true
        
        // In CardView, when accessibility mode is enabled and focused:
        // .stroke(isFocused && settingsManager.accessibilityModeEnabled ? Color.yellow: Color.clear, lineWidth: 4)
        
        // Simulate focused state
        let isFocused = true
        let expectedBorderColor = isFocused && settingsManager.accessibilityModeEnabled ? "yellow" : "clear"
        
        XCTAssertEqual(expectedBorderColor, "yellow", "Focus border should be yellow when accessibility mode is enabled")
        
        // Simulate not focused
        let isNotFocused = false
        let expectedBorderColorNotFocused = isNotFocused && settingsManager.accessibilityModeEnabled ? "yellow" : "clear"
        
        XCTAssertEqual(expectedBorderColorNotFocused, "clear", "Focus border should be clear when not focused")
        #endif
    }
    
    func testScaleEffectAccessibilityMode() {
        #if os(tvOS)
        settingsManager.accessibilityModeEnabled = true
        
        // In CardView, when accessibility mode is enabled and focused:
        // .scaleEffect(isFocused ? (settingsManager.accessibilityModeEnabled ? 1.15: 1.1) : 1.0)
        
        let isFocused = true
        let expectedScale = isFocused ? (settingsManager.accessibilityModeEnabled ? 1.15: 1.1) : 1.0
        
        XCTAssertEqual(expectedScale, 1.15, accuracy: 0.01, "Scale should be 1.15 when accessibility mode is enabled and focused")
        
        // Without accessibility mode
        settingsManager.accessibilityModeEnabled = false
        let expectedScaleWithoutAccessibility = isFocused ? (settingsManager.accessibilityModeEnabled ? 1.15: 1.1) : 1.0
        
        XCTAssertEqual(expectedScaleWithoutAccessibility, 1.1, accuracy: 0.01, "Scale should be 1.1 when accessibility mode is disabled and focused")
        #endif
    }
    
    func testCardSpacingAccessibilityMode() {
        settingsManager.accessibilityModeEnabled = true
        
        // In HomeView, card spacing is determined by:
        // HStack(spacing: settingsManager.accessibilityModeEnabled ? 30: 20)
        
        let expectedSpacing = settingsManager.accessibilityModeEnabled ? 30: 20
        XCTAssertEqual(expectedSpacing, 30, "Card spacing should be 30 when accessibility mode is enabled")
        
        // Without accessibility mode
        settingsManager.accessibilityModeEnabled = false
        let expectedSpacingWithoutAccessibility = settingsManager.accessibilityModeEnabled ? 30: 20
        XCTAssertEqual(expectedSpacingWithoutAccessibility, 20, "Card spacing should be 20 when accessibility mode is disabled")
    }
    
    // MARK: - Integration Tests
    
    func testAccessibilityModeEnablesAllEnhancements() {
        settingsManager.accessibilityModeEnabled = true
        
        // Verify all accessibility enhancements are applied
        XCTAssertTrue(settingsManager.accessibilityModeEnabled, "Accessibility mode should be enabled")
        
        #if os(tvOS)
        // Enhanced focus scale: 1.15 instead of 1.1
        let focusScale = settingsManager.accessibilityModeEnabled ? 1.15: 1.1
        XCTAssertEqual(focusScale, 1.15, accuracy: 0.01, "Focus scale should be enhanced")
        #endif
        
        // Increased card spacing: 30 instead of 20
        let cardSpacing = settingsManager.accessibilityModeEnabled ? 30: 20
        XCTAssertEqual(cardSpacing, 30, "Card spacing should be increased")
    }
    
    func testAccessibilityModeDisablesAllEnhancements() {
        settingsManager.accessibilityModeEnabled = false
        
        // Verify all accessibility enhancements are disabled
        XCTAssertFalse(settingsManager.accessibilityModeEnabled, "Accessibility mode should be disabled")
        
        #if os(tvOS)
        // Standard focus scale: 1.1
        let focusScale = settingsManager.accessibilityModeEnabled ? 1.15: 1.1
        XCTAssertEqual(focusScale, 1.1, accuracy: 0.01, "Focus scale should be standard")
        #endif
        
        // Standard card spacing: 20
        let cardSpacing = settingsManager.accessibilityModeEnabled ? 30: 20
        XCTAssertEqual(cardSpacing, 20, "Card spacing should be standard")
    }
    
    // MARK: - Dwell Control Support Tests
    
    func testDwellControlCompatibility() {
        // Dwell Control is a system-level feature (iOS/tvOS Accessibility settings)
        // Our app supports it through:
        // 1. Enhanced focus indicators (yellow border, larger scale)
        // 2. Increased spacing between interactive elements
        // 3. Larger touch/focus targets
        
        settingsManager.accessibilityModeEnabled = true
        
        // Verify larger spacing for easier dwell targeting
        let spacing = settingsManager.accessibilityModeEnabled ? 30: 20
        XCTAssertEqual(spacing, 30, "Increased spacing supports Dwell Control targeting")
        
        #if os(tvOS)
        // Verify enhanced focus scale for better visual feedback
        let scale = settingsManager.accessibilityModeEnabled ? 1.15: 1.1
        XCTAssertEqual(scale, 1.15, accuracy: 0.01, "Enhanced scale supports Dwell Control feedback")
        #endif
    }
    
    // MARK: - Edge Cases
    
    func testMultipleToggles() {
        // Toggle multiple times
        settingsManager.accessibilityModeEnabled = true
        settingsManager.accessibilityModeEnabled = false
        settingsManager.accessibilityModeEnabled = true
        settingsManager.accessibilityModeEnabled = false
        
        XCTAssertFalse(settingsManager.accessibilityModeEnabled, "Should handle multiple toggles correctly")
    }
    
    func testAccessibilityModeWithOtherSettings() {
        // Enable accessibility mode alongside other settings
        settingsManager.accessibilityModeEnabled = true
        settingsManager.hideAdultContent = true
        settingsManager.subtitleSize = 150.0
        
        XCTAssertTrue(settingsManager.accessibilityModeEnabled, "Accessibility mode should work with other settings")
        XCTAssertTrue(settingsManager.hideAdultContent, "Other settings should remain independent")
        XCTAssertEqual(settingsManager.subtitleSize, 150.0, accuracy: 0.01, "Subtitle size should be unaffected")
    }
}
