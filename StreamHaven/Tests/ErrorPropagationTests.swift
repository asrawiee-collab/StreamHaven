import XCTest
import CoreData
@testable import StreamHaven

@MainActor
final class ErrorPropagationTests: XCTestCase {
    func testImportPlaylistNetworkErrorPropagates() async throws {
        // TODO: Implement test once network error handling is in place
        throw XCTSkip("Test needs implementation with mock URLSession")
    }
}
