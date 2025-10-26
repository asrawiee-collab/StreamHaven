import XCTest
import CoreData
@testable import StreamHaven

final class XtreamCodesParserTests: XCTestCase {
    var persistenceController: PersistenceController?
    var context: NSManagedObjectContext?
    var session: URLSession?

    override func setUp() {
        super.setUp()
        persistenceController = PersistenceController(inMemory: true)
        context = persistenceController?.container.viewContext

        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [MockURLProtocol.self]
        session = URLSession(configuration: config)
        if let session { XtreamCodesParser.urlSession = session }
    }

    override func tearDown() {
        persistenceController = nil
        context = nil
        XtreamCodesParser.urlSession = .shared
        super.tearDown()
    }

    func testParsesLiveAndVODResponses() async throws {
        // Arrange sample responses
        guard let baseURL = URL(string: "http://example.com/portal.php") else {
            XCTFail("Invalid baseURL")
            return
        }
        var callIndex = 0
        MockURLProtocol.requestHandler = { request in
            callIndex += 1
            guard let reqURL = request.url else {
                throw URLError(.badURL)
            }
            let url = reqURL.absoluteString
            let json: String
            if url.contains("get_vod_streams") {
                json = """
                [
                  {"name":"Movie A","stream_id":101,"stream_icon":null,"rating":"7.0","category_id":1,"container_extension":"mp4"}
                ]
                """
            } else if url.contains("get_series") {
                json = "[]"
            } else if url.contains("get_live_streams") {
                json = """
                [
                  {"name":"Live 1","stream_id":201,"stream_icon":null,"category_id":2}
                ]
                """
            } else {
                json = "[]"
            }
            guard let data = json.data(using: .utf8) else {
                throw URLError(.cannotDecodeRawData)
            }
            guard let response = HTTPURLResponse(url: reqURL, statusCode: 200, httpVersion: nil, headerFields: nil) else {
                throw URLError(.badServerResponse)
            }
            return (response, data)
        }

        // Act
        guard let context = context else { XCTFail("Missing context"); return }
        try await XtreamCodesParser.parse(url: baseURL, username: "u", password: "p", context: context)

        // Assert
        let movies = try context.fetch(Movie.fetchRequest())
        XCTAssertEqual(movies.count, 1)
        let channels = try context.fetch(Channel.fetchRequest())
        XCTAssertEqual(channels.count, 1)
    }
}
