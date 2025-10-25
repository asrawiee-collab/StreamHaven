//
//  RecommendationsTests.swift
//  StreamHaven
//
//  Tests for recommendations and trending functionality
//

import XCTest
import CoreData
@testable import StreamHaven

@MainActor
final class RecommendationsTests: XCTestCase {
    var tmdbManager: TMDbManager!
    var context: NSManagedObjectContext!
    
    override func setUp() async throws {
        try await super.setUp()
        
        // Use test API key or skip if not available
        tmdbManager = TMDbManager(apiKey: ProcessInfo.processInfo.environment["TMDB_API_KEY"])
        
        // Create in-memory Core Data context
        let container = NSPersistentContainer(name: "StreamHaven", managedObjectModel: PersistenceController.shared.managedObjectModel)
        let description = NSPersistentStoreDescription()
        description.type = NSInMemoryStoreType
        container.persistentStoreDescriptions = [description]
        
        container.loadPersistentStores { _, error in
            XCTAssertNil(error)
        }
        
        context = container.viewContext
    }
    
    override func tearDown() async throws {
        tmdbManager = nil
        context = nil
        try await super.tearDown()
    }
    
    // MARK: - TMDb API Structure Tests
    
    func testTMDbMovieStructure() {
        let json = """
        {
            "id": 123,
            "title": "Test Movie",
            "overview": "A test movie overview",
            "poster_path": "/test.jpg",
            "release_date": "2025-01-01",
            "vote_average": 8.5
        }
        """.data(using: .utf8)!
        
        do {
            let movie = try JSONDecoder().decode(TMDbMovie.self, from: json)
            XCTAssertEqual(movie.id, 123)
            XCTAssertEqual(movie.title, "Test Movie")
            XCTAssertEqual(movie.overview, "A test movie overview")
            XCTAssertEqual(movie.posterPath, "/test.jpg")
            XCTAssertEqual(movie.releaseDate, "2025-01-01")
            XCTAssertEqual(movie.voteAverage, 8.5)
        } catch {
            XCTFail("Failed to decode TMDbMovie: \(error)")
        }
    }
    
    func testTMDbSeriesStructure() {
        let json = """
        {
            "id": 456,
            "name": "Test Series",
            "overview": "A test series overview",
            "poster_path": "/series.jpg",
            "first_air_date": "2024-06-15",
            "vote_average": 7.8
        }
        """.data(using: .utf8)!
        
        do {
            let series = try JSONDecoder().decode(TMDbSeries.self, from: json)
            XCTAssertEqual(series.id, 456)
            XCTAssertEqual(series.name, "Test Series")
            XCTAssertEqual(series.overview, "A test series overview")
            XCTAssertEqual(series.posterPath, "/series.jpg")
            XCTAssertEqual(series.firstAirDate, "2024-06-15")
            XCTAssertEqual(series.voteAverage, 7.8)
        } catch {
            XCTFail("Failed to decode TMDbSeries: \(error)")
        }
    }
    
    func testTMDbMovieListResponse() {
        let json = """
        {
            "results": [
                {
                    "id": 1,
                    "title": "Movie 1",
                    "overview": "Overview 1",
                    "poster_path": "/poster1.jpg",
                    "release_date": "2025-01-01",
                    "vote_average": 8.0
                },
                {
                    "id": 2,
                    "title": "Movie 2",
                    "overview": "Overview 2",
                    "poster_path": "/poster2.jpg",
                    "release_date": "2025-02-01",
                    "vote_average": 7.5
                }
            ]
        }
        """.data(using: .utf8)!
        
        do {
            let response = try JSONDecoder().decode(TMDbMovieListResponse.self, from: json)
            XCTAssertEqual(response.results.count, 2)
            XCTAssertEqual(response.results[0].title, "Movie 1")
            XCTAssertEqual(response.results[1].title, "Movie 2")
        } catch {
            XCTFail("Failed to decode TMDbMovieListResponse: \(error)")
        }
    }
    
    // MARK: - Local Movie Search Tests
    
    func testFindLocalMovieExactMatch() {
        // Create test movie
        let movie = Movie(context: context)
        movie.title = "The Matrix"
        movie.posterURL = "https://example.com/matrix.jpg"
        try? context.save()
        
        // Search for movie
        let found = tmdbManager.findLocalMovie(title: "The Matrix", context: context)
        
        XCTAssertNotNil(found, "Should find movie with exact title match")
        XCTAssertEqual(found?.title, "The Matrix")
    }
    
    func testFindLocalMoviePartialMatch() {
        // Create test movie
        let movie = Movie(context: context)
        movie.title = "Inception: The Dream"
        movie.posterURL = "https://example.com/inception.jpg"
        try? context.save()
        
        // Search with partial title
        let found = tmdbManager.findLocalMovie(title: "Inception", context: context)
        
        XCTAssertNotNil(found, "Should find movie with partial title match")
        XCTAssertEqual(found?.title, "Inception: The Dream")
    }
    
    func testFindLocalMovieCaseInsensitive() {
        // Create test movie
        let movie = Movie(context: context)
        movie.title = "The Dark Knight"
        movie.posterURL = "https://example.com/dark-knight.jpg"
        try? context.save()
        
        // Search with different case
        let found = tmdbManager.findLocalMovie(title: "the dark knight", context: context)
        
        XCTAssertNotNil(found, "Should find movie with case-insensitive search")
        XCTAssertEqual(found?.title, "The Dark Knight")
    }
    
    func testFindLocalMovieNoMatch() {
        // Create test movie
        let movie = Movie(context: context)
        movie.title = "Existing Movie"
        try? context.save()
        
        // Search for non-existent movie
        let found = tmdbManager.findLocalMovie(title: "Non-Existent Movie", context: context)
        
        XCTAssertNil(found, "Should return nil for non-existent movie")
    }
    
    // MARK: - Local Series Search Tests
    
    func testFindLocalSeriesExactMatch() {
        // Create test series
        let series = Series(context: context)
        series.title = "Breaking Bad"
        series.posterURL = "https://example.com/breaking-bad.jpg"
        try? context.save()
        
        // Search for series
        let found = tmdbManager.findLocalSeries(name: "Breaking Bad", context: context)
        
        XCTAssertNotNil(found, "Should find series with exact name match")
        XCTAssertEqual(found?.title, "Breaking Bad")
    }
    
    func testFindLocalSeriesPartialMatch() {
        // Create test series
        let series = Series(context: context)
        series.title = "Game of Thrones: Complete Series"
        series.posterURL = "https://example.com/got.jpg"
        try? context.save()
        
        // Search with partial name
        let found = tmdbManager.findLocalSeries(name: "Game of Thrones", context: context)
        
        XCTAssertNotNil(found, "Should find series with partial name match")
        XCTAssertEqual(found?.title, "Game of Thrones: Complete Series")
    }
    
    func testFindLocalSeriesCaseInsensitive() {
        // Create test series
        let series = Series(context: context)
        series.title = "Stranger Things"
        series.posterURL = "https://example.com/stranger-things.jpg"
        try? context.save()
        
        // Search with different case
        let found = tmdbManager.findLocalSeries(name: "stranger things", context: context)
        
        XCTAssertNotNil(found, "Should find series with case-insensitive search")
        XCTAssertEqual(found?.title, "Stranger Things")
    }
    
    func testFindLocalSeriesNoMatch() {
        // Create test series
        let series = Series(context: context)
        series.title = "Existing Series"
        try? context.save()
        
        // Search for non-existent series
        let found = tmdbManager.findLocalSeries(name: "Non-Existent Series", context: context)
        
        XCTAssertNil(found, "Should return nil for non-existent series")
    }
    
    // MARK: - TMDb Error Tests
    
    func testTMDbErrorMissingAPIKey() {
        let managerWithoutKey = TMDbManager(apiKey: nil)
        
        Task {
            do {
                let _ = try await managerWithoutKey.getTrendingMovies()
                XCTFail("Should throw error when API key is missing")
            } catch let error as TMDbError {
                switch error {
                case .missingAPIKey:
                    XCTAssertTrue(true, "Correctly throws missingAPIKey error")
                default:
                    XCTFail("Wrong error type: \(error)")
                }
            } catch {
                XCTFail("Wrong error type: \(error)")
            }
        }
    }
    
    // MARK: - Integration Tests (Require Real API Key)
    
    func testGetTrendingMoviesIntegration() async throws {
        // Skip if no API key available
        guard tmdbManager.apiKey != nil else {
            throw XCTSkip("TMDb API key not available")
        }
        
        let trendingMovies = try await tmdbManager.getTrendingMovies()
        
        XCTAssertFalse(trendingMovies.isEmpty, "Should return trending movies")
        XCTAssertLessThanOrEqual(trendingMovies.count, 20, "Should return up to 20 movies")
        
        if let firstMovie = trendingMovies.first {
            XCTAssertFalse(firstMovie.title.isEmpty, "Movie should have a title")
            XCTAssertNotNil(firstMovie.overview, "Movie should have an overview")
        }
    }
    
    func testGetTrendingSeriesIntegration() async throws {
        // Skip if no API key available
        guard tmdbManager.apiKey != nil else {
            throw XCTSkip("TMDb API key not available")
        }
        
        let trendingSeries = try await tmdbManager.getTrendingSeries()
        
        XCTAssertFalse(trendingSeries.isEmpty, "Should return trending series")
        XCTAssertLessThanOrEqual(trendingSeries.count, 20, "Should return up to 20 series")
        
        if let firstSeries = trendingSeries.first {
            XCTAssertFalse(firstSeries.name.isEmpty, "Series should have a name")
            XCTAssertNotNil(firstSeries.overview, "Series should have an overview")
        }
    }
    
    func testGetSimilarMoviesIntegration() async throws {
        // Skip if no API key available
        guard tmdbManager.apiKey != nil else {
            throw XCTSkip("TMDb API key not available")
        }
        
        // Use a known movie ID (e.g., The Matrix = 603)
        let similarMovies = try await tmdbManager.getSimilarMovies(tmdbID: 603)
        
        XCTAssertFalse(similarMovies.isEmpty, "Should return similar movies")
        
        if let firstMovie = similarMovies.first {
            XCTAssertFalse(firstMovie.title.isEmpty, "Similar movie should have a title")
        }
    }
    
    // MARK: - Recommendation Matching Tests
    
    func testTrendingMoviesMatchingWithLocalLibrary() async throws {
        // Create local movies
        let movie1 = Movie(context: context)
        movie1.title = "The Shawshank Redemption"
        movie1.posterURL = "https://example.com/shawshank.jpg"
        
        let movie2 = Movie(context: context)
        movie2.title = "The Godfather"
        movie2.posterURL = "https://example.com/godfather.jpg"
        
        try context.save()
        
        // Simulate TMDb trending response
        let tmdbMovies = [
            TMDbMovie(id: 1, title: "The Shawshank Redemption", overview: "Hope", posterPath: "/shawshank.jpg", releaseDate: "1994", voteAverage: 9.3),
            TMDbMovie(id: 2, title: "Unknown Movie", overview: "Not in library", posterPath: "/unknown.jpg", releaseDate: "2025", voteAverage: 7.0)
        ]
        
        // Match TMDb with local library
        let matched = tmdbMovies.compactMap { tmdbMovie in
            tmdbManager.findLocalMovie(title: tmdbMovie.title, context: context)
        }
        
        XCTAssertEqual(matched.count, 1, "Should match 1 movie from local library")
        XCTAssertEqual(matched.first?.title, "The Shawshank Redemption")
    }
}
