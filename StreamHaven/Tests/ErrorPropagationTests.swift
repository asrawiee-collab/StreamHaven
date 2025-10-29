import XCTest
import CoreData
@testable import StreamHaven

@MainActor
final class ErrorPropagationTests: XCTestCase {
    func testImportPlaylistNetworkErrorPropagates() async throws {
        throw XCTSkip("Test disabled - involves EPG parsing which uses NSBatchDeleteRequest that hangs with in-memory stores")
    }
}
