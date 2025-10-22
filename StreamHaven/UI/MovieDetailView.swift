import SwiftUI

struct MovieDetailView: View {
    let movie: Movie

    @Environment(\.managedObjectContext) private var viewContext
    @EnvironmentObject var profileManager: ProfileManager
    @EnvironmentObject var playbackController: PlaybackController

    @State private var showingPlayer = false

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

                Text(movie.title ?? "No Title")
                    .font(.largeTitle)
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
    }
}
