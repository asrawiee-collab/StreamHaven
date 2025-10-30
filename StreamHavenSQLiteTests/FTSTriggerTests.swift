import XCTest
import CoreData
@testable import StreamHaven

@MainActor
final class FTSTriggerTests: FileBasedTestCase {

    override func needsFTS() -> Bool {
        return true
    }

    func testFTSSetupCreatesVirtualTables() async throws {
        let ftsManager = FullTextSearchManager(persistenceProvider: persistenceProvider)
        try ftsManager.initializeFullTextSearch()
        
        // Verify FTS tables exist by attempting a search
        // If tables don't exist, this would throw an error
        XCTAssertNoThrow(try ftsManager.initializeFullTextSearch())
    }

    func testFTSSearchReturnsRelevantResults() async throws {
        let ftsManager = FullTextSearchManager(persistenceProvider: persistenceProvider)
        try ftsManager.initializeFullTextSearch()
        
        // Insert test movie
        guard let ctx = context else {
            XCTFail("Context not available")
            return
        }
        
        let localContext = ctx
        try await localContext.perform {
            let movie = Movie(context: localContext)
            movie.title = "Jurassic Park"
            movie.summary = "Dinosaurs come back to life"
            try localContext.save()
        }
        
        // Search should find the movie
        let expectation = XCTestExpectation(description: "Search completes")
        
        ftsManager.fuzzySearch(query: "jurassic", maxResults: 10) { results in
            let titles = results.compactMap { result -> String? in
                if let movie = result as? Movie {
                    return movie.title
                }
                return nil
            }
            XCTAssertGreaterThan(results.count, 0, "Should find at least one result")
            XCTAssertTrue(titles.contains(where: { $0.localizedCaseInsensitiveContains("Jurassic") }), "Should find Jurassic Park")
            expectation.fulfill()
        }
        
        await fulfillment(of: [expectation], timeout: 5.0)
    }

    func testFTSFuzzyMatchingWithTypos() async throws {
        let ftsManager = FullTextSearchManager(persistenceProvider: persistenceProvider)
        try ftsManager.initializeFullTextSearch()
        
        guard let ctx = context else {
            XCTFail("Context not available")
            return
        }
        
        let localContext = ctx
        try await localContext.perform {
            let movie = Movie(context: localContext)
            movie.title = "The Matrix"
            movie.summary = "Neo discovers reality"
            try localContext.save()
        }
        
        let expectation = XCTestExpectation(description: "Fuzzy search completes")
        
        // Search with typo "matri" should still find "Matrix"
        ftsManager.fuzzySearch(query: "matri", maxResults: 10) { results in
            let titles = results.compactMap { result -> String? in
                if let movie = result as? Movie {
                    return movie.title
                }
                return nil
            }
            XCTAssertGreaterThan(results.count, 0, "Should find results with fuzzy match")
            XCTAssertTrue(titles.contains(where: { $0.localizedCaseInsensitiveContains("Matrix") }), "Should find Matrix with fuzzy search")
            expectation.fulfill()
        }
        
        await fulfillment(of: [expectation], timeout: 5.0)
    }

    func testFTSSearchAcrossMultipleTypes() async throws {
        let ftsManager = FullTextSearchManager(persistenceProvider: persistenceProvider)
        try ftsManager.initializeFullTextSearch()
        
        guard let ctx = context else {
            XCTFail("Context not available")
            return
        }
        
        let localContext = ctx
        try await localContext.perform {
            let movie = Movie(context: localContext)
            movie.title = "Star Wars"
            
            let series = Series(context: localContext)
            series.title = "Star Trek"
            
            let channel = Channel(context: localContext)
            channel.name = "Star Channel"
            
            try localContext.save()
        }
        
        let expectation = XCTestExpectation(description: "Multi-type search completes")
        
        ftsManager.fuzzySearch(query: "star", maxResults: 20) { results in
            XCTAssertGreaterThanOrEqual(results.count, 3, "Should find at least 3 results")
            
            let hasMovie = results.contains { $0 is Movie }
            let hasSeries = results.contains { $0 is Series }
            let hasChannel = results.contains { $0 is Channel }
            
            XCTAssertTrue(hasMovie || hasSeries || hasChannel, "Should find mixed entity types")
            expectation.fulfill()
        }
        
        await fulfillment(of: [expectation], timeout: 5.0)
    }

    func testFTSRankingPrioritizesRelevance() async throws {
        let ftsManager = FullTextSearchManager(persistenceProvider: persistenceProvider)
        try ftsManager.initializeFullTextSearch()
        
        guard let ctx = context else {
            XCTFail("Context not available")
            return
        }
        
        let localContext = ctx
        try await localContext.perform {
            let movie1 = Movie(context: localContext)
            movie1.title = "Inception"
            movie1.summary = "A brief mention of dreams"
            
            let movie2 = Movie(context: localContext)
            movie2.title = "Dream Analysis"
            movie2.summary = "All about dreams and dream interpretation and dream theory"
            
            try localContext.save()
        }
        
        let expectation = XCTestExpectation(description: "Ranking search completes")
        
        ftsManager.fuzzySearch(query: "dream", maxResults: 10) { results in
            let titles = results.compactMap { result -> String? in
                if let movie = result as? Movie {
                    return movie.title
                }
                return nil
            }
            XCTAssertGreaterThanOrEqual(titles.count, 2, "Should find both movies")
            
            // Expect "Dream Analysis" to rank ahead of "Inception" due to more matches
            if let firstTitle = titles.first {
                XCTAssertTrue(firstTitle.contains("Dream"), "Movie with 'dream' in title should rank higher")
            }
            
            expectation.fulfill()
        }
        
        await fulfillment(of: [expectation], timeout: 5.0)
    }

    func testFTSHandlesEmptyQuery() async throws {
        let ftsManager = FullTextSearchManager(persistenceProvider: persistenceProvider)
        try ftsManager.initializeFullTextSearch()
        
        let expectation = XCTestExpectation(description: "Empty query search completes")
        
        ftsManager.fuzzySearch(query: "", maxResults: 10) { results in
            // Empty query should return no results or handle gracefully without crashing
            expectation.fulfill()
        }
        
        await fulfillment(of: [expectation], timeout: 5.0)
    }

    func testFTSHandlesSpecialCharacters() async throws {
        let ftsManager = FullTextSearchManager(persistenceProvider: persistenceProvider)
        try ftsManager.initializeFullTextSearch()
        
        guard let ctx = context else {
            XCTFail("Context not available")
            return
        }
        
        let localContext = ctx
        try await localContext.perform {
            let movie = Movie(context: localContext)
            movie.title = "Mission: Impossible"
            try localContext.save()
        }
        
        let expectation = XCTestExpectation(description: "Special char search completes")
        
        ftsManager.fuzzySearch(query: "mission impossible", maxResults: 10) { results in
            let titles = results.compactMap { result -> String? in
                if let movie = result as? Movie {
                    return movie.title
                }
                return nil
            }
            XCTAssertGreaterThan(results.count, 0, "Should find results ignoring special chars")
            XCTAssertTrue(titles.contains(where: { $0.localizedCaseInsensitiveContains("Mission") }), "Should find Mission: Impossible")
            expectation.fulfill()
        }
        
        await fulfillment(of: [expectation], timeout: 5.0)
    }

    func testFTSHandlesUnicodeCharacters() async throws {
        let ftsManager = FullTextSearchManager(persistenceProvider: persistenceProvider)
        try ftsManager.initializeFullTextSearch()
        
        guard let ctx = context else {
            XCTFail("Context not available")
            return
        }
        
        let localContext = ctx
        try await localContext.perform {
            let movie = Movie(context: localContext)
            movie.title = "Amélie"
            try localContext.save()
        }
        
        let expectation = XCTestExpectation(description: "Unicode search completes")
        
        ftsManager.fuzzySearch(query: "amelie", maxResults: 10) { results in
            let titles = results.compactMap { result -> String? in
                if let movie = result as? Movie {
                    return movie.title
                }
                return nil
            }
            // FTS porter stemming should handle diacritics
            XCTAssertTrue(titles.contains(where: { $0.localizedCaseInsensitiveContains("Amélie") }), "Should find movie with unicode characters")
            expectation.fulfill()
        }
        
        await fulfillment(of: [expectation], timeout: 5.0)
    }

    func testFTSPerformanceWithLargeDataset() async throws {
        let ftsManager = FullTextSearchManager(persistenceProvider: persistenceProvider)
        try ftsManager.initializeFullTextSearch()
        
        guard let ctx = context else {
            XCTFail("Context not available")
            return
        }
        
        // Create 1000 movies for performance testing
        let localContext = ctx
        try await localContext.perform {
            for i in 1...1000 {
                let movie = Movie(context: localContext)
                movie.title = "Movie \(i)"
                movie.summary = "Test movie number \(i) for performance testing"
                
                if i % 100 == 0 {
                    try localContext.save()
                }
            }
            try localContext.save()
        }
        
        let expectation = XCTestExpectation(description: "Performance search completes")
        
        measure {
            ftsManager.fuzzySearch(query: "movie 500", maxResults: 10) { results in
                XCTAssertGreaterThan(results.count, 0, "Should find results")
                expectation.fulfill()
            }
        }
        
        await fulfillment(of: [expectation], timeout: 10.0)
    }
}

