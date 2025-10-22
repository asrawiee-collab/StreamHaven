import SwiftUI
import CoreData

struct HomeView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @ObservedObject var profileManager: ProfileManager

    @State private var movies: [Movie] = []
    @State private var series: [Series] = []
    @State private var channels: [Channel] = []

    @State private var showingAddPlaylist = false

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
                                NavigationLink(destination: MovieDetailView(movie: movie).environmentObject(profileManager)) {
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
                                NavigationLink(destination: SeriesDetailView(series: seriesItem).environmentObject(profileManager)) {
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
                    .environment(\.managedObjectContext, self.viewContext)
            }
            .onAppear(perform: fetchContent)
        }
    }

    private func fetchContent() {
        fetchMovies()
        fetchSeries()
        fetchChannels()
    }

    private func fetchMovies() {
        let request: NSFetchRequest<Movie> = Movie.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(keyPath: \Movie.releaseDate, ascending: false)]

        if let profile = profileManager.currentProfile, !profile.isAdult {
            let allowedRatings = [Rating.g.rawValue, Rating.pg.rawValue, Rating.pg13.rawValue, Rating.unrated.rawValue]
            request.predicate = NSPredicate(format: "rating IN %@", allowedRatings)
        }

        do {
            movies = try viewContext.fetch(request)
        } catch {
            print("Failed to fetch movies: \\(error)")
        }
    }

    private func fetchSeries() {
        let request: NSFetchRequest<Series> = Series.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(keyPath: \Series.releaseDate, ascending: false)]

        if let profile = profileManager.currentProfile, !profile.isAdult {
            let allowedRatings = [Rating.g.rawValue, Rating.pg.rawValue, Rating.pg13.rawValue, Rating.unrated.rawValue]
            request.predicate = NSPredicate(format: "rating IN %@", allowedRatings)
        }

        do {
            series = try viewContext.fetch(request)
        } catch {
            print("Failed to fetch series: \\(error)")
        }
    }

    private func fetchChannels() {
        let request: NSFetchRequest<Channel> = Channel.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(keyPath: \Channel.name, ascending: true)]
        do {
            channels = try viewContext.fetch(request)
        } catch {
            print("Failed to fetch channels: \\(error)")
        }
    }
}
