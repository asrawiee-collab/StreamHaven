import Foundation
import CoreData

class PlaylistCacheManager {

    static func cachePlaylist(url: URL, data: Data, context: NSManagedObjectContext) {
        let fetchRequest: NSFetchRequest<PlaylistCache> = PlaylistCache.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "url == %@", url.absoluteString)

        do {
            let results = try context.fetch(fetchRequest)
            let cacheEntry: PlaylistCache
            if let existingEntry = results.first {
                cacheEntry = existingEntry
            } else {
                cacheEntry = PlaylistCache(context: context)
                cacheEntry.url = url.absoluteString
            }

            cacheEntry.data = data
            cacheEntry.lastRefreshed = Date()

            try context.save()
            print("Successfully cached playlist from \\(url.absoluteString)")
        } catch {
            print("Failed to cache playlist for url: \\(url.absoluteString). Error: \\(error)")
        }
    }

    static func getCachedPlaylist(url: URL, context: NSManagedObjectContext) -> Data? {
        let fetchRequest: NSFetchRequest<PlaylistCache> = PlaylistCache.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "url == %@", url.absoluteString)

        // Cache is valid for 24 hours
        let twentyFourHoursAgo = Date().addingTimeInterval(-24 * 60 * 60)
        fetchRequest.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [
            fetchRequest.predicate!,
            NSPredicate(format: "lastRefreshed > %@", twentyFourHoursAgo as NSDate)
        ])

        do {
            let results = try context.fetch(fetchRequest)
            if let cacheEntry = results.first {
                print("Retrieved cached playlist from \\(url.absoluteString)")
                return cacheEntry.data
            }
        } catch {
            print("Failed to retrieve cached playlist for url: \\(url.absoluteString). Error: \\(error)")
        }

        print("No valid cache found for \\(url.absoluteString)")
        return nil
    }
}
