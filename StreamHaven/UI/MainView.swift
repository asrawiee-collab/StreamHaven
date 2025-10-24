import SwiftUI

/// The main view of the application, which contains the tab bar for iPhone and the split view for iPad.
public struct MainView: View {
    @StateObject private var playbackManager: PlaybackManager
    @StateObject private var favoritesManager: FavoritesManager
    @StateObject private var watchHistoryManager: WatchHistoryManager
    @StateObject private var navigationCoordinator = NavigationCoordinator()
    @ObservedObject var profileManager: ProfileManager

    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    /// Initializes a new `MainView`.
    ///
    /// - Parameters:
    ///   - profileManager: The `ProfileManager` for accessing the current profile.
    ///   - settingsManager: The `SettingsManager` for accessing user settings.
    public init(profileManager: ProfileManager, settingsManager: SettingsManager) {
        self.profileManager = profileManager

        let context = PersistenceController.shared.container.viewContext
        guard let profile = profileManager.currentProfile else {
            fatalError("MainView should not be initialized without a current profile.")
        }

        let watchHistoryManager = WatchHistoryManager(context: context, profile: profile)
        _watchHistoryManager = StateObject(wrappedValue: watchHistoryManager)

        _playbackManager = StateObject(wrappedValue: PlaybackManager(context: context, settingsManager: settingsManager, watchHistoryManager: watchHistoryManager))
        _favoritesManager = StateObject(wrappedValue: FavoritesManager(context: context, profile: profile))
    }

    /// The body of the view.
    public var body: some View {
        Group {
            if horizontalSizeClass == .compact {
                iPhoneTabView
            } else {
                iPadContainerView(profileManager: profileManager)
            }
        }
        .environmentObject(playbackManager)
        .environmentObject(favoritesManager)
        .environmentObject(watchHistoryManager)
        .environmentObject(navigationCoordinator)
    }

    /// The tab view for iPhone.
    private var iPhoneTabView: some View {
        TabView {
            NavigationStack(path: $navigationCoordinator.path) {
                HomeView(profileManager: profileManager)
                    .navigationDestination(for: Destination.self) { destination in
                        switch destination {
                        case .movieDetail(let movie):
                            MovieDetailView(movie: movie)
                        case .seriesDetail(let series):
                            SeriesDetailView(series: series)
                        }
                    }
            }
            .tabItem {
                Label(NSLocalizedString("Home", comment: "Tab bar item"), systemImage: "house")
            }

            NavigationStack {
                FavoritesView(profileManager: profileManager)
            }
            .tabItem {
                Label(NSLocalizedString("Favorites", comment: "Tab bar item"), systemImage: "heart")
            }

            NavigationStack {
                SearchView()
            }
            .tabItem {
                Label(NSLocalizedString("Search", comment: "Tab bar item"), systemImage: "magnifyingglass")
            }

            NavigationStack {
                SettingsView()
            }
            .tabItem {
                Label(NSLocalizedString("Settings", comment: "Tab bar item"), systemImage: "gear")
            }
        }
    }
}
