#if os(tvOS)
import CoreData
import SwiftUI

/// A view that displays the user's library of movies, series, and channels on tvOS.
public struct HomeView_tvOS: View {
    @Environment(\.managedObjectContext) private var viewContext
    @ObservedObject var profileManager: ProfileManager
    @EnvironmentObject var settingsManager: SettingsManager
    @EnvironmentObject var previewManager: HoverPreviewManager

    @FetchRequest var movies: FetchedResults<Movie>
    @FetchRequest var series: FetchedResults<Series>
    @FetchRequest var channels: FetchedResults<Channel>
    @FetchRequest var watchHistory: FetchedResults<WatchHistory>
    @State private var backgroundPosterURL: URL?
    @State private var trendingMovies: [Movie] = []
    @State private var trendingSeries: [Series] = []
    @State private var recommendedMovies: [Movie] = []
    @EnvironmentObject var tmdbManager: TMDbManager

    /// Initializes a new `HomeView_tvOS`.
    /// - Parameter profileManager: The `ProfileManager` for accessing the current profile.
    public init(profileManager: ProfileManager) {
        self.profileManager = profileManager

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
            sortDescriptors: [NSSortDescriptor(keyPath: \Movie.releaseDate, ascending: false)], predicate: moviePredicate, animation: .default)

        _series = FetchRequest<Series>(
            sortDescriptors: [NSSortDescriptor(keyPath: \Series.releaseDate, ascending: false)], predicate: seriesPredicate, animation: .default)

        _channels = FetchRequest<Channel>(
            sortDescriptors: [NSSortDescriptor(keyPath: \Channel.name, ascending: true)], animation: .default)

        var watchHistoryPredicate = NSPredicate(value: false)
        if let profile = profileManager.currentProfile {
            watchHistoryPredicate = NSPredicate(format: "profile == %@", profile)
        }

        _watchHistory = FetchRequest<WatchHistory>(
            sortDescriptors: [NSSortDescriptor(keyPath: \WatchHistory.watchedDate, ascending: false)], predicate: watchHistoryPredicate, animation: .default)
    }

    private var sectionHeader: (String) -> some View {
        return { title in
            Text(title)
                .font(.headline)
                .padding(.leading)
        }
    }

    /// The body of the view.
    public var body: some View {
        ZStack {
            // Animated blurred background
            AsyncImage(url: backgroundPosterURL) { image in
                image.resizable()
            } placeholder: {
                Color.clear
            }
            .scaledToFill()
            .blur(radius: 50, opaque: true)
            .ignoresSafeArea()
            .animation(.easeInOut.speed(0.2), value: backgroundPosterURL)

            // Dimming overlay
            Rectangle()
                .fill(.black.opacity(0.5))
                .ignoresSafeArea()

            // Foreground content
            ScrollView(.vertical) {
                VStack(alignment: .leading, spacing: 30) {
                    if !watchHistory.isEmpty {
                        sectionHeader(NSLocalizedString("Resume Watching", comment: "Home view section title"))

                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 50) {
                                ForEach(watchHistory) { history in
                                    if let movie = history.movie {
                                        MovieCardWithPreview(
                                            movie: movie, previewManager: previewManager, backgroundURL: $backgroundPosterURL
                                        )
                                    } else if let episode = history.episode, let series = episode.season?.series {
                                        SeriesCardWithPreview(
                                            series: series, previewManager: previewManager, backgroundURL: $backgroundPosterURL
                                        )
                                    }
                                }
                            }
                            .padding(.horizontal)
                        }
                    }

                    // Trending This Week
                    if !trendingMovies.isEmpty || !trendingSeries.isEmpty {
                        sectionHeader(NSLocalizedString("Trending This Week", comment: "Home view section title"))

                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 50) {
                                ForEach(trendingMovies) { movie in
                                    MovieCardWithPreview(
                                        movie: movie, previewManager: previewManager, backgroundURL: $backgroundPosterURL
                                    )
                                }
                                ForEach(trendingSeries) { series in
                                    SeriesCardWithPreview(
                                        series: series, previewManager: previewManager, backgroundURL: $backgroundPosterURL
                                    )
                                }
                            }
                            .padding(.horizontal)
                        }
                    }

                    // Recommended for You
                    if !recommendedMovies.isEmpty {
                        sectionHeader(NSLocalizedString("Recommended for You", comment: "Home view section title"))

                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 50) {
                                ForEach(recommendedMovies) { movie in
                                    MovieCardWithPreview(
                                        movie: movie, previewManager: previewManager, backgroundURL: $backgroundPosterURL
                                    )
                                }
                            }
                            .padding(.horizontal)
                        }
                    }

                    sectionHeader(NSLocalizedString("Movies", comment: "Home view section title"))

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 50) {
                            ForEach(movies) { movie in
                                MovieCardWithPreview(
                                    movie: movie, previewManager: previewManager, backgroundURL: $backgroundPosterURL
                                )
                            }
                        }
                        .padding(.horizontal)
                    }

                    sectionHeader(NSLocalizedString("Series", comment: "Home view section title"))

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 50) {
                            ForEach(series) { seriesItem in
                                SeriesCardWithPreview(
                                    series: seriesItem, previewManager: previewManager, backgroundURL: $backgroundPosterURL
                                )
                            }
                        }
                        .padding(.horizontal)
                    }

                    sectionHeader(NSLocalizedString("Live TV", comment: "Home view section title"))

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 50) {
                            ForEach(channels) { channel in
                                CarouselItemView(url: channel.logoURL, title: channel.name, destination: EmptyView(), backgroundURL: $backgroundPosterURL)
                            }
                        }
                        .padding(.horizontal)
                    }
                }
                .padding(.top, 40)
            }
            .navigationTitle(NSLocalizedString("Home", comment: "Home view navigation title"))
        }
        .onAppear {
            // Set initial background
            if let firstMovie = movies.first {
                backgroundPosterURL = URL(string: firstMovie.posterURL ?? "")
            }
            fetchRecommendations()
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
                    // For simplicity, use trending as recommendations
                    // In production, you'd use TMDb similar movies API
                    await MainActor.run {
                        recommendedMovies = trendingMovies.filter { $0.objectID != recentlyWatched.objectID }
                    }
                } catch {
                    PerformanceLogger.logNetwork("Failed to fetch recommendations: \(error)")
                }
            }
        }
    }
}

/// A view that displays a carousel item.
fileprivate struct CarouselItemView<Destination: View>: View {
    let url: String?
    let title: String?
    let destination: Destination
    @Binding var backgroundURL: URL?
    @State private var isFocused = false

    var body: some View {
        NavigationLink(destination: destination) {
            CardView(url: URL(string: url ?? ""), title: title ?? "No Title")
        }
        .buttonStyle(.card)
        .scaleEffect(isFocused ? 1.1: 1.0)
        .shadow(radius: isFocused ? 20: 0)
        .animation(.easeInOut, value: isFocused)
        .focusable { focused in
            self.isFocused = focused
            if focused {
                backgroundURL = URL(string: url ?? "")
            }
        }
        .accessibilityLabel(title ?? "")
    }
}
#endif
