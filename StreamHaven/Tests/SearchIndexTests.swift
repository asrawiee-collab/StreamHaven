import XCTest
import CoreData
@testable import StreamHaven

class SearchIndexTests: XCTestCase {

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

    func testSearch() {
        let movie = Movie(context: context)
        movie.title = "The Best Movie Ever"

        try! context.save()

        let expectation = self.expectation(description: "Search completes")

        SearchIndexSync.search(query: "Best", persistence: persistenceController) { results in
            XCTAssertEqual(results.count, 1)
            XCTAssertEqual((results.first as? Movie)?.title, "The Best Movie Ever")
            expectation.fulfill()
        }

        waitForExpectations(timeout: 5, handler: nil)
    }
}
