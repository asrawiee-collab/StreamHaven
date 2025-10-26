import XCTest
import CoreData
@testable import StreamHaven

final class M3UPlaylistParserEdgeCasesTests: XCTestCase {
    var provider: PersistenceProviding!
    var context: NSManagedObjectContext!

    override func setUpWithError() throws {
        let controller = PersistenceController(inMemory: true)
        provider = DefaultPersistenceProvider(controller: controller)
        context = provider.container.newBackgroundContext()
    }

    func testParsingInvalidLinesDoesNotCrashAndThrows() throws {
        let invalidM3U = """
        #EXTM3U
        #EXTINF:-1,Missing URL line
        #EXTINF:-1 tvg-id="" tvg-name="Channel" group-title="News":Channel Name
        http://
        random-garbage-line
        """.data(using: .utf8)!

        XCTAssertThrowsError(try context.performAndWait { () -> Void in
            try M3UPlaylistParser.parse(data: invalidM3U, context: context)
        }) { error in
            // Ensure a meaningful error is propagated
            XCTAssertTrue(error.localizedDescription.count > 0)
        }
    }

    func testStreamingEarlyEOFHandledGracefully() throws {
        // Simulate a partial file that ends mid-entry
        let partial = """
        #EXTM3U
        #EXTINF:-1 tvg-id="abc" tvg-name="A" group-title="News":A
        http://example.com/stream
        #EXTINF:-1 tvg-id="def" tvg-name="B" group-title="News":B
        """.data(using: .utf8)!

        // Should not insert incomplete second entry
        try context.performAndWait {
            // Using non-throwing file-based path for streaming mode where possible
            let tmp = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
            try partial.write(to: tmp)
            defer { try? FileManager.default.removeItem(at: tmp) }
            try M3UPlaylistParser.parse(fileURL: tmp, context: context)
        }

        let request: NSFetchRequest<Channel> = Channel.fetchRequest()
        let channels = try context.fetch(request)
        XCTAssertEqual(channels.count, 1)
    }
}
