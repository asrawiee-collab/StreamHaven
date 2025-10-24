import AVKit
import CoreData
import Combine

/// A class for managing media playback.
public class PlaybackManager: ObservableObject {

    /// The `AVPlayer` instance.
    @Published public var player: AVPlayer?
    /// A boolean indicating whether the player is currently playing.
    @Published public var isPlaying: Bool = false
    /// The current playback state.
    @Published public var playbackState: PlaybackState = .stopped

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
    private var context: NSManagedObjectContext
    private var settingsManager: SettingsManager
    private var watchHistoryManager: WatchHistoryManager
    private var progressTracker: PlaybackProgressTracker?

    private var cancellables = Set<AnyCancellable>()

    /// Initializes a new `PlaybackManager`.
    ///
    /// - Parameters:
    ///   - context: The `NSManagedObjectContext` to use for Core Data operations.
    ///   - settingsManager: The `SettingsManager` for accessing user settings.
    ///   - watchHistoryManager: The `WatchHistoryManager` for managing watch history.
    public init(context: NSManagedObjectContext, settingsManager: SettingsManager, watchHistoryManager: WatchHistoryManager) {
        self.context = context
        self.settingsManager = settingsManager
        self.watchHistoryManager = watchHistoryManager
    }

    /// Loads media for a given item and profile.
    ///
    /// - Parameters:
    ///   - item: The `NSManagedObject` to play (e.g., `Movie`, `Episode`, `ChannelVariant`).
    ///   - profile: The `Profile` of the current user.
    public func loadMedia(for item: NSManagedObject, profile: Profile) {
        guard let streamURLString = getStreamURL(for: item),
              let streamURL = URL(string: streamURLString) else {
            self.playbackState = .failed(NSError(domain: "PlaybackManager", code: 1, userInfo: [NSLocalizedDescriptionKey: "Invalid stream URL"]))
            return
        }

        stop() // Stop any existing playback before starting new media

        self.currentItem = item
        self.currentProfile = profile

        let playerItem = AVPlayerItem(url: streamURL)

        // Apply subtitle size preference
        let subtitleRule = AVTextStyleRule(textMarkupAttributes: [
            kCMTextMarkupAttribute_FontSizePercentage as String: settingsManager.subtitleSize
        ])
        playerItem.textStyleRules = [subtitleRule]

        self.player = AVPlayer(playerItem: playerItem)
        self.progressTracker = PlaybackProgressTracker(player: self.player, item: self.currentItem, watchHistoryManager: self.watchHistoryManager)

        setupPlayerObservers()

        play()
    }

    /// Retrieves the stream URL for a given item.
    /// - Parameter item: The `NSManagedObject` to get the stream URL for.
    /// - Returns: The stream URL as a string, or `nil` if not found.
    private func getStreamURL(for item: NSManagedObject) -> String? {
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
    }

    /// Pauses playback.
    public func pause() {
        player?.pause()
        isPlaying = false
        playbackState = .paused
    }

    /// Seeks to a specific time in the media.
    /// - Parameter time: The `CMTime` to seek to.
    public func seek(to time: CMTime) {
        player?.seek(to: time)
    }

    /// Stops playback and resets the player.
    public func stop() {
        player?.pause()
        progressTracker?.stopTracking()
        progressTracker = nil
        player = nil
        currentItem = nil
        currentProfile = nil
        isPlaying = false
        playbackState = .stopped
        cancellables.removeAll()
    }

    /// Sets up observers for player events.
    private func setupPlayerObservers() {
        guard let player = player else { return }

        NotificationCenter.default.publisher(for: .AVPlayerItemDidPlayToEndTime, object: player.currentItem)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.playNextEpisode()
            }
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
            stop()
            return
        }

        loadMedia(for: nextEpisode, profile: profile)
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
}
