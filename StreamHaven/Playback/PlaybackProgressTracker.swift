import AVKit
import CoreData
import CoreMedia

/// Delegate protocol for pre-buffering next episode.
@MainActor
public protocol PreBufferDelegate: AnyObject {
    /// Called when it's time to start pre-buffering the next episode.
    /// - Parameter timeRemaining: Seconds remaining in current episode.
    func shouldPreBufferNextEpisode(timeRemaining: Double)
    
    /// Called periodically to update Live Activity with playback progress.
    func updateLiveActivityProgress()
}

/// Tracks playback progress, updates watch history, and coordinates pre-buffering.
@MainActor
public final class PlaybackProgressTracker {

    private weak var player: AVPlayer?
    private var timeObserver: Any?
    private weak var currentItem: NSManagedObject?
    private var watchHistoryManager: WatchHistoryManager?

    /// Delegate for pre-buffer notifications.
    public weak var preBufferDelegate: PreBufferDelegate?
    /// Pre-buffer time threshold in seconds (default: 120 seconds).
    public var preBufferTimeSeconds: Double = 120.0
    /// Flag to ensure pre-buffer is triggered only once per episode.
    private var hasTriggeredPreBuffer = false
    /// Interval at which we sample the player's progress.
    private let observationInterval = CMTime(seconds: 1.0, preferredTimescale: CMTimeScale(NSEC_PER_SEC))

    /// Initializes a new `PlaybackProgressTracker`.
    ///
    /// - Parameters:
    ///   - player: The `AVPlayer` to track.
    ///   - item: The `NSManagedObject` being played.
    ///   - watchHistoryManager: The `WatchHistoryManager` to use for updating watch history.
    public init(player: AVPlayer?, item: NSManagedObject?, watchHistoryManager: WatchHistoryManager?) {
        self.player = player
        self.currentItem = item
        self.watchHistoryManager = watchHistoryManager
        setupProgressObserver()
    }

    /// Sets up an observer to periodically update the watch history.
    private func setupProgressObserver() {
        guard let player else { return }

        timeObserver = player.addPeriodicTimeObserver(forInterval: observationInterval, queue: .main) { [weak self] time in
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.handlePeriodicUpdate(with: time)
            }
        }
    }

    /// Stops tracking playback progress.
    public func stopTracking() {
        if let observer = timeObserver {
            player?.removeTimeObserver(observer)
            timeObserver = nil
        }
        hasTriggeredPreBuffer = false
    }

    /// Updates the watch history with the current playback time.
    /// - Parameter time: The current playback time.
    private func updateWatchHistory(with time: CMTime) {
        guard let item = currentItem else { return }
        let seconds = CMTimeGetSeconds(time)
        guard seconds.isFinite else { return }

        let progress = Float(seconds)
        watchHistoryManager?.updateWatchHistory(for: item, progress: progress)
    }
    
    /// Notifies the delegate to refresh Live Activity progress.
    private func updateLiveActivity() {
        preBufferDelegate?.updateLiveActivityProgress()
    }
    
    private func handlePeriodicUpdate(with time: CMTime) {
        updateWatchHistory(with: time)
        checkPreBufferTiming(currentTime: time)
        updateLiveActivity()
    }
    
    /// Checks if it's time to pre-buffer the next episode.
    /// - Parameter currentTime: The current playback time.
    private func checkPreBufferTiming(currentTime: CMTime) {
        guard !hasTriggeredPreBuffer, let player, let duration = player.currentItem?.duration, duration.isValid, !duration.isIndefinite else { return }

        let currentSeconds = CMTimeGetSeconds(currentTime)
        let totalSeconds = CMTimeGetSeconds(duration)
        let timeRemaining = totalSeconds - currentSeconds

        guard timeRemaining.isFinite else { return }

        if timeRemaining > 0, timeRemaining <= preBufferTimeSeconds {
            hasTriggeredPreBuffer = true
            preBufferDelegate?.shouldPreBufferNextEpisode(timeRemaining: timeRemaining)
            PerformanceLogger.logPlayback("Pre-buffer triggered: \(String(format: "%.1f", timeRemaining))s remaining")
        }
    }
}
