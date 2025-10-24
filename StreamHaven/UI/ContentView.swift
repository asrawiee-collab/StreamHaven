import SwiftUI

/// The main content view of the application.
public struct ContentView: View {
    @StateObject private var profileManager: ProfileManager
    @StateObject private var dataManager: StreamHavenData
    @StateObject private var settingsManager = SettingsManager()
    @StateObject private var subtitleManager = SubtitleManager()
    @StateObject private var audioSubtitleManager = AudioSubtitleManager()
    @StateObject private var tmdbManager = TMDbManager()

    /// Initializes a new `ContentView`.
    public init() {
        let persistenceController = PersistenceController.shared
        _profileManager = StateObject(wrappedValue: ProfileManager(context: persistenceController.container.viewContext))
        _dataManager = StateObject(wrappedValue: StreamHavenData(persistenceController: persistenceController))
    }

    /// The body of the view.
    public var body: some View {
        Group {
            if profileManager.currentProfile != nil {
                MainView(profileManager: profileManager, settingsManager: settingsManager)
            } else {
                ProfileSelectionView(profileManager: profileManager)
            }
        }
        .environment(\.managedObjectContext, PersistenceController.shared.container.viewContext)
        .environmentObject(profileManager)
        .environmentObject(dataManager)
        .environmentObject(settingsManager)
        .environmentObject(subtitleManager)
        .environmentObject(audioSubtitleManager)
        .environmentObject(tmdbManager)
        .preferredColorScheme(settingsManager.colorScheme)
    }
}
