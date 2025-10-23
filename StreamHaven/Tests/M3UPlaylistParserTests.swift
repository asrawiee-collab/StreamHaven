import XCTest
import CoreData
@testable import StreamHaven

class M3UPlaylistParserTests: XCTestCase {

    var persistenceController: PersistenceController!
    var context: NSManagedObjectContext!

    override func setUp() {
        super.setUp()
        persistenceController = PersistenceController(inMemory: true)
        context = persistenceController.container.viewContext
    }

    override func tearDown() {
        context = nil
        persistenceController = nil
        super.tearDown()
    }

    func testStandardM3U() {
        let m3uString = """
        #EXTM3U
        #EXTINF:-1 tvg-id="channel1" tvg-name="Channel 1" tvg-logo="http://logo.url/1.png" group-title="Group A",Channel 1
        http://stream.url/1
        """
        let data = m3uString.data(using: .utf8)!

        XCTAssertNoThrow(try M3UPlaylistParser.parse(data: data, context: context))

        let fetchRequest: NSFetchRequest<Channel> = Channel.fetchRequest()

        XCTAssertNoThrow(try {
            let channels = try context.fetch(fetchRequest)
            XCTAssertEqual(channels.count, 1)
            XCTAssertEqual(channels.first?.name, "Channel 1")
            XCTAssertEqual(channels.first?.variants?.count, 1)
        }())
    }

    func testInvalidDataEncoding() {
        // Using a different encoding to make the data invalid for UTF-8 parsing
        let m3uString = "invalid data"
        let data = m3uString.data(using: .utf16)!

        XCTAssertThrowsError(try M3UPlaylistParser.parse(data: data, context: context)) { error in
            XCTAssertEqual(error as? M3UParserError, .invalidDataEncoding)
        }
    }
}
