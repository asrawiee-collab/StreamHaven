import XCTest
import CoreData
@testable import StreamHaven

/// Tests for the StreamCacheManager temporary caching functionality.
final class StreamCacheManagerTests: XCTestCase {
    
    var persistenceController: PersistenceController!
    var context: NSManagedObjectContext!
    var cacheManager: StreamCacheManager!
    
    override func setUp() async throws {
        persistenceController = PersistenceController(inMemory: true)
        context = persistenceController.container.viewContext
        cacheManager = StreamCacheManager(context: context)
    }
    
    override func tearDown() async throws {
        cacheManager.clearAllCache()
        persistenceController = nil
        context = nil
        cacheManager = nil
    }
    
    // MARK: - Cache Recording Tests
    
    func testRecordStreamAccessCreatesNewEntry() throws {
        // Given: A stream URL and cache identifier
        let streamURL = "https://example.com/stream.m3u8"
        let cacheIdentifier = "movie_12345"
        
        // When: Recording stream access
        cacheManager.recordStreamAccess(for: streamURL, cacheIdentifier: cacheIdentifier)
        
        // Then: Cache entry should be created
        let metadata = cacheManager.getCachedStreamMetadata(for: streamURL)
        XCTAssertNotNil(metadata, "Cache metadata should be created")
        XCTAssertEqual(metadata?.streamURL, streamURL)
        XCTAssertEqual(metadata?.cacheIdentifier, cacheIdentifier)
        
        // And: Expiration should be set to 24 hours from now
        let expectedExpiration = Date().addingTimeInterval(24 * 3600)
        let expirationDifference = abs(metadata!.expiresAt.timeIntervalSince(expectedExpiration))
        XCTAssertLessThan(expirationDifference, 5, "Expiration should be approximately 24 hours from now")
    }
    
    func testRecordStreamAccessUpdatesExistingEntry() throws {
        // Given: An existing cache entry
        let streamURL = "https://example.com/stream.m3u8"
        let cacheIdentifier = "movie_12345"
        cacheManager.recordStreamAccess(for: streamURL, cacheIdentifier: cacheIdentifier)
        
        guard let originalMetadata = cacheManager.getCachedStreamMetadata(for: streamURL) else {
            XCTFail("Original metadata should exist")
            return
        }
        let originalLastAccessed = originalMetadata.lastAccessed
        
        // When: Recording access again after a delay
        Thread.sleep(forTimeInterval: 0.1)
        cacheManager.recordStreamAccess(for: streamURL, cacheIdentifier: cacheIdentifier)
        
        // Then: Last accessed time should be updated
        let updatedMetadata = cacheManager.getCachedStreamMetadata(for: streamURL)
        XCTAssertNotNil(updatedMetadata)
        XCTAssertGreaterThan(updatedMetadata!.lastAccessed, originalLastAccessed, "Last accessed time should be updated")
        
        // And: Only one entry should exist
        let fetchRequest: NSFetchRequest<StreamCache> = StreamCache.fetchRequest()
        let allEntries = try context.fetch(fetchRequest)
        XCTAssertEqual(allEntries.count, 1, "Should only have one cache entry")
    }
    
    // MARK: - Cache Retrieval Tests
    
    func testGetCachedStreamMetadataReturnsValidEntry() throws {
        // Given: A cached stream
        let streamURL = "https://example.com/stream.m3u8"
        cacheManager.recordStreamAccess(for: streamURL, cacheIdentifier: "test_123")
        
        // When: Retrieving cache metadata
        let metadata = cacheManager.getCachedStreamMetadata(for: streamURL)
        
        // Then: Valid metadata should be returned
        XCTAssertNotNil(metadata)
        XCTAssertEqual(metadata?.streamURL, streamURL)
        XCTAssertGreaterThan(metadata!.expiresAt, Date(), "Entry should not be expired")
    }
    
    func testGetCachedStreamMetadataReturnsNilForExpiredEntry() throws {
        // Given: An expired cache entry
        let streamURL = "https://example.com/stream.m3u8"
        let cacheEntry = StreamCache(context: context)
        cacheEntry.streamURL = streamURL
        cacheEntry.cacheIdentifier = "test_123"
        cacheEntry.cachedAt = Date().addingTimeInterval(-25 * 3600) // 25 hours ago
        cacheEntry.lastAccessed = Date().addingTimeInterval(-25 * 3600)
        cacheEntry.expiresAt = Date().addingTimeInterval(-1 * 3600) // Expired 1 hour ago
        try context.save()
        
        // When: Retrieving cache metadata
        let metadata = cacheManager.getCachedStreamMetadata(for: streamURL)
        
        // Then: nil should be returned
        XCTAssertNil(metadata, "Expired entries should return nil")
    }
    
    func testGetCachedStreamMetadataReturnsNilForNonexistentEntry() {
        // Given: A stream URL that was never cached
        let streamURL = "https://example.com/nonexistent.m3u8"
        
        // When: Retrieving cache metadata
        let metadata = cacheManager.getCachedStreamMetadata(for: streamURL)
        
        // Then: nil should be returned
        XCTAssertNil(metadata, "Nonexistent entries should return nil")
    }
    
    // MARK: - Cache Expiration Tests
    
    func testClearExpiredCacheRemovesOldEntries() throws {
        // Given: Multiple cache entries, some expired
        let validURL = "https://example.com/valid.m3u8"
        let expiredURL = "https://example.com/expired.m3u8"
        
        // Valid entry
        cacheManager.recordStreamAccess(for: validURL, cacheIdentifier: "valid_123")
        
        // Expired entry
        let expiredEntry = StreamCache(context: context)
        expiredEntry.streamURL = expiredURL
        expiredEntry.cacheIdentifier = "expired_123"
        expiredEntry.cachedAt = Date().addingTimeInterval(-25 * 3600)
        expiredEntry.lastAccessed = Date().addingTimeInterval(-25 * 3600)
        expiredEntry.expiresAt = Date().addingTimeInterval(-1 * 3600) // Expired
        try context.save()
        
        // When: Clearing expired cache
        cacheManager.clearExpiredCache()
        
        // Then: Expired entry should be removed, valid entry should remain
        XCTAssertNotNil(cacheManager.getCachedStreamMetadata(for: validURL), "Valid entry should remain")
        XCTAssertNil(cacheManager.getCachedStreamMetadata(for: expiredURL), "Expired entry should be removed")
        
        let fetchRequest: NSFetchRequest<StreamCache> = StreamCache.fetchRequest()
        let remainingEntries = try context.fetch(fetchRequest)
        XCTAssertEqual(remainingEntries.count, 1, "Only valid entry should remain")
    }
    
    func testClearAllCacheRemovesAllEntries() throws {
        // Given: Multiple cache entries
        cacheManager.recordStreamAccess(for: "https://example.com/stream1.m3u8", cacheIdentifier: "test_1")
        cacheManager.recordStreamAccess(for: "https://example.com/stream2.m3u8", cacheIdentifier: "test_2")
        cacheManager.recordStreamAccess(for: "https://example.com/stream3.m3u8", cacheIdentifier: "test_3")
        
        // When: Clearing all cache
        cacheManager.clearAllCache()
        
        // Then: All entries should be removed
        let fetchRequest: NSFetchRequest<StreamCache> = StreamCache.fetchRequest()
        let remainingEntries = try context.fetch(fetchRequest)
        XCTAssertEqual(remainingEntries.count, 0, "All cache entries should be removed")
        XCTAssertEqual(cacheManager.getActiveCacheCount(), 0, "Active cache count should be zero")
    }
    
    // MARK: - Cache Statistics Tests
    
    func testGetActiveCacheCountReturnsCorrectNumber() throws {
        // Given: Multiple valid cache entries
        cacheManager.recordStreamAccess(for: "https://example.com/stream1.m3u8", cacheIdentifier: "test_1")
        cacheManager.recordStreamAccess(for: "https://example.com/stream2.m3u8", cacheIdentifier: "test_2")
        
        // And: One expired entry
        let expiredEntry = StreamCache(context: context)
        expiredEntry.streamURL = "https://example.com/expired.m3u8"
        expiredEntry.cacheIdentifier = "expired_123"
        expiredEntry.cachedAt = Date().addingTimeInterval(-25 * 3600)
        expiredEntry.lastAccessed = Date().addingTimeInterval(-25 * 3600)
        expiredEntry.expiresAt = Date().addingTimeInterval(-1 * 3600)
        try context.save()
        
        // When: Getting active cache count
        let count = cacheManager.getActiveCacheCount()
        
        // Then: Should only count non-expired entries
        XCTAssertEqual(count, 2, "Should only count active (non-expired) entries")
    }
    
    func testGetCacheStorageInfoReturnsUsageStats() {
        // When: Getting cache storage info
        let (memoryUsage, diskUsage) = cacheManager.getCacheStorageInfo()
        
        // Then: Should return non-negative values
        XCTAssertGreaterThanOrEqual(memoryUsage, 0, "Memory usage should be non-negative")
        XCTAssertGreaterThanOrEqual(diskUsage, 0, "Disk usage should be non-negative")
    }
}
