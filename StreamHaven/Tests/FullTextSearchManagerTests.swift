import XCTest
import CoreData
@testable import StreamHaven

final class FullTextSearchManagerTests: XCTestCase {
    var provider: PersistenceProviding!

    override func setUpWithError() throws {
        let controller = PersistenceController(inMemory: true)
        provider = DefaultPersistenceProvider(controller: controller)
    }

    func testFTSSetupIsIdempotent() throws {
        let fts = FullTextSearchManager(persistenceProvider: provider)
        try fts.initializeFullTextSearch()
        // Calling again should not throw
        try fts.initializeFullTextSearch()
    }
}
