import SwiftUI
import CoreData

/// A view displaying an actor's filmography filtered from local library.
struct ActorDetailView: View {
    let actor: Actor
    
    @Environment(\.managedObjectContext) private var viewContext
    @EnvironmentObject var navigationCoordinator: NavigationCoordinator
    @EnvironmentObject var settingsManager: SettingsManager
    
    @State private var movies: [Movie] = []
    @State private var series: [Series] = []
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Actor Header
                HStack(spacing: 20) {
                    AsyncImage(url: URL(string: actor.photoURL ?? "")) { image in
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    } placeholder: {
                        ZStack {
                            Color.gray.opacity(0.3)
                            Image(systemName: "person.fill")
                                .foregroundColor(.gray)
                                .font(.system(size: 60))
                        }
                    }
                    .frame(width: 150, height: 225)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text(actor.name ?? "Unknown Actor")
                            .font(.largeTitle)
                            .fontWeight(.bold)
                        
                        if let biography = actor.biography, !biography.isEmpty {
                            Text(biography)
                                .font(.body)
                                .lineLimit(5)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .padding()
                
                // Movies Section
                if !movies.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Movies in Your Library")
                            .font(.title2)
                            .fontWeight(.bold)
                            .padding(.horizontal)
                        
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 150))], spacing: 20) {
                            ForEach(movies, id: \.objectID) { movie in
                                Button(action: {
                                    navigationCoordinator.push(.movieDetail(movie))
                                }) {
                                    CardView(
                                        url: URL(string: movie.posterURL ?? ""),
                                        title: movie.title ?? "No Title"
                                    )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.horizontal)
                    }
                }
                
                // Series Section
                if !series.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Series in Your Library")
                            .font(.title2)
                            .fontWeight(.bold)
                            .padding(.horizontal)
                        
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 150))], spacing: 20) {
                            ForEach(series, id: \.objectID) { seriesItem in
                                Button(action: {
                                    navigationCoordinator.push(.seriesDetail(seriesItem))
                                }) {
                                    CardView(
                                        url: URL(string: seriesItem.posterURL ?? ""),
                                        title: seriesItem.title ?? "No Title"
                                    )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.horizontal)
                    }
                }
                
                // Empty State
                if movies.isEmpty && series.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "film.stack")
                            .font(.system(size: 60))
                            .foregroundColor(.gray)
                        Text("No content found in your library")
                            .font(.title3)
                            .foregroundColor(.secondary)
                        Text("This actor appears in other titles not currently in your playlists")
                            .font(.body)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 40)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.top, 100)
                }
            }
        }
        .navigationTitle(actor.name ?? "Actor")
        .onAppear {
            loadFilmography()
        }
    }
    
    /// Loads movies and series featuring this actor from local library.
    private func loadFilmography() {
        guard let credits = actor.credits as? Set<Credit> else { return }
        
        // Extract movies
        let movieCredits = credits.compactMap { $0.movie }
        movies = movieCredits.sorted { ($0.title ?? "") < ($1.title ?? "") }
        
        // Extract series
        let seriesCredits = credits.compactMap { $0.series }
        series = seriesCredits.sorted { ($0.title ?? "") < ($1.title ?? "") }
    }
}
