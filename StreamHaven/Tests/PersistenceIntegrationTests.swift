import CoreData
import XCTest
@testable import StreamHaven

@MainActor
class PersistenceIntegrationTests: XCTestCase {
    var container: NSPersistentContainer!
    var context: NSManagedObjectContext!
    var persistenceProvider: PersistenceProviding!
    var dataManager: StreamHavenData? 

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
        dataManager = StreamHavenData(persistenceProvider: persistenceProvider)
    }

    override func tearDown() async throws {
        dataManager = nil
        context = nil
        persistenceProvider = nil
        container = nil
        try await super.tearDown()
    }

    func testParseSaveFetchRoundtrip() {
        let m3uString = """
        #EXTM3U
        #EXTINF:-1 tvg-id="channel1" tvg-name="Channel 1" tvg-logo="http://logo.url/1.png" group-title="Group A", Channel 1
        http://stream.url/1
        """
        guard let data = m3uString.data(using: .utf8) else { XCTFail("UTF8 conversion failed"); return }
        guard let url = URL(string: "http://example.com/playlist.m3u") else { XCTFail("Invalid URL"); return }

        let expectation = XCTestExpectation(description: "Playlist is parsed and saved")

        guard let dataManager = dataManager, let context = context else { XCTFail("Missing dependencies"); return }
        let backgroundContext = dataManager.backgroundContext

        backgroundContext.perform {
            _ = PlaylistCacheManager.cachePlaylist(url: url, data: data, context: backgroundContext)
            do {
                try M3UPlaylistParser.parse(data: data, context: backgroundContext)
            } catch {
                XCTFail("Parse failed: \(error)")
            }

            do {
                try backgroundContext.save()
            } catch {
                XCTFail("Failed to save background context: \(error)")
            }

            context.perform {
                let fetchRequest: NSFetchRequest<Channel> = Channel.fetchRequest()
                do {
                    let channels = try context.fetch(fetchRequest)

                    XCTAssertEqual(channels.count, 1)
                    XCTAssertEqual(channels.first?.name, "Channel 1")

                    expectation.fulfill()
                } catch {
                    XCTFail("Fetch failed: \(error)")
                }
            }
        }

        wait(for: [expectation], timeout: 5.0)
    }
}
