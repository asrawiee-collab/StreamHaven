import XCTest
import CoreData
@testable import StreamHaven

final class PlaylistCacheManagerStressTests: XCTestCase {
    var provider: PersistenceProviding!
    var context: NSManagedObjectContext!

    override func setUpWithError() throws {
        let controller = PersistenceController(inMemory: true)
        provider = DefaultPersistenceProvider(controller: controller)
        context = provider.container.newBackgroundContext()
    }

    func testCacheLargePlaylist() throws {
        let url = URL(string: "https://example.com/large.m3u8")!
        
        // Create 10MB of test data
        let largeData = Data(repeating: 0x41, count: 10 * 1024 * 1024)
        
        let cachePath = try context.performAndWait {
            PlaylistCacheManager.cachePlaylist(url: url, data: largeData, context: context)
        }
        
        XCTAssertNotNil(cachePath)
        
        // Verify can retrieve
        let retrieved = try context.performAndWait {
            PlaylistCacheManager.getCachedPlaylist(url: url, context: context)
        }
        
        XCTAssertNotNil(retrieved)
        XCTAssertEqual(retrieved?.count, largeData.count)
    }

    func testCacheMultiplePlaylists() throws {
        let urls = (1...50).map { URL(string: "https://example.com/playlist\($0).m3u8")! }
        let testData = "test data".data(using: .utf8)!
        
        try context.performAndWait {
            for url in urls {
                let cachePath = PlaylistCacheManager.cachePlaylist(url: url, data: testData, context: context)
                XCTAssertNotNil(cachePath)
            }
        }
        
        // Verify all can be retrieved
        try context.performAndWait {
            for url in urls {
                let retrieved = PlaylistCacheManager.getCachedPlaylist(url: url, context: context)
                XCTAssertNotNil(retrieved)
            }
        }
    }

    func testConcurrentCaching() async throws {
        let urls = (1...20).map { URL(string: "https://example.com/concurrent\($0).m3u8")! }
        let testData = "concurrent test".data(using: .utf8)!
        
        await withTaskGroup(of: Bool.self) { group in
            for url in urls {
                group.addTask {
                    let bgContext = self.provider.container.newBackgroundContext()
                    let result = bgContext.performAndWait {
                        PlaylistCacheManager.cachePlaylist(url: url, data: testData, context: bgContext)
                    }
                    return result != nil
                }
            }
            
            var successCount = 0
            for await success in group {
                if success { successCount += 1 }
            }
            
            XCTAssertEqual(successCount, urls.count)
        }
    }

    func testCacheInvalidation() throws {
        let url = URL(string: "https://example.com/expiring.m3u8")!
        let testData = "test".data(using: .utf8)!
        
        // Cache the playlist
        _ = try context.performAndWait {
            PlaylistCacheManager.cachePlaylist(url: url, data: testData, context: context)
        }
        
        // Manually set lastRefreshed to >24 hours ago
        try context.performAndWait {
            let fetch: NSFetchRequest<PlaylistCache> = PlaylistCache.fetchRequest()
            fetch.predicate = NSPredicate(format: "url == %@", url.absoluteString)
            let results = try context.fetch(fetch)
            
            if let cache = results.first {
                cache.lastRefreshed = Date().addingTimeInterval(-25 * 60 * 60) // 25 hours ago
                try context.save()
            }
        }
        
        // Should not retrieve expired cache
        let retrieved = try context.performAndWait {
            PlaylistCacheManager.getCachedPlaylist(url: url, context: context)
        }
        
        XCTAssertNil(retrieved)
    }

    func testUpdateExistingCache() throws {
        let url = URL(string: "https://example.com/update.m3u8")!
        let originalData = "original".data(using: .utf8)!
        let updatedData = "updated".data(using: .utf8)!
        
        // Cache original
        _ = try context.performAndWait {
            PlaylistCacheManager.cachePlaylist(url: url, data: originalData, context: context)
        }
        
        // Update cache
        _ = try context.performAndWait {
            PlaylistCacheManager.cachePlaylist(url: url, data: updatedData, context: context)
        }
        
        // Retrieve should get updated data
        let retrieved = try context.performAndWait {
            PlaylistCacheManager.getCachedPlaylist(url: url, context: context)
        }
        
        XCTAssertNotNil(retrieved)
        XCTAssertEqual(String(data: retrieved!, encoding: .utf8), "updated")
    }

    func testCacheWithSpecialCharactersInURL() throws {
        let url = URL(string: "https://example.com/playlist?user=test&token=abc123&special=%20%21")!
        let testData = "special url test".data(using: .utf8)!
        
        let cachePath = try context.performAndWait {
            PlaylistCacheManager.cachePlaylist(url: url, data: testData, context: context)
        }
        
        XCTAssertNotNil(cachePath)
        
        let retrieved = try context.performAndWait {
            PlaylistCacheManager.getCachedPlaylist(url: url, context: context)
        }
        
        XCTAssertNotNil(retrieved)
    }

    func testCacheEmptyPlaylist() throws {
        let url = URL(string: "https://example.com/empty.m3u8")!
        let emptyData = Data()
        
        let cachePath = try context.performAndWait {
            PlaylistCacheManager.cachePlaylist(url: url, data: emptyData, context: context)
        }
        
        XCTAssertNotNil(cachePath)
        
        let retrieved = try context.performAndWait {
            PlaylistCacheManager.getCachedPlaylist(url: url, context: context)
        }
        
        XCTAssertNotNil(retrieved)
        XCTAssertEqual(retrieved?.count, 0)
    }

    func testGetCachedPlaylistForNonexistentURL() throws {
        let url = URL(string: "https://example.com/nonexistent.m3u8")!
        
        let retrieved = try context.performAndWait {
            PlaylistCacheManager.getCachedPlaylist(url: url, context: context)
        }
        
        XCTAssertNil(retrieved)
    }

    func testCacheWithBinaryData() throws {
        let url = URL(string: "https://example.com/binary.dat")!
        let binaryData = Data([0x00, 0xFF, 0x7F, 0x80, 0xDE, 0xAD, 0xBE, 0xEF])
        
        let cachePath = try context.performAndWait {
            PlaylistCacheManager.cachePlaylist(url: url, data: binaryData, context: context)
        }
        
        XCTAssertNotNil(cachePath)
        
        let retrieved = try context.performAndWait {
            PlaylistCacheManager.getCachedPlaylist(url: url, context: context)
        }
        
        XCTAssertEqual(retrieved, binaryData)
    }

    func testStressTestManyConcurrentReads() async throws {
        let url = URL(string: "https://example.com/popular.m3u8")!
        let testData = "popular playlist".data(using: .utf8)!
        
        // Cache once
        _ = try await context.perform {
            PlaylistCacheManager.cachePlaylist(url: url, data: testData, context: self.context)
        }
        
        // Concurrent reads
        await withTaskGroup(of: Bool.self) { group in
            for _ in 1...100 {
                group.addTask {
                    let bgContext = self.provider.container.newBackgroundContext()
                    let retrieved = bgContext.performAndWait {
                        PlaylistCacheManager.getCachedPlaylist(url: url, context: bgContext)
                    }
                    return retrieved != nil
                }
            }
            
            var successCount = 0
            for await success in group {
                if success { successCount += 1 }
            }
            
            XCTAssertEqual(successCount, 100)
        }
    }
}
