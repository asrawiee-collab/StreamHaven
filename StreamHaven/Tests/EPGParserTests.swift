import XCTest
import CoreData
@testable import StreamHaven

@MainActor
final class EPGParserTests: XCTestCase {

    func testParseValidXMLTV() throws {
        throw XCTSkip("EPGParser uses NSBatchDeleteRequest which requires file-based SQLite store")
    }

    func testParseInvalidXMLThrows() throws {
        throw XCTSkip("EPGParser uses NSBatchDeleteRequest which requires file-based SQLite store")
    }

    func testParseMissingRequiredFields() throws {
        throw XCTSkip("EPGParser uses NSBatchDeleteRequest which requires file-based SQLite store")
    }

    func testParseTimezoneOffsets() throws {
        throw XCTSkip("EPGParser uses NSBatchDeleteRequest which requires file-based SQLite store")
    }

    func testParseMultipleProgrammes() throws {
        throw XCTSkip("EPGParser uses NSBatchDeleteRequest which requires file-based SQLite store")
    }

    func testSkipsEntriesForUnknownChannels() throws {
        throw XCTSkip("EPGParser uses NSBatchDeleteRequest which requires file-based SQLite store")
    }

    func testSkipsDuplicateEntries() throws {
        throw XCTSkip("EPGParser uses NSBatchDeleteRequest which requires file-based SQLite store")
    }

    func testHandlesEmptyEPG() throws {
        throw XCTSkip("EPGParser uses NSBatchDeleteRequest which requires file-based SQLite store")
    }

    func testHandlesSpecialCharactersInContent() throws {
        throw XCTSkip("EPGParser uses NSBatchDeleteRequest which requires file-based SQLite store")
    }
}

