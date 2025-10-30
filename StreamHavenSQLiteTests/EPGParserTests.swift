import XCTest
import CoreData
@testable import StreamHaven

@MainActor
final class EPGParserTests: FileBasedTestCase {
    var channel: Channel!

    override func setUp() async throws {
        try await super.setUp()
        
        // Create a test channel
        guard let ctx = context else {
            throw NSError(domain: "Test", code: 1, userInfo: [NSLocalizedDescriptionKey: "Context not available"])
        }
        
        let localContext = ctx
        channel = try localContext.performAndWait {
            let ch = Channel(context: localContext)
            ch.name = "Test Channel"
            ch.tvgID = "channel1"
            try localContext.save()
            return ch
        }
    }

    func testParseValidXMLTV() throws {
        let xmltv = """
        <?xml version="1.0" encoding="UTF-8"?>
        <tv>
            <programme start="20231024180000 +0000" stop="20231024190000 +0000" channel="channel1">
                <title>Test Show</title>
                <desc>Test Description</desc>
                <category>Drama</category>
            </programme>
        </tv>
        """.data(using: .utf8)!
        
        guard let ctx = context else {
            XCTFail("Context not available")
            return
        }
        
        let localContext = ctx
        try localContext.performAndWait {
            try EPGParser.parse(data: xmltv, context: localContext)
        }
        
        let fetch: NSFetchRequest<EPGEntry> = EPGEntry.fetchRequest()
        let entries = try localContext.fetch(fetch)
        
        XCTAssertEqual(entries.count, 1)
        XCTAssertEqual(entries.first?.title, "Test Show")
        XCTAssertEqual(entries.first?.descriptionText, "Test Description")
        XCTAssertEqual(entries.first?.category, "Drama")
    }

    func testParseInvalidXMLThrows() {
        let invalidXML = "not valid xml".data(using: .utf8)!
        
        guard let ctx = context else {
            XCTFail("Context not available")
            return
        }
        
        let localContext = ctx
        XCTAssertThrowsError(try localContext.performAndWait {
            try EPGParser.parse(data: invalidXML, context: localContext)
        })
    }

    func testParseMissingRequiredFields() throws {
        let xmltv = """
        <?xml version="1.0" encoding="UTF-8"?>
        <tv>
            <programme channel="channel1">
                <title>No Times</title>
            </programme>
        </tv>
        """.data(using: .utf8)!
        
        guard let ctx = context else {
            XCTFail("Context not available")
            return
        }
        
        let localContext = ctx
        try localContext.performAndWait {
            try EPGParser.parse(data: xmltv, context: localContext)
        }
        
        let fetch: NSFetchRequest<EPGEntry> = EPGEntry.fetchRequest()
        let entries = try localContext.fetch(fetch)
        
        // Should skip entries without required times
        XCTAssertEqual(entries.count, 0)
    }

    func testParseTimezoneOffsets() throws {
        let xmltv = """
        <?xml version="1.0" encoding="UTF-8"?>
        <tv>
            <programme start="20231024180000 -0500" stop="20231024190000 -0500" channel="channel1">
                <title>Timezone Test</title>
            </programme>
        </tv>
        """.data(using: .utf8)!
        
        guard let ctx = context else {
            XCTFail("Context not available")
            return
        }
        
        let localContext = ctx
        try localContext.performAndWait {
            try EPGParser.parse(data: xmltv, context: localContext)
        }
        
        let fetch: NSFetchRequest<EPGEntry> = EPGEntry.fetchRequest()
        let entries = try localContext.fetch(fetch)
        
        XCTAssertEqual(entries.count, 1)
        XCTAssertNotNil(entries.first?.startTime)
    }

    func testParseMultipleProgrammes() throws {
        let xmltv = """
        <?xml version="1.0" encoding="UTF-8"?>
        <tv>
            <programme start="20231024180000 +0000" stop="20231024190000 +0000" channel="channel1">
                <title>Show 1</title>
            </programme>
            <programme start="20231024190000 +0000" stop="20231024200000 +0000" channel="channel1">
                <title>Show 2</title>
            </programme>
            <programme start="20231024200000 +0000" stop="20231024210000 +0000" channel="channel1">
                <title>Show 3</title>
            </programme>
        </tv>
        """.data(using: .utf8)!
        
        guard let ctx = context else {
            XCTFail("Context not available")
            return
        }
        
        let localContext = ctx
        try localContext.performAndWait {
            try EPGParser.parse(data: xmltv, context: localContext)
        }
        
        let fetch: NSFetchRequest<EPGEntry> = EPGEntry.fetchRequest()
        let entries = try localContext.fetch(fetch)
        
        XCTAssertEqual(entries.count, 3)
    }

    func testSkipsEntriesForUnknownChannels() throws {
        let xmltv = """
        <?xml version="1.0" encoding="UTF-8"?>
        <tv>
            <programme start="20231024180000 +0000" stop="20231024190000 +0000" channel="unknown_channel">
                <title>Unknown Channel Show</title>
            </programme>
        </tv>
        """.data(using: .utf8)!
        
        guard let ctx = context else {
            XCTFail("Context not available")
            return
        }
        
        let localContext = ctx
        try localContext.performAndWait {
            try EPGParser.parse(data: xmltv, context: localContext)
        }
        
        let fetch: NSFetchRequest<EPGEntry> = EPGEntry.fetchRequest()
        let entries = try localContext.fetch(fetch)
        
        // Should skip entries for channels not in database
        XCTAssertEqual(entries.count, 0)
    }

    func testSkipsDuplicateEntries() throws {
        let xmltv = """
        <?xml version="1.0" encoding="UTF-8"?>
        <tv>
            <programme start="20231024180000 +0000" stop="20231024190000 +0000" channel="channel1">
                <title>Test Show</title>
            </programme>
        </tv>
        """.data(using: .utf8)!
        
        guard let ctx = context else {
            XCTFail("Context not available")
            return
        }
        
        let localContext = ctx
        // Parse twice
        try localContext.performAndWait {
            try EPGParser.parse(data: xmltv, context: localContext)
            try EPGParser.parse(data: xmltv, context: localContext)
        }
        
        let fetch: NSFetchRequest<EPGEntry> = EPGEntry.fetchRequest()
        let entries = try localContext.fetch(fetch)
        
        // Should only have one entry, not duplicates
        XCTAssertEqual(entries.count, 1)
    }

    func testHandlesEmptyEPG() throws {
        let xmltv = """
        <?xml version="1.0" encoding="UTF-8"?>
        <tv>
        </tv>
        """.data(using: .utf8)!
        
        guard let ctx = context else {
            XCTFail("Context not available")
            return
        }
        
        let localContext = ctx
        try localContext.performAndWait {
            try EPGParser.parse(data: xmltv, context: localContext)
        }
        
        let fetch: NSFetchRequest<EPGEntry> = EPGEntry.fetchRequest()
        let entries = try localContext.fetch(fetch)
        
        XCTAssertEqual(entries.count, 0)
    }

    func testHandlesSpecialCharactersInContent() throws {
        let xmltv = """
        <?xml version="1.0" encoding="UTF-8"?>
        <tv>
            <programme start="20231024180000 +0000" stop="20231024190000 +0000" channel="channel1">
                <title>Test &amp; Show "Quotes"</title>
                <desc>Description with &lt;HTML&gt; &amp; special chars</desc>
            </programme>
        </tv>
        """.data(using: .utf8)!
        
        guard let ctx = context else {
            XCTFail("Context not available")
            return
        }
        
        let localContext = ctx
        try localContext.performAndWait {
            try EPGParser.parse(data: xmltv, context: localContext)
        }
        
        let fetch: NSFetchRequest<EPGEntry> = EPGEntry.fetchRequest()
        let entries = try localContext.fetch(fetch)
        
        XCTAssertEqual(entries.count, 1)
        XCTAssertTrue(entries.first?.title?.contains("&") ?? false)
    }
}
