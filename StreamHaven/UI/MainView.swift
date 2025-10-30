import SwiftUI

#if os(iOS) || os(tvOS)

/// The main view of the application, which contains the tab bar for iPhone and the split view for iPad.
/// This view is only displayed after a profile has been selected, deferring the creation of
/// heavy services like SubtitleManager, AudioSubtitleManager, and TMDbManager until they're needed.
public struct MainView: View {
    @StateObject private var playbackManager: PlaybackManager
    @StateObject private var favoritesManager: FavoritesManager
    @StateObject private var watchHistoryManager: WatchHistoryManager
    @StateObject private var navigationCoordinator = NavigationCoordinator()
    @StateObject private var downloadManager: DownloadManager
    @StateObject private var queueManager: UpNextQueueManager
    @StateObject private var watchlistManager: WatchlistManager
    @StateObject private var sourceManager: PlaylistSourceManager
    @StateObject private var contentManager: MultiSourceContentManager
    
    // These managers are created lazily on first access through the body
    @StateObject private var subtitleManager = SubtitleManager()
    @StateObject private var audioSubtitleManager = AudioSubtitleManager()
    @StateObject private var tmdbManager = TMDbManager()
    @StateObject private var subscriptionManager: SubscriptionManager
    
    #if os(tvOS)
    @StateObject private var previewManager: HoverPreviewManager
    #endif
    
    @ObservedObject var profileManager: ProfileManager
    @ObservedObject var settingsManager: SettingsManager
    private let persistenceProvider: PersistenceProviding

    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    /// Initializes a new `MainView`.
    ///
    /// - Parameters:
    ///   - profileManager: The `ProfileManager` for accessing the current profile.
    ///   - settingsManager: The `SettingsManager` for accessing user settings.
    public init(profileManager: ProfileManager, settingsManager: SettingsManager, persistenceProvider: PersistenceProviding = DefaultPersistenceProvider()) {
        self.profileManager = profileManager
        self.settingsManager = settingsManager
        self.persistenceProvider = persistenceProvider

        let context = persistenceProvider.container.viewContext
        guard let profile = profileManager.currentProfile else {
            // Prefer explicit failure over hard crash; this should be routed via ProfileSelectionView before MainView.
            preconditionFailure("MainView initialized without a current profile. Ensure profile selection flow precedes MainView.")
        }

        let watchHistoryManager = WatchHistoryManager(context: context, profile: profile)
        _watchHistoryManager = StateObject(wrappedValue: watchHistoryManager)

        _playbackManager = StateObject(wrappedValue: PlaybackManager(context: context, settingsManager: settingsManager, watchHistoryManager: watchHistoryManager))
        _favoritesManager = StateObject(wrappedValue: FavoritesManager(context: context, profile: profile))
        
        // Initialize download manager
        _downloadManager = StateObject(wrappedValue: DownloadManager(context: context, maxStorageGB: 10))
        
        // Initialize queue and watchlist managers
        _queueManager = StateObject(wrappedValue: UpNextQueueManager(context: context, watchHistoryManager: watchHistoryManager))
        _watchlistManager = StateObject(wrappedValue: WatchlistManager(context: context))
        
        // Initialize multi-source managers
        _sourceManager = StateObject(wrappedValue: PlaylistSourceManager(persistenceController: persistenceProvider as? PersistenceController ?? .shared))
        _contentManager = StateObject(wrappedValue: MultiSourceContentManager(context: context))
        
        #if os(tvOS)
        // Initialize preview manager with settings
        _previewManager = StateObject(wrappedValue: HoverPreviewManager(settingsManager: settingsManager))
        #endif

        // Initialize SubscriptionManager with appropriate StoreKit provider
        #if canImport(StoreKit)
        if #available(iOS 15.0, tvOS 15.0, *) {
            _subscriptionManager = StateObject(wrappedValue: SubscriptionManager(storeKitProvider: AppleStoreKitProvider()))
        } else {
            _subscriptionManager = StateObject(wrappedValue: SubscriptionManager(storeKitProvider: NoopStoreKitProvider()))
        }
        #else
        _subscriptionManager = StateObject(wrappedValue: SubscriptionManager(storeKitProvider: NoopStoreKitProvider()))
        #endif
    }

    /// The body of the view.
    public var body: some View {
        Group {
            if horizontalSizeClass == .compact {
                iPhoneTabView
            } else {
                iPadContainerView(profileManager: profileManager, persistenceProvider: persistenceProvider)
            }
        }
        .environmentObject(playbackManager)
        .environmentObject(favoritesManager)
        .environmentObject(watchHistoryManager)
        .environmentObject(navigationCoordinator)
        .environmentObject(subtitleManager)
        .environmentObject(audioSubtitleManager)
        .environmentObject(tmdbManager)
        .environmentObject(downloadManager)
        .environmentObject(queueManager)
        .environmentObject(watchlistManager)
        .environmentObject(sourceManager)
        .environmentObject(contentManager)
        .environmentObject(settingsManager)
        .environmentObject(subscriptionManager)
        #if os(tvOS)
        .environmentObject(previewManager)
        #endif
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
                        case .actorDetail(let actor):
                            ActorDetailView(actor: actor)
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
                WatchlistsView()
            }
            .tabItem {
                Label(NSLocalizedString("Watchlists", comment: "Tab bar item"), systemImage: "list.bullet")
            }
            
#if !os(tvOS)
            NavigationStack {
                DownloadsView()
            }
            .tabItem {
                Label(NSLocalizedString("Downloads", comment: "Tab bar item"), systemImage: "arrow.down.circle")
            }
            
            NavigationStack {
                UpNextView()
            }
            .tabItem {
                Label(NSLocalizedString("Up Next", comment: "Tab bar item"), systemImage: "text.badge.plus")
            }
#endif

            NavigationStack {
                EPGView()
                    .environment(\.managedObjectContext, persistenceProvider.container.viewContext)
            }
            .tabItem {
                Label(NSLocalizedString("TV Guide", comment: "Tab bar item"), systemImage: "tv")
            }

            NavigationStack {
                SearchView(persistenceProvider: persistenceProvider)
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

#else

public struct MainView: View {
    @ObservedObject var profileManager: ProfileManager
    @ObservedObject var settingsManager: SettingsManager
    private let persistenceProvider: PersistenceProviding

    public init(profileManager: ProfileManager, settingsManager: SettingsManager, persistenceProvider: PersistenceProviding = DefaultPersistenceProvider()) {
        self.profileManager = profileManager
        self.settingsManager = settingsManager
        self.persistenceProvider = persistenceProvider
    }

    public var body: some View {
        Text("MainView is not available on this platform.")
            .padding()
    }
}

#endif
