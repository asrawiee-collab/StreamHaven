import CoreData
import XCTest
@testable import StreamHaven

@MainActor
class IntegrationTests: XCTestCase {
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

    func testImportPersistSearchFlow() async throws {
        let m3uString = """
        #EXTM3U
        #EXTINF:-1 tvg-id="movie1" tvg-name="Test Movie" tvg-logo="logo.png" group-title="Movies", Test Movie
        http://server.com/movie1
        """
        guard let m3uData = m3uString.data(using: .utf8) else { XCTFail("UTF8 conversion failed"); return }

        try M3UPlaylistParser.parse(data: m3uData, context: context)

        let searchExpectation = expectation(description: "Search for imported movie")
        SearchIndexSync.search(query: "Test Movie", persistence: persistenceProvider) { results in
            XCTAssertEqual(results.count, 1)
            XCTAssertEqual((results.first as? Movie)?.title, "Test Movie")
            searchExpectation.fulfill()
        }

        await fulfillment(of: [searchExpectation], timeout: 1.0)
    }
}
