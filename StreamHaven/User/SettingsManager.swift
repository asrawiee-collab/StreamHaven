import SwiftUI

/// A class for managing user settings.
@MainActor
public class SettingsManager: ObservableObject {

    /// An enumeration of the available app themes.
    public enum AppTheme: String, CaseIterable, Identifiable {
        /// Uses the system's theme.
        case system = "System"
        /// Uses the light theme.
        case light = "Light"
        /// Uses the dark theme.
        case dark = "Dark"
        /// The identifier for the theme.
        public var id: Self { self }
    }

    /// The current app theme.
    @AppStorage("appTheme") public var theme: AppTheme = .system
    /// The subtitle size as a percentage.
    @AppStorage("subtitleSize") public var subtitleSize: Double = 100.0 // Percentage
    /// A boolean indicating whether the parental lock is enabled.
    @AppStorage("parentalLockEnabled") public var isParentalLockEnabled: Bool = false

    /// The color scheme for the app.
    public var colorScheme: ColorScheme? {
        switch theme {
        case .system:
            return nil
        case .light:
            return .light
        case .dark:
            return .dark
        }
    }
}
