import XCTest
import CoreData
@testable import StreamHaven

@MainActor
class M3UPlaylistParserTests: XCTestCase {
    var container: NSPersistentContainer!
    var context: NSManagedObjectContext!
    var persistenceProvider: PersistenceProviding!

    override func setUp() async throws {
        try await super.setUp()
        container = NSPersistentContainer(
            name: "StreamHavenTest",
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
        
        context = container.viewContext
        struct TestProvider: PersistenceProviding {
            let container: NSPersistentContainer
        }
        persistenceProvider = TestProvider(container: container)
    }
    
    override func tearDown() async throws {
        context = nil
        persistenceProvider = nil
        container = nil
        try await super.tearDown()
    }

    func testParseM3UPlaylist() throws {
        let m3uString = """
        #EXTM3U
        #EXTINF:-1 tvg-id="channel1" tvg-name="Channel 1" tvg-logo="logo1.png" group-title="News",Channel 1
        http://server.com/stream1
        #EXTINF:-1 tvg-id="movie1" tvg-name="Movie 1" tvg-logo="logo2.png" group-title="Movies",Movie 1
        http://server.com/movie1
        """
        guard let m3uData = m3uString.data(using: .utf8) else { XCTFail("UTF8 conversion failed"); return }

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

    func testParsesHeaderEPGURL() throws {
        let m3uString = "#EXTM3U url-tvg=\"http://epg.example.com/guide.xml\"\n#EXTINF:-1,Channel\nhttp://server/stream"
        guard let data = m3uString.data(using: .utf8) else { XCTFail("UTF8 conversion failed"); return }
        try M3UPlaylistParser.parse(data: data, context: context)
        let req: NSFetchRequest<PlaylistCache> = PlaylistCache.fetchRequest()
        let cache = try context.fetch(req).first
        XCTAssertEqual(cache?.epgURL, "http://epg.example.com/guide.xml")
    }

    func testHandlesEmptyFileGracefully() throws {
        let data = Data()
        XCTAssertThrowsError(try M3UPlaylistParser.parse(data: data, context: context))
    }

    func testMalformedEXTINFDoesNotCrash() throws {
        let m3uString = "#EXTM3U\n#EXTINF:-1 tvg-id=\"ch1\" tvg-name=Channel 1\nhttp://server/stream1"
        guard let data = m3uString.data(using: .utf8) else { XCTFail("UTF8 conversion failed"); return }
        try M3UPlaylistParser.parse(data: data, context: context)
        let channels = try context.fetch(Channel.fetchRequest())
        XCTAssertEqual(channels.count, 1)
    }

    func testDuplicateMoviesAreNotInsertedTwice() throws {
        let m3uString = """
        #EXTM3U
        #EXTINF:-1 group-title=\"Movies\",Movie A
        http://server/movieA
        #EXTINF:-1 group-title=\"Movies\",Movie A
        http://server/movieA2
        """
        guard let data = m3uString.data(using: .utf8) else { XCTFail("UTF8 conversion failed"); return }
        try M3UPlaylistParser.parse(data: data, context: context)
        try M3UPlaylistParser.parse(data: data, context: context) // parse twice to test dedupe
        let movies = try context.fetch(Movie.fetchRequest())
        XCTAssertEqual(movies.count, 1)
    }
}
