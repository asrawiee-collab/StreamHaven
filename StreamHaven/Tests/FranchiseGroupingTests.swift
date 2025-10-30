import XCTest
import CoreData
@testable import StreamHaven

final class FranchiseGroupingTests: XCTestCase {
    var context: NSManagedObjectContext!

    override func setUpWithError() throws {
        let container = NSPersistentContainer(
            name: "FranchiseGroupingTesting",
            managedObjectModel: LightweightCoreDataModelBuilder.sharedModel
        )
        
        let description = NSPersistentStoreDescription()
        description.type = NSInMemoryStoreType
        container.persistentStoreDescriptions = [description]
        
        var loadError: Error?
        container.loadPersistentStores { _, error in
            loadError = error
        }
        
        guard loadError == nil else {
            throw XCTSkip("Failed to load in-memory store: \(loadError!)")
        }
        
        context = container.viewContext
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
        
        // With enhanced subtitle detection, these should now be grouped as a franchise
        XCTAssertTrue(groups.keys.contains(where: { $0.contains("Matrix") }), "Should detect Matrix franchise with subtitle-based sequels")
        
        if let matrixGroup = groups.first(where: { $0.key.contains("Matrix") }) {
            XCTAssertEqual(matrixGroup.value.count, 3, "Should group all three Matrix movies together")
        }
    }
    
    func testGroupFranchisesDetectsVariousSubtitlePatterns() throws {
        let movies = try context.performAndWait { () -> [Movie] in
            // Test colon pattern detection
            let movie1 = Movie(context: context)
            movie1.title = "Mad Max"
            
            let movie2 = Movie(context: context)
            movie2.title = "Mad Max: Fury Road"    // Colon pattern: "Mad Max: ..." → "Mad Max"
            
            // Test subtitle word removal at the end
            let movie3 = Movie(context: context)
            movie3.title = "The Matrix"
            
            let movie4 = Movie(context: context)
            movie4.title = "The Matrix Reloaded"   // "Reloaded" at end → "The Matrix"
            
            let movie5 = Movie(context: context)
            movie5.title = "The Matrix Revolutions" // "Revolutions" at end → "The Matrix"
            
            // Test trailing number pattern
            let movie6 = Movie(context: context)
            movie6.title = "Terminator"
            
            let movie7 = Movie(context: context)
            movie7.title = "Terminator 2"          // Trailing number → "Terminator"
            
            try context.save()
            return [movie1, movie2, movie3, movie4, movie5, movie6, movie7]
        }
        
        let groups = FranchiseGroupingManager.groupFranchises(movies: movies)
        
        // Should detect Mad Max grouping (original + colon subtitle)
        let madMaxGroups = groups.filter { $0.key.contains("Mad Max") }
        XCTAssertTrue(madMaxGroups.count >= 1, "Should detect Mad Max franchise grouping via colon pattern")
        
        // Should detect The Matrix grouping (original + subtitle words)
        let matrixGroups = groups.filter { $0.key.contains("Matrix") }
        XCTAssertTrue(matrixGroups.count >= 1, "Should detect The Matrix franchise grouping via subtitle removal")
        
        // Should detect Terminator grouping (original + trailing number)
        let terminatorGroups = groups.filter { $0.key.contains("Terminator") }
        XCTAssertTrue(terminatorGroups.count >= 1, "Should detect Terminator franchise grouping via number pattern")
    }
}
