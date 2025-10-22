import AVKit
import CoreData

class PlaybackProgressTracker {

    private var player: AVPlayer?
    private var timeObserver: Any?

    private var currentItem: NSManagedObject?
    private var currentProfile: Profile?
    private var context: NSManagedObjectContext

    init(player: AVPlayer?, item: NSManagedObject?, profile: Profile?, context: NSManagedObjectContext) {
        self.player = player
        self.currentItem = item
        self.currentProfile = profile
        self.context = context

        setupProgressObserver()
    }

    deinit {
        stopTracking()
    }

    // MARK: - Progress Tracking

    private func setupProgressObserver() {
        guard let player = player else { return }

        // Update progress every 15 seconds
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

    // MARK: - Core Data Interaction

    private func updateWatchHistory(with time: CMTime) {
        guard let item = currentItem, let profile = currentProfile else { return }

        let progress = Float(CMTimeGetSeconds(time))

        context.perform {
            let history = self.findOrCreateWatchHistory(for: item, profile: profile)
            history.progress = progress
            history.watchedDate = Date()

            do {
                try self.context.save()
            } catch {
                print("Failed to save watch history progress: \\(error)")
            }
        }
    }

    private func findOrCreateWatchHistory(for item: NSManagedObject, profile: Profile) -> WatchHistory {
        let request: NSFetchRequest<WatchHistory> = WatchHistory.fetchRequest()

        var predicates: [NSPredicate] = [NSPredicate(format: "profile == %@", profile)]

        if let movie = item as? Movie {
            predicates.append(NSPredicate(format: "movie == %@", movie))
        } else if let episode = item as? Episode {
            predicates.append(NSPredicate(format: "episode == %@", episode))
        }

        request.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: predicates)

        do {
            if let existingHistory = try context.fetch(request).first {
                return existingHistory
            }
        } catch {
            print("Failed to fetch watch history: \\(error)")
        }

        // Create a new entry if one doesn't exist
        let newHistory = WatchHistory(context: context)
        newHistory.profile = profile

        if let movie = item as? Movie {
            newHistory.movie = movie
        } else if let episode = item as? Episode {
            newHistory.episode = episode
        }

        return newHistory
    }
}
