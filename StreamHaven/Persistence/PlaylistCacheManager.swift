import Foundation
import CoreData

class PlaylistCacheManager {

    private static let playlistsDirectory: URL = {
        let fileManager = FileManager.default
        let urls = fileManager.urls(for: .documentDirectory, in: .userDomainMask)
        let documentsDirectory = urls[0]
        let playlistsDir = documentsDirectory.appendingPathComponent("Playlists")

        if !fileManager.fileExists(atPath: playlistsDir.path) {
            try? fileManager.createDirectory(at: playlistsDir, withIntermediateDirectories: true)
        }

        return playlistsDir
    }()

    static func cachePlaylist(url: URL, data: Data, context: NSManagedObjectContext) -> String? {
        let fileName = url.absoluteString.data(using: .utf8)!.base64EncodedString()
        let fileURL = playlistsDirectory.appendingPathComponent(fileName)

        do {
            try data.write(to: fileURL, options: .atomic)

            let fetchRequest: NSFetchRequest<PlaylistCache> = PlaylistCache.fetchRequest()
            fetchRequest.predicate = NSPredicate(format: "url == %@", url.absoluteString)

            let results = try context.fetch(fetchRequest)
            let cacheEntry: PlaylistCache
            if let existingEntry = results.first {
                cacheEntry = existingEntry
            } else {
                cacheEntry = PlaylistCache(context: context)
                cacheEntry.url = url.absoluteString
            }

            cacheEntry.filePath = fileURL.path
            cacheEntry.lastRefreshed = Date()

            try context.save()
            print("Successfully cached playlist from \\(url.absoluteString) to \\(fileURL.path)")
            return fileURL.path
        } catch {
            print("Failed to cache playlist for url: \\(url.absoluteString). Error: \\(error)")
            return nil
        }
    }

    static func getCachedPlaylist(url: URL, context: NSManagedObjectContext) -> Data? {
        let fetchRequest: NSFetchRequest<PlaylistCache> = PlaylistCache.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "url == %@", url.absoluteString)

        let twentyFourHoursAgo = Date().addingTimeInterval(-24 * 60 * 60)
        fetchRequest.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [
            fetchRequest.predicate!,
            NSPredicate(format: "lastRefreshed > %@", twentyFourHoursAgo as NSDate)
        ])

        do {
            let results = try context.fetch(fetchRequest)
            if let cacheEntry = results.first, let filePath = cacheEntry.filePath {
                let fileURL = URL(fileURLWithPath: filePath)
                print("Retrieved cached playlist from \\(fileURL.path)")
                return try Data(contentsOf: fileURL)
            }
        } catch {
            print("Failed to retrieve cached playlist for url: \\(url.absoluteString). Error: \\(error)")
        }

        print("No valid cache found for \\(url.absoluteString)")
        return nil
    }
}
