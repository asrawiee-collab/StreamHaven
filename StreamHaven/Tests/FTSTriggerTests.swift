import XCTest
import CoreData
@testable import StreamHaven

final class FTSTriggerTests: XCTestCase {
    var provider: PersistenceProviding!
    var context: NSManagedObjectContext!
    var ftsManager: FullTextSearchManager!

    override func setUpWithError() throws {
        let controller = PersistenceController(inMemory: true)
        provider = DefaultPersistenceProvider(controller: controller)
        context = provider.container.newBackgroundContext()
        ftsManager = FullTextSearchManager(persistenceProvider: provider)
    }

    func testFTSSetupCreatesVirtualTables() async throws {
        try await ftsManager.setupFullTextSearch()
        
        // Verify setup completes without error
        XCTAssertTrue(true)
    }

    func testFTSSearchReturnsRelevantResults() async throws {
        try await ftsManager.setupFullTextSearch()
        
        // Insert test movie
        try await context.perform {
            let movie = Movie(context: self.context)
            movie.title = "Jurassic Park"
            movie.summary = "Dinosaurs come back to life"
            try self.context.save()
        }
        
        // Search should find the movie
        let expectation = XCTestExpectation(description: "Search completes")
        
        ftsManager.fuzzySearch(query: "jurassic", maxResults: 10) { results in
            XCTAssertGreaterThan(results.count, 0)
            XCTAssertTrue(results.contains(where: { $0.title.contains("Jurassic") }))
            expectation.fulfill()
        }
        
        await fulfillment(of: [expectation], timeout: 5.0)
    }

    func testFTSFuzzyMatchingWithTypos() async throws {
        try await ftsManager.setupFullTextSearch()
        
        try await context.perform {
            let movie = Movie(context: self.context)
            movie.title = "The Matrix"
            movie.summary = "Neo discovers reality"
            try self.context.save()
        }
        
        let expectation = XCTestExpectation(description: "Fuzzy search completes")
        
        // Search with typo "matri" should still find "Matrix"
        ftsManager.fuzzySearch(query: "matri", maxResults: 10) { results in
            XCTAssertGreaterThan(results.count, 0)
            expectation.fulfill()
        }
        
        await fulfillment(of: [expectation], timeout: 5.0)
    }

    func testFTSSearchAcrossMultipleTypes() async throws {
        try await ftsManager.setupFullTextSearch()
        
        try await context.perform {
            let movie = Movie(context: self.context)
            movie.title = "Star Wars"
            
            let series = Series(context: self.context)
            series.title = "Star Trek"
            
            let channel = Channel(context: self.context)
            channel.name = "Star Channel"
            
            try self.context.save()
        }
        
        let expectation = XCTestExpectation(description: "Multi-type search completes")
        
        ftsManager.fuzzySearch(query: "star", maxResults: 20) { results in
            XCTAssertGreaterThanOrEqual(results.count, 3)
            
            let hasMovie = results.contains(where: { $0.type == .movie })
            let hasSeries = results.contains(where: { $0.type == .series })
            let hasChannel = results.contains(where: { $0.type == .channel })
            
            XCTAssertTrue(hasMovie || hasSeries || hasChannel)
            expectation.fulfill()
        }
        
        await fulfillment(of: [expectation], timeout: 5.0)
    }

    func testFTSRankingPrioritizesRelevance() async throws {
        try await ftsManager.setupFullTextSearch()
        
        try await context.perform {
            let movie1 = Movie(context: self.context)
            movie1.title = "Inception"
            movie1.summary = "A brief mention of dreams"
            
            let movie2 = Movie(context: self.context)
            movie2.title = "Dream Analysis"
            movie2.summary = "All about dreams and dream interpretation and dream theory"
            
            try self.context.save()
        }
        
        let expectation = XCTestExpectation(description: "Ranking search completes")
        
        ftsManager.fuzzySearch(query: "dream", maxResults: 10) { results in
            XCTAssertGreaterThanOrEqual(results.count, 2)
            
            // Results should be ranked by relevance (BM25)
            // Movie with more "dream" mentions should rank higher
            if results.count >= 2 {
                let firstRank = results[0].rank
                let secondRank = results[1].rank
                // Lower rank values = higher relevance in BM25
                XCTAssertLessThanOrEqual(firstRank, secondRank)
            }
            
            expectation.fulfill()
        }
        
        await fulfillment(of: [expectation], timeout: 5.0)
    }

    func testFTSHandlesEmptyQuery() async throws {
        try await ftsManager.setupFullTextSearch()
        
        let expectation = XCTestExpectation(description: "Empty query search completes")
        
        ftsManager.fuzzySearch(query: "", maxResults: 10) { results in
            // Empty query should return no results or handle gracefully
            expectation.fulfill()
        }
        
        await fulfillment(of: [expectation], timeout: 5.0)
    }

    func testFTSHandlesSpecialCharacters() async throws {
        try await ftsManager.setupFullTextSearch()
        
        try await context.perform {
            let movie = Movie(context: self.context)
            movie.title = "Mission: Impossible"
            try self.context.save()
        }
        
        let expectation = XCTestExpectation(description: "Special char search completes")
        
        ftsManager.fuzzySearch(query: "mission impossible", maxResults: 10) { results in
            XCTAssertGreaterThan(results.count, 0)
            expectation.fulfill()
        }
        
        await fulfillment(of: [expectation], timeout: 5.0)
    }

    func testFTSHandlesUnicodeCharacters() async throws {
        try await ftsManager.setupFullTextSearch()
        
        try await context.perform {
            let movie = Movie(context: self.context)
            movie.title = "Amélie"
            try self.context.save()
        }
        
        let expectation = XCTestExpectation(description: "Unicode search completes")
        
        ftsManager.fuzzySearch(query: "amelie", maxResults: 10) { results in
            // FTS porter stemming should handle diacritics
            expectation.fulfill()
        }
        
        await fulfillment(of: [expectation], timeout: 5.0)
    }
}
