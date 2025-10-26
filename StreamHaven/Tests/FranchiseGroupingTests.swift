import XCTest
import CoreData
@testable import StreamHaven

final class FranchiseGroupingTests: XCTestCase {
    var context: NSManagedObjectContext!

    override func setUpWithError() throws {
        let controller = PersistenceController(inMemory: true)
        context = controller.container.newBackgroundContext()
    }

    func testGroupFranchisesDetectsSequentialMovies() throws {
        let movies = try context.performAndWait { () -> [Movie] in
            let movie1 = Movie(context: context)
            movie1.title = "Scream"
            
            let movie2 = Movie(context: context)
            movie2.title = "Scream 2"
            
            let movie3 = Movie(context: context)
            movie3.title = "Scream 3"
            
            try context.save()
            return [movie1, movie2, movie3]
        }
        
        let groups = FranchiseGroupingManager.groupFranchises(movies: movies)
        
        XCTAssertTrue(groups.keys.contains(where: { $0.contains("Scream") }))
        
        if let screamGroup = groups.first(where: { $0.key.contains("Scream") }) {
            XCTAssertEqual(screamGroup.value.count, 3)
        }
    }

    func testGroupFranchisesHandlesVariousNamingPatterns() throws {
        let movies = try context.performAndWait { () -> [Movie] in
            let movie1 = Movie(context: context)
            movie1.title = "Die Hard"
            
            let movie2 = Movie(context: context)
            movie2.title = "Die Hard 2"
            
            let movie3 = Movie(context: context)
            movie3.title = "Die Hard with a Vengeance"
            
            try context.save()
            return [movie1, movie2, movie3]
        }
        
        let groups = FranchiseGroupingManager.groupFranchises(movies: movies)
        
        // Should detect "Die Hard" franchise
        XCTAssertTrue(groups.keys.contains(where: { $0.contains("Die Hard") }))
    }

    func testGroupFranchisesIgnoresUnrelatedMovies() throws {
        let movies = try context.performAndWait { () -> [Movie] in
            let movie1 = Movie(context: context)
            movie1.title = "Toy Story"
            
            let movie2 = Movie(context: context)
            movie2.title = "Toy Story 2"
            
            let unrelated = Movie(context: context)
            unrelated.title = "Inception"
            
            try context.save()
            return [movie1, movie2, unrelated]
        }
        
        let groups = FranchiseGroupingManager.groupFranchises(movies: movies)
        
        // Inception should not be in any franchise group
        let allGroupedMovies = groups.values.flatMap { $0 }
        XCTAssertFalse(allGroupedMovies.contains(where: { $0.title == "Inception" }))
    }

    func testGroupFranchisesHandlesEmptyArray() {
        let groups = FranchiseGroupingManager.groupFranchises(movies: [])
        XCTAssertTrue(groups.isEmpty)
    }

    func testGroupFranchisesHandlesSingleMovie() throws {
        let movies = try context.performAndWait { () -> [Movie] in
            let movie = Movie(context: context)
            movie.title = "Standalone Movie"
            try context.save()
            return [movie]
        }
        
        let groups = FranchiseGroupingManager.groupFranchises(movies: movies)
        
        // Single movie should not create a franchise group
        XCTAssertTrue(groups.isEmpty || groups.values.allSatisfy { $0.count > 1 })
    }

    func testGroupFranchisesHandlesRomanNumerals() throws {
        let movies = try context.performAndWait { () -> [Movie] in
            let movie1 = Movie(context: context)
            movie1.title = "Rocky"
            
            let movie2 = Movie(context: context)
            movie2.title = "Rocky II"
            
            let movie3 = Movie(context: context)
            movie3.title = "Rocky III"
            
            try context.save()
            return [movie1, movie2, movie3]
        }
        
        let groups = FranchiseGroupingManager.groupFranchises(movies: movies)
        
        XCTAssertTrue(groups.keys.contains(where: { $0.contains("Rocky") }))
    }

    func testGroupFranchisesHandlesSubtitles() throws {
        let movies = try context.performAndWait { () -> [Movie] in
            let movie1 = Movie(context: context)
            movie1.title = "The Matrix"
            
            let movie2 = Movie(context: context)
            movie2.title = "The Matrix Reloaded"
            
            let movie3 = Movie(context: context)
            movie3.title = "The Matrix Revolutions"
            
            try context.save()
            return [movie1, movie2, movie3]
        }
        
        let groups = FranchiseGroupingManager.groupFranchises(movies: movies)
        
        XCTAssertTrue(groups.keys.contains(where: { $0.contains("Matrix") }))
    }
}
