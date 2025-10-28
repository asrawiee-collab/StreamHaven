import CoreData
import Foundation

/// Manages persisted watch history for a specific profile.
@MainActor
public final class WatchHistoryManager: ObservableObject, WatchHistoryManaging {
    private let context: NSManagedObjectContext
    private let profile: Profile
    private let cloudKitSyncManager: CloudKitSyncManager?

    public init(
        context: NSManagedObjectContext,
        profile: Profile,
        cloudKitSyncManager: CloudKitSyncManager? = nil
    ) {
        self.context = context
        self.profile = profile
        self.cloudKitSyncManager = cloudKitSyncManager
    }

    public func findWatchHistory(for item: NSManagedObject) -> WatchHistory? {
        let request: NSFetchRequest<WatchHistory> = WatchHistory.fetchRequest()

        var predicates: [NSPredicate] = [NSPredicate(format: "profile == %@", profile)]
        if let movie = item as? Movie {
            predicates.append(NSPredicate(format: "movie == %@", movie))
        } else if let episode = item as? Episode {
            predicates.append(NSPredicate(format: "episode == %@", episode))
        } else {
            return nil
        }

        request.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: predicates)
        request.fetchLimit = 1

        do {
            return try context.fetch(request).first
        } catch {
            ErrorReporter.log(error, context: "WatchHistoryManager.findWatchHistory.fetch")
            return nil
        }
    }

    public func updateWatchHistory(for item: NSManagedObject, progress: Float) {
        let history = findOrCreateWatchHistory(for: item)
        history.progress = progress
        history.watchedDate = Date()
        history.modifiedAt = Date()

        do {
            try context.save()
            Task { @MainActor in
                try? await cloudKitSyncManager?.syncWatchHistory(history)
            }
        } catch {
            ErrorReporter.log(error, context: "WatchHistoryManager.updateWatchHistory.save")
        }
    }

    public func hasWatched(_ item: NSManagedObject, profile: Profile, threshold: Float = 0.9) -> Bool {
        let request: NSFetchRequest<WatchHistory> = WatchHistory.fetchRequest()

        var predicates: [NSPredicate] = [
            NSPredicate(format: "profile == %@", profile),
            NSPredicate(format: "progress >= %f", threshold)
        ]

        if let movie = item as? Movie {
            predicates.append(NSPredicate(format: "movie == %@", movie))
        } else if let episode = item as? Episode {
            predicates.append(NSPredicate(format: "episode == %@", episode))
        } else {
            return false
        }

        request.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: predicates)
        request.fetchLimit = 1

        do {
            return try context.count(for: request) > 0
        } catch {
            ErrorReporter.log(error, context: "WatchHistoryManager.hasWatched.count")
            return false
        }
    }

    private func findOrCreateWatchHistory(for item: NSManagedObject) -> WatchHistory {
        if let existing = findWatchHistory(for: item) {
            return existing
        }

        let history = WatchHistory(context: context)
        history.profile = profile

        if let movie = item as? Movie {
            history.movie = movie
        } else if let episode = item as? Episode {
            history.episode = episode
        }

        return history
    }
}