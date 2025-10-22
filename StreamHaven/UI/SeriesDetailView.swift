import SwiftUI

struct SeriesDetailView: View {
    let series: Series

    @EnvironmentObject var profileManager: ProfileManager
    @StateObject private var playbackController: PlaybackController

    @State private var showingPlayer = false
    @State private var selectedEpisode: Episode?

    init(series: Series) {
        self.series = series
        _playbackController = StateObject(wrappedValue: PlaybackController(context: PersistenceController.shared.container.viewContext))
    }

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

                Text(series.title ?? "No Title")
                    .font(.largeTitle)
                    .padding()

                Text(series.summary ?? "No summary available.")
                    .padding()

                ForEach(seasons) { season in
                    Section(header: Text("Season \\(season.seasonNumber)").font(.title2).padding()) {
                        ForEach(episodes(for: season)) { episode in
                            Button(action: {
                                self.selectedEpisode = episode
                                guard let profile = profileManager.currentProfile else { return }
                                playbackController.loadMedia(for: episode, profile: profile)
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
            if let player = playbackController.player {
                PlaybackViewController(player: player)
            }
        }
    }
}
