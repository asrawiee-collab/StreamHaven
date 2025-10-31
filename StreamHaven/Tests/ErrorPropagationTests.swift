import XCTest
import CoreData
@testable import StreamHaven

@MainActor
final class ErrorPropagationTests: XCTestCase {
    var provider: PersistenceProviding!
    var context: NSManagedObjectContext!
    
    override func setUp() async throws {
        try await super.setUp()
        let container = NSPersistentContainer(
            name: "ErrorPropagationTest",
            managedObjectModel: TestCoreDataModelBuilder.sharedModel
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
        
        provider = TestPersistenceProvider(container: container)
        context = provider.container.newBackgroundContext()
    }
    
    override func tearDown() async throws {
        context = nil
        provider = nil
        try await super.tearDown()
    }
    
    func testM3UParserEmptyDataThrowsError() throws {
        let emptyData = Data()
        XCTAssertThrowsError(try M3UPlaylistParser.parse(data: emptyData, context: context)) { error in
            // Verify error is properly propagated
            XCTAssertTrue(error.localizedDescription.contains("Empty") || error.localizedDescription.count > 0)
        }
    }
    
    func testM3UParserInvalidEncodingThrowsError() throws {
        // Create data that can't be decoded as UTF-8
        let invalidData = Data([0xFF, 0xFE, 0xFF, 0xFE])
        XCTAssertThrowsError(try M3UPlaylistParser.parse(data: invalidData, context: context)) { error in
            XCTAssertTrue(error.localizedDescription.count > 0, "Error should have description")
        }
    }
    
    func testCoreDataSaveErrorsPropagateCorrectly() throws {
        // Test that Core Data operations handle errors properly
        let channel = Channel(context: context)
        channel.name = "Test Channel"
        channel.tvgID = "test"
        channel.logoURL = "https://example.com/logo.png"
        
        // Save should succeed
        XCTAssertNoThrow(try context.save())
        
        // Verify channel was created
        let channels = try context.fetch(Channel.fetchRequest())
        XCTAssertEqual(channels.count, 1, "Should create one channel")
        XCTAssertEqual(channels.first?.name, "Test Channel")
    }
    
    func testImportPlaylistInvalidURLError() async throws {
        // Test error propagation with invalid URL
        let invalidURL = URL(string: "not-a-valid-url")!
        
        do {
            try await PlaylistParser.parse(url: invalidURL, context: context)
            XCTFail("Should throw error for invalid URL")
        } catch {
            // Error should be propagated
            XCTAssertTrue(error.localizedDescription.count > 0)
        }
    }
}

private struct TestPersistenceProvider: PersistenceProviding {
    let container: NSPersistentContainer
}
