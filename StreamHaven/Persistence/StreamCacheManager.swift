import Foundation
import AVFoundation
import CoreData
import os.log

/// A manager for handling temporary stream caching to enable smooth 24-hour resume functionality.
public final class StreamCacheManager {
    
    private let context: NSManagedObjectContext
    private let logger = Logger(subsystem: "com.asrawiee.StreamHaven", category: "StreamCache")
    private let expirationHours: TimeInterval = 24 // 24 hours
    
    /// Initializes a new `StreamCacheManager`.
    /// - Parameter context: The `NSManagedObjectContext` for Core Data operations.
    public init(context: NSManagedObjectContext) {
        self.context = context
        setupURLCache()
    }
    
    // MARK: - URL Cache Setup
    
    /// Configures URLCache with appropriate memory and disk capacity for HLS segment caching.
    private func setupURLCache() {
        let memoryCapacity = 50 * 1024 * 1024 // 50 MB
        let diskCapacity = 200 * 1024 * 1024 // 200 MB
        
        let cache = URLCache(memoryCapacity: memoryCapacity, diskCapacity: diskCapacity)
        URLCache.shared = cache
        
        logger.info("URLCache configured: \(memoryCapacity / 1024 / 1024)MB memory, \(diskCapacity / 1024 / 1024)MB disk")
    }
    
    // MARK: - Cache Metadata Management
    
    /// Records stream access in Core Data for tracking expiration.
    /// - Parameters:
    ///   - streamURL: The stream URL being accessed.
    ///   - cacheIdentifier: A unique identifier for the cached content.
    public func recordStreamAccess(for streamURL: String, cacheIdentifier: String) {
        let now = Date()
        let expiresAt = now.addingTimeInterval(expirationHours * 3600)
        
        // Check if cache entry already exists
        let fetchRequest: NSFetchRequest<StreamCache> = StreamCache.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "streamURL == %@", streamURL)
        
        do {
            let existingEntries = try context.fetch(fetchRequest)
            
            if let existingEntry = existingEntries.first {
                // Update existing entry
                existingEntry.lastAccessed = now
                existingEntry.expiresAt = expiresAt
                logger.debug("Updated cache metadata for: \(streamURL)")
            } else {
                // Create new entry
                let cacheEntry = StreamCache(context: context)
                cacheEntry.streamURL = streamURL
                cacheEntry.cacheIdentifier = cacheIdentifier
                cacheEntry.cachedAt = now
                cacheEntry.lastAccessed = now
                cacheEntry.expiresAt = expiresAt
                logger.debug("Created cache metadata for: \(streamURL)")
            }
            
            try context.save()
        } catch {
            logger.error("Failed to record stream access: \(error.localizedDescription)")
        }
    }
    
    /// Retrieves cached stream metadata if it exists and hasn't expired.
    /// - Parameter streamURL: The stream URL to look up.
    /// - Returns: The `StreamCache` entry if valid, nil otherwise.
    public func getCachedStreamMetadata(for streamURL: String) -> StreamCache? {
        let fetchRequest: NSFetchRequest<StreamCache> = StreamCache.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "streamURL == %@ AND expiresAt > %@", streamURL, Date() as NSDate)
        fetchRequest.fetchLimit = 1
        
        do {
            let results = try context.fetch(fetchRequest)
            if let entry = results.first {
                logger.debug("Found valid cache metadata for: \(streamURL)")
                return entry
            }
        } catch {
            logger.error("Failed to fetch cache metadata: \(error.localizedDescription)")
        }
        
        return nil
    }
    
    // MARK: - Cache Expiration
    
    /// Clears expired cache entries from Core Data and URLCache.
    /// Should be called on app launch or periodically.
    public func clearExpiredCache() {
        logger.info("Starting expired cache cleanup...")
        
        let fetchRequest: NSFetchRequest<StreamCache> = StreamCache.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "expiresAt <= %@", Date() as NSDate)
        
        do {
            let expiredEntries = try context.fetch(fetchRequest)
            
            for entry in expiredEntries {
                logger.debug("Removing expired cache: \(entry.streamURL)")
                context.delete(entry)
            }
            
            if !expiredEntries.isEmpty {
                try context.save()
                logger.info("Removed \(expiredEntries.count) expired cache entries")
            } else {
                logger.info("No expired cache entries found")
            }
            
            // Also clear old URLCache entries (URLCache handles this automatically based on age)
            URLCache.shared.removeAllCachedResponses()
            
        } catch {
            logger.error("Failed to clear expired cache: \(error.localizedDescription)")
        }
    }
    
    /// Clears all cache entries (both metadata and URLCache).
    /// Useful for settings/debug purposes.
    public func clearAllCache() {
        logger.warning("Clearing ALL cache entries...")
        
        let fetchRequest: NSFetchRequest<StreamCache> = StreamCache.fetchRequest()
        
        do {
            let allEntries = try context.fetch(fetchRequest)
            
            for entry in allEntries {
                context.delete(entry)
            }
            
            try context.save()
            URLCache.shared.removeAllCachedResponses()
            
            logger.info("Cleared \(allEntries.count) cache entries and URLCache")
        } catch {
            logger.error("Failed to clear all cache: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Cache Statistics
    
    /// Returns the total number of active cached streams.
    public func getActiveCacheCount() -> Int {
        let fetchRequest: NSFetchRequest<StreamCache> = StreamCache.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "expiresAt > %@", Date() as NSDate)
        
        do {
            return try context.count(for: fetchRequest)
        } catch {
            logger.error("Failed to count active cache: \(error.localizedDescription)")
            return 0
        }
    }
    
    /// Returns the URLCache disk usage statistics.
    public func getCacheStorageInfo() -> (memoryUsage: Int, diskUsage: Int) {
        let memoryUsage = URLCache.shared.currentMemoryUsage
        let diskUsage = URLCache.shared.currentDiskUsage
        return (memoryUsage, diskUsage)
    }
}
