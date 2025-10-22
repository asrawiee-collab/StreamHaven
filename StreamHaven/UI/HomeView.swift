import SwiftUI
import CoreData

struct HomeView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @ObservedObject var profileManager: ProfileManager

    @FetchRequest var movies: FetchedResults<Movie>
    @FetchRequest var series: FetchedResults<Series>
    @FetchRequest var channels: FetchedResults<Channel>

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
    }

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading) {

                    Text("Movies")
                        .font(.title)
                        .padding()

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 20) {
                            ForEach(movies) { movie in
                                NavigationLink(destination: MovieDetailView(movie: movie)) {
                                    CardView(url: URL(string: movie.posterURL ?? ""), title: movie.title ?? "No Title")
                                }
                                .buttonStyle(PlainButtonStyle())
                            }
                        }
                        .padding(.horizontal)
                    }

                    Text("Series")
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

                    Text("Live TV")
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
            .navigationTitle("Home")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(profileManager.currentProfile?.name ?? "No Profile") {
                        profileManager.deselectProfile()
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Add Playlist") {
                        showingAddPlaylist = true
                    }
                }
            }
            .sheet(isPresented: $showingAddPlaylist) {
                AddPlaylistView()
            }
        }
    }
}
