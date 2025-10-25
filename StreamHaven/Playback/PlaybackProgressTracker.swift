import AVKit
import CoreData

/// Delegate protocol for pre-buffering next episode.
public protocol PreBufferDelegate: AnyObject {
    /// Called when it's time to start pre-buffering the next episode.
    /// - Parameter timeRemaining: Seconds remaining in current episode.
    func shouldPreBufferNextEpisode(timeRemaining: Double)
    
    /// Called periodically to update Live Activity with playback progress.
    func updateLiveActivityProgress()
}

/// A class for tracking playback progress and updating watch history.
public final class PlaybackProgressTracker {

    private var player: AVPlayer?
    private var timeObserver: Any?

    private var currentItem: NSManagedObject?
    private var watchHistoryManager: WatchHistoryManager?
    
    /// Delegate for pre-buffer notifications.
    public weak var preBufferDelegate: PreBufferDelegate?
    /// Pre-buffer time threshold in seconds (default: 120 seconds).
    public var preBufferTimeSeconds: Double = 120.0
    /// Flag to ensure pre-buffer is triggered only once per episode.
    private var hasTriggeredPreBuffer: Bool = false

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

    deinit {
        stopTracking()
    }

    /// Sets up an observer to periodically update the watch history.
    private func setupProgressObserver() {
        guard let player = player else { return }
        timeObserver = player.addPeriodicTimeObserver(forInterval: interval, queue: .main) { [weak self] time in
            self?.updateWatchHistory(with: time)
            self?.checkPreBufferTiming(currentTime: time)
            self?.updateLiveActivity()
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

        let progress = Float(CMTimeGetSeconds(time))
        watchHistoryManager?.updateWatchHistory(for: item, progress: progress)
    }
    
    /// Updates the Live Activity with current playback progress.
    private func updateLiveActivity() {
        preBufferDelegate?.updateLiveActivityProgress()
    }
        let progress = Float(CMTimeGetSeconds(time))
        watchHistoryManager?.updateWatchHistory(for: item, progress: progress)
    }
    
    /// Checks if it's time to pre-buffer the next episode.
    /// - Parameter currentTime: The current playback time.
    private func checkPreBufferTiming(currentTime: CMTime) {
        guard !hasTriggeredPreBuffer,
              let player = player,
              let duration = player.currentItem?.duration,
              duration.isValid,
              !duration.isIndefinite else { return }
        
        let currentSeconds = CMTimeGetSeconds(currentTime)
        let totalSeconds = CMTimeGetSeconds(duration)
        let timeRemaining = totalSeconds - currentSeconds
        
        // Trigger pre-buffer when time remaining is less than threshold
        if timeRemaining > 0 && timeRemaining <= preBufferTimeSeconds {
            hasTriggeredPreBuffer = true
            preBufferDelegate?.shouldPreBufferNextEpisode(timeRemaining: timeRemaining)
            PerformanceLogger.logPlayback("Pre-buffer triggered: \(String(format: "%.1f", timeRemaining))s remaining")
        }
    }
}
