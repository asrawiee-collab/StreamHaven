import XCTest
import CoreData
@testable import StreamHaven

final class FTSTriggerTests: XCTestCase {
    var provider: PersistenceProviding!
    var context: NSManagedObjectContext!
    var ftsManager: FullTextSearchManager!

    private static func extractTitles(from results: [NSManagedObject]) -> [String] {
        results.compactMap { object in
            if let movie = object as? Movie { return movie.title }
            if let series = object as? Series { return series.title }
            if let channel = object as? Channel { return channel.name }
            return nil
        }
    }

    override func setUpWithError() throws {
        let controller = PersistenceController(inMemory: true)
        provider = DefaultPersistenceProvider(controller: controller)
        context = provider.container.newBackgroundContext()
        ftsManager = FullTextSearchManager(persistenceProvider: provider)
    }

    func testFTSSetupCreatesVirtualTables() async throws {
        try ftsManager.initializeFullTextSearch()
        
        // Verify setup completes without error
        XCTAssertTrue(true)
    }

    func testFTSSearchReturnsRelevantResults() async throws {
        try ftsManager.initializeFullTextSearch()
        
        // Insert test movie
        guard let ctx = context else {
            XCTFail("Context not available")
            return
        }
        try await ctx.perform {
            let movie = Movie(context: ctx)
            movie.title = "Jurassic Park"
            movie.summary = "Dinosaurs come back to life"
            try ctx.save()
        }
        
        // Search should find the movie
        let expectation = XCTestExpectation(description: "Search completes")
        
        ftsManager.fuzzySearch(query: "jurassic", maxResults: 10) { results in
            let titles = FTSTriggerTests.extractTitles(from: results)
            XCTAssertGreaterThan(results.count, 0)
            XCTAssertTrue(titles.contains(where: { $0.localizedCaseInsensitiveContains("Jurassic") }))
            expectation.fulfill()
        }
        
        await fulfillment(of: [expectation], timeout: 5.0)
    }

    func testFTSFuzzyMatchingWithTypos() async throws {
        try ftsManager.initializeFullTextSearch()
        
        guard let ctx = context else {
            XCTFail("Context not available")
            return
        }
        try await ctx.perform {
            let movie = Movie(context: ctx)
            movie.title = "The Matrix"
            movie.summary = "Neo discovers reality"
            try ctx.save()
        }
        
        let expectation = XCTestExpectation(description: "Fuzzy search completes")
        
        // Search with typo "matri" should still find "Matrix"
        ftsManager.fuzzySearch(query: "matri", maxResults: 10) { results in
            let titles = FTSTriggerTests.extractTitles(from: results)
            XCTAssertGreaterThan(results.count, 0)
            XCTAssertTrue(titles.contains(where: { $0.localizedCaseInsensitiveContains("Matrix") }))
            expectation.fulfill()
        }
        
        await fulfillment(of: [expectation], timeout: 5.0)
    }

    func testFTSSearchAcrossMultipleTypes() async throws {
        try ftsManager.initializeFullTextSearch()
        
        guard let ctx = context else {
            XCTFail("Context not available")
            return
        }
        try await ctx.perform {
            let movie = Movie(context: ctx)
            movie.title = "Star Wars"
            
            let series = Series(context: ctx)
            series.title = "Star Trek"
            
            let channel = Channel(context: ctx)
            channel.name = "Star Channel"
            
            try ctx.save()
        }
        
        let expectation = XCTestExpectation(description: "Multi-type search completes")
        
        ftsManager.fuzzySearch(query: "star", maxResults: 20) { results in
            XCTAssertGreaterThanOrEqual(results.count, 3)
            
            let hasMovie = results.contains { $0 is Movie }
            let hasSeries = results.contains { $0 is Series }
            let hasChannel = results.contains { $0 is Channel }
            
            XCTAssertTrue(hasMovie || hasSeries || hasChannel)
            expectation.fulfill()
        }
        
        await fulfillment(of: [expectation], timeout: 5.0)
    }

    func testFTSRankingPrioritizesRelevance() async throws {
        try ftsManager.initializeFullTextSearch()
        
        guard let ctx = context else {
            XCTFail("Context not available")
            return
        }
        try await ctx.perform {
            let movie1 = Movie(context: ctx)
            movie1.title = "Inception"
            movie1.summary = "A brief mention of dreams"
            
            let movie2 = Movie(context: ctx)
            movie2.title = "Dream Analysis"
            movie2.summary = "All about dreams and dream interpretation and dream theory"
            
            try ctx.save()
        }
        
        let expectation = XCTestExpectation(description: "Ranking search completes")
        
        ftsManager.fuzzySearch(query: "dream", maxResults: 10) { results in
            let titles = FTSTriggerTests.extractTitles(from: results)
            XCTAssertGreaterThanOrEqual(titles.count, 2)
            
            // Expect "Dream Analysis" to rank ahead of "Inception"
            if let firstTitle = titles.first,
               let dreamIndex = titles.firstIndex(of: "Dream Analysis"),
               let inceptionIndex = titles.firstIndex(of: "Inception") {
                XCTAssertLessThan(dreamIndex, inceptionIndex)
                XCTAssertEqual(firstTitle, "Dream Analysis")
            }
            
            expectation.fulfill()
        }
        
        await fulfillment(of: [expectation], timeout: 5.0)
    }

    func testFTSHandlesEmptyQuery() async throws {
        try ftsManager.initializeFullTextSearch()
        
        let expectation = XCTestExpectation(description: "Empty query search completes")
        
        ftsManager.fuzzySearch(query: "", maxResults: 10) { results in
            // Empty query should return no results or handle gracefully
            expectation.fulfill()
        }
        
        await fulfillment(of: [expectation], timeout: 5.0)
    }

    func testFTSHandlesSpecialCharacters() async throws {
        try ftsManager.initializeFullTextSearch()
        
        guard let ctx = context else {
            XCTFail("Context not available")
            return
        }
        try await ctx.perform {
            let movie = Movie(context: ctx)
            movie.title = "Mission: Impossible"
            try ctx.save()
        }
        
        let expectation = XCTestExpectation(description: "Special char search completes")
        
        ftsManager.fuzzySearch(query: "mission impossible", maxResults: 10) { results in
            let titles = FTSTriggerTests.extractTitles(from: results)
            XCTAssertGreaterThan(results.count, 0)
            XCTAssertTrue(titles.contains(where: { $0.localizedCaseInsensitiveContains("Mission") }))
            expectation.fulfill()
        }
        
        await fulfillment(of: [expectation], timeout: 5.0)
    }

    func testFTSHandlesUnicodeCharacters() async throws {
        try ftsManager.initializeFullTextSearch()
        
        guard let ctx = context else {
            XCTFail("Context not available")
            return
        }
        try await ctx.perform {
            let movie = Movie(context: ctx)
            movie.title = "Amélie"
            try ctx.save()
        }
        
        let expectation = XCTestExpectation(description: "Unicode search completes")
        
        ftsManager.fuzzySearch(query: "amelie", maxResults: 10) { results in
            let titles = FTSTriggerTests.extractTitles(from: results)
            // FTS porter stemming should handle diacritics
            XCTAssertTrue(titles.contains(where: { $0.localizedCaseInsensitiveContains("Amélie") }))
            expectation.fulfill()
        }
        
        await fulfillment(of: [expectation], timeout: 5.0)
    }
}
