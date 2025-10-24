import XCTest
import CoreData
@testable import StreamHaven

class SearchIndexTests: XCTestCase {

    var persistenceController: PersistenceController?
    var persistenceProvider: PersistenceProviding?
    var context: NSManagedObjectContext?

    override func setUp() {
        super.setUp()
        persistenceController = PersistenceController(inMemory: true)
        if let pc = persistenceController {
            persistenceProvider = DefaultPersistenceProvider(controller: pc)
            context = persistenceProvider?.container.viewContext
        }
    }

    override func tearDown() {
        context = nil
        persistenceProvider = nil
        persistenceController = nil
        super.tearDown()
    }

    func testSearch() {
        guard let context = context, let persistenceProvider = persistenceProvider else { XCTFail("Missing dependencies"); return }
        let movie = Movie(context: context)
        movie.title = "The Best Movie Ever"

        do { try context.save() } catch { XCTFail("Save failed: \(error)") }

        let expectation = self.expectation(description: "Search completes")

        SearchIndexSync.search(query: "Best", persistence: persistenceProvider) { results in
            XCTAssertEqual(results.count, 1)
            XCTAssertEqual((results.first as? Movie)?.title, "The Best Movie Ever")
            expectation.fulfill()
        }

        waitForExpectations(timeout: 5, handler: nil)
    }
}
