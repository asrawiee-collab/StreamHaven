import AVKit
import CoreData

/// A class for tracking playback progress and updating watch history.
public class PlaybackProgressTracker {

    private var player: AVPlayer?
    private var timeObserver: Any?

    private var currentItem: NSManagedObject?
    private var watchHistoryManager: WatchHistoryManager?

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

        let interval = CMTime(seconds: 15, preferredTimescale: 1)

        timeObserver = player.addPeriodicTimeObserver(forInterval: interval, queue: .main) { [weak self] time in
            self?.updateWatchHistory(with: time)
        }
    }

    /// Stops tracking playback progress.
    public func stopTracking() {
        if let observer = timeObserver {
            player?.removeTimeObserver(observer)
            timeObserver = nil
        }
    }

    /// Updates the watch history with the current playback time.
    /// - Parameter time: The current playback time.
    private func updateWatchHistory(with time: CMTime) {
        guard let item = currentItem else { return }

        let progress = Float(CMTimeGetSeconds(time))
        watchHistoryManager?.updateWatchHistory(for: item, progress: progress)
    }
}
