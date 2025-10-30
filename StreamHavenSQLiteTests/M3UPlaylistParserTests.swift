import XCTest
import CoreData
@testable import StreamHaven

@MainActor
final class M3UPlaylistParserTests: FileBasedTestCase {
    // FileBasedTestCase provides: container, context, persistenceProvider
    // No custom setUp/tearDown needed - handled by base class

    func testParseM3UPlaylist() throws {
        guard let ctx = context else {
            XCTFail("Context not available")
            return
        }
        
        let m3uString = """
        #EXTM3U
        #EXTINF:-1 tvg-id="channel1" tvg-name="Channel 1" tvg-logo="logo1.png" group-title="News",Channel 1
        http://server.com/stream1
        #EXTINF:-1 tvg-id="movie1" tvg-name="Movie 1" tvg-logo="logo2.png" group-title="Movies",Movie 1
        http://server.com/movie1
        """
        guard let m3uData = m3uString.data(using: .utf8) else { XCTFail("UTF8 conversion failed"); return }

        try M3UPlaylistParser.parse(data: m3uData, context: ctx)

        let channelFetchRequest: NSFetchRequest<Channel> = Channel.fetchRequest()
        let channels = try ctx.fetch(channelFetchRequest)
        XCTAssertEqual(channels.count, 1)
        XCTAssertEqual(channels.first?.name, "Channel 1")

        let movieFetchRequest: NSFetchRequest<Movie> = Movie.fetchRequest()
        let movies = try ctx.fetch(movieFetchRequest)
        XCTAssertEqual(movies.count, 1)
        XCTAssertEqual(movies.first?.title, "Movie 1")
    }

    func testParsesHeaderEPGURL() throws {
        guard let ctx = context else {
            XCTFail("Context not available")
            return
        }
        
        let m3uString = "#EXTM3U url-tvg=\"http://epg.example.com/guide.xml\"\n#EXTINF:-1,Channel\nhttp://server/stream"
        guard let data = m3uString.data(using: .utf8) else { XCTFail("UTF8 conversion failed"); return }
        try M3UPlaylistParser.parse(data: data, context: ctx)
        let req: NSFetchRequest<PlaylistCache> = PlaylistCache.fetchRequest()
        let cache = try ctx.fetch(req).first
        XCTAssertEqual(cache?.epgURL, "http://epg.example.com/guide.xml")
    }

    func testHandlesEmptyFileGracefully() throws {
        guard let ctx = context else {
            XCTFail("Context not available")
            return
        }
        
        let data = Data()
        XCTAssertThrowsError(try M3UPlaylistParser.parse(data: data, context: ctx))
    }

    func testMalformedEXTINFDoesNotCrash() throws {
        guard let ctx = context else {
            XCTFail("Context not available")
            return
        }
        
        let m3uString = "#EXTM3U\n#EXTINF:-1 tvg-id=\"ch1\" tvg-name=Channel 1\nhttp://server/stream1"
        guard let data = m3uString.data(using: .utf8) else { XCTFail("UTF8 conversion failed"); return }
        try M3UPlaylistParser.parse(data: data, context: ctx)
        let channels = try ctx.fetch(Channel.fetchRequest())
        XCTAssertEqual(channels.count, 1)
    }

    func testDuplicateMoviesAreNotInsertedTwice() throws {
        guard let ctx = context else {
            XCTFail("Context not available")
            return
        }
        
        let m3uString = """
        #EXTM3U
        #EXTINF:-1 group-title=\"Movies\",Movie A
        http://server/movieA
        #EXTINF:-1 group-title=\"Movies\",Movie A
        http://server/movieA2
        """
        guard let data = m3uString.data(using: .utf8) else { XCTFail("UTF8 conversion failed"); return }
        try M3UPlaylistParser.parse(data: data, context: ctx)
        try M3UPlaylistParser.parse(data: data, context: ctx) // parse twice to test dedupe
        let movies = try ctx.fetch(Movie.fetchRequest())
        XCTAssertEqual(movies.count, 1)
    }
}
