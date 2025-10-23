import SwiftUI
import CoreData

#if os(iOS)
struct HomeView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @ObservedObject var profileManager: ProfileManager

    @FetchRequest var movies: FetchedResults<Movie>
    @FetchRequest var series: FetchedResults<Series>
    @FetchRequest var channels: FetchedResults<Channel>
    @FetchRequest var watchHistory: FetchedResults<WatchHistory>

    @State private var showingAddPlaylist = false

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

    @State private var franchiseGroups: [String: [Movie]] = [:]

    private var moviesNotInFranchise: [Movie] {
        let franchiseMovieIDs = franchiseGroups.values.flatMap { $0 }.map { $0.objectID }
        return movies.filter { !franchiseMovieIDs.contains($0.objectID) }
    }

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading) {

                    if !watchHistory.isEmpty {
                        Text(NSLocalizedString("Resume Watching", comment: "Home view section title"))
                            .font(.title)
                            .padding()

                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 20) {
                                ForEach(watchHistory) { history in
                                    if let movie = history.movie {
                                        NavigationLink(destination: MovieDetailView(movie: movie)) {
                                            CardView(url: URL(string: movie.posterURL ?? ""), title: movie.title ?? "No Title")
                                        }
                                        .buttonStyle(PlainButtonStyle())
                                    } else if let episode = history.episode, let series = episode.season?.series {
                                        NavigationLink(destination: SeriesDetailView(series: series)) {
                                            CardView(url: URL(string: series.posterURL ?? ""), title: episode.title ?? "No Title")
                                        }
                                        .buttonStyle(PlainButtonStyle())
                                    }
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
                            HStack(spacing: 20) {
                                ForEach(franchiseGroups[franchiseName]!) { movie in
                                    NavigationLink(destination: MovieDetailView(movie: movie)) {
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
                        HStack(spacing: 20) {
                            ForEach(moviesNotInFranchise) { movie in
                                NavigationLink(destination: MovieDetailView(movie: movie)) {
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
                        HStack(spacing: 20) {
                            ForEach(series) { seriesItem in
                                NavigationLink(destination: SeriesDetailView(series: seriesItem)) {
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
                        HStack(spacing: 20) {
                            ForEach(channels) { channel in
                                CardView(url: URL(string: channel.logoURL ?? ""), title: channel.name ?? "No Name")
                            }
                        }
                        .padding(.horizontal)
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
        }
        .onAppear {
            self.franchiseGroups = FranchiseGroupingManager.groupFranchises(movies: Array(movies))
        }
    }
}
#elseif os(tvOS)
typealias HomeView = HomeView_tvOS
#endif
