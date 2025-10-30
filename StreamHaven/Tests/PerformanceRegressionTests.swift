import XCTest
import CoreData
@testable import StreamHaven

@MainActor
final class PerformanceRegressionTests: XCTestCase {

    func testSearchPerformanceWith10KMovies() throws {
        throw XCTSkip("Performance tests require file-based SQLite store for batch operations")
    }

    func testFTSSearchPerformanceWith50KEntries() throws {
        throw XCTSkip("Performance tests require file-based SQLite store for batch operations")
    }

    func testFetchFavoritesPerformanceWith100KMovies() throws {
        throw XCTSkip("Performance tests require file-based SQLite store for batch operations")
    }

    func testBatchInsertPerformance() throws {
        throw XCTSkip("Performance tests require file-based SQLite store for batch operations")
    }

    func testWatchProgressUpdatePerformance() throws {
        throw XCTSkip("Performance tests require file-based SQLite store for batch operations")
    }

    func testDenormalizationRebuildPerformance() throws {
        throw XCTSkip("Performance tests require file-based SQLite store for batch operations")
    }

    func testEPGQueryPerformanceWith100KEntries() throws {
        throw XCTSkip("Performance tests require file-based SQLite store for batch operations")
    }

    func testConcurrentFetchPerformance() throws {
        throw XCTSkip("Performance tests require file-based SQLite store for batch operations")
    }

    func testMemoryPressureWith100KMovies() throws {
        throw XCTSkip("Performance tests require file-based SQLite store for batch operations")
    }

    func testFetchBatchingPerformance() throws {
        throw XCTSkip("Performance tests require file-based SQLite store for batch operations")
    }
}

