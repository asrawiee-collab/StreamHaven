import XCTest
import CoreData
@testable import StreamHaven

class M3UPlaylistParserTests: XCTestCase {

    var persistenceController: PersistenceController!
    var context: NSManagedObjectContext!

    override func setUp() {
        super.setUp()
        persistenceController = PersistenceController(inMemory: true)
        context = persistenceController.container.viewContext
    }

    override func tearDown() {
        super.tearDown()
        persistenceController = nil
        context = nil
    }

    func testParseM3UPlaylist() throws {
        let m3uString = """
        #EXTM3U
        #EXTINF:-1 tvg-id="channel1" tvg-name="Channel 1" tvg-logo="logo1.png" group-title="News",Channel 1
        http://server.com/stream1
        #EXTINF:-1 tvg-id="movie1" tvg-name="Movie 1" tvg-logo="logo2.png" group-title="Movies",Movie 1
        http://server.com/movie1
        """
        let m3uData = m3uString.data(using: .utf8)!

        try M3UPlaylistParser.parse(data: m3uData, context: context)

        let channelFetchRequest: NSFetchRequest<Channel> = Channel.fetchRequest()
        let channels = try context.fetch(channelFetchRequest)
        XCTAssertEqual(channels.count, 1)
        XCTAssertEqual(channels.first?.name, "Channel 1")

        let movieFetchRequest: NSFetchRequest<Movie> = Movie.fetchRequest()
        let movies = try context.fetch(movieFetchRequest)
        XCTAssertEqual(movies.count, 1)
        XCTAssertEqual(movies.first?.title, "Movie 1")
    }
}
