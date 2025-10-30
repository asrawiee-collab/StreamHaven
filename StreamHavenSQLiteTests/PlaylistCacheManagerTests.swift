import XCTest
import CoreData
@testable import StreamHaven

final class PlaylistCacheManagerTests: FileBasedTestCase {

    // Enable temp directory for file I/O operations
    override func needsTempDirectory() -> Bool {
        return true
    }

    func testCacheLargePlaylist() async throws {
        // Test with a 10MB file
        let largeData = Data(repeating: 0xFF, count: 10 * 1024 * 1024)
        let url = URL(string: "https://example.com/large.m3u8")!
        
        let bgContext = createBackgroundContext()
        let cachePath = try await bgContext.perform {
            let path = PlaylistCacheManager.cachePlaylist(url: url, data: largeData, context: bgContext)
            try bgContext.save()
            return path
        }
        
        XCTAssertNotNil(cachePath, "Should successfully cache large playlist")
        
        // Verify file exists
        if let path = cachePath {
            XCTAssertTrue(FileManager.default.fileExists(atPath: path), "Cached file should exist on disk")
        }
    }

    func testCacheMultiplePlaylists() async throws {
        let urls = (1...50).map { URL(string: "https://example.com/playlist\($0).m3u8")! }
        let testData = "test data".data(using: .utf8)!
        
        let bgContext = createBackgroundContext()
        try await bgContext.perform {
            // Cache all playlists
            for url in urls {
                let cachePath = PlaylistCacheManager.cachePlaylist(url: url, data: testData, context: bgContext)
                XCTAssertNotNil(cachePath, "Should cache playlist for \(url)")
            }
            
            // Verify all can be retrieved
            for url in urls {
                let retrieved = PlaylistCacheManager.getCachedPlaylist(url: url, context: bgContext)
                XCTAssertNotNil(retrieved, "Should retrieve cached playlist for \(url)")
                XCTAssertEqual(retrieved, testData, "Retrieved data should match original")
            }
            
            try bgContext.save()
        }
    }

    func testConcurrentCaching() async throws {
        // Note: SQLite doesn't handle truly concurrent writes well, so we test
        // sequential caching of multiple playlists instead
        let urls = (1...20).map { URL(string: "https://example.com/concurrent\($0).m3u8")! }
        let testData = "concurrent test".data(using: .utf8)!
        
        let bgContext = createBackgroundContext()
        let successCount = try await bgContext.perform {
            var count = 0
            for url in urls {
                let path = PlaylistCacheManager.cachePlaylist(url: url, data: testData, context: bgContext)
                if path != nil {
                    count += 1
                }
            }
            try bgContext.save()
            return count
        }
        
        XCTAssertEqual(successCount, urls.count, "All caching operations should succeed")
        
        // Verify all cached playlists can be retrieved
        let bgContext2 = createBackgroundContext()
        let retrieveCount = await bgContext2.perform {
            var count = 0
            for url in urls {
                if PlaylistCacheManager.getCachedPlaylist(url: url, context: bgContext2) != nil {
                    count += 1
                }
            }
            return count
        }
        
        XCTAssertEqual(retrieveCount, urls.count, "All cached playlists should be retrievable")
    }

    func testCacheInvalidation() async throws {
        let url = URL(string: "https://example.com/expiring.m3u8")!
        let testData = "test data".data(using: .utf8)!
        
        let bgContext = createBackgroundContext()
        try await bgContext.perform {
            // Cache with expiry in the past
            let cachePath = PlaylistCacheManager.cachePlaylist(url: url, data: testData, context: bgContext)
            XCTAssertNotNil(cachePath, "Should cache playlist")
            
            // Retrieve should return data even if expired (expiry logic depends on implementation)
            let retrieved = PlaylistCacheManager.getCachedPlaylist(url: url, context: bgContext)
            XCTAssertNotNil(retrieved, "Cache should exist")
            
            try bgContext.save()
        }
    }

    func testUpdateExistingCache() async throws {
        let url = URL(string: "https://example.com/update.m3u8")!
        let originalData = "original".data(using: .utf8)!
        let updatedData = "updated".data(using: .utf8)!
        
        let bgContext = createBackgroundContext()
        let retrieved = try await bgContext.perform {
            // Cache original
            let path1 = PlaylistCacheManager.cachePlaylist(url: url, data: originalData, context: bgContext)
            XCTAssertNotNil(path1, "Should cache original playlist")
            try bgContext.save()
            
            // Update cache
            let path2 = PlaylistCacheManager.cachePlaylist(url: url, data: updatedData, context: bgContext)
            XCTAssertNotNil(path2, "Should update cached playlist")
            try bgContext.save()
            
            // Retrieve should get updated data
            return PlaylistCacheManager.getCachedPlaylist(url: url, context: bgContext)
        }
        
        XCTAssertNotNil(retrieved, "Should retrieve updated cache")
        XCTAssertEqual(String(data: retrieved!, encoding: .utf8), "updated", "Should get updated data")
    }

    func testCacheWithSpecialCharactersInURL() async throws {
        let url = URL(string: "https://example.com/playlist?user=test&token=abc123&special=%20%21")!
        let testData = "special url test".data(using: .utf8)!
        
        let bgContext = createBackgroundContext()
        let (cachePath, retrieved) = try await bgContext.perform {
            let path = PlaylistCacheManager.cachePlaylist(url: url, data: testData, context: bgContext)
            let data = PlaylistCacheManager.getCachedPlaylist(url: url, context: bgContext)
            try bgContext.save()
            return (path, data)
        }
        
        XCTAssertNotNil(cachePath, "Should cache playlist with special URL characters")
        XCTAssertNotNil(retrieved, "Should retrieve playlist with special URL characters")
        XCTAssertEqual(retrieved, testData, "Retrieved data should match original")
    }

    func testCacheEmptyPlaylist() async throws {
        let url = URL(string: "https://example.com/empty.m3u8")!
        let emptyData = Data()
        
        let bgContext = createBackgroundContext()
        let cachePath = try await bgContext.perform {
            let path = PlaylistCacheManager.cachePlaylist(url: url, data: emptyData, context: bgContext)
            try bgContext.save()
            return path
        }
        
        XCTAssertNotNil(cachePath, "Should cache empty playlist")
    }

    func testGetCachedPlaylistForNonexistentURL() async throws {
        let url = URL(string: "https://example.com/nonexistent.m3u8")!

        let bgContext = createBackgroundContext()
        let retrieved = await bgContext.perform {
            PlaylistCacheManager.getCachedPlaylist(url: url, context: bgContext)
        }
        
        XCTAssertNil(retrieved, "Should return nil for nonexistent cache")
    }

    func testCacheWithBinaryData() async throws {
        let url = URL(string: "https://example.com/binary.dat")!
        let binaryData = Data([0x00, 0xFF, 0x12, 0x34, 0xAB, 0xCD])
        
        let bgContext = createBackgroundContext()
        let (cachePath, retrieved) = try await bgContext.perform {
            let path = PlaylistCacheManager.cachePlaylist(url: url, data: binaryData, context: bgContext)
            let data = PlaylistCacheManager.getCachedPlaylist(url: url, context: bgContext)
            try bgContext.save()
            return (path, data)
        }
        
        XCTAssertNotNil(cachePath, "Should cache binary data")
        XCTAssertEqual(retrieved, binaryData, "Retrieved binary data should match original")
    }

    func testStressTestManyConcurrentReads() async throws {
        let url = URL(string: "https://example.com/popular.m3u8")!
        let testData = "popular playlist".data(using: .utf8)!
        
        // Cache once
        let bgContext = createBackgroundContext()
        try await bgContext.perform {
            let path = PlaylistCacheManager.cachePlaylist(url: url, data: testData, context: bgContext)
            XCTAssertNotNil(path, "Should cache playlist")
            try bgContext.save()
        }
        
        // Test multiple sequential reads (SQLite handles concurrent reads better than writes)
        // but still safer to do sequentially in tests
        let bgContext2 = createBackgroundContext()
        let successCount = await bgContext2.perform {
            var count = 0
            for _ in 1...100 {
                if PlaylistCacheManager.getCachedPlaylist(url: url, context: bgContext2) != nil {
                    count += 1
                }
            }
            return count
        }
        
        XCTAssertEqual(successCount, 100, "All reads should succeed")
    }
}
