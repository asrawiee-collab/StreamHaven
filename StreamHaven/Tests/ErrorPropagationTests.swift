import XCTest
import CoreData
@testable import StreamHaven

final class ErrorPropagationTests: XCTestCase {
    func testImportPlaylistNetworkErrorPropagates() async {
        // Arrange a manager with isolated provider
        let controller = PersistenceController(inMemory: true)
        let provider = DefaultPersistenceProvider(controller: controller)
        let manager = StreamHavenData(persistenceProvider: provider)

        // Inject URLProtocol to force error
        let config = URLSessionConfiguration.default
        config.protocolClasses = [MockURLProtocol.self]
        MockURLProtocol.requestHandler = { _ in
            throw URLError(.timedOut)
        }

        // Act
        do {
            guard let url = URL(string: "https://example.com/fail.m3u") else {
                return XCTFail("Invalid URL")
            }
            try await manager.importPlaylist(from: url) { _ in }
            XCTFail("Expected error to be thrown")
        } catch {
            // Assert: we receive an error and can log it
            ErrorReporter.log(error, context: "ErrorPropagationTests")
            XCTAssertTrue(error.localizedDescription.count > 0)
        }
    }
}
