import CoreData
import Foundation

/// A class for managing the caching of playlist data.
public final class PlaylistCacheManager {

    /// The directory where playlists are cached.
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

    /// Caches the data of a playlist to a local file and creates a `PlaylistCache` entry in Core Data.
    ///
    /// - Parameters:
    ///   - url: The URL of the playlist.
    ///   - data: The `Data` of the playlist to cache.
    ///   - sourceID: Optional source ID to associate with this cache entry.
    ///   - context: The `NSManagedObjectContext` to perform the save on.
    /// - Returns: The file path of the cached playlist, or `nil` if caching failed.
    /// - Important: This method performs file I/O and should be called on a background context.
    public static func cachePlaylist(url: URL, data: Data, context: NSManagedObjectContext, epgURL: URL? = nil, sourceID: UUID? = nil) -> String? {
        // Ensure we're not on the main thread for file I/O
        precondition(!Thread.isMainThread, "PlaylistCacheManager.cachePlaylist should not be called on the main thread")
        
        let fileName: String
        if let data = url.absoluteString.data(using: .utf8) {
            fileName = data.base64EncodedString()
        } else {
            // Fallback to a sanitized filename
            fileName = url.absoluteString.replacingOccurrences(of: "/", with: "_")
        }
        let fileURL = playlistsDirectory.appendingPathComponent(fileName)

        do {
            try data.write(to: fileURL, options: .atomic)

            let fetchRequest: NSFetchRequest<PlaylistCache> = PlaylistCache.fetchRequest()
            var predicates: [NSPredicate] = [NSPredicate(format: "url == %@", url.absoluteString)]
            if let sourceID = sourceID {
                predicates.append(NSPredicate(format: "sourceID == %@", sourceID as CVarArg))
            }
            fetchRequest.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: predicates)

            let results = try context.fetch(fetchRequest)
            let cacheEntry: PlaylistCache
            if let existingEntry = results.first {
                cacheEntry = existingEntry
            } else {
                cacheEntry = PlaylistCache(context: context)
                cacheEntry.url = url.absoluteString
                cacheEntry.sourceID = sourceID
            }

            cacheEntry.filePath = fileURL.path
            cacheEntry.lastRefreshed = Date()
            cacheEntry.epgURL = epgURL?.absoluteString

            try context.save()
            print("Successfully cached playlist from \(url.absoluteString) to \(fileURL.path) for source \(sourceID?.uuidString ?? "unknown")")
            return fileURL.path
        } catch {
            print("Failed to cache playlist for url: \(url.absoluteString). Error: \(error)")
            return nil
        }
    }

    /// Retrieves the cached data of a playlist if it is less than 24 hours old.
    ///
    /// - Parameters:
    ///   - url: The URL of the playlist.
    ///   - sourceID: Optional source ID to filter cache entries.
    ///   - context: The `NSManagedObjectContext` to fetch the cache entry from.
    /// - Returns: The cached `Data` of the playlist, or `nil` if no valid cache is found.
    /// - Important: This method performs file I/O and should be called on a background thread.
    public static func getCachedPlaylist(url: URL, sourceID: UUID? = nil, context: NSManagedObjectContext) -> Data? {
        // Ensure we're not on the main thread for file I/O
        precondition(!Thread.isMainThread, "PlaylistCacheManager.getCachedPlaylist should not be called on the main thread")
        
        let fetchRequest: NSFetchRequest<PlaylistCache> = PlaylistCache.fetchRequest()
        var predicates: [NSPredicate] = [
            NSPredicate(format: "url == %@", url.absoluteString), NSPredicate(format: "lastRefreshed > %@", Date().addingTimeInterval(-24 * 60 * 60) as NSDate)
        ]
        if let sourceID = sourceID {
            predicates.append(NSPredicate(format: "sourceID == %@", sourceID as CVarArg))
        }
        fetchRequest.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: predicates)

        do {
            let results = try context.fetch(fetchRequest)
            if let cacheEntry = results.first, let filePath = cacheEntry.filePath {
                let fileURL = URL(fileURLWithPath: filePath)
                print("Retrieved cached playlist from \(fileURL.path) for source \(sourceID?.uuidString ?? "unknown")")
                return try Data(contentsOf: fileURL)
            }
        } catch {
            print("Failed to retrieve cached playlist for url: \(url.absoluteString). Error: \(error)")
        }

        print("No valid cache found for \(url.absoluteString)")
        return nil
    }
}
