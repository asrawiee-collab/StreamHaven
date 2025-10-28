import AVKit
import CoreData
import Combine
import CoreMedia
import os.log
#if canImport(Sentry)
import Sentry
#endif

/// A class for managing media playback.
@MainActor
public final class PlaybackManager: NSObject, ObservableObject, PlaybackManaging, PreBufferDelegate {

    /// The `AVPlayer` instance.
    @Published public var player: AVPlayer?
    /// A boolean indicating whether the player is currently playing.
    @Published public var isPlaying: Bool = false
    /// The current playback state.
    @Published public var playbackState: PlaybackState = .stopped
    /// The Picture-in-Picture manager (iOS/iPadOS only).
    #if os(iOS)
    public var pipManager: PiPManager?
    #endif
    /// Background player for pre-buffering next episode.
    private var nextEpisodePlayer: AVPlayer?
    /// A boolean indicating whether next episode is pre-buffered and ready.
    @Published public var isNextEpisodeReady: Bool = false

    /// An enumeration of the possible playback states.
    public enum PlaybackState {
        /// The player is playing.
        case playing
        /// The player is paused.
        case paused
        /// The player is buffering.
        case buffering
        /// The player is stopped.
        case stopped
        /// The player has failed.
        case failed(Error)
    }

    private var currentItem: NSManagedObject?
    private var currentProfile: Profile?
    public var availableVariants: [ChannelVariant] = []
    public var currentVariantIndex: Int = 0
    private var context: NSManagedObjectContext
    private var settingsManager: SettingsManager
    private var watchHistoryManager: WatchHistoryManager
    private var progressTracker: PlaybackProgressTracker?
    private var streamCacheManager: StreamCacheManager?
    #if os(iOS)
    @available(iOS 16.1, *)
    private var liveActivityManager: LiveActivityManager?
    #endif
    private var downloadManager: DownloadManager?
    private var queueManager: UpNextQueueManager?

    private var cancellables = Set<AnyCancellable>()
    /// Initializes a new `PlaybackManager`.
    ///
    /// - Parameters:
    ///   - context: The `NSManagedObjectContext` to use for Core Data operations.
    ///   - settingsManager: The `SettingsManager` for accessing user settings.
    ///   - watchHistoryManager: The `WatchHistoryManager` for managing watch history.
    ///   - streamCacheManager: Optional `StreamCacheManager` for temporary stream caching.
    ///   - liveActivityManager: Optional `LiveActivityManager` for Live Activities (iOS 16.1+).
    ///   - downloadManager: Optional `DownloadManager` for offline playback support.
    ///   - queueManager: Optional `UpNextQueueManager` for auto-play next in queue.
    public init(context: NSManagedObjectContext, settingsManager: SettingsManager, watchHistoryManager: WatchHistoryManager, streamCacheManager: StreamCacheManager? = nil, downloadManager: DownloadManager? = nil, queueManager: UpNextQueueManager? = nil) {
        self.context = context
        self.settingsManager = settingsManager
        self.watchHistoryManager = watchHistoryManager
        self.streamCacheManager = streamCacheManager ?? StreamCacheManager(context: context)
        #if os(iOS)
        if #available(iOS 16.1, *) {
            self.liveActivityManager = LiveActivityManager()
        }
        self.pipManager = PiPManager()
        #endif
        self.downloadManager = downloadManager
        self.queueManager = queueManager
        super.init()
    }

    /// Loads media for a given item and profile.
    ///
    /// - Parameters:
    ///   - item: The `NSManagedObject` to play (e.g., `Movie`, `Episode`, `ChannelVariant`).
    ///   - profile: The `Profile` of the current user.
    public func loadMedia(for item: NSManagedObject, profile: Profile) {
        loadMedia(for: item, profile: profile, isOffline: false)
    }

    /// Loads media for a given item and profile.
    ///
    /// - Parameters:
    ///   - item: The `NSManagedObject` to play (e.g., `Movie`, `Episode`, `ChannelVariant`).
    ///   - profile: The `Profile` of the current user.
    ///   - isOffline: Indicates whether the media should be loaded from an offline cache.
    public func loadMedia(for item: NSManagedObject, profile: Profile, isOffline: Bool = false) {
        stop()

        self.currentItem = item
        self.currentProfile = profile
        self.availableVariants = []
        self.currentVariantIndex = 0

        if let channelVariant = item as? ChannelVariant, let channel = channelVariant.channel {
            self.availableVariants = (channel.variants as? Set<ChannelVariant> ?? []).sorted { $0.name ?? "" < $1.name ?? "" }
            self.currentVariantIndex = self.availableVariants.firstIndex(of: channelVariant) ?? 0
        }

        loadCurrentVariant(isOffline: isOffline)
    }

    public func loadCurrentVariant(isOffline: Bool = false) {
        let itemToLoad = availableVariants.isEmpty ? currentItem : availableVariants[currentVariantIndex]

        // Check for offline download first
        if isOffline, let downloadManager = downloadManager,
           let localPath = downloadManager.getLocalFilePath(for: itemToLoad!),
           let localURL = URL(string: "file://\(localPath)") {
            
            let playerItem = AVPlayerItem(url: localURL)
            playerItem.addObserver(self, forKeyPath: #keyPath(AVPlayerItem.status), options: [.new, .old], context: nil)
            
            if self.player == nil {
                self.player = AVPlayer(playerItem: playerItem)
                setupPiPController()
            } else {
                self.player?.replaceCurrentItem(with: playerItem)
            }
            
            setupPlaybackTracking()
            return
        }

        guard let streamURLString = getStreamURL(for: itemToLoad),
              let streamURL = URL(string: streamURLString) else {
            handlePlaybackFailure()
            return
        }

        // Record stream access for caching
        let cacheIdentifier = getCacheIdentifier(for: itemToLoad)
        streamCacheManager?.recordStreamAccess(for: streamURLString, cacheIdentifier: cacheIdentifier)

        let playerItem = AVPlayerItem(url: streamURL)
        playerItem.addObserver(self, forKeyPath: #keyPath(AVPlayerItem.status), options: [.new, .old], context: nil)

        #if os(iOS) || os(tvOS)
        let subtitleAttributes = [kCMTextMarkupAttribute_FontSizePercentage as String: settingsManager.subtitleSize]
        let subtitleRule = AVTextStyleRule(textMarkupAttributes: subtitleAttributes)
        playerItem.textStyleRules = [subtitleRule]
        #endif

        self.player = AVPlayer(playerItem: playerItem)
        setupPlaybackTracking()
        
        #if os(iOS)
        // Configure PiP if enabled
        if settingsManager.enablePiP, let player = self.player {
            let layer = AVPlayerLayer(player: player)
            pipManager?.configure(with: layer)
        }
        
        // Start Live Activity if enabled
        if settingsManager.enableLiveActivities, #available(iOS 16.1, *) {
            let title = getContentTitle(for: itemToLoad)
            let isLive = (itemToLoad as? Channel) != nil
            Task { @MainActor in
                await liveActivityManager?.start(title: title, isLive: isLive)
            }
        }
        #endif
        
        setupPiPController()
        setupPlayerObservers()
        play()
    }

    private func setupPlaybackTracking() {
        guard let player else { return }
        progressTracker?.stopTracking()
        progressTracker = PlaybackProgressTracker(player: player, item: currentItem, watchHistoryManager: watchHistoryManager)
        progressTracker?.preBufferDelegate = self
        progressTracker?.preBufferTimeSeconds = settingsManager.preBufferTimeSeconds
    }

    private func handlePlaybackFailure() {
        if currentVariantIndex < availableVariants.count - 1 {
            currentVariantIndex += 1
            loadCurrentVariant()
        } else {
            self.playbackState = .failed(NSError(domain: "PlaybackManager", code: 1, userInfo: [NSLocalizedDescriptionKey: "All stream variants failed."]))
        }
    }

    override public func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
        if keyPath == #keyPath(AVPlayerItem.status), let item = object as? AVPlayerItem {
            if item == player?.currentItem && item.status == .failed {
                handlePlaybackFailure()
            } else if item == nextEpisodePlayer?.currentItem && item.status == .readyToPlay {
                isNextEpisodeReady = true
                PerformanceLogger.logPlayback("Next episode pre-buffered and ready")
            }
        }
    }

    private func getStreamURL(for item: NSManagedObject?) -> String? {
        guard let item = item else { return nil }
        if let movie = item as? Movie {
            return movie.streamURL
        } else if let episode = item as? Episode {
            return episode.streamURL
        } else if let variant = item as? ChannelVariant {
            return variant.streamURL
        }
        return nil
    }

    /// Starts playback.
    public func play() {
        player?.play()
        isPlaying = true
        playbackState = .playing
        
        // Resume Live Activity if active
        #if os(iOS)
        if settingsManager.enableLiveActivities, #available(iOS 16.1, *) {
            Task { @MainActor in
                await liveActivityManager?.resumeActivity()
            }
        }
        #endif
    }

    /// Pauses playback.
    public func pause() {
        player?.pause()
        isPlaying = false
        playbackState = .paused
        
        // Pause Live Activity if active
        #if os(iOS)
        if settingsManager.enableLiveActivities, #available(iOS 16.1, *) {
            Task { @MainActor in
                await liveActivityManager?.pauseActivity()
            }
        }
        #endif
    }

    /// Seeks to a specific time in the media.
    /// - Parameter time: The `CMTime` to seek to.
    public func seek(to time: CMTime) {
        player?.seek(to: time)
    }

    /// Stops playback and resets the player.
    public func stop() {
        player?.currentItem?.removeObserver(self, forKeyPath: #keyPath(AVPlayerItem.status))
        player?.pause()
        progressTracker?.stopTracking()
        progressTracker = nil
        player = nil
        nextEpisodePlayer?.pause()
        nextEpisodePlayer = nil
        isNextEpisodeReady = false
        currentItem = nil
        currentProfile = nil
        isPlaying = false
        playbackState = .stopped
        cancellables.removeAll()
        
        // End Live Activity when stopping playback
        #if os(iOS)
        if settingsManager.enableLiveActivities, #available(iOS 16.1, *) {
            Task { @MainActor in
                await liveActivityManager?.endActivity()
            }
        }
        #endif
    }

    /// Sets up observers for player events.
    private func setupPlayerObservers() {
        guard let player = player else { return }

        NotificationCenter.default.publisher(for: .AVPlayerItemDidPlayToEndTime, object: player.currentItem)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in 
                guard let self = self else { return }
                
                // Mark content as completed in queue
                if let currentItem = self.currentItem, let profile = self.currentProfile {
                    self.queueManager?.processCompletion(of: currentItem, profile: profile)
                }
                
                // For series, try next episode first
                if self.isNextEpisodeReady == true {
                    self.swapToNextEpisode()
                } else if self.getNextEpisodeInSeries() != nil {
                    self.playNextEpisode()
                } else {
                    // No next episode, check Up Next queue
                    self.playNextInQueue()
                }
            }
            .store(in: &cancellables)

        NotificationCenter.default.publisher(for: .AVPlayerItemPlaybackStalled, object: player.currentItem)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.handlePlaybackFailure() }
            .store(in: &cancellables)

        // Access and error logs for HLS performance metrics
        NotificationCenter.default.publisher(for: .AVPlayerItemNewAccessLogEntry, object: player.currentItem)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.logAccessLog() }
            .store(in: &cancellables)

        NotificationCenter.default.publisher(for: .AVPlayerItemNewErrorLogEntry, object: player.currentItem)
            .receive(on: DispatchQueue.main)
            .sink { _ in PerformanceLogger.logPlayback("AVPlayerItem error log entry added") }
            .store(in: &cancellables)

        player.publisher(for: \.timeControlStatus)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] status in
                switch status {
                case .playing:
                    self?.isPlaying = true
                    self?.playbackState = .playing
                case .paused:
                    self?.isPlaying = false
                    self?.playbackState = .paused
                case .waitingToPlayAtSpecifiedRate:
                    self?.playbackState = .buffering
                @unknown default:
                    break
                }
            }
            .store(in: &cancellables)
    }

    /// Plays the next episode in a series.
    private func playNextEpisode() {
        guard let currentEpisode = currentItem as? Episode,
              let profile = currentProfile,
              let nextEpisode = findNextEpisode(for: currentEpisode) else {
            // No next episode, check Up Next queue
            playNextInQueue()
            return
        }
        loadMedia(for: nextEpisode, profile: profile)
    }
    
    /// Gets the next episode in a series for the current episode.
    /// - Returns: The next Episode if found, nil otherwise.
    private func getNextEpisodeInSeries() -> Episode? {
        guard let currentEpisode = currentItem as? Episode else {
            return nil
        }
        return findNextEpisode(for: currentEpisode)
    }
    
    /// Plays the next item in the Up Next queue.
    private func playNextInQueue() {
        guard let profile = currentProfile,
              let queueManager = queueManager,
              let nextQueueItem = queueManager.getNextItem(),
              let content = nextQueueItem.fetchContent(context: context) else {
            stop()
            return
        }
        
        if let movie = content as? Movie {
            loadMedia(for: movie, profile: profile)
        } else if let episode = content as? Episode {
            loadMedia(for: episode, profile: profile)
        } else {
            stop()
        }
    }

    /// Finds the next episode in a season.
    /// - Parameter episode: The current `Episode`.
    /// - Returns: The next `Episode` in the season, or `nil` if there is no next episode.
    private func findNextEpisode(for episode: Episode) -> Episode? {
        guard let season = episode.season,
              let episodesSet = season.episodes as? Set<Episode> else {
            return nil
        }

        let episodes = episodesSet.sorted { $0.episodeNumber < $1.episodeNumber }

        if let currentIndex = episodes.firstIndex(of: episode), currentIndex + 1 < episodes.count {
            return episodes[currentIndex + 1]
        }

        return nil
    }
    
    /// Generates a unique cache identifier for the given item.
    /// - Parameter item: The media item.
    /// - Returns: A unique identifier string.
    private func getCacheIdentifier(for item: NSManagedObject?) -> String {
        if let movie = item as? Movie {
            return "movie_\(movie.objectID.uriRepresentation().absoluteString)"
        } else if let episode = item as? Episode {
            return "episode_\(episode.objectID.uriRepresentation().absoluteString)"
        } else if let channelVariant = item as? ChannelVariant {
            return "channel_\(channelVariant.objectID.uriRepresentation().absoluteString)"
        }
        return "unknown_\(UUID().uuidString)"
    }
    
    private func getContentTitle(for item: NSManagedObject?) -> String {
        if let movie = item as? Movie {
            return movie.title ?? "Movie"
        } else if let episode = item as? Episode {
            let seriesTitle = episode.season?.series?.title ?? "Series"
            let seasonNum = episode.season?.seasonNumber ?? 0
            let episodeNum = episode.episodeNumber
            return "\(seriesTitle) S\(seasonNum)E\(episodeNum)"
        } else if let channelVariant = item as? ChannelVariant {
            return channelVariant.channel?.name ?? "Live TV"
        }
        return "StreamHaven"
    }
}

extension PlaybackManager {
    // MARK: - PreBufferDelegate
    
    public func shouldPreBufferNextEpisode(timeRemaining: Double) {
        guard settingsManager.enablePreBuffer else { return }
        
        PerformanceLogger.logPlayback("Pre-buffer requested with \(String(format: "%.1f", timeRemaining))s remaining")
        
        // Find next episode
        guard let currentEpisode = currentItem as? Episode,
              let nextEpisode = findNextEpisode(for: currentEpisode) else {
            PerformanceLogger.logPlayback("No next episode found for pre-buffer")
            return
        }
        
        loadNextEpisodeInBackground(nextEpisode)
    }
    
    /// Loads the next episode in a background player for seamless transition.
    /// - Parameter episode: The next episode to pre-buffer.
    private func loadNextEpisodeInBackground(_ episode: Episode) {
        guard let streamURLString = episode.streamURL,
              let streamURL = URL(string: streamURLString) else {
            PerformanceLogger.logPlayback("Invalid stream URL for next episode")
            return
        }
        
        PerformanceLogger.logPlayback("Pre-buffering next episode: \(episode.title ?? "Unknown")")
        
        // Record stream access for caching
        let cacheIdentifier = getCacheIdentifier(for: episode)
        streamCacheManager?.recordStreamAccess(for: streamURLString, cacheIdentifier: cacheIdentifier)
        
        // Create background player with same settings
        let playerItem = AVPlayerItem(url: streamURL)
        #if os(iOS) || os(tvOS)
        let subtitleAttributes = [kCMTextMarkupAttribute_FontSizePercentage as String: settingsManager.subtitleSize]
        let subtitleRule = AVTextStyleRule(textMarkupAttributes: subtitleAttributes)
        playerItem.textStyleRules = [subtitleRule]
        #endif
        
        nextEpisodePlayer = AVPlayer(playerItem: playerItem)
        
        // Observe when pre-buffer is ready
        nextEpisodePlayer?.currentItem?.addObserver(self, forKeyPath: #keyPath(AVPlayerItem.status), options: [.new], context: nil)
        
        // Preload the item to start buffering
        nextEpisodePlayer?.currentItem?.preferredForwardBufferDuration = TimeInterval(30)
    }
    
    /// Swaps the pre-buffered player to become the active player.
    private func swapToNextEpisode() {
        guard let nextPlayer = nextEpisodePlayer,
              isNextEpisodeReady else {
            PerformanceLogger.logPlayback("Next episode not ready, falling back to normal transition")
            playNextEpisode()
            return
        }
        
        PerformanceLogger.logPlayback("Seamlessly transitioning to pre-buffered episode")
        
        // Stop current player
        player?.pause()
        progressTracker?.stopTracking()
        player = nil
        
        // Swap to next player
        player = nextPlayer
        nextEpisodePlayer = nil
        isNextEpisodeReady = false
        
        // Update current item to next episode
        if let currentEpisode = currentItem as? Episode,
           let nextEpisode = findNextEpisode(for: currentEpisode) {
            currentItem = nextEpisode
        }
        
        // Setup tracking for new episode
        progressTracker = PlaybackProgressTracker(player: player, item: currentItem, watchHistoryManager: watchHistoryManager)
        progressTracker?.preBufferDelegate = self
        progressTracker?.preBufferTimeSeconds = settingsManager.preBufferTimeSeconds
        
        // Setup observers and play
        setupPiPController()
        setupPlayerObservers()
        play()
    }
    
    /// Sets up the Picture-in-Picture controller (iOS/iPadOS only).
    private func setupPiPController() {
        // PiP is now managed by PiPManager, this method kept for compatibility
        // Actual setup happens in loadCurrentVariant after player creation
        #if os(iOS)
        PerformanceLogger.logPlayback("PiP controller setup delegated to PiPManager")
        #endif
    }
    
    /// Starts Picture-in-Picture mode.
    public func startPiP() {
        #if os(iOS)
        pipManager?.start()
        PerformanceLogger.logPlayback("PiP start requested")
        #endif
    }
    
    /// Stops Picture-in-Picture mode.
    public func stopPiP() {
        #if os(iOS)
        pipManager?.stop()
        PerformanceLogger.logPlayback("PiP stop requested")
        #endif
    }
    
    /// Computed property for PiP active state
    public var isPiPActive: Bool {
        #if os(iOS)
        return pipManager?.isPictureInPictureActive ?? false
        #else
        return false
        #endif
    }
    
    // MARK: - AVPictureInPictureControllerDelegate
    // Removed - now handled by PiPManager
    
    // MARK: - Live Activity Management
    
    /// Starts a Live Activity for the current playback item
    #if os(iOS)
    private func startLiveActivity(for item: NSManagedObject?) async {
        guard let item = item else { return }
        
        var title = ""
        var contentType = ""
        var seriesInfo: String?
        var thumbnailURL: String?
        var duration: TimeInterval = 0
        
        if let movie = item as? Movie {
            title = movie.title ?? "Unknown Movie"
            contentType = "movie"
            thumbnailURL = movie.posterURL
            if let playerDuration = player?.currentItem?.duration,
               !playerDuration.isIndefinite {
                duration = CMTimeGetSeconds(playerDuration)
            }
        } else if let episode = item as? Episode {
            title = episode.title ?? "Unknown Episode"
            contentType = "episode"
            if let season = episode.season,
               let series = season.series {
                seriesInfo = "\(series.title ?? "") S\(season.seasonNumber)E\(episode.episodeNumber)"
                thumbnailURL = series.posterURL
            }
            if let playerDuration = player?.currentItem?.duration,
               !playerDuration.isIndefinite {
                duration = CMTimeGetSeconds(playerDuration)
            }
        } else if let variant = item as? ChannelVariant,
                  let channel = variant.channel {
            title = channel.name ?? "Unknown Channel"
            contentType = "channel"
            thumbnailURL = channel.logoURL
            duration = 0 // Live content has no fixed duration
        }
        
        let streamIdentifier = getStreamURL(for: item) ?? UUID().uuidString
        
        do {
            try await liveActivityManager?.startActivity(
                title: title,
                contentType: contentType,
                streamIdentifier: streamIdentifier,
                thumbnailURL: thumbnailURL,
                seriesInfo: seriesInfo,
                duration: duration
            )
        } catch {
            ErrorReporter.log(error, context: "PlaybackManager.startLiveActivity")
        }
    }
    #endif
    
    /// Updates the Live Activity with current playback progress
    /// Called periodically by PlaybackProgressTracker
    public func updateLiveActivityProgress() {
        #if os(iOS)
        guard settingsManager.enableLiveActivities,
              #available(iOS 16.1, *),
              let player,
              let currentTime = player.currentItem?.currentTime(),
              let duration = player.currentItem?.duration,
              !currentTime.isIndefinite,
              !duration.isIndefinite else {
            return
        }

        let elapsed = CMTimeGetSeconds(currentTime)
        let total = CMTimeGetSeconds(duration)
        let progress = total > 0 ? elapsed / total : 0.0

        Task { @MainActor in
            await liveActivityManager?.updateActivity(
                progress: progress,
                isPlaying: isPlaying,
                elapsedSeconds: elapsed
            )
        }
        #endif
    }
    
    private func logAccessLog() {
        guard let events = player?.currentItem?.accessLog()?.events else { return }
        if let last = events.last {
            let bitrate = last.indicatedBitrate
            let stalls = last.numberOfStalls
            let startup = last.startupTime
            let rtt = last.transferDuration > 0 ? last.indicatedBitrate / last.transferDuration : 0
            PerformanceLogger.logPlayback("HLS metrics: bitrate=\(Int(bitrate))bps stalls=\(stalls) startup=\(String(format: "%.2fs", startup)) rtt=\(String(format: "%.2f", rtt))")
#if canImport(Sentry)
            let crumb = Breadcrumb()
            crumb.level = .info
            crumb.category = "playback"
            crumb.type = "navigation"
            crumb.message = "HLS: bitrate=\(Int(bitrate)) stalls=\(stalls) startup=\(String(format: "%.2f", startup))"
            SentrySDK.addBreadcrumb(crumb)
#endif
        }
    }
}
