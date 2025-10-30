#if os(iOS) || os(tvOS)
import CoreData
import SwiftUI

/// A view that displays the details of a series.
public struct SeriesDetailView: View {
    /// The series to display.
    let series: Series

    @EnvironmentObject var profileManager: ProfileManager
    @EnvironmentObject var playbackManager: PlaybackManager
    @EnvironmentObject var favoritesManager: FavoritesManager
    @EnvironmentObject var watchHistoryManager: WatchHistoryManager
    @EnvironmentObject var watchlistManager: WatchlistManager
    @EnvironmentObject var navigationCoordinator: NavigationCoordinator
    @EnvironmentObject var tmdbManager: TMDbManager

    @Environment(\.managedObjectContext) private var viewContext
    @StateObject private var smartSummaryManager = SmartSummaryManager()
    @State private var showingPlayer = false
    @State private var selectedEpisode: Episode?
    @State private var isFavorite: Bool = false
    @State private var smartSummary: String?
    @State private var showingWatchlistPicker = false
    @State private var isInWatchlist: Bool = false
    @State private var cast: [Actor] = []

    private var seasons: [Season] {
        let set = series.seasons as? Set<Season> ?? []
        return set.sorted { $0.seasonNumber < $1.seasonNumber }
    }

    private func episodes(for season: Season) -> [Episode] {
        let set = season.episodes as? Set<Episode> ?? []
        return set.sorted { $0.episodeNumber < $1.episodeNumber }
    }

    /// The body of the view.
    public var body: some View {
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

                // Smart Summary (Free Tier)
                if let summary = smartSummary {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("AI Summary")
                            .font(.headline)
                            .foregroundColor(.secondary)
                        Text(summary)
                            .font(.body)
                            .lineLimit(nil)
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(10)
                    .padding(.horizontal)
                } else {
                    Text(series.summary ?? "No summary available.")
                        .padding()
                }
                
                // Cast Section
                if !cast.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Cast")
                            .font(.title2)
                            .fontWeight(.bold)
                            .padding(.horizontal)
                        
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 16) {
                                ForEach(cast, id: \.tmdbID) { actor in
                                    ActorCardView(actor: actor) {
                                        navigationCoordinator.push(.actorDetail(actor))
                                    }
                                }
                            }
                            .padding(.horizontal)
                        }
                    }
                    .padding(.vertical)
                }
                
                // Add to Watchlist Button
                Button(action: { showingWatchlistPicker = true }) {
                    Label(isInWatchlist ? "In Watchlists" : "Add to Watchlist", systemImage: isInWatchlist ? "checkmark.circle.fill" : "plus.circle")
                        .font(.headline)
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(isInWatchlist ? Color.green : Color.indigo)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                }
                .padding(.horizontal)

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
        .sheet(isPresented: $showingWatchlistPicker) {
            WatchlistPickerSheet(content: series, isPresented: $showingWatchlistPicker)
                .environmentObject(watchlistManager)
                .environmentObject(profileManager)
                .onDisappear {
                    updateWatchlistStatus()
                }
        }
        .onAppear(perform: {
            setup()
            generateSmartSummary()
            loadCast()
        })
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

            ScrollView {
                HStack(alignment: .top, spacing: 50) {
                    posterImage
                        .scaledToFit()
                        .frame(width: 400)
                        .cornerRadius(10)

                    VStack(alignment: .leading, spacing: 30) {
                        Text(series.title ?? "No Title")
                            .font(.largeTitle)

                        // Smart Summary (Free Tier) for tvOS
                        if let summary = smartSummary {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("AI Summary")
                                    .font(.headline)
                                    .foregroundColor(.secondary)
                                Text(summary)
                                    .font(.body)
                            }
                        } else {
                            Text(series.summary ?? "No summary available.")
                                .font(.body)
                        }

                        favoriteButton

                        Button(action: { showingWatchlistPicker = true }) {
                            Label(isInWatchlist ? "In Watchlists" : "Add to Watchlist", systemImage: isInWatchlist ? "checkmark.circle.fill" : "plus.circle")
                                .font(.title2)
                                .padding(.horizontal, 24)
                                .padding(.vertical, 12)
                                .background(isInWatchlist ? Color.green : Color.indigo)
                                .foregroundColor(.white)
                                .clipShape(Capsule())
                        }

                        episodeList
                    }

                    Spacer()
                }
                .padding(50)
            }
        }
        .fullScreenCover(isPresented: $showingPlayer) {
            if let player = playbackManager.player {
                PlaybackViewController(player: player)
            }
        }
        .sheet(isPresented: $showingWatchlistPicker) {
            WatchlistPickerSheet(content: series, isPresented: $showingWatchlistPicker)
                .environmentObject(watchlistManager)
                .environmentObject(profileManager)
                .onDisappear {
                    updateWatchlistStatus()
                }
        }
        .onAppear {
            setup()
            generateSmartSummary()
        }
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
        .accessibilityLabel(Text(NSLocalizedString("Favorite", comment: "Accessibility label for favorite button")))
        .accessibilityHint(isFavorite ? Text(NSLocalizedString("Removes the series from favorites", comment: "Accessibility hint for favorited item")) : Text(NSLocalizedString("Adds the series to favorites", comment: "Accessibility hint for add to favorites button")))
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
                    .accessibilityLabel(Text(episode.title ?? "No Title"))
                    .accessibilityHint(Text(NSLocalizedString("Plays the episode", comment: "Accessibility hint for play episode button")))
                }
            }
        }
    }

    private func setup() {
        isFavorite = favoritesManager.isFavorite(item: series)
        updateWatchlistStatus()
    }
    
    /// Updates watchlist status for this series.
    private func updateWatchlistStatus() {
        guard let profile = profileManager.currentProfile else { return }
        isInWatchlist = watchlistManager.isInAnyWatchlist(series, profile: profile)
    }

    private func play(episode: Episode) {
        self.selectedEpisode = episode
        guard let profile = profileManager.currentProfile else { return }
        playbackManager.loadMedia(for: episode, profile: profile)
        showingPlayer = true
    }

    /// Generates smart summary using NaturalLanguage framework
    private func generateSmartSummary() {
        guard let fullPlot = series.summary, !fullPlot.isEmpty else {
            return
        }

        let cacheKey = "series_\(series.objectID.uriRepresentation().absoluteString)"
        smartSummary = smartSummaryManager.getCachedSummary(cacheKey: cacheKey, fullPlot: fullPlot)
    }

    /// Loads cast members for this series.
    private func loadCast() {
        // Fetch credits if not already loaded
        if let credits = series.credits as? Set<Credit>, !credits.isEmpty {
            let sortedCredits = credits
                .filter { $0.creditType == "cast" }
                .sorted { $0.order < $1.order }
            cast = sortedCredits.compactMap { $0.actor }
        } else {
            // Fetch from TMDb in background
            Task {
                await tmdbManager.fetchSeriesCredits(for: series, context: viewContext)
                
                // Reload cast after fetch
                if let credits = series.credits as? Set<Credit> {
                    let sortedCredits = credits
                        .filter { $0.creditType == "cast" }
                        .sorted { $0.order < $1.order }
                    await MainActor.run {
                        cast = sortedCredits.compactMap { $0.actor }
                    }
                }
            }
        }
    }
}
#endif
