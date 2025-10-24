import XCTest
import CoreData
@testable import StreamHaven

class IntegrationTests: XCTestCase {

    var persistenceController: PersistenceController!
    var context: NSManagedObjectContext!

    override func setUp() {
        super.setUp()
        persistenceController = PersistenceController(inMemory: true)
        context = persistenceController.container.viewContext
    }

    override func tearDown() {
        super.tearDown()
        persistenceController = nil
        context = nil
    }

    func testImportPersistSearchFlow() async throws {
        let m3uString = """
        #EXTM3U
        #EXTINF:-1 tvg-id="movie1" tvg-name="Test Movie" tvg-logo="logo.png" group-title="Movies",Test Movie
        http://server.com/movie1
        """
        let m3uData = m3uString.data(using: .utf8)!

        try M3UPlaylistParser.parse(data: m3uData, context: context)

        let searchExpectation = expectation(description: "Search for imported movie")
        SearchIndexSync.search(query: "Test Movie", persistence: persistenceController) { results in
            XCTAssertEqual(results.count, 1)
            XCTAssertEqual((results.first as? Movie)?.title, "Test Movie")
            searchExpectation.fulfill()
        }

        await fulfillment(of: [searchExpectation], timeout: 1.0)
    }
}
