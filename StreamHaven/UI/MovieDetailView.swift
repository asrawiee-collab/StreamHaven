import SwiftUI

struct MovieDetailView: View {
    let movie: Movie

    @Environment(\.managedObjectContext) private var viewContext
    @EnvironmentObject var profileManager: ProfileManager
    @EnvironmentObject var playbackController: PlaybackController
    @EnvironmentObject var favoritesManager: FavoritesManager

    @State private var showingPlayer = false
    @State private var isFavorite: Bool = false

    var body: some View {
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

                Button(action: {
                    guard let profile = profileManager.currentProfile else { return }
                    playbackController.loadMedia(for: movie, profile: profile)
                    showingPlayer = true
                }) {
                    Text("Play")
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
            if let player = playbackController.player {
                PlaybackViewController(player: player)
            }
        }
        .onAppear {
            isFavorite = favoritesManager.isFavorite(item: movie)
        }
    }
}
