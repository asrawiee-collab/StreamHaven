import AVKit
import CoreData

class PlaybackProgressTracker {

    private var player: AVPlayer?
    private var timeObserver: Any?

    private var currentItem: NSManagedObject?
    private var watchHistoryManager: WatchHistoryManager?

    init(player: AVPlayer?, item: NSManagedObject?, watchHistoryManager: WatchHistoryManager?) {
        self.player = player
        self.currentItem = item
        self.watchHistoryManager = watchHistoryManager

        setupProgressObserver()
    }

    deinit {
        stopTracking()
    }

    private func setupProgressObserver() {
        guard let player = player else { return }

        let interval = CMTime(seconds: 15, preferredTimescale: 1)

        timeObserver = player.addPeriodicTimeObserver(forInterval: interval, queue: .main) { [weak self] time in
            self?.updateWatchHistory(with: time)
        }
    }

    func stopTracking() {
        if let observer = timeObserver {
            player?.removeTimeObserver(observer)
            timeObserver = nil
        }
    }

    private func updateWatchHistory(with time: CMTime) {
        guard let item = currentItem else { return }

        let progress = Float(CMTimeGetSeconds(time))
        watchHistoryManager?.updateWatchHistory(for: item, progress: progress)
    }
}
