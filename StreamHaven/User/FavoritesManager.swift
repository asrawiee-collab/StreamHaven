import Foundation
import CoreData
import SwiftUI

/// A class for managing a user's favorites.
public class FavoritesManager: ObservableObject {
    private let context: NSManagedObjectContext
    private let profile: Profile

    /// Initializes a new `FavoritesManager`.
    ///
    /// - Parameters:
    ///   - context: The `NSManagedObjectContext` to use for Core Data operations.
    ///   - profile: The `Profile` for which to manage favorites.
    public init(context: NSManagedObjectContext, profile: Profile) {
        self.context = context
        self.profile = profile
    }

    /// Checks if an item is a favorite.
    ///
    /// - Parameter item: The `NSManagedObject` to check (e.g., `Movie`, `Series`, `Channel`).
    /// - Returns: `true` if the item is a favorite, `false` otherwise.
    public func isFavorite(item: NSManagedObject) -> Bool {
        return findFavorite(for: item) != nil
    }

    /// Toggles the favorite status of an item.
    ///
    /// - Parameter item: The `NSManagedObject` to toggle (e.g., `Movie`, `Series`, `Channel`).
    public func toggleFavorite(for item: NSManagedObject) {
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

    /// Finds the `Favorite` object for a given item.
    ///
    /// - Parameter item: The `NSManagedObject` to find the favorite for.
    /// - Returns: The `Favorite` object, or `nil` if the item is not a favorite.
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
            print("Failed to fetch favorite status: \(error)")
            return nil
        }
    }

    /// Saves the context if there are changes.
    private func saveContext() {
        guard context.hasChanges else { return }
        do {
            try context.save()
        } catch {
            print("Failed to save context after favorite toggle: \(error)")
        }
    }
}
