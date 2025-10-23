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

    var body: some View {
        List {
            if !watchHistory.isEmpty {
                Section(header: Text(NSLocalizedString("Resume Watching", comment: "Home view section title"))) {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 40) {
                            ForEach(watchHistory) { history in
                                if let movie = history.movie {
                                    NavigationLink(destination: MovieDetailView(movie: movie)) {
                                        CardView(url: URL(string: movie.posterURL ?? ""), title: movie.title ?? "No Title")
                                    }
                                    .buttonStyle(.card)
                                } else if let episode = history.episode, let series = episode.season?.series {
                                    NavigationLink(destination: SeriesDetailView(series: series)) {
                                        CardView(url: URL(string: series.posterURL ?? ""), title: episode.title ?? "No Title")
                                    }
                                    .buttonStyle(.card)
                                }
                            }
                        }
                    }
                }
            }

            Section(header: Text(NSLocalizedString("Movies", comment: "Home view section title"))) {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 40) {
                        ForEach(movies) { movie in
                            NavigationLink(destination: MovieDetailView(movie: movie)) {
                                CardView(url: URL(string: movie.posterURL ?? ""), title: movie.title ?? "No Title")
                            }
                            .buttonStyle(.card)
                        }
                    }
                }
            }

            Section(header: Text(NSLocalizedString("Series", comment: "Home view section title"))) {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 40) {
                        ForEach(series) { seriesItem in
                            NavigationLink(destination: SeriesDetailView(series: seriesItem)) {
                                CardView(url: URL(string: seriesItem.posterURL ?? ""), title: seriesItem.title ?? "No Title")
                            }
                            .buttonStyle(.card)
                        }
                    }
                }
            }

            Section(header: Text(NSLocalizedString("Live TV", comment: "Home view section title"))) {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 40) {
                        ForEach(channels) { channel in
                            CardView(url: URL(string: channel.logoURL ?? ""), title: channel.name ?? "No Name")
                        }
                    }
                }
            }
        }
        .navigationTitle(NSLocalizedString("Home", comment: "Home view navigation title"))
    }
}
#endif
