import SwiftUI

struct MainView: View {
    @StateObject private var playbackController: PlaybackController
    @ObservedObject var profileManager: ProfileManager

    init(profileManager: ProfileManager) {
        self.profileManager = profileManager

        let context = PersistenceController.shared.container.viewContext
        _playbackController = StateObject(wrappedValue: PlaybackController(context: context))
    }

    var body: some View {
        TabView {
            HomeView(profileManager: profileManager)
                .tabItem {
                    Label("Home", systemImage: "house")
                }
        }
        .environmentObject(playbackController)
    }
}
