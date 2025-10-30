import XCTest
import CoreData
@testable import StreamHaven

/// Performance tests for playlist parsing operations.
@MainActor
class ParserPerformanceTests: XCTestCase {
    var container: NSPersistentContainer!
    var context: NSManagedObjectContext!
    var persistenceProvider: PersistenceProviding!
    
    override func setUp() async throws {
        try await super.setUp()
        container = NSPersistentContainer(
            name: "StreamHavenTest",
            managedObjectModel: TestCoreDataModelBuilder.sharedModel
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
    
    // MARK: - M3U Parser Performance Tests
    
    func testM3UBatchInsertPerformance_SmallPlaylist() throws {
        // Generate a small M3U playlist with 100 channels
        let m3uContent = generateM3UPlaylist(channelCount: 100, movieCount: 50)
        guard let data = m3uContent.data(using: .utf8) else { XCTFail("UTF8 conversion failed"); return }
        
        measure {
            do { try M3UPlaylistParser.parse(data: data, context: context) } catch { XCTFail("Parse failed: \(error)") }
            context.reset() // Clean up for next iteration
        }
    }
    
    func testM3UBatchInsertPerformance_MediumPlaylist() throws {
        // Generate a medium M3U playlist with 1,000 channels
        let m3uContent = generateM3UPlaylist(channelCount: 1000, movieCount: 500)
        guard let data = m3uContent.data(using: .utf8) else { XCTFail("UTF8 conversion failed"); return }
        
        measure {
            do { try M3UPlaylistParser.parse(data: data, context: context) } catch { XCTFail("Parse failed: \(error)") }
            context.reset()
        }
    }
    
    func testM3UBatchInsertPerformance_LargePlaylist() throws {
        // Generate a large M3U playlist with 10,000 channels
        let m3uContent = generateM3UPlaylist(channelCount: 10000, movieCount: 5000)
        guard let data = m3uContent.data(using: .utf8) else { XCTFail("UTF8 conversion failed"); return }
        
        measure {
            do { try M3UPlaylistParser.parse(data: data, context: context) } catch { XCTFail("Parse failed: \(error)") }
            context.reset()
        }
    }
    
    func testM3UStreamingParserMemoryEfficiency() throws {
        // Test streaming parser with a large file
        let m3uContent = generateM3UPlaylist(channelCount: 50000, movieCount: 25000)
        guard let data = m3uContent.data(using: .utf8) else { XCTFail("UTF8 conversion failed"); return }
        
        // Write to temporary file
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("large_playlist.m3u")
        try data.write(to: tempURL)
        
        defer {
            try? FileManager.default.removeItem(at: tempURL)
        }
        
        measure {
            do { try M3UPlaylistParser.parse(fileURL: tempURL, context: context) } catch { XCTFail("Parse failed: \(error)") }
            context.reset()
        }
    }
    
    // MARK: - Xtream Codes Parser Performance Tests
    
    func testXtreamCodesBatchInsertPerformance() async throws {
        // Note: This test would require a mock URLSession
        // See XtreamCodesParserTests for actual implementation with MockURLProtocol
    }
    
    // MARK: - Helper Methods
    
    /// Generates a synthetic M3U playlist for testing.
    private func generateM3UPlaylist(channelCount: Int, movieCount: Int) -> String {
        var lines = ["#EXTM3U url-tvg=\"http://example.com/epg.xml\""]
        
        // Generate channels
        for i in 1...channelCount {
            lines.append("#EXTINF:-1 tvg-id=\"channel\(i)\" tvg-name=\"Channel \(i)\" tvg-logo=\"http://logo.url/\(i).png\" group-title=\"Live TV\",Channel \(i)")
            lines.append("http://stream.url/channel\(i)")
        }
        
        // Generate movies
        for i in 1...movieCount {
            lines.append("#EXTINF:-1 tvg-id=\"movie\(i)\" tvg-name=\"Movie \(i)\" tvg-logo=\"http://poster.url/\(i).png\" group-title=\"Movies\",Movie \(i)")
            lines.append("http://stream.url/movie\(i).mp4")
        }
        
        return lines.joined(separator: "\n")
    }
    
    // MARK: - Batch Insert Validation
    
    func testBatchInsertCreatesCorrectCount() throws {
        let m3uContent = generateM3UPlaylist(channelCount: 100, movieCount: 50)
        guard let data = m3uContent.data(using: .utf8) else { XCTFail("UTF8 conversion failed"); return }
        
        try M3UPlaylistParser.parse(data: data, context: context)
        
        let channelFetch: NSFetchRequest<Channel> = Channel.fetchRequest()
        let channelCount = try context.count(for: channelFetch)
        XCTAssertEqual(channelCount, 100, "Should create 100 channels")
        
        let movieFetch: NSFetchRequest<Movie> = Movie.fetchRequest()
        let movieCount = try context.count(for: movieFetch)
        XCTAssertEqual(movieCount, 50, "Should create 50 movies")
        
        let variantFetch: NSFetchRequest<ChannelVariant> = ChannelVariant.fetchRequest()
        let variantCount = try context.count(for: variantFetch)
        XCTAssertEqual(variantCount, 100, "Should create 100 channel variants")
    }
    
    func testBatchInsertAvoidseDuplicates() throws {
        let m3uContent = generateM3UPlaylist(channelCount: 50, movieCount: 25)
        guard let data = m3uContent.data(using: .utf8) else { XCTFail("UTF8 conversion failed"); return }
        
        // Import twice
        try M3UPlaylistParser.parse(data: data, context: context)
        try M3UPlaylistParser.parse(data: data, context: context)
        
        let channelFetch: NSFetchRequest<Channel> = Channel.fetchRequest()
        let channelCount = try context.count(for: channelFetch)
        XCTAssertEqual(channelCount, 50, "Should not create duplicate channels")
        
        let movieFetch: NSFetchRequest<Movie> = Movie.fetchRequest()
        let movieCount = try context.count(for: movieFetch)
        XCTAssertEqual(movieCount, 25, "Should not create duplicate movies")
    }
}
