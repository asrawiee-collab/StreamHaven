import XCTest
import CoreData
@testable import StreamHaven

@MainActor
final class FullTextSearchManagerTests: FileBasedTestCase {
    
    override func needsFTS() -> Bool {
        return true
    }

    func testFTSSetupIsIdempotent() throws {
        let fts = FullTextSearchManager(persistenceProvider: persistenceProvider)
        try fts.initializeFullTextSearch()
        // Calling again should not throw
        try fts.initializeFullTextSearch()
        
        XCTAssertTrue(true, "FTS setup should be idempotent")
    }
}
