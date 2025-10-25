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
    @EnvironmentObject var downloadManager: DownloadManager
    @EnvironmentObject var queueManager: UpNextQueueManager
    @EnvironmentObject var watchlistManager: WatchlistManager

    @StateObject private var smartSummaryManager = SmartSummaryManager()
    @State private var showingPlayer = false
    @State private var isFavorite: Bool = false
    @State private var smartSummary: String?
    @State private var isDownloaded: Bool = false
    @State private var downloadProgress: Float = 0.0
    @State private var isInQueue: Bool = false
    @State private var showingWatchlistPicker = false
    @State private var isInWatchlist: Bool = false

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
                    Text(movie.summary ?? "No summary available.")
                        .padding()
                }

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

#if !os(tvOS)
                // Download Button (iOS only)
                HStack {
                    if isDownloaded {
                        Button(action: deleteDownload) {
                            Label("Downloaded", systemImage: "checkmark.circle.fill")
                                .font(.headline)
                                .padding()
                                .frame(maxWidth: .infinity)
                                .background(Color.green)
                                .foregroundColor(.white)
                                .cornerRadius(10)
                        }
                    } else if let activeDownload = getActiveDownload() {
                        VStack {
                            HStack {
                                Button(action: {
                                    if activeDownload.downloadStatus == .downloading {
                                        downloadManager.pauseDownload(activeDownload)
                                    } else {
                                        downloadManager.resumeDownload(activeDownload)
                                    }
                                }) {
                                    Image(systemName: activeDownload.downloadStatus == .downloading ? "pause.circle" : "play.circle")
                                        .font(.title2)
                                }
                                
                                ProgressView(value: downloadProgress)
                                    .progressViewStyle(LinearProgressViewStyle())
                                
                                Button(action: {
                                    downloadManager.cancelDownload(activeDownload)
                                }) {
                                    Image(systemName: "xmark.circle")
                                        .font(.title2)
                                }
                            }
                            .padding()
                            
                            Text("\(Int(downloadProgress * 100))% Downloaded")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    } else {
                        Button(action: startDownload) {
                            Label("Download", systemImage: "arrow.down.circle")
                                .font(.headline)
                                .padding()
                                .frame(maxWidth: .infinity)
                                .background(Color.purple)
                                .foregroundColor(.white)
                                .cornerRadius(10)
                        }
                    }
                }
                .padding(.horizontal)
#endif
                
                // Add to Up Next Button
                Button(action: addToQueue) {
                    Label(isInQueue ? "In Up Next" : "Add to Up Next", systemImage: isInQueue ? "checkmark.circle.fill" : "text.badge.plus")
                        .font(.headline)
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(isInQueue ? Color.green : Color.orange)
                .padding(.horizontal)
                .disabled(isInQueue)
                
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

                Spacer()
            }
        }
        .navigationTitle(movie.title ?? "")
        .sheet(isPresented: $showingPlayer) {
            if let player = playbackManager.player {
                PlaybackViewController(player: player, imdbID: movie.imdbID)
            }
        }
        .sheet(isPresented: $showingWatchlistPicker) {
            WatchlistPickerSheet(content: movie, isPresented: $showingWatchlistPicker)
                .environmentObject(watchlistManager)
                .environmentObject(profileManager)
                .onDisappear {
                    updateWatchlistStatus()
                }
        }
        .onAppear(perform: {
            setup()
            fetchIMDbID()
            generateSmartSummary()
        })
        .onReceive(downloadManager.$activeDownloads) { _ in
            updateDownloadProgress()
        }
        .onReceive(downloadManager.$completedDownloads) { _ in
            isDownloaded = downloadManager.isDownloaded(movie)
        }
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
                        .accessibilityLabel(Text(movie.title ?? "No Title"))
                        .accessibilityHint(Text(NSLocalizedString("Plays the movie", comment: "Accessibility hint for play button")))

                        Button(action: {
                            favoritesManager.toggleFavorite(for: movie)
                            isFavorite = favoritesManager.isFavorite(item: movie)
                        }) {
                            Image(systemName: isFavorite ? "heart.fill" : "heart")
                            Text(isFavorite ? NSLocalizedString("Favorited", comment: "Button title for favorited item") : NSLocalizedString("Add to Favorites", comment: "Button title to add an item to favorites"))
                        }
                        .accessibilityLabel(Text(NSLocalizedString("Favorite", comment: "Accessibility label for favorite button")))
                        .accessibilityHint(isFavorite ? Text(NSLocalizedString("Removes the movie from favorites", comment: "Accessibility hint for favorited item")) : Text(NSLocalizedString("Adds the movie to favorites", comment: "Accessibility hint for add to favorites button")))
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
            generateSmartSummary()
        })
        .onReceive(downloadManager.$activeDownloads) { _ in
            updateDownloadProgress()
        }
        .onReceive(downloadManager.$completedDownloads) { _ in
            isDownloaded = downloadManager.isDownloaded(movie)
        }
    }

    /// Sets up the view.
    private func setup() {
        isFavorite = favoritesManager.isFavorite(item: movie)
        isDownloaded = downloadManager.isDownloaded(movie)
        updateDownloadProgress()
        updateQueueStatus()
        updateWatchlistStatus()
    }
    
    /// Updates queue status for this movie.
    private func updateQueueStatus() {
        guard let profile = profileManager.currentProfile else { return }
        isInQueue = queueManager.isInQueue(movie, profile: profile)
    }
    
    /// Updates watchlist status for this movie.
    private func updateWatchlistStatus() {
        guard let profile = profileManager.currentProfile else { return }
        isInWatchlist = watchlistManager.isInAnyWatchlist(movie, profile: profile)
    }

    /// Updates download progress for active downloads.
    private func updateDownloadProgress() {
        if let activeDownload = getActiveDownload() {
            downloadProgress = activeDownload.progress
        }
    }

    /// Gets the active download for this movie.
    private func getActiveDownload() -> Download? {
        return downloadManager.activeDownloads.first { $0.movie == movie }
    }

    /// Starts downloading the movie.
    private func startDownload() {
        do {
            try downloadManager.startDownload(
                for: movie,
                title: movie.title ?? "Unknown Movie",
                thumbnailURL: movie.posterURL
            )
            isDownloaded = false
        } catch {
            print("Download error: \(error.localizedDescription)")
        }
    }

    /// Deletes the downloaded movie.
    private func deleteDownload() {
        if let download = downloadManager.completedDownloads.first(where: { $0.movie == movie }) {
            downloadManager.deleteDownload(download)
            isDownloaded = false
        }
    }
    
    /// Adds the movie to Up Next queue.
    private func addToQueue() {
        guard let profile = profileManager.currentProfile else { return }
        
        do {
            try queueManager.addToQueue(movie, profile: profile, autoAdded: false)
            isInQueue = true
        } catch {
            print("Queue error: \(error.localizedDescription)")
        }
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

    /// Generates smart summary using NaturalLanguage framework
    private func generateSmartSummary() {
        guard let fullPlot = movie.summary, !fullPlot.isEmpty else {
            return
        }

        let cacheKey = "movie_\(movie.objectID.uriRepresentation().absoluteString)"
        smartSummary = smartSummaryManager.getCachedSummary(cacheKey: cacheKey, fullPlot: fullPlot)
    }
}

// MARK: - Watchlist Picker Sheet

struct WatchlistPickerSheet: View {
    @EnvironmentObject var watchlistManager: WatchlistManager
    @EnvironmentObject var profileManager: ProfileManager
    
    let content: NSManagedObject
    @Binding var isPresented: Bool
    
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var showingCreateSheet = false
    
    var body: some View {
        NavigationView {
            List {
                if watchlistManager.watchlists.isEmpty {
                    VStack(spacing: 16) {
                        Text("No watchlists yet")
                            .font(.headline)
                            .foregroundColor(.secondary)
                        
                        Button(action: { showingCreateSheet = true }) {
                            Label("Create Watchlist", systemImage: "plus.circle.fill")
                                .font(.headline)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                } else {
                    ForEach(watchlistManager.watchlists, id: \.objectID) { watchlist in
                        WatchlistPickerRow(
                            watchlist: watchlist,
                            content: content,
                            isPresented: $isPresented,
                            showError: $showError,
                            errorMessage: $errorMessage
                        )
                        .environmentObject(watchlistManager)
                        .environmentObject(profileManager)
                    }
                }
            }
            .navigationTitle("Add to Watchlist")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        isPresented = false
                    }
                }
                
                if !watchlistManager.watchlists.isEmpty {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button(action: { showingCreateSheet = true }) {
                            Image(systemName: "plus")
                        }
                    }
                }
            }
            .sheet(isPresented: $showingCreateSheet) {
                CreateWatchlistSheet(isPresented: $showingCreateSheet)
                    .environmentObject(watchlistManager)
                    .environmentObject(profileManager)
                    .onDisappear {
                        if let profile = profileManager.currentProfile {
                            watchlistManager.loadWatchlists(for: profile)
                        }
                    }
            }
            .alert("Error", isPresented: $showError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorMessage)
            }
            .onAppear {
                if let profile = profileManager.currentProfile {
                    watchlistManager.loadWatchlists(for: profile)
                }
            }
        }
    }
}

// MARK: - Watchlist Picker Row

struct WatchlistPickerRow: View {
    @EnvironmentObject var watchlistManager: WatchlistManager
    @EnvironmentObject var profileManager: ProfileManager
    
    let watchlist: Watchlist
    let content: NSManagedObject
    @Binding var isPresented: Bool
    @Binding var showError: Bool
    @Binding var errorMessage: String
    
    @State private var isInWatchlist = false
    
    var body: some View {
        Button(action: toggleWatchlist) {
            HStack {
                Image(systemName: watchlist.icon)
                    .foregroundColor(.blue)
                    .frame(width: 30)
                
                VStack(alignment: .leading) {
                    Text(watchlist.name)
                        .font(.headline)
                    Text("\(watchlist.itemCount) items")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                if isInWatchlist {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                }
            }
        }
        .onAppear {
            updateStatus()
        }
    }
    
    private func updateStatus() {
        let contentID = content.objectID.uriRepresentation().absoluteString
        isInWatchlist = watchlist.contains(contentID: contentID)
    }
    
    private func toggleWatchlist() {
        do {
            if isInWatchlist {
                // Find and remove the item
                if let item = watchlist.sortedItems.first(where: {
                    $0.contentID == content.objectID.uriRepresentation().absoluteString
                }) {
                    try watchlistManager.removeFromWatchlist(item, watchlist: watchlist)
                    isInWatchlist = false
                }
            } else {
                // Add to watchlist
                try watchlistManager.addToWatchlist(content, watchlist: watchlist)
                isInWatchlist = true
            }
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
    }
}
