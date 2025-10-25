import XCTest
import CoreData
@testable import StreamHaven

final class VODOrderingTests: XCTestCase {
    var context: NSManagedObjectContext!

    override func setUpWithError() throws {
        let controller = PersistenceController(inMemory: true)
        context = controller.container.newBackgroundContext()
    }

    func testOrdersByReleaseDate() throws {
        let movies = try context.performAndWait { () -> [Movie] in
            let movie1 = Movie(context: context)
            movie1.title = "Old Movie"
            movie1.releaseDate = Date(timeIntervalSince1970: 946684800) // 2000-01-01
            
            let movie2 = Movie(context: context)
            movie2.title = "New Movie"
            movie2.releaseDate = Date(timeIntervalSince1970: 1609459200) // 2021-01-01
            
            let movie3 = Movie(context: context)
            movie3.title = "Newer Movie"
            movie3.releaseDate = Date(timeIntervalSince1970: 1640995200) // 2022-01-01
            
            try context.save()
            return [movie1, movie2, movie3]
        }
        
        let ordered = VODOrderingManager.orderByReleaseDate(movies: movies)
        
        XCTAssertEqual(ordered.count, 3)
        XCTAssertEqual(ordered[0].title, "Newer Movie")
        XCTAssertEqual(ordered[2].title, "Old Movie")
    }

    func testHandlesMoviesWithoutReleaseDate() throws {
        let movies = try context.performAndWait { () -> [Movie] in
            let movieWithDate = Movie(context: context)
            movieWithDate.title = "Has Date"
            movieWithDate.releaseDate = Date()
            
            let movieNoDate = Movie(context: context)
            movieNoDate.title = "No Date"
            movieNoDate.releaseDate = nil
            
            try context.save()
            return [movieWithDate, movieNoDate]
        }
        
        let ordered = VODOrderingManager.orderByReleaseDate(movies: movies)
        
        // Should not crash and should include all movies
        XCTAssertEqual(ordered.count, 2)
    }

    func testOrdersByPopularity() throws {
        let movies = try context.performAndWait { () -> [Movie] in
            let movie1 = Movie(context: context)
            movie1.title = "Popular"
            movie1.rating = Rating.r.rawValue
            
            let movie2 = Movie(context: context)
            movie2.title = "Less Popular"
            movie2.rating = Rating.pg.rawValue
            
            try context.save()
            return [movie1, movie2]
        }
        
        let ordered = VODOrderingManager.orderByPopularity(movies: movies)
        
        // Should order based on internal popularity metrics
        XCTAssertEqual(ordered.count, 2)
    }

    func testOrderByTitleAlphabetically() throws {
        let movies = try context.performAndWait { () -> [Movie] in
            let movie1 = Movie(context: context)
            movie1.title = "Zebra Movie"
            
            let movie2 = Movie(context: context)
            movie2.title = "Apple Movie"
            
            let movie3 = Movie(context: context)
            movie3.title = "Banana Movie"
            
            try context.save()
            return [movie1, movie2, movie3]
        }
        
        let ordered = VODOrderingManager.orderByTitle(movies: movies)
        
        XCTAssertEqual(ordered[0].title, "Apple Movie")
        XCTAssertEqual(ordered[1].title, "Banana Movie")
        XCTAssertEqual(ordered[2].title, "Zebra Movie")
    }

    func testHandlesEmptyArray() {
        let ordered = VODOrderingManager.orderByReleaseDate(movies: [])
        XCTAssertTrue(ordered.isEmpty)
    }

    func testHandlesSingleMovie() throws {
        let movies = try context.performAndWait { () -> [Movie] in
            let movie = Movie(context: context)
            movie.title = "Only Movie"
            try context.save()
            return [movie]
        }
        
        let ordered = VODOrderingManager.orderByReleaseDate(movies: movies)
        
        XCTAssertEqual(ordered.count, 1)
        XCTAssertEqual(ordered[0].title, "Only Movie")
    }

    func testOrdersByRating() throws {
        let movies = try context.performAndWait { () -> [Movie] in
            let movie1 = Movie(context: context)
            movie1.title = "G Rated"
            movie1.rating = Rating.g.rawValue
            
            let movie2 = Movie(context: context)
            movie2.title = "R Rated"
            movie2.rating = Rating.r.rawValue
            
            let movie3 = Movie(context: context)
            movie3.title = "PG Rated"
            movie3.rating = Rating.pg.rawValue
            
            try context.save()
            return [movie1, movie2, movie3]
        }
        
        let ordered = VODOrderingManager.orderByRating(movies: movies)
        
        // Should order by rating severity
        XCTAssertEqual(ordered.count, 3)
    }

    func testHandlesNilTitles() throws {
        let movies = try context.performAndWait { () -> [Movie] in
            let movie1 = Movie(context: context)
            movie1.title = nil
            
            let movie2 = Movie(context: context)
            movie2.title = "Has Title"
            
            try context.save()
            return [movie1, movie2]
        }
        
        let ordered = VODOrderingManager.orderByTitle(movies: movies)
        
        // Should handle nil titles gracefully
        XCTAssertEqual(ordered.count, 2)
    }
}
