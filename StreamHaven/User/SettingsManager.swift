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
    /// A boolean indicating whether adult content (NC-17) should be hidden for adult profiles.
    @AppStorage("hideAdultContent") public var hideAdultContent: Bool = false
    /// A boolean indicating whether accessibility mode is enabled (enhanced focus, Dwell Control support).
    @AppStorage("accessibilityModeEnabled") public var accessibilityModeEnabled: Bool = false
    /// A boolean indicating whether Picture-in-Picture is enabled (iOS/iPadOS only).
    @AppStorage("enablePiP") public var enablePiP: Bool = true
    /// A boolean indicating whether pre-buffering next episode is enabled.
    @AppStorage("enablePreBuffer") public var enablePreBuffer: Bool = true
    /// Number of seconds before episode end to start pre-buffering next episode.
    @AppStorage("preBufferTimeSeconds") public var preBufferTimeSeconds: Double = 120.0
    /// A boolean indicating whether skip intro button is enabled.
    @AppStorage("enableSkipIntro") public var enableSkipIntro: Bool = true
    /// A boolean indicating whether to automatically skip intros (no button shown).
    @AppStorage("autoSkipIntro") public var autoSkipIntro: Bool = false
    /// Optional TheTVDB API key for fetching intro timing data.
    @AppStorage("tvdbAPIKey") public var tvdbAPIKey: String?
    /// A boolean indicating whether iCloud sync is enabled.
    @AppStorage("enableCloudSync") public var enableCloudSync: Bool = false
    /// Last successful iCloud sync timestamp.
    @AppStorage("lastCloudSyncDate") public var lastCloudSyncDate: Date?
    /// A boolean indicating whether Live Activities are enabled (iOS 16.1+).
    @AppStorage("enableLiveActivities") public var enableLiveActivities: Bool = true
    
    // MARK: - Download Settings
    
    /// Maximum storage for downloads in gigabytes.
    @AppStorage("maxDownloadStorageGB") public var maxDownloadStorageGB: Int = 10
    /// Download quality preference.
    @AppStorage("downloadQuality") public var downloadQuality: String = "medium"
    /// Auto-delete watched downloads.
    @AppStorage("autoDeleteWatchedDownloads") public var autoDeleteWatchedDownloads: Bool = false
    /// Download expiration days.
    @AppStorage("downloadExpirationDays") public var downloadExpirationDays: Int = 30
    
    // MARK: - Up Next Queue Settings
    
    /// Enable auto-queue suggestions.
    @AppStorage("enableAutoQueue") public var enableAutoQueue: Bool = true
    /// Number of auto-queue suggestions.
    @AppStorage("autoQueueSuggestions") public var autoQueueSuggestions: Int = 3
    /// Clear queue on profile switch.
    @AppStorage("clearQueueOnProfileSwitch") public var clearQueueOnProfileSwitch: Bool = false
    /// Maximum queue size.
    @AppStorage("maxQueueSize") public var maxQueueSize: Int = 50
    
    // MARK: - tvOS Hover Preview Settings
    
    #if os(tvOS)
    /// Enable hover previews on tvOS (video previews when focusing on content).
    @AppStorage("enableHoverPreviews") public var enableHoverPreviews: Bool = true
    /// Delay in seconds before preview starts playing.
    @AppStorage("hoverPreviewDelay") public var hoverPreviewDelay: Double = 1.0
    #endif

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
