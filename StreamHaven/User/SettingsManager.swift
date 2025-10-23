import SwiftUI

@MainActor
class SettingsManager: ObservableObject {

    enum AppTheme: String, CaseIterable, Identifiable {
        case system = "System"
        case light = "Light"
        case dark = "Dark"
        var id: Self { self }
    }

    @AppStorage("appTheme") var theme: AppTheme = .system
    @AppStorage("subtitleSize") var subtitleSize: Double = 100.0 // Percentage
    @AppStorage("parentalLockEnabled") var isParentalLockEnabled: Bool = false

    var colorScheme: ColorScheme? {
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
