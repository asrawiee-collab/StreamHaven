import SwiftUI

struct ContentView: View {
    @StateObject private var profileManager: ProfileManager
    @StateObject private var dataManager: StreamHavenData
    @StateObject private var settingsManager = SettingsManager()

    init() {
        let persistenceController = PersistenceController.shared
        _profileManager = StateObject(wrappedValue: ProfileManager(context: persistenceController.container.viewContext))
        _dataManager = StateObject(wrappedValue: StreamHavenData(persistenceController: persistenceController))
    }

    var body: some View {
        Group {
            if profileManager.currentProfile != nil {
                MainView(profileManager: profileManager, settingsManager: settingsManager)
            } else {
                ProfileSelectionVew(profileManager: profileManager)
            }
        }
        .environment(\.managedObjectContext, PersistenceController.shared.container.viewContext)
        .environmentObject(profileManager)
        .environmentObject(dataManager)
        .environmentObject(settingsManager)
        .preferredColorScheme(settingsManager.colorScheme)
    }
}
