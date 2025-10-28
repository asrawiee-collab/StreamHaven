import CoreData
import Foundation

/// Handles adding and removing favorites for a given profile.
public final class FavoritesManager: ObservableObject, FavoritesManaging {
    private let context: NSManagedObjectContext
    private let profile: Profile
    private let cloudKitSyncManager: CloudKitSyncManager?

    public init(context: NSManagedObjectContext, profile: Profile, cloudKitSyncManager: CloudKitSyncManager? = nil) {
        self.context = context
        self.profile = profile
        self.cloudKitSyncManager = cloudKitSyncManager
    }

    public func isFavorite(item: NSManagedObject) -> Bool {
        findFavorite(for: item) != nil
    }

    public func toggleFavorite(for item: NSManagedObject) {
        if let favorite = findFavorite(for: item) {
            removeFavorite(favorite)
        } else {
            addFavorite(for: item)
        }
    }

    // MARK: - Private helpers

    private func addFavorite(for item: NSManagedObject) {
        let favorite = Favorite(context: context)
        favorite.profile = profile
        favorite.favoritedDate = Date()
        favorite.modifiedAt = Date()

        switch item {
        case let movie as Movie:
            favorite.movie = movie
        case let series as Series:
            favorite.series = series
        case let channel as Channel:
            favorite.channel = channel
        default:
            context.delete(favorite)
            return
        }

        persistChanges(contextMessage: "FavoritesManager.addFavorite.save")

        Task { @MainActor in
            try? await cloudKitSyncManager?.syncFavorite(favorite)
        }
    }

    private func removeFavorite(_ favorite: Favorite) {
        Task { @MainActor in
            try? await cloudKitSyncManager?.deleteFavorite(favorite)
        }

        context.delete(favorite)
        persistChanges(contextMessage: "FavoritesManager.removeFavorite.save")
    }

    private func findFavorite(for item: NSManagedObject) -> Favorite? {
        let request: NSFetchRequest<Favorite> = Favorite.fetchRequest()
        var predicates: [NSPredicate] = [NSPredicate(format: "profile == %@", profile)]

        switch item {
        case let movie as Movie:
            predicates.append(NSPredicate(format: "movie == %@", movie))
        case let series as Series:
            predicates.append(NSPredicate(format: "series == %@", series))
        case let channel as Channel:
            predicates.append(NSPredicate(format: "channel == %@", channel))
        default:
            return nil
        }

        request.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: predicates)
        request.fetchLimit = 1

        do {
            return try context.fetch(request).first
        } catch {
            ErrorReporter.log(error, context: "FavoritesManager.findFavorite.fetch")
            return nil
        }
    }

    private func persistChanges(contextMessage: String) {
        guard context.hasChanges else { return }

        do {
            try context.save()
        } catch {
            ErrorReporter.log(error, context: contextMessage)
        }
    }

}