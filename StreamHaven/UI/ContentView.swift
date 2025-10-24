import SwiftUI

/// The main content view of the application.
/// This view manages the app's initial state and defers heavy manager initialization
/// (SubtitleManager, TMDbManager, AudioSubtitleManager) until after profile selection.
public struct ContentView: View {
    @StateObject private var profileManager: ProfileManager
    @StateObject private var dataManager: StreamHavenData
    @StateObject private var settingsManager
    private let persistenceProvider: PersistenceProviding

    /// Initializes a new `ContentView`.
    /// Only lightweight managers (ProfileManager, SettingsManager) are created here.
    /// Heavy services are deferred to MainView after profile selection.
    public init(persistenceProvider: PersistenceProviding) {
        self.persistenceProvider = persistenceProvider
        _settingsManager = StateObject(wrappedValue: SettingsManager())
        let context = persistenceProvider.container.viewContext
        _profileManager = StateObject(wrappedValue: ProfileManager(context: context))
        _dataManager = StateObject(wrappedValue: StreamHavenData(persistenceProvider: persistenceProvider))
    }

    /// The body of the view.
    public var body: some View {
        Group {
            if profileManager.currentProfile != nil {
                MainView(profileManager: profileManager, settingsManager: settingsManager, persistenceProvider: persistenceProvider)
            } else {
                ProfileSelectionView(profileManager: profileManager)
            }
        }
        .environment(\.managedObjectContext, persistenceProvider.container.viewContext)
        .environmentObject(profileManager)
        .environmentObject(dataManager)
        .environmentObject(settingsManager)
        .preferredColorScheme(settingsManager.colorScheme)
    }
}
