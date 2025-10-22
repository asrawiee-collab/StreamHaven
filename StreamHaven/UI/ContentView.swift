import SwiftUI

struct ContentView: View {
    @StateObject private var profileManager: ProfileManager

    init() {
        let context = PersistenceController.shared.container.viewContext
        _profileManager = StateObject(wrappedValue: ProfileManager(context: context))
    }

    var body: some View {
        if let profile = profileManager.currentProfile {
            HomeView(profileManager: profileManager)
                .environment(\.managedObjectContext, PersistenceController.shared.container.viewContext)
                .environmentObject(profileManager)
        } else {
            ProfileSelectionView(profileManager: profileManager)
                .environment(\.managedObjectContext, PersistenceController.shared.container.viewContext)
                .environmentObject(profileManager)
        }
    }
}
