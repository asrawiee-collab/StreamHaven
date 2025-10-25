import SwiftUI
import CoreData

#if os(iOS)
/// A view that displays the user's library of movies, series, and channels.
public struct HomeView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @ObservedObject var profileManager: ProfileManager
    @EnvironmentObject var settingsManager: SettingsManager

    @FetchRequest var movies: FetchedResults<Movie>
    @FetchRequest var series: FetchedResults<Series>
    @FetchRequest var channels: FetchedResults<Channel>
    @FetchRequest var watchHistory: FetchedResults<WatchHistory>

    @State private var showingAddPlaylist = false
    @State private var showSourceModePrompt = false
    @State private var trendingMovies: [Movie] = []
    @State private var trendingSeries: [Series] = []
    @State private var recommendedMovies: [Movie] = []
    @EnvironmentObject private var navigationCoordinator: NavigationCoordinator
    @EnvironmentObject var tmdbManager: TMDbManager
    @EnvironmentObject var sourceManager: PlaylistSourceManager

    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    /// A closure that is called when an item is selected.
    public var onItemSelected: ((Destination) -> Void)? = nil

    /// Initializes a new `HomeView`.
    ///
    /// - Parameters:
    ///   - profileManager: The `ProfileManager` for accessing the current profile.
    ///   - onItemSelected: A closure that is called when an item is selected.
    public init(profileManager: ProfileManager, onItemSelected: ((Destination) -> Void)? = nil) {
        self.profileManager = profileManager
        self.onItemSelected = onItemSelected

        var moviePredicate = NSPredicate(value: true)
        var seriesPredicate = NSPredicate(value: true)
        
        // Enforced filtering for Kids profiles (G, PG, PG-13, Unrated only)
        if let profile = profileManager.currentProfile, !profile.isAdult {
            let allowedRatings = [Rating.g.rawValue, Rating.pg.rawValue, Rating.pg13.rawValue, Rating.unrated.rawValue]
            moviePredicate = NSPredicate(format: "rating IN %@", allowedRatings)
            seriesPredicate = NSPredicate(format: "rating IN %@", allowedRatings)
        }
        // Optional filtering for Adult profiles (exclude NC-17 if hideAdultContent is enabled)
        else if UserDefaults.standard.bool(forKey: "hideAdultContent") {
            let safeRatings = [Rating.g.rawValue, Rating.pg.rawValue, Rating.pg13.rawValue, Rating.r.rawValue, Rating.unrated.rawValue]
            moviePredicate = NSPredicate(format: "rating IN %@", safeRatings)
            seriesPredicate = NSPredicate(format: "rating IN %@", safeRatings)
        }

        _movies = FetchRequest<Movie>(
            sortDescriptors: [NSSortDescriptor(keyPath: \Movie.releaseDate, ascending: false)],
            predicate: moviePredicate,
            animation: .default)

        _series = FetchRequest<Series>(
            sortDescriptors: [NSSortDescriptor(keyPath: \Series.releaseDate, ascending: false)],
            predicate: seriesPredicate,
            animation: .default)

        _channels = FetchRequest<Channel>(
            sortDescriptors: [NSSortDescriptor(keyPath: \Channel.name, ascending: true)],
            animation: .default)

        var watchHistoryPredicate = NSPredicate(value: false)
        if let profile = profileManager.currentProfile {
            watchHistoryPredicate = NSPredicate(format: "profile == %@", profile)
        }

        _watchHistory = FetchRequest<WatchHistory>(
            sortDescriptors: [NSSortDescriptor(keyPath: \WatchHistory.watchedDate, ascending: false)],
            predicate: watchHistoryPredicate,
            animation: .default)
    }

    @State private var franchiseGroups: [String: [Movie]] = [:]

    private var moviesNotInFranchise: [Movie] {
        let franchiseMovieIDs = franchiseGroups.values.flatMap { $0 }.map { $0.objectID }
        return movies.filter { !franchiseMovieIDs.contains($0.objectID) }
    }

    /// The body of the view.
    public var body: some View {
        Group {
            if movies.isEmpty && series.isEmpty && channels.isEmpty {
                EmptyStateView(
                    title: NSLocalizedString("Your Library is Empty", comment: "Empty state title"),
                    message: NSLocalizedString("Add a playlist to get started.", comment: "Empty state message"),
                    actionTitle: NSLocalizedString("Add Playlist", comment: "Empty state action button title"),
                    action: {
                        showingAddPlaylist = true
                    }
                )
                .onAppear {
                    checkSourceModePrompt()
                }
            } else {
                ScrollView {
                    VStack(alignment: .leading) {
                        if !watchHistory.isEmpty {
                            Text(NSLocalizedString("Resume Watching", comment: "Home view section title"))
                        .font(.title)
                        .padding()

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: settingsManager.accessibilityModeEnabled ? 30 : 20) {
                            ForEach(watchHistory) { history in
                                if let movie = history.movie {
                                        Button(action: { handleSelection(.movieDetail(movie)) }) {
                                        CardView(url: URL(string: movie.posterURL ?? ""), title: movie.title ?? "No Title")
                                    }
                                    .buttonStyle(PlainButtonStyle())
                                } else if let episode = history.episode, let series = episode.season?.series {
                                        Button(action: { handleSelection(.seriesDetail(series)) }) {
                                        CardView(url: URL(string: series.posterURL ?? ""), title: episode.title ?? "No Title")
                                    }
                                    .buttonStyle(PlainButtonStyle())
                                }
                            }
                        }
                        .padding(.horizontal)
                    }
                }

                // Trending This Week
                if !trendingMovies.isEmpty || !trendingSeries.isEmpty {
                    Text(NSLocalizedString("Trending This Week", comment: "Home view section title"))
                        .font(.title)
                        .padding()

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: settingsManager.accessibilityModeEnabled ? 30 : 20) {
                            ForEach(trendingMovies) { movie in
                                Button(action: { handleSelection(.movieDetail(movie)) }) {
                                    CardView(url: URL(string: movie.posterURL ?? ""), title: movie.title ?? "No Title")
                                }
                                .buttonStyle(PlainButtonStyle())
                            }
                            ForEach(trendingSeries) { series in
                                Button(action: { handleSelection(.seriesDetail(series)) }) {
                                    CardView(url: URL(string: series.posterURL ?? ""), title: series.title ?? "No Title")
                                }
                                .buttonStyle(PlainButtonStyle())
                            }
                        }
                        .padding(.horizontal)
                    }
                }

                // Recommended for You
                if !recommendedMovies.isEmpty {
                    Text(NSLocalizedString("Recommended for You", comment: "Home view section title"))
                        .font(.title)
                        .padding()

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: settingsManager.accessibilityModeEnabled ? 30 : 20) {
                            ForEach(recommendedMovies) { movie in
                                Button(action: { handleSelection(.movieDetail(movie)) }) {
                                    CardView(url: URL(string: movie.posterURL ?? ""), title: movie.title ?? "No Title")
                                }
                                .buttonStyle(PlainButtonStyle())
                            }
                        }
                        .padding(.horizontal)
                    }
                }

                ForEach(franchiseGroups.keys.sorted(), id: \.self) { franchiseName in
                    Text(franchiseName)
                        .font(.title)
                        .padding()

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: settingsManager.accessibilityModeEnabled ? 30 : 20) {
                            ForEach(franchiseGroups[franchiseName] ?? []) { movie in
                                    Button(action: { handleSelection(.movieDetail(movie)) }) {
                                    CardView(url: URL(string: movie.posterURL ?? ""), title: movie.title ?? "No Title")
                                }
                                .buttonStyle(PlainButtonStyle())
                            }
                        }
                        .padding(.horizontal)
                    }
                }

                Text(NSLocalizedString("Movies", comment: "Home view section title"))
                    .font(.title)
                    .padding()

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: settingsManager.accessibilityModeEnabled ? 30 : 20) {
                        ForEach(moviesNotInFranchise) { movie in
                                Button(action: { handleSelection(.movieDetail(movie)) }) {
                                CardView(url: URL(string: movie.posterURL ?? ""), title: movie.title ?? "No Title")
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                    }
                    .padding(.horizontal)
                }

                Text(NSLocalizedString("Series", comment: "Home view section title"))
                    .font(.title)
                    .padding()

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: settingsManager.accessibilityModeEnabled ? 30 : 20) {
                        ForEach(series) { seriesItem in
                                Button(action: { handleSelection(.seriesDetail(seriesItem)) }) {
                                CardView(url: URL(string: seriesItem.posterURL ?? ""), title: seriesItem.title ?? "No Title")
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                    }
                    .padding(.horizontal)
                }

                Text(NSLocalizedString("Live TV", comment: "Home view section title"))
                    .font(.title)
                    .padding()

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: settingsManager.accessibilityModeEnabled ? 30 : 20) {
                        ForEach(channels) { channel in
                            let epgEntries = (channel.epgEntries as? Set<EPGEntry>)?.sorted { ($0.startTime ?? .distantPast) < ($1.startTime ?? .distantPast) } ?? []
                            let now = Date()
                            let nowEntry = epgEntries.first(where: { ($0.startTime ?? .distantPast) <= now && ($0.endTime ?? .distantFuture) > now })
                            let nextEntry = epgEntries.first(where: { ($0.startTime ?? .distantPast) > now })
                            CardView(
                                url: URL(string: channel.logoURL ?? ""),
                                title: channel.name ?? "No Name",
                                nowProgram: nowEntry?.title,
                                nextProgram: nextEntry?.title
                            )
                        }
                    }
                    .padding(.horizontal)
                }
            }
        }
    }
}
        .navigationTitle(NSLocalizedString("Home", comment: "Home view navigation title"))
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button(profileManager.currentProfile?.name ?? NSLocalizedString("No Profile", comment: "Button title when no profile is selected")) {
                    profileManager.deselectProfile()
                }
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(NSLocalizedString("Add Playlist", comment: "Button title to add a playlist")) {
                    showingAddPlaylist = true
                }
            }
        }
        .sheet(isPresented: $showingAddPlaylist) {
            AddPlaylistView()
        }
        .sheet(isPresented: $showSourceModePrompt) {
            if let profile = profileManager.currentProfile {
                SourceModePromptView(profile: profile, sourceManager: sourceManager)
            }
        }
        .onAppear {
            self.franchiseGroups = FranchiseGroupingManager.groupFranchises(movies: Array(movies))
            fetchRecommendations()
            checkSourceModePrompt()
        }
    }

    /// Fetches trending and recommended content from TMDb
    private func fetchRecommendations() {
        Task {
            // Fetch trending movies and series
            do {
                let tmdbTrendingMovies = try await tmdbManager.getTrendingMovies()
                let tmdbTrendingSeries = try await tmdbManager.getTrendingSeries()
                
                // Match TMDb trending with local library
                await MainActor.run {
                    trendingMovies = tmdbTrendingMovies.compactMap { tmdbMovie in
                        tmdbManager.findLocalMovie(title: tmdbMovie.title, context: viewContext)
                    }.prefix(10).map { $0 }
                    
                    trendingSeries = tmdbTrendingSeries.compactMap { tmdbSeries in
                        tmdbManager.findLocalSeries(name: tmdbSeries.name, context: viewContext)
                    }.prefix(10).map { $0 }
                }
            } catch {
                PerformanceLogger.logNetwork("Failed to fetch trending content: \(error)")
            }
            
            // Fetch recommendations based on watch history
            if let recentlyWatched = watchHistory.first?.movie {
                do {
                    // First, we need to get the TMDb ID from the movie title
                    let searchQuery = recentlyWatched.title?.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
                    if !searchQuery.isEmpty {
                        // For simplicity, just use trending as recommendations for now
                        // In production, you'd search TMDb for the movie and get similar ones
                        await MainActor.run {
                            recommendedMovies = trendingMovies.filter { $0.objectID != recentlyWatched.objectID }
                        }
                    }
                } catch {
                    PerformanceLogger.logNetwork("Failed to fetch recommendations: \(error)")
                }
            }
        }
    }

    /// Checks if source mode prompt should be shown.
    private func checkSourceModePrompt() {
        guard let profile = profileManager.currentProfile else { return }
        sourceManager.loadSources(for: profile)
        
        // Show prompt if multiple sources are active and mode hasn't been set
        let hasMultipleSources = sourceManager.activeSourceCount(for: profile) > 1
        let hasSetMode = profile.sourceMode != nil
        
        if hasMultipleSources && !hasSetMode {
            showSourceModePrompt = true
        }
    }

    /// Handles the selection of an item.
    /// - Parameter destination: The `Destination` to navigate to.
    private func handleSelection(_ destination: Destination) {
        if horizontalSizeClass == .regular {
            onItemSelected?(destination)
        } else {
            navigationCoordinator.goTo(destination)
        }
    }
}
#elseif os(tvOS)
typealias HomeView = HomeView_tvOS
#endif
