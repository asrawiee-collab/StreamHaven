import SwiftUI

struct ContentView: View {
    @StateObject private var profileManager: ProfileManager

    init() {
        let context = PersistenceController.shared.container.viewContext
        _profileManager = StateObject(wrappedValue: ProfileManager(context: context))
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
    }
}
