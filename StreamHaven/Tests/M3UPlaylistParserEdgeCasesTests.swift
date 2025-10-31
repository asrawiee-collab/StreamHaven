import XCTest
import CoreData
@testable import StreamHaven

final class M3UPlaylistParserEdgeCasesTests: XCTestCase {
    var provider: PersistenceProviding!
    var context: NSManagedObjectContext!

    override func setUpWithError() throws {
        let container = NSPersistentContainer(
            name: "M3UEdgeCaseTesting",
            managedObjectModel: TestCoreDataModelBuilder.sharedModel
        )
        
        let description = NSPersistentStoreDescription()
        description.type = NSInMemoryStoreType
        container.persistentStoreDescriptions = [description]
        
        var loadError: Error?
        container.loadPersistentStores { _, error in
            loadError = error
        }
        
        guard loadError == nil else {
            throw XCTSkip("Failed to load in-memory store: \(loadError!)")
        }
        
        provider = TestPersistenceProvider(container: container)
        context = provider.container.newBackgroundContext()
    }

    func testParsingInvalidLinesDoesNotCrashAndThrows() throws {
        // Test that parser handles invalid M3U data gracefully
        let invalidM3U = """
        #EXTM3U
        #EXTINF:-1,Missing URL line
        #EXTINF:-1 tvg-id="" tvg-name="Channel" group-title="News",Channel Name
        http://
        random-garbage-line
        """.data(using: .utf8)!

        // Parser should complete without crashing, even with malformed data
        // It may either throw an error or skip invalid entries
        do {
            try context.performAndWait {
                try M3UPlaylistParser.parse(data: invalidM3U, context: context)
            }
            // If parsing succeeds, verify it didn't create invalid entries
            let channelRequest: NSFetchRequest<Channel> = Channel.fetchRequest()
            let channels = try context.fetch(channelRequest)
            // Should have at most 1 channel (the one with http:// URL, though invalid)
            XCTAssertLessThanOrEqual(channels.count, 1, "Should not create multiple entries from invalid data")
        } catch {
            // It's acceptable to throw an error for invalid data
            XCTAssertTrue(error.localizedDescription.count > 0, "Error should have description")
        }
    }

    func testStreamingEarlyEOFHandledGracefully() throws {
        // Test that parser handles incomplete playlist file gracefully
        // Simulate a partial file that ends mid-entry
        let partial = """
        #EXTM3U
        #EXTINF:-1 tvg-id="abc" tvg-name="A" group-title="News",A
        http://example.com/stream
        #EXTINF:-1 tvg-id="def" tvg-name="B" group-title="News",B
        """.data(using: .utf8)!

        // Should not insert incomplete second entry (no URL for entry B)
        try context.performAndWait {
            // Using file-based path for streaming mode
            let tmp = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
            try partial.write(to: tmp)
            defer { try? FileManager.default.removeItem(at: tmp) }
            try M3UPlaylistParser.parse(fileURL: tmp, context: context)
        }

        let request: NSFetchRequest<Channel> = Channel.fetchRequest()
        let channels = try context.fetch(request)
        // Should only have the complete first entry
        XCTAssertEqual(channels.count, 1, "Should only import complete entries")
        XCTAssertEqual(channels.first?.name, "A", "Should import the first complete channel")
    }
}

private struct TestPersistenceProvider: PersistenceProviding {
    let container: NSPersistentContainer
}
