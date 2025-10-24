import SwiftUI

/// A view that displays the details of a movie.
public struct MovieDetailView: View {
    /// The movie to display.
    let movie: Movie

    @Environment(\.managedObjectContext) private var viewContext
    @EnvironmentObject var profileManager: ProfileManager
    @EnvironmentObject var playbackManager: PlaybackManager
    @EnvironmentObject var favoritesManager: FavoritesManager
    @EnvironmentObject var watchHistoryManager: WatchHistoryManager
    @EnvironmentObject var tmdbManager: TMDbManager

    @State private var showingPlayer = false
    @State private var isFavorite: Bool = false

    /// The body of the view.
    public var body: some View {
#if os(tvOS)
        tvOSDetailView
#else
        iosDetailView
#endif
    }

    /// The detail view for iOS.
    private var iosDetailView: some View {
        ScrollView {
            VStack(alignment: .leading) {
                AsyncImage(url: URL(string: movie.posterURL ?? "")) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                } placeholder: {
                    ZStack {
                        Color.gray
                        Text(movie.title ?? "No Title")
                            .foregroundColor(.white)
                            .multilineTextAlignment(.center)
                    }
                }
                .frame(height: 300)

                HStack {
                    Text(movie.title ?? "No Title")
                        .font(.largeTitle)
                    Spacer()
                    Button(action: {
                        favoritesManager.toggleFavorite(for: movie)
                        isFavorite = favoritesManager.isFavorite(item: movie)
                    }) {
                        Image(systemName: isFavorite ? "heart.fill" : "heart")
                            .font(.title)
                            .foregroundColor(.red)
                    }
                }
                .padding()

                Text(movie.summary ?? "No summary available.")
                    .padding()

                Button(action: playMovie) {
                    Text(NSLocalizedString("Play", comment: "Button title to play a movie"))
                        .font(.headline)
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                }
                .padding()

                Spacer()
            }
        }
        .navigationTitle(movie.title ?? "")
        .sheet(isPresented: $showingPlayer) {
            if let player = playbackManager.player {
                PlaybackViewController(player: player, imdbID: movie.imdbID)
            }
        }
        .onAppear(perform: {
            setup()
            fetchIMDbID()
        })
    }

    /// The detail view for tvOS.
    private var tvOSDetailView: some View {
        ZStack {
            AsyncImage(url: URL(string: movie.posterURL ?? "")) { image in
                image.resizable()
            } placeholder: { Color.clear }
            .scaledToFill()
            .blur(radius: 50, opaque: true)
            .ignoresSafeArea()

            Rectangle()
                .fill(.black.opacity(0.6))
                .ignoresSafeArea()

            HStack(alignment: .top, spacing: 50) {
                AsyncImage(url: URL(string: movie.posterURL ?? "")) { image in
                    image.resizable()
                } placeholder: { Color.gray }
                .scaledToFit()
                .frame(width: 400)
                .cornerRadius(10)

                VStack(alignment: .leading, spacing: 30) {
                    Text(movie.title ?? "No Title")
                        .font(.largeTitle)

                    Text(movie.summary ?? "No summary available.")
                        .font(.body)

                    HStack(spacing: 30) {
                        Button(action: playMovie) {
                            Text(NSLocalizedString("Play", comment: "Button title to play a movie"))
                        }
                        .accessibilityLabel(Text(NSLocalizedString("Play", comment: "Accessibility label for play button")))

                        Button(action: {
                            favoritesManager.toggleFavorite(for: movie)
                            isFavorite = favoritesManager.isFavorite(item: movie)
                        }) {
                            Image(systemName: isFavorite ? "heart.fill" : "heart")
                            Text(isFavorite ? NSLocalizedString("Favorited", comment: "Button title for favorited item") : NSLocalizedString("Add to Favorites", comment: "Button title to add an item to favorites"))
                        }
                        .accessibilityLabel(isFavorite ? Text(NSLocalizedString("Remove from favorites", comment: "Accessibility label for favorited item")) : Text(NSLocalizedString("Add to favorites", comment: "Accessibility label for add to favorites button")))
                    }

                    Spacer()
                }
            }
            .padding(50)
        }
        .fullScreenCover(isPresented: $showingPlayer) {
            if let player = playbackManager.player {
                PlaybackViewController(player: player, imdbID: movie.imdbID)
            }
        }
        .onAppear(perform: {
            setup()
            fetchIMDbID()
        })
    }

    /// Sets up the view.
    private func setup() {
        isFavorite = favoritesManager.isFavorite(item: movie)
    }

    /// Plays the movie.
    private func playMovie() {
        guard let profile = profileManager.currentProfile else { return }
        playbackManager.loadMedia(for: movie, profile: profile)
        showingPlayer = true
    }

    /// Fetches the IMDb ID for the movie.
    private func fetchIMDbID() {
        Task {
            await tmdbManager.fetchIMDbID(for: movie, context: viewContext)
        }
    }
}
