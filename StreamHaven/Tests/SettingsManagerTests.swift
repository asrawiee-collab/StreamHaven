import SwiftUI
import XCTest
@testable import StreamHaven

@MainActor
final class SettingsManagerTests: XCTestCase {
    var manager: SettingsManager!

    override func setUpWithError() throws {
        manager = SettingsManager()
        
        // Reset to defaults
        manager.theme = .system
        manager.subtitleSize = 100.0
        manager.isParentalLockEnabled = false
    }

    func testDefaultThemeIsSystem() {
        XCTAssertEqual(manager.theme, .system)
    }

    func testDefaultSubtitleSizeIs100() {
        XCTAssertEqual(manager.subtitleSize, 100.0)
    }

    func testDefaultParentalLockIsDisabled() {
        XCTAssertFalse(manager.isParentalLockEnabled)
    }

    func testThemeCanBeChanged() {
        manager.theme = .dark
        XCTAssertEqual(manager.theme, .dark)
        
        manager.theme = .light
        XCTAssertEqual(manager.theme, .light)
        
        manager.theme = .system
        XCTAssertEqual(manager.theme, .system)
    }

    func testSubtitleSizeCanBeChanged() {
        manager.subtitleSize = 150.0
        XCTAssertEqual(manager.subtitleSize, 150.0)
        
        manager.subtitleSize = 75.0
        XCTAssertEqual(manager.subtitleSize, 75.0)
    }

    func testParentalLockCanBeToggled() {
        manager.isParentalLockEnabled = true
        XCTAssertTrue(manager.isParentalLockEnabled)
        
        manager.isParentalLockEnabled = false
        XCTAssertFalse(manager.isParentalLockEnabled)
    }

    func testColorSchemeForSystemTheme() {
        manager.theme = .system
        XCTAssertNil(manager.colorScheme)
    }

    func testColorSchemeForLightTheme() {
        manager.theme = .light
        XCTAssertEqual(manager.colorScheme, .light)
    }

    func testColorSchemeForDarkTheme() {
        manager.theme = .dark
        XCTAssertEqual(manager.colorScheme, .dark)
    }

    func testAllThemeCases() {
        let allThemes = SettingsManager.AppTheme.allCases
        XCTAssertEqual(allThemes.count, 3)
        XCTAssertTrue(allThemes.contains(.system))
        XCTAssertTrue(allThemes.contains(.light))
        XCTAssertTrue(allThemes.contains(.dark))
    }

    func testThemeRawValues() {
        XCTAssertEqual(SettingsManager.AppTheme.system.rawValue, "System")
        XCTAssertEqual(SettingsManager.AppTheme.light.rawValue, "Light")
        XCTAssertEqual(SettingsManager.AppTheme.dark.rawValue, "Dark")
    }

    func testThemeIdentifiable() {
        let theme = SettingsManager.AppTheme.dark
        XCTAssertEqual(theme.id, theme)
    }

    func testSubtitleSizeBounds() {
        // Test extreme values
        manager.subtitleSize = 0.0
        XCTAssertEqual(manager.subtitleSize, 0.0)
        
        manager.subtitleSize = 500.0
        XCTAssertEqual(manager.subtitleSize, 500.0)
    }

    func testSettingsPersistence() {
        // Change all settings
        manager.theme = .dark
        manager.subtitleSize = 125.0
        manager.isParentalLockEnabled = true
        
        // Create new manager instance
        let newManager = SettingsManager()
        
        // Values should persist via @AppStorage
        XCTAssertEqual(newManager.theme, .dark)
        XCTAssertEqual(newManager.subtitleSize, 125.0)
        XCTAssertTrue(newManager.isParentalLockEnabled)
    }
}
