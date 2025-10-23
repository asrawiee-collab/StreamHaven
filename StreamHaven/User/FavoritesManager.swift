import Foundation
import CoreData
import SwiftUI

class FavoritesManager: ObservableObject {
    private let context: NSManagedObjectContext
    private let profile: Profile

    init(context: NSManagedObjectContext, profile: Profile) {
        self.context = context
        self.profile = profile
    }

    func isFavorite(item: NSManagedObject) -> Bool {
        return findFavorite(for: item) != nil
    }

    func toggleFavorite(for item: NSManagedObject) {
        if let favorite = findFavorite(for: item) {
            // It is a favorite, so remove it
            context.delete(favorite)
        } else {
            // It is not a favorite, so add it
            let newFavorite = Favorite(context: context)
            newFavorite.favoritedDate = Date()
            newFavorite.profile = profile

            if let movie = item as? Movie {
                newFavorite.movie = movie
            } else if let series = item as? Series {
                newFavorite.series = series
            } else if let channel = item as? Channel {
                newFavorite.channel = channel
            }
        }

        saveContext()
    }

    private func findFavorite(for item: NSManagedObject) -> Favorite? {
        let request: NSFetchRequest<Favorite> = Favorite.fetchRequest()
        var predicates: [NSPredicate] = [NSPredicate(format: "profile == %@", profile)]

        if let movie = item as? Movie {
            predicates.append(NSPredicate(format: "movie == %@", movie))
        } else if let series = item as? Series {
            predicates.append(NSPredicate(format: "series == %@", series))
        } else if let channel = item as? Channel {
            predicates.append(NSPredicate(format: "channel == %@", channel))
        } else {
            return nil // Unsupported type
        }

        request.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: predicates)
        request.fetchLimit = 1

        do {
            return try context.fetch(request).first
        } catch {
            print("Failed to fetch favorite status: \\(error)")
            return nil
        }
    }

    private func saveContext() {
        guard context.hasChanges else { return }
        do {
            try context.save()
        } catch {
            print("Failed to save context after favorite toggle: \\(error)")
        }
    }
}
