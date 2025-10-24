import Foundation
import CoreData

/// A class for managing a user's watch history.
public final class WatchHistoryManager: WatchHistoryManaging {

    private let context: NSManagedObjectContext
    private let profile: Profile

    /// Initializes a new `WatchHistoryManager`.
    ///
    /// - Parameters:
    ///   - context: The `NSManagedObjectContext` to use for Core Data operations.
    ///   - profile: The `Profile` for which to manage watch history.
    public init(context: NSManagedObjectContext, profile: Profile) {
        self.context = context
        self.profile = profile
    }

    /// Finds the `WatchHistory` object for a given item.
    ///
    /// - Parameter item: The `NSManagedObject` to find the watch history for (e.g., `Movie`, `Episode`).
    /// - Returns: The `WatchHistory` object, or `nil` if no watch history is found.
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

        do {
            return try context.fetch(request).first
        } catch {
            print("Failed to fetch watch history: \(error)")
            return nil
        }
    }

    /// Updates the watch history for a given item.
    ///
    /// - Parameters:
    ///   - item: The `NSManagedObject` to update the watch history for.
    ///   - progress: The watch progress as a percentage (0.0 to 1.0).
    public func updateWatchHistory(for item: NSManagedObject, progress: Float) {
        context.perform {
            let history = self.findOrCreateWatchHistory(for: item)
            history.progress = progress
            history.watchedDate = Date()

            do {
                try self.context.save()
            } catch {
                print("Failed to save watch history progress: \(error)")
            }
        }
    }

    /// Finds or creates a `WatchHistory` object for a given item.
    ///
    /// - Parameter item: The `NSManagedObject` to find or create the watch history for.
    /// - Returns: The existing or newly created `WatchHistory` object.
    private func findOrCreateWatchHistory(for item: NSManagedObject) -> WatchHistory {
        if let existingHistory = findWatchHistory(for: item) {
            return existingHistory
        }

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
