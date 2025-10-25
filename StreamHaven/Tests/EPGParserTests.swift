import XCTest
import CoreData
@testable import StreamHaven

final class EPGParserTests: XCTestCase {
    var provider: PersistenceProviding!
    var context: NSManagedObjectContext!
    var channel: Channel!

    override func setUpWithError() throws {
        let controller = PersistenceController(inMemory: true)
        provider = DefaultPersistenceProvider(controller: controller)
        context = provider.container.newBackgroundContext()
        
        try context.performAndWait {
            channel = Channel(context: context)
            channel.name = "Test Channel"
            channel.tvgID = "channel1"
            try context.save()
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
        
        try context.performAndWait {
            try EPGParser.parse(data: xmltv, context: context)
        }
        
        let fetch: NSFetchRequest<EPGEntry> = EPGEntry.fetchRequest()
        let entries = try context.fetch(fetch)
        
        XCTAssertEqual(entries.count, 1)
        XCTAssertEqual(entries.first?.title, "Test Show")
        XCTAssertEqual(entries.first?.descriptionText, "Test Description")
        XCTAssertEqual(entries.first?.category, "Drama")
    }

    func testParseInvalidXMLThrows() {
        let invalidXML = "not valid xml".data(using: .utf8)!
        
        XCTAssertThrowsError(try context.performAndWait {
            try EPGParser.parse(data: invalidXML, context: context)
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
        
        try context.performAndWait {
            try EPGParser.parse(data: xmltv, context: context)
        }
        
        let fetch: NSFetchRequest<EPGEntry> = EPGEntry.fetchRequest()
        let entries = try context.fetch(fetch)
        
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
        
        try context.performAndWait {
            try EPGParser.parse(data: xmltv, context: context)
        }
        
        let fetch: NSFetchRequest<EPGEntry> = EPGEntry.fetchRequest()
        let entries = try context.fetch(fetch)
        
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
        
        try context.performAndWait {
            try EPGParser.parse(data: xmltv, context: context)
        }
        
        let fetch: NSFetchRequest<EPGEntry> = EPGEntry.fetchRequest()
        let entries = try context.fetch(fetch)
        
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
        
        try context.performAndWait {
            try EPGParser.parse(data: xmltv, context: context)
        }
        
        let fetch: NSFetchRequest<EPGEntry> = EPGEntry.fetchRequest()
        let entries = try context.fetch(fetch)
        
        // Should skip entries for channels not in database
        XCTAssertEqual(entries.count, 0)
    }

    func testDeletesOldEPGEntries() throws {
        // Create an old entry
        try context.performAndWait {
            let oldEntry = EPGEntry(context: context)
            oldEntry.channel = channel
            oldEntry.title = "Old Show"
            oldEntry.startTime = Date().addingTimeInterval(-2 * 24 * 3600) // 2 days ago
            oldEntry.endTime = Date().addingTimeInterval(-2 * 24 * 3600 + 3600)
            try context.save()
        }
        
        // Parse new data
        let xmltv = """
        <?xml version="1.0" encoding="UTF-8"?>
        <tv>
            <programme start="20231024180000 +0000" stop="20231024190000 +0000" channel="channel1">
                <title>New Show</title>
            </programme>
        </tv>
        """.data(using: .utf8)!
        
        try context.performAndWait {
            try EPGParser.parse(data: xmltv, context: context)
        }
        
        let fetch: NSFetchRequest<EPGEntry> = EPGEntry.fetchRequest()
        let entries = try context.fetch(fetch)
        
        // Old entry should be deleted
        XCTAssertEqual(entries.count, 1)
        XCTAssertEqual(entries.first?.title, "New Show")
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
        
        // Parse twice
        try context.performAndWait {
            try EPGParser.parse(data: xmltv, context: context)
            try EPGParser.parse(data: xmltv, context: context)
        }
        
        let fetch: NSFetchRequest<EPGEntry> = EPGEntry.fetchRequest()
        let entries = try context.fetch(fetch)
        
        // Should only have one entry, not duplicates
        XCTAssertEqual(entries.count, 1)
    }

    func testHandlesEmptyEPG() throws {
        let xmltv = """
        <?xml version="1.0" encoding="UTF-8"?>
        <tv>
        </tv>
        """.data(using: .utf8)!
        
        try context.performAndWait {
            try EPGParser.parse(data: xmltv, context: context)
        }
        
        let fetch: NSFetchRequest<EPGEntry> = EPGEntry.fetchRequest()
        let entries = try context.fetch(fetch)
        
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
        
        try context.performAndWait {
            try EPGParser.parse(data: xmltv, context: context)
        }
        
        let fetch: NSFetchRequest<EPGEntry> = EPGEntry.fetchRequest()
        let entries = try context.fetch(fetch)
        
        XCTAssertEqual(entries.count, 1)
        XCTAssertTrue(entries.first?.title?.contains("&") ?? false)
    }
}
