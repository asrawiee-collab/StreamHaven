//
//  SearchFiltersTests.swift
//  StreamHaven
//
//  Tests for search filter functionality
//

import XCTest
import CoreData
@testable import StreamHaven

@MainActor
final class SearchFiltersTests: XCTestCase {
    var context: NSManagedObjectContext!
    var testMovies: [Movie] = []
    var testSeries: [Series] = []
    
    override func setUp() async throws {
        try await super.setUp()
        
        // Create in-memory Core Data context
        let container = NSPersistentContainer(name: "StreamHaven", managedObjectModel: PersistenceController.shared.managedObjectModel)
        let description = NSPersistentStoreDescription()
        description.type = NSInMemoryStoreType
        container.persistentStoreDescriptions = [description]
        
        container.loadPersistentStores { _, error in
            XCTAssertNil(error)
        }
        
        context = container.viewContext
        
        // Create test movies
        let actionMovie = Movie(context: context)
        actionMovie.title = "Action Movie"
        actionMovie.genres = "Action, Adventure"
        actionMovie.releaseYear = 2022
        actionMovie.rating = Rating.pg13.rawValue
        testMovies.append(actionMovie)
        
        let comedyMovie = Movie(context: context)
        comedyMovie.title = "Comedy Movie"
        comedyMovie.genres = "Comedy, Romance"
        comedyMovie.releaseYear = 2015
        comedyMovie.rating = Rating.r.rawValue
        testMovies.append(comedyMovie)
        
        let horrorMovie = Movie(context: context)
        horrorMovie.title = "Horror Movie"
        horrorMovie.genres = "Horror, Thriller"
        horrorMovie.releaseYear = 1995
        horrorMovie.rating = Rating.nc17.rawValue
        testMovies.append(horrorMovie)
        
        let classicMovie = Movie(context: context)
        classicMovie.title = "Classic Movie"
        classicMovie.genres = "Drama"
        classicMovie.releaseYear = 1985
        classicMovie.rating = Rating.pg.rawValue
        testMovies.append(classicMovie)
        
        // Create test series
        let dramaSeriesItem = Series(context: context)
        dramaSeriesItem.title = "Drama Series"
        dramaSeriesItem.genres = "Drama, Mystery"
        dramaSeriesItem.releaseYear = 2020
        dramaSeriesItem.rating = Rating.pg13.rawValue
        testSeries.append(dramaSeriesItem)
        
        try context.save()
    }
    
    override func tearDown() async throws {
        testMovies.removeAll()
        testSeries.removeAll()
        context = nil
        try await super.tearDown()
    }
    
    // MARK: - Year Range Tests
    
    func testYearRangeRecent() {
        let yearRange = SearchView.YearRange.recent
        
        XCTAssertTrue(yearRange.matches(year: 2022), "2022 should match recent (2020-2024)")
        XCTAssertTrue(yearRange.matches(year: 2020), "2020 should match recent")
        XCTAssertTrue(yearRange.matches(year: 2024), "2024 should match recent")
        XCTAssertFalse(yearRange.matches(year: 2019), "2019 should not match recent")
        XCTAssertFalse(yearRange.matches(year: 2025), "2025 should not match recent")
    }
    
    func testYearRangeTens() {
        let yearRange = SearchView.YearRange.tens
        
        XCTAssertTrue(yearRange.matches(year: 2015), "2015 should match tens (2010-2019)")
        XCTAssertTrue(yearRange.matches(year: 2010), "2010 should match tens")
        XCTAssertTrue(yearRange.matches(year: 2019), "2019 should match tens")
        XCTAssertFalse(yearRange.matches(year: 2009), "2009 should not match tens")
        XCTAssertFalse(yearRange.matches(year: 2020), "2020 should not match tens")
    }
    
    func testYearRangeNoughties() {
        let yearRange = SearchView.YearRange.noughties
        
        XCTAssertTrue(yearRange.matches(year: 2005), "2005 should match noughties (2000-2009)")
        XCTAssertTrue(yearRange.matches(year: 2000), "2000 should match noughties")
        XCTAssertTrue(yearRange.matches(year: 2009), "2009 should match noughties")
        XCTAssertFalse(yearRange.matches(year: 1999), "1999 should not match noughties")
        XCTAssertFalse(yearRange.matches(year: 2010), "2010 should not match noughties")
    }
    
    func testYearRangeNineties() {
        let yearRange = SearchView.YearRange.nineties
        
        XCTAssertTrue(yearRange.matches(year: 1995), "1995 should match nineties (1990-1999)")
        XCTAssertTrue(yearRange.matches(year: 1990), "1990 should match nineties")
        XCTAssertTrue(yearRange.matches(year: 1999), "1999 should match nineties")
        XCTAssertFalse(yearRange.matches(year: 1989), "1989 should not match nineties")
        XCTAssertFalse(yearRange.matches(year: 2000), "2000 should not match nineties")
    }
    
    func testYearRangeClassic() {
        let yearRange = SearchView.YearRange.classic
        
        XCTAssertTrue(yearRange.matches(year: 1985), "1985 should match classic (before 1990)")
        XCTAssertTrue(yearRange.matches(year: 1950), "1950 should match classic")
        XCTAssertTrue(yearRange.matches(year: 1989), "1989 should match classic")
        XCTAssertFalse(yearRange.matches(year: 1990), "1990 should not match classic")
        XCTAssertFalse(yearRange.matches(year: 2000), "2000 should not match classic")
    }
    
    func testYearRangeAll() {
        let yearRange = SearchView.YearRange.all
        
        XCTAssertTrue(yearRange.matches(year: 1950), "All range should match 1950")
        XCTAssertTrue(yearRange.matches(year: 2024), "All range should match 2024")
        XCTAssertTrue(yearRange.matches(year: nil), "All range should match nil year")
    }
    
    // MARK: - Genre Filter Tests
    
    func testGenreFilterSingleGenre() {
        // Test movies with "Action" genre
        let actionMovies = testMovies.filter { movie in
            let genres = movie.genres?.components(separatedBy: ",").map { $0.trimmingCharacters(in: .whitespaces) } ?? []
            return genres.contains("Action")
        }
        
        XCTAssertEqual(actionMovies.count, 1, "Should find 1 action movie")
        XCTAssertEqual(actionMovies.first?.title, "Action Movie")
    }
    
    func testGenreFilterMultipleGenres() {
        // Test movies with "Comedy" OR "Drama" genres
        let selectedGenres: Set<String> = ["Comedy", "Drama"]
        let filteredMovies = testMovies.filter { movie in
            let genres = movie.genres?.components(separatedBy: ",").map { $0.trimmingCharacters(in: .whitespaces) } ?? []
            return genres.contains(where: { selectedGenres.contains($0) })
        }
        
        XCTAssertEqual(filteredMovies.count, 2, "Should find 2 movies (Comedy Movie + Classic Movie)")
    }
    
    func testGenreFilterNoMatches() {
        // Test movies with "Western" genre (none exist)
        let westernMovies = testMovies.filter { movie in
            let genres = movie.genres?.components(separatedBy: ",").map { $0.trimmingCharacters(in: .whitespaces) } ?? []
            return genres.contains("Western")
        }
        
        XCTAssertEqual(westernMovies.count, 0, "Should find 0 western movies")
    }
    
    // MARK: - Rating Filter Tests
    
    func testRatingFilterSingleRating() {
        // Test movies with PG-13 rating
        let pg13Movies = testMovies.filter { movie in
            return movie.rating == Rating.pg13.rawValue
        }
        
        XCTAssertEqual(pg13Movies.count, 1, "Should find 1 PG-13 movie")
        XCTAssertEqual(pg13Movies.first?.title, "Action Movie")
    }
    
    func testRatingFilterMultipleRatings() {
        // Test movies with R or NC-17 ratings
        let selectedRatings: Set<String> = [Rating.r.rawValue, Rating.nc17.rawValue]
        let filteredMovies = testMovies.filter { movie in
            return selectedRatings.contains(movie.rating ?? Rating.unrated.rawValue)
        }
        
        XCTAssertEqual(filteredMovies.count, 2, "Should find 2 movies (Comedy + Horror)")
    }
    
    // MARK: - Combined Filter Tests
    
    func testCombinedFiltersYearAndGenre() {
        // Test movies from 2010-2019 with "Comedy" genre
        let yearRange = SearchView.YearRange.tens
        let selectedGenres: Set<String> = ["Comedy"]
        
        let filteredMovies = testMovies.filter { movie in
            let genres = movie.genres?.components(separatedBy: ",").map { $0.trimmingCharacters(in: .whitespaces) } ?? []
            let matchesGenre = genres.contains(where: { selectedGenres.contains($0) })
            let matchesYear = yearRange.matches(year: movie.releaseYear)
            return matchesGenre && matchesYear
        }
        
        XCTAssertEqual(filteredMovies.count, 1, "Should find 1 movie (Comedy Movie from 2015)")
        XCTAssertEqual(filteredMovies.first?.title, "Comedy Movie")
    }
    
    func testCombinedFiltersAllThreeTypes() {
        // Test movies from 2020-2024, Action genre, PG-13 rating
        let yearRange = SearchView.YearRange.recent
        let selectedGenres: Set<String> = ["Action"]
        let selectedRatings: Set<String> = [Rating.pg13.rawValue]
        
        let filteredMovies = testMovies.filter { movie in
            let genres = movie.genres?.components(separatedBy: ",").map { $0.trimmingCharacters(in: .whitespaces) } ?? []
            let matchesGenre = genres.contains(where: { selectedGenres.contains($0) })
            let matchesYear = yearRange.matches(year: movie.releaseYear)
            let matchesRating = selectedRatings.contains(movie.rating ?? Rating.unrated.rawValue)
            return matchesGenre && matchesYear && matchesRating
        }
        
        XCTAssertEqual(filteredMovies.count, 1, "Should find 1 movie (Action Movie)")
        XCTAssertEqual(filteredMovies.first?.title, "Action Movie")
    }
    
    func testCombinedFiltersNoMatches() {
        // Test movies from 1990s with Horror genre and PG rating (none exist)
        let yearRange = SearchView.YearRange.nineties
        let selectedGenres: Set<String> = ["Horror"]
        let selectedRatings: Set<String> = [Rating.pg.rawValue]
        
        let filteredMovies = testMovies.filter { movie in
            let genres = movie.genres?.components(separatedBy: ",").map { $0.trimmingCharacters(in: .whitespaces) } ?? []
            let matchesGenre = genres.contains(where: { selectedGenres.contains($0) })
            let matchesYear = yearRange.matches(year: movie.releaseYear)
            let matchesRating = selectedRatings.contains(movie.rating ?? Rating.unrated.rawValue)
            return matchesGenre && matchesYear && matchesRating
        }
        
        XCTAssertEqual(filteredMovies.count, 0, "Should find 0 movies (Horror from 90s is NC-17, not PG)")
    }
    
    // MARK: - Series Filter Tests
    
    func testSeriesFiltering() {
        // Test series from 2020-2024 with Drama genre
        let yearRange = SearchView.YearRange.recent
        let selectedGenres: Set<String> = ["Drama"]
        
        let filteredSeries = testSeries.filter { series in
            let genres = series.genres?.components(separatedBy: ",").map { $0.trimmingCharacters(in: .whitespaces) } ?? []
            let matchesGenre = genres.contains(where: { selectedGenres.contains($0) })
            let matchesYear = yearRange.matches(year: series.releaseYear)
            return matchesGenre && matchesYear
        }
        
        XCTAssertEqual(filteredSeries.count, 1, "Should find 1 series (Drama Series)")
        XCTAssertEqual(filteredSeries.first?.title, "Drama Series")
    }
}
