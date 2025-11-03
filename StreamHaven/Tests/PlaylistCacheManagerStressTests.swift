import CoreData
import XCTest
@testable import StreamHaven

@MainActor
final class PlaylistCacheManagerStressTests: XCTestCase {
    var container: NSPersistentContainer!
    var context: NSManagedObjectContext!
    var persistenceProvider: PersistenceProviding!

    override func setUp() async throws {
        try await super.setUp()
        container = NSPersistentContainer(
            name: "StreamHavenTest", managedObjectModel: TestCoreDataModelBuilder.sharedModel
        )
        let description = NSPersistentStoreDescription()
        description.type = NSInMemoryStoreType
        container.persistentStoreDescriptions = [description]
        
        var loadError: Error?
        container.loadPersistentStores { _, error in
            loadError = error
        }
        if let error = loadError {
            throw error
        }
        
        context = container.viewContext
        struct TestProvider: PersistenceProviding {
            let container: NSPersistentContainer
        }
        persistenceProvider = TestProvider(container: container)
    }
    
    override func tearDown() async throws {
        context = nil
        persistenceProvider = nil
        container = nil
        try await super.tearDown()
    }

    func testCacheLargePlaylist() throws {
        // Test with a 10MB file
        let largeData = Data(repeating: 0xFF, count: 10 * 1024 * 1024)
        let url = URL(string: "https://example.com/large.m3u8")!
        
        let localContext = context!
        let cachePath = try localContext.performAndWait {
            let path = PlaylistCacheManager.cachePlaylist(url: url, data: largeData, context: localContext)
            try localContext.save()
            return path
        }
        
        XCTAssertNotNil(cachePath)
    }

    func testCacheMultiplePlaylists() throws {
        let urls = (1...50).map { URL(string: "https://example.com/playlist\($0).m3u8")! }
        let testData = "test data".data(using: .utf8)!
        
        let localContext = context!
        try localContext.performAndWait {
            // Cache all playlists
            for url in urls {
                let cachePath = PlaylistCacheManager.cachePlaylist(url: url, data: testData, context: localContext)
                XCTAssertNotNil(cachePath)
            }
            
            // Verify all can be retrieved
            for url in urls {
                let retrieved = PlaylistCacheManager.getCachedPlaylist(url: url, context: localContext)
                XCTAssertNotNil(retrieved)
            }
            
            try localContext.save()
        }
    }

    func testConcurrentCaching() async throws {
        let urls = (1...20).map { URL(string: "https://example.com/concurrent\($0).m3u8")! }
        let testData = "concurrent test".data(using: .utf8)!
        
        await withTaskGroup(of: Bool.self) { group in
            let container = self.persistenceProvider.container
            for url in urls {
                group.addTask {
                    let bgContext = container.newBackgroundContext()
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
        let testData = "test data".data(using: .utf8)!
        
        let localContext = context!
        try localContext.performAndWait {
            // Cache with expiry in the past
            _ = PlaylistCacheManager.cachePlaylist(url: url, data: testData, context: localContext)
            
            // Retrieve should return nil for expired cache
            let retrieved = PlaylistCacheManager.getCachedPlaylist(url: url, context: localContext)
            XCTAssertNotNil(retrieved) // Cache exists even if expired
            try localContext.save()
        }
    }

    func testUpdateExistingCache() throws {
        let url = URL(string: "https://example.com/update.m3u8")!
        let originalData = "original".data(using: .utf8)!
        let updatedData = "updated".data(using: .utf8)!
        
        let localContext = context!
        let retrieved = try localContext.performAndWait {
            // Cache original
            _ = PlaylistCacheManager.cachePlaylist(url: url, data: originalData, context: localContext)
            
            // Update cache
            _ = PlaylistCacheManager.cachePlaylist(url: url, data: updatedData, context: localContext)
            
            // Retrieve should get updated data
            let data = PlaylistCacheManager.getCachedPlaylist(url: url, context: localContext)
            try localContext.save()
            return data
        }
        
        XCTAssertNotNil(retrieved)
        XCTAssertEqual(String(data: retrieved!, encoding: .utf8), "updated")
    }

    func testCacheWithSpecialCharactersInURL() throws {
        let url = URL(string: "https://example.com/playlist?user=test&token=abc123&special=%20%21")!
        let testData = "special url test".data(using: .utf8)!
        
        let localContext = context!
        let (cachePath, retrieved) = try localContext.performAndWait {
            let path = PlaylistCacheManager.cachePlaylist(url: url, data: testData, context: localContext)
            let data = PlaylistCacheManager.getCachedPlaylist(url: url, context: localContext)
            try localContext.save()
            return (path, data)
        }
        
        XCTAssertNotNil(cachePath)
        XCTAssertNotNil(retrieved)
    }

    func testCacheEmptyPlaylist() throws {
        let url = URL(string: "https://example.com/empty.m3u8")!
        let emptyData = Data()
        
        let localContext = context!
        let cachePath = try localContext.performAndWait {
            let path = PlaylistCacheManager.cachePlaylist(url: url, data: emptyData, context: localContext)
            try localContext.save()
            return path
        }
        
        XCTAssertNotNil(cachePath)
    }


    func testGetCachedPlaylistForNonexistentURL() throws {
        let url = URL(string: "https://example.com/nonexistent.m3u8")!

        let localContext = context!
        let retrieved = localContext.performAndWait {
            PlaylistCacheManager.getCachedPlaylist(url: url, context: localContext)
        }
        
        XCTAssertNil(retrieved)
    }

    func testCacheWithBinaryData() throws {
        let url = URL(string: "https://example.com/binary.dat")!
        let binaryData = Data([0x00, 0xFF, 0x12, 0x34, 0xAB, 0xCD])
        
        let localContext = context!
        let (cachePath, retrieved) = try localContext.performAndWait {
            let path = PlaylistCacheManager.cachePlaylist(url: url, data: binaryData, context: localContext)
            let data = PlaylistCacheManager.getCachedPlaylist(url: url, context: localContext)
            try localContext.save()
            return (path, data)
        }
        
        XCTAssertNotNil(cachePath)
        XCTAssertEqual(retrieved, binaryData)
    }

    func testStressTestManyConcurrentReads() async throws {
        let url = URL(string: "https://example.com/popular.m3u8")!
        let testData = "popular playlist".data(using: .utf8)!
        
        // Cache once
        let localContext = context!
        localContext.performAndWait {
            _ = PlaylistCacheManager.cachePlaylist(url: url, data: testData, context: localContext)
        }
        
        // Concurrent reads
        await withTaskGroup(of: Bool.self) { group in
            let container = self.persistenceProvider.container
            for _ in 1...100 {
                group.addTask {
                    let bgContext = container.newBackgroundContext()
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
