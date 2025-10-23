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
        return set.sorted { $0.seasonNumber < $1.seasonNumber }
    }

    private func episodes(for season: Season) -> [Episode] {
        let set = season.episodes as? Set<Episode> ?? []
        return set.sorted { $0.episodeNumber < $1.episodeNumber }
    }

    var body: some View {
#if os(tvOS)
        tvOSDetailView
#else
        iosDetailView
#endif
    }

    private var iosDetailView: some View {
        ScrollView {
            VStack(alignment: .leading) {
                posterImage.frame(height: 300)

                HStack {
                    Text(series.title ?? "No Title")
                        .font(.largeTitle)
                    Spacer()
                    favoriteButton
                }
                .padding()

                Text(series.summary ?? "No summary available.")
                    .padding()

                episodeList

                Spacer()
            }
        }
        .navigationTitle(series.title ?? "")
        .sheet(isPresented: $showingPlayer) {
            if let player = playbackManager.player {
                PlaybackViewController(player: player)
            }
        }
        .onAppear(perform: setup)
    }

    private var tvOSDetailView: some View {
        ZStack {
            posterImage
                .scaledToFill()
                .blur(radius: 50, opaque: true)
                .ignoresSafeArea()

            Rectangle()
                .fill(.black.opacity(0.6))
                .ignoresSafeArea()

            HStack(alignment: .top, spacing: 50) {
                posterImage
                    .scaledToFit()
                    .frame(width: 400)
                    .cornerRadius(10)

                VStack(alignment: .leading, spacing: 30) {
                    Text(series.title ?? "No Title")
                        .font(.largeTitle)

                    Text(series.summary ?? "No summary available.")
                        .font(.body)

                    favoriteButton

                    episodeList

                    Spacer()
                }
            }
            .padding(50)
        }
        .fullScreenCover(isPresented: $showingPlayer) {
            if let player = playbackManager.player {
                PlaybackViewController(player: player)
            }
        }
        .onAppear(perform: setup)
    }

    // MARK: - Reusable Components

    @ViewBuilder
    private var posterImage: some View {
        AsyncImage(url: URL(string: series.posterURL ?? "")) { image in
            image.resizable()
        } placeholder: {
            ZStack {
                Color.gray
                Text(series.title ?? "No Title")
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
            }
        }
    }

    private var favoriteButton: some View {
        Button(action: {
            favoritesManager.toggleFavorite(for: series)
            isFavorite = favoritesManager.isFavorite(item: series)
        }) {
#if os(tvOS)
            Image(systemName: isFavorite ? "heart.fill" : "heart")
            Text(isFavorite ? NSLocalizedString("Favorited", comment: "Button title for favorited item") : NSLocalizedString("Add to Favorites", comment: "Button title to add an item to favorites"))
#else
            Image(systemName: isFavorite ? "heart.fill" : "heart")
                .font(.title)
                .foregroundColor(.red)
#endif
        }
    }

    private var episodeList: some View {
        ForEach(seasons) { season in
            Section(header: Text(String(format: NSLocalizedString("Season %d", comment: "Season number header"), season.seasonNumber)).font(.title2).padding(.vertical)) {
                ForEach(episodes(for: season)) { episode in
                    Button(action: { play(episode: episode) }) {
                        Text(episode.title ?? "No Title")
                            .padding(.vertical, 4)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private func setup() {
        isFavorite = favoritesManager.isFavorite(item: series)
    }

    private func play(episode: Episode) {
        self.selectedEpisode = episode
        guard let profile = profileManager.currentProfile else { return }
        playbackManager.loadMedia(for: episode, profile: profile)
        let _ = PlaybackProgressTracker(player: playbackManager.player, item: episode, watchHistoryManager: watchHistoryManager)
        showingPlayer = true
    }
}
