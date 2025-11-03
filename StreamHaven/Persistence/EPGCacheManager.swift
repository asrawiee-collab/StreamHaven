import CoreData
import Foundation

/// Manages the caching and refreshing of EPG (Electronic Program Guide) data.
public final class EPGCacheManager {
    
    /// The expiration time for cached EPG data (24 hours).
    private static let cacheExpirationInterval: TimeInterval = 24 * 60 * 60
    
    /// The key for storing the last EPG refresh date in UserDefaults.
    private static let lastRefreshKey = "EPGLastRefreshDate"
    
    /// Fetches and caches EPG data from the specified URL.
    ///
    /// - Parameters:
    ///   - url: The URL of the XMLTV EPG source.
    ///   - context: The `NSManagedObjectContext` to perform the import on.
    ///   - force: Whether to force refresh even if cache is still valid.
    /// - Throws: An error if the download or parsing fails.
    public static func fetchAndCacheEPG(from url: URL, context: NSManagedObjectContext, force: Bool = false) async throws {
        // Check if cache is still valid
        if !force, let lastRefresh = UserDefaults.standard.object(forKey: lastRefreshKey) as? Date {
            let timeSinceRefresh = Date().timeIntervalSince(lastRefresh)
            if timeSinceRefresh < cacheExpirationInterval {
                print("EPG cache is still valid. Skipping refresh.")
                return
            }
        }
        
        print("Downloading EPG data from \(url)...")
        
        // Download the EPG data
        let (data, _) = try await URLSession.shared.data(from: url)
        
        // Parse and save to Core Data
        try await context.perform {
            try EPGParser.parse(data: data, context: context)
        }
        
        // Update the last refresh time
        UserDefaults.standard.set(Date(), forKey: lastRefreshKey)
        
        print("EPG data successfully cached.")
    }
    
    /// Refreshes EPG data for all playlists that have an EPG URL configured.
    ///
    /// - Parameter context: The `NSManagedObjectContext` to perform the import on.
    public static func refreshAllEPGs(context: NSManagedObjectContext) async {
        do {
            // Fetch all playlist caches with EPG URLs
            let fetchRequest: NSFetchRequest<PlaylistCache> = PlaylistCache.fetchRequest()
            fetchRequest.predicate = NSPredicate(format: "epgURL != nil AND epgURL != ''")
            
            let playlists = try await context.perform {
                try context.fetch(fetchRequest)
            }
            
            print("Found \(playlists.count) playlist(s) with EPG URLs.")
            
            for playlist in playlists {
                guard let epgURLString = playlist.epgURL, let epgURL = URL(string: epgURLString) else {
                    continue
                }
                
                do {
                    try await fetchAndCacheEPG(from: epgURL, context: context, force: true)
                } catch {
                    print("Failed to refresh EPG from \(epgURLString): \(error)")
                }
            }
        } catch {
            print("Failed to refresh EPGs: \(error)")
        }
    }
    
    /// Returns the current and next programme for a given channel.
    ///
    /// - Parameters:
    ///   - channel: The `Channel` to get programmes for.
    ///   - context: The `NSManagedObjectContext` to perform the query on.
    /// - Returns: A tuple containing the current and next `EPGEntry` objects, or `nil` if not found.
    public static func getNowAndNext(for channel: Channel, context: NSManagedObjectContext) -> (now: EPGEntry?, next: EPGEntry?) {
        let now = Date()
        
        // Fetch current programme (start <= now < end)
        let currentRequest: NSFetchRequest<EPGEntry> = EPGEntry.fetchRequest()
        currentRequest.predicate = NSPredicate(format: "channel == %@ AND startTime <= %@ AND endTime > %@", channel, now as CVarArg, now as CVarArg)
        currentRequest.sortDescriptors = [NSSortDescriptor(keyPath: \EPGEntry.startTime, ascending: false)]
        currentRequest.fetchLimit = 1
        
        // Fetch next programme (start > now)
        let nextRequest: NSFetchRequest<EPGEntry> = EPGEntry.fetchRequest()
        nextRequest.predicate = NSPredicate(format: "channel == %@ AND startTime > %@", channel, now as CVarArg)
        nextRequest.sortDescriptors = [NSSortDescriptor(keyPath: \EPGEntry.startTime, ascending: true)]
        nextRequest.fetchLimit = 1
        
        do {
            let current = try context.fetch(currentRequest).first
            let next = try context.fetch(nextRequest).first
            return (current, next)
        } catch {
            print("Failed to fetch EPG entries: \(error)")
            return (nil, nil)
        }
    }
    
    /// Returns all programmes for a given channel within a time range.
    ///
    /// - Parameters:
    ///   - channel: The `Channel` to get programmes for.
    ///   - startDate: The start of the time range.
    ///   - endDate: The end of the time range.
    ///   - context: The `NSManagedObjectContext` to perform the query on.
    /// - Returns: An array of `EPGEntry` objects within the time range.
    public static func getProgrammes(for channel: Channel, from startDate: Date, to endDate: Date, context: NSManagedObjectContext) -> [EPGEntry] {
        let fetchRequest: NSFetchRequest<EPGEntry> = EPGEntry.fetchRequest()
        fetchRequest.predicate = NSPredicate(
            format: "channel == %@ AND endTime >= %@ AND startTime <= %@", channel, startDate as CVarArg, endDate as CVarArg
        )
        fetchRequest.sortDescriptors = [NSSortDescriptor(keyPath: \EPGEntry.startTime, ascending: true)]
        
        do {
            return try context.fetch(fetchRequest)
        } catch {
            print("Failed to fetch EPG entries: \(error)")
            return []
        }
    }
    
    /// Clears all expired EPG entries from the database.
    ///
    /// - Parameter context: The `NSManagedObjectContext` to perform the operation on.
    public static func clearExpiredEntries(context: NSManagedObjectContext) async throws {
        let now = Date()
        let oneDayAgo = Calendar.current.date(byAdding: .day, value: -1, to: now) ?? now
        
        try await context.perform {
            let fetchRequest: NSFetchRequest<NSFetchRequestResult> = EPGEntry.fetchRequest()
            fetchRequest.predicate = NSPredicate(format: "endTime < %@", oneDayAgo as CVarArg)
            
            let deleteRequest = NSBatchDeleteRequest(fetchRequest: fetchRequest)
            try context.execute(deleteRequest)
            
            if context.hasChanges {
                try context.save()
            }
            
            print("Cleared expired EPG entries.")
        }
    }
}
