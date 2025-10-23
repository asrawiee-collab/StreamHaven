import SwiftUI

struct ContentView: View {
    @StateObject private var profileManager: ProfileManager
    @StateObject private var dataManager: StreamHavenData

    init() {
        let persistenceController = PersistenceController.shared
        _profileManager = StateObject(wrappedValue: ProfileManager(context: persistenceController.container.viewContext))
        _dataManager = StateObject(wrappedValue: StreamHavenData(persistenceController: persistenceController))
    }

    var body: some View {
        Group {
            if profileManager.currentProfile != nil {
                MainView(profileManager: profileManager)
            } else {
                ProfileSelectionView(profileManager: profileManager)
            }
        }
        .environment(\.managedObjectContext, PersistenceController.shared.container.viewContext)
        .environmentObject(profileManager)
        .environmentObject(dataManager)
    }
}
