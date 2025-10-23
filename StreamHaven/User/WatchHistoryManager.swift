import Foundation
import CoreData

class WatchHistoryManager: ObservableObject {

    private let context: NSManagedObjectContext
    private let profile: Profile

    init(context: NSManagedObjectContext, profile: Profile) {
        self.context = context
        self.profile = profile
    }

    func findWatchHistory(for item: NSManagedObject) -> WatchHistory? {
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
            print("Failed to fetch watch history: \\(error)")
            return nil
        }
    }

    func updateWatchHistory(for item: NSManagedObject, progress: Float) {
        context.perform {
            let history = self.findOrCreateWatchHistory(for: item)
            history.progress = progress
            history.watchedDate = Date()

            do {
                try self.context.save()
            } catch {
                print("Failed to save watch history progress: \\(error)")
            }
        }
    }

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
