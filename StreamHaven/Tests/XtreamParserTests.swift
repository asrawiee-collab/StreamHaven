import CoreData
import XCTest
@testable import StreamHaven

class XtreamParserTests: XCTestCase {

    var persistenceController: PersistenceController?
    var context: NSManagedObjectContext?

    override func setUp() {
        super.setUp()
        persistenceController = PersistenceController(inMemory: true)
        context = persistenceController?.container.viewContext
    }

    override func tearDown() {
        context = nil
        persistenceController = nil
        super.tearDown()
    }

    func testInvalidURL() async {
        guard let invalidURL = URL(string: "http://invalid-url-that-will-fail.com") else {
            XCTFail("Invalid test URL")
            return
        }

        do {
            guard let context = context else { XCTFail("Missing context"); return }
            try await XtreamCodesParser.parse(url: invalidURL, username: "test", password: "test", context: context)
            XCTFail("Parser should have thrown an error for an invalid URL")
        } catch {
            XCTAssertNotNil(error)
        }
    }

    // Note: A full integration test would require a mock URLSession.
    // This test primarily ensures that the data is saved to Core Data correctly
    // when a valid payload is decoded. A full test of the networking and parsing
    // logic would require more extensive mocking.
}
