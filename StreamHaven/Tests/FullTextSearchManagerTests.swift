import XCTest
import CoreData
@testable import StreamHaven

@MainActor
final class FullTextSearchManagerTests: XCTestCase {

    func testFTSSetupIsIdempotent() throws {
        throw XCTSkip("FTS tests require file-based SQLite store with FTS5 support")
    }
}
