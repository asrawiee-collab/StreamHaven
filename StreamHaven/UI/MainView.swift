import SwiftUI

struct MainView: View {
    @StateObject private var playbackManager: PlaybackManager
    @StateObject private var favoritesManager: FavoritesManager
    @StateObject private var watchHistoryManager: WatchHistoryManager
    @ObservedObject var profileManager: ProfileManager

    init(profileManager: ProfileManager) {
        self.profileManager = profileManager

        let context = PersistenceController.shared.container.viewContext
        _playbackManager = StateObject(wrappedValue: PlaybackManager(context: context))

        guard let profile = profileManager.currentProfile else {
            fatalError("MainView should not be initialized without a current profile.")
        }
        _favoritesManager = StateObject(wrappedValue: FavoritesManager(context: context, profile: profile))
        _watchHistoryManager = StateObject(wrappedValue: WatchHistoryManager(context: context, profile: profile))
    }

    var body: some View {
        TabView {
            HomeView(profileManager: profileManager)
                .tabItem {
                    Label(NSLocalizedString("Home", comment: "Tab bar item"), systemImage: "house")
                }

            FavoritesView(profileManager: profileManager)
                .tabItem {
                    Label(NSLocalizedString("Favorites", comment: "Tab bar item"), systemImage: "heart")
                }

            SearchView()
                .tabItem {
                    Label(NSLocalizedString("Search", comment: "Tab bar item"), systemImage: "magnifyingglass")
                }
        }
        .environmentObject(playbackManager)
        .environmentObject(favoritesManager)
        .environmentObject(watchHistoryManager)
    }
}
