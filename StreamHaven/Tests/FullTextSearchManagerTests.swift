import XCTest
import CoreData
@testable import StreamHaven

final class FullTextSearchManagerTests: XCTestCase {
    var provider: PersistenceProviding!

    override func setUpWithError() throws {
        throw XCTSkip("FTS requires file-based SQLite store, incompatible with in-memory testing")
        throw XCTSkip("FTS requires file-based SQLite store, incompatible with in-memory testing")
        let container = NSPersistentContainer(
            name: "FullTextSearchTesting",
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
    }

    func testFTSSetupIsIdempotent() throws {
        let fts = FullTextSearchManager(persistenceProvider: provider)
        try fts.initializeFullTextSearch()
        // Calling again should not throw
        try fts.initializeFullTextSearch()
    }
}

private struct TestPersistenceProvider: PersistenceProviding {
    let container: NSPersistentContainer
}
