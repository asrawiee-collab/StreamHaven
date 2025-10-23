import XCTest
import CoreData
@testable import StreamHaven

class PersistenceIntegrationTests: XCTestCase {

    var persistenceController: PersistenceController!
    var context: NSManagedObjectContext!
    var dataManager: StreamHavenData!

    override func setUp() {
        super.setUp()
        persistenceController = PersistenceController(inMemory: true)
        context = persistenceController.container.viewContext
        dataManager = StreamHavenData(persistenceController: persistenceController)
    }

    override func tearDown() {
        dataManager = nil
        context = nil
        persistenceController = nil
        super.tearDown()
    }

    func testParseSaveFetchRoundtrip() {
        let m3uString = """
        #EXTM3U
        #EXTINF:-1 tvg-id="channel1" tvg-name="Channel 1" tvg-logo="http://logo.url/1.png" group-title="Group A",Channel 1
        http://stream.url/1
        """
        let data = m3uString.data(using: .utf8)!
        let url = URL(string: "http://example.com/playlist.m3u")!

        let expectation = XCTestExpectation(description: "Playlist is parsed and saved")

        let backgroundContext = dataManager.backgroundContext

        backgroundContext.perform {
            let _ = PlaylistCacheManager.cachePlaylist(url: url, data: data, context: backgroundContext)
            M3UPlaylistParser.parse(data: data, context: backgroundContext)

            do {
                try backgroundContext.save()
            } catch {
                XCTFail("Failed to save background context: \\(error)")
            }

            self.context.perform {
                let fetchRequest: NSFetchRequest<Channel> = Channel.fetchRequest()
                let channels = try! self.context.fetch(fetchRequest)

                XCTAssertEqual(channels.count, 1)
                XCTAssertEqual(channels.first?.name, "Channel 1")

                expectation.fulfill()
            }
        }

        wait(for: [expectation], timeout: 5.0)
    }
}
