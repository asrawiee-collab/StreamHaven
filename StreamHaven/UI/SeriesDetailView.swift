import SwiftUI

struct SeriesDetailView: View {
    let series: Series

    @EnvironmentObject var profileManager: ProfileManager
    @EnvironmentObject var playbackManager: PlaybackManager
    @EnvironmentObject var favoritesManager: FavoritesManager
    @EnvironmentObject var watchHistoryManager: WatchHistoryManager

    @State private var showingPlayer = false
    @State private var selectedEpisode: Episode?
    @State private var isFavorite: Bool = false

    private var seasons: [Season] {
        let set = series.seasons as? Set<Season> ?? []
        return set.sorted {
            $0.seasonNumber < $1.seasonNumber
        }
    }

    private func episodes(for season: Season) -> [Episode] {
        let set = season.episodes as? Set<Episode> ?? []
        return set.sorted {
            $0.episodeNumber < $1.episodeNumber
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading) {
                AsyncImage(url: URL(string: series.posterURL ?? "")) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                } placeholder: {
                    ZStack {
                        Color.gray
                        Text(series.title ?? "No Title")
                            .foregroundColor(.white)
                            .multilineTextAlignment(.center)
                    }
                }
                .frame(height: 300)

                HStack {
                    Text(series.title ?? "No Title")
                        .font(.largeTitle)
                    Spacer()
                    Button(action: {
                        favoritesManager.toggleFavorite(for: series)
                        isFavorite = favoritesManager.isFavorite(item: series)
                    }) {
                        Image(systemName: isFavorite ? "heart.fill" : "heart")
                            .font(.title)
                            .foregroundColor(.red)
                    }
                }
                .padding()

                Text(series.summary ?? "No summary available.")
                    .padding()

                ForEach(seasons) { season in
                    Section(header: Text(String(format: NSLocalizedString("Season %d", comment: "Season number header"), season.seasonNumber)).font(.title2).padding()) {
                        ForEach(episodes(for: season)) { episode in
                            Button(action: {
                                self.selectedEpisode = episode
                                guard let profile = profileManager.currentProfile else { return }
                                playbackManager.loadMedia(for: episode, profile: profile)
                                let _ = PlaybackProgressTracker(player: playbackManager.player, item: episode, watchHistoryManager: watchHistoryManager)
                                showingPlayer = true
                            }) {
                                Text(episode.title ?? "No Title")
                                    .padding()
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                    }
                }

                Spacer()
            }
        }
        .navigationTitle(series.title ?? "")
        .sheet(isPresented: $showingPlayer) {
            if let player = playbackManager.player {
                PlaybackViewController(player: player)
            }
        }
        .onAppear {
            isFavorite = favoritesManager.isFavorite(item: series)
        }
    }
}
