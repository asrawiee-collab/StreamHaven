#if os(tvOS)
import SwiftUI
import CoreData

struct HomeView_tvOS: View {
    @Environment(\.managedObjectContext) private var viewContext
    @ObservedObject var profileManager: ProfileManager

    @FetchRequest var movies: FetchedResults<Movie>
    @FetchRequest var series: FetchedResults<Series>
    @FetchRequest var channels: FetchedResults<Channel>
    @FetchRequest var watchHistory: FetchedResults<WatchHistory>
    @State private var backgroundPosterURL: URL?

    init(profileManager: ProfileManager) {
        self.profileManager = profileManager

        var moviePredicate = NSPredicate(value: true)
        var seriesPredicate = NSPredicate(value: true)
        if let profile = profileManager.currentProfile, !profile.isAdult {
            let allowedRatings = [Rating.g.rawValue, Rating.pg.rawValue, Rating.pg13.rawValue, Rating.unrated.rawValue]
            moviePredicate = NSPredicate(format: "rating IN %@", allowedRatings)
            seriesPredicate = NSPredicate(format: "rating IN %@", allowedRatings)
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

    private var sectionHeader: (String) -> some View {
        return { title in
            Text(title)
                .font(.headline)
                .padding(.leading)
        }
    }

    var body: some View {
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
                                        CarouselItemView(url: movie.posterURL, title: movie.title, destination: MovieDetailView(movie: movie), backgroundURL: $backgroundPosterURL)
                                    } else if let episode = history.episode, let series = episode.season?.series {
                                        CarouselItemView(url: series.posterURL, title: episode.title, destination: SeriesDetailView(series: series), backgroundURL: $backgroundPosterURL)
                                    }
                                }
                            }
                            .padding(.horizontal)
                        }
                    }

                    sectionHeader(NSLocalizedString("Movies", comment: "Home view section title"))

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 50) {
                            ForEach(movies) { movie in
                                CarouselItemView(url: movie.posterURL, title: movie.title, destination: MovieDetailView(movie: movie), backgroundURL: $backgroundPosterURL)
                            }
                        }
                        .padding(.horizontal)
                    }

                    sectionHeader(NSLocalizedString("Series", comment: "Home view section title"))

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 50) {
                            ForEach(series) { seriesItem in
                                CarouselItemView(url: seriesItem.posterURL, title: seriesItem.title, destination: SeriesDetailView(series: seriesItem), backgroundURL: $backgroundPosterURL)
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
        }
    }
}

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
        .scaleEffect(isFocused ? 1.1 : 1.0)
        .shadow(radius: isFocused ? 20 : 0)
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
