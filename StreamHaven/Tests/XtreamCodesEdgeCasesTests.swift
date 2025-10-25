import XCTest
import CoreData
@testable import StreamHaven

final class XtreamCodesEdgeCasesTests: XCTestCase {
    var provider: PersistenceProviding!
    var context: NSManagedObjectContext!

    override func setUpWithError() throws {
        let controller = PersistenceController(inMemory: true)
        provider = DefaultPersistenceProvider(controller: controller)
        context = provider.container.newBackgroundContext()
    }

    func testParsingInvalidJSONThrows() throws {
        let invalidJSON = "not valid json".data(using: .utf8)!
        
        XCTAssertThrowsError(try context.performAndWait {
            _ = try JSONDecoder().decode([String: String].self, from: invalidJSON)
        })
    }

    func testParsingEmptyVODArraySucceeds() throws {
        let emptyVOD = """
        []
        """.data(using: .utf8)!

        try context.performAndWait {
            let items = try JSONDecoder().decode([XtreamVODItem].self, from: emptyVOD)
            XCTAssertEqual(items.count, 0)
        }
    }

    func testParsingVODWithMissingFieldsUsesDefaults() throws {
        let minimalVOD = """
        [{"stream_id": 123, "name": "Test Movie"}]
        """.data(using: .utf8)!

        try context.performAndWait {
            let items = try JSONDecoder().decode([XtreamVODItem].self, from: minimalVOD)
            XCTAssertEqual(items.count, 1)
            XCTAssertEqual(items[0].name, "Test Movie")
            // Verify optional fields are nil
            XCTAssertNil(items[0].rating)
            XCTAssertNil(items[0].categoryID)
        }
    }

    func testParsingSeriesWithNoSeasonsSucceeds() throws {
        let seriesNoSeasons = """
        {"seasons": [], "info": {"name": "Empty Series"}}
        """.data(using: .utf8)!

        try context.performAndWait {
            let decoded = try JSONDecoder().decode([String: AnyCodable].self, from: seriesNoSeasons)
            XCTAssertNotNil(decoded["seasons"])
        }
    }

    func testParsingChannelsWithSpecialCharactersInName() throws {
        let channelData = """
        [{"stream_id": 1, "name": "Test & Channel <with> \"quotes\""}]
        """.data(using: .utf8)!

        try context.performAndWait {
            let items = try JSONDecoder().decode([XtreamLiveStream].self, from: channelData)
            XCTAssertEqual(items.count, 1)
            XCTAssertTrue(items[0].name.contains("&"))
            XCTAssertTrue(items[0].name.contains("\""))
        }
    }

    func testParsingVeryLongStringFieldsDoesNotCrash() throws {
        let longString = String(repeating: "A", count: 10000)
        let vodWithLongSummary = """
        [{"stream_id": 1, "name": "Test", "plot": "\(longString)"}]
        """.data(using: .utf8)!

        try context.performAndWait {
            let items = try JSONDecoder().decode([XtreamVODItem].self, from: vodWithLongSummary)
            XCTAssertEqual(items.count, 1)
            XCTAssertEqual(items[0].plot?.count, 10000)
        }
    }

    func testParsingNullValuesInOptionalFields() throws {
        let vodWithNulls = """
        [{"stream_id": 1, "name": "Test", "rating": null, "plot": null}]
        """.data(using: .utf8)!

        try context.performAndWait {
            let items = try JSONDecoder().decode([XtreamVODItem].self, from: vodWithNulls)
            XCTAssertEqual(items.count, 1)
            XCTAssertNil(items[0].rating)
            XCTAssertNil(items[0].plot)
        }
    }
}

// Helper decodable types matching Xtream structure
private struct XtreamVODItem: Decodable {
    let streamID: Int
    let name: String
    let rating: String?
    let categoryID: String?
    let plot: String?
    
    enum CodingKeys: String, CodingKey {
        case streamID = "stream_id"
        case name
        case rating
        case categoryID = "category_id"
        case plot
    }
}

private struct XtreamLiveStream: Decodable {
    let streamID: Int
    let name: String
    
    enum CodingKeys: String, CodingKey {
        case streamID = "stream_id"
        case name
    }
}

private struct AnyCodable: Decodable {
    let value: Any
    
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let intVal = try? container.decode(Int.self) {
            value = intVal
        } else if let stringVal = try? container.decode(String.self) {
            value = stringVal
        } else if let arrayVal = try? container.decode([AnyCodable].self) {
            value = arrayVal.map { $0.value }
        } else if let dictVal = try? container.decode([String: AnyCodable].self) {
            value = dictVal.mapValues { $0.value }
        } else {
            value = NSNull()
        }
    }
}
