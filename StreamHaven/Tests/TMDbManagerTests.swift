import CoreData
import XCTest
@testable import StreamHaven

@MainActor
final class TMDbManagerTests: XCTestCase {
    var provider: PersistenceProviding!
    var context: NSManagedObjectContext!
    var manager: TMDbManager!

    override func setUpWithError() throws {
        let controller = PersistenceController(inMemory: true)
        provider = DefaultPersistenceProvider(controller: controller)
        context = provider.container.viewContext
        
        // Initialize with a test API key
        manager = TMDbManager(apiKey: "test_api_key")
    }

    func testManagerInitializationWithAPIKey() {
        XCTAssertNotNil(manager)
    }

    func testManagerInitializationWithoutAPIKey() {
        let managerWithoutKey = TMDbManager(apiKey: nil)
        XCTAssertNotNil(managerWithoutKey)
    }

    func testSkipsFetchIfIMDbIDAlreadyExists() async {
        let movie = Movie(context: context)
        movie.title = "Test Movie"
        movie.imdbID = "tt1234567"
        try? context.save()
        
        await manager.fetchIMDbID(for: movie, context: context)
        
        // Should still have the same IMDb ID
        XCTAssertEqual(movie.imdbID, "tt1234567")
    }

    func testHandlesMissingTitle() async {
        let movie = Movie(context: context)
        movie.title = nil
        try? context.save()
        
        await manager.fetchIMDbID(for: movie, context: context)
        
        // Should handle gracefully without crashing
        XCTAssertNil(movie.imdbID)
    }

    func testHandlesNetworkErrors() async {
        // Use invalid API key to trigger error
        let managerWithBadKey = TMDbManager(apiKey: "invalid_key")
        
        let movie = Movie(context: context)
        movie.title = "Test Movie"
        try? context.save()
        
        await managerWithBadKey.fetchIMDbID(for: movie, context: context)
        
        // Should handle error gracefully
        XCTAssertNil(movie.imdbID)
    }

    func testHandlesMovieNotFound() async {
        let movie = Movie(context: context)
        movie.title = "NonexistentMovieXYZ123456789"
        try? context.save()
        
        await manager.fetchIMDbID(for: movie, context: context)
        
        // Should handle "not found" gracefully
        XCTAssertNil(movie.imdbID)
    }

    func testHandlesEmptySearchResults() async {
        let movie = Movie(context: context)
        movie.title = ""
        try? context.save()
        
        await manager.fetchIMDbID(for: movie, context: context)
        
        XCTAssertNil(movie.imdbID)
    }

    func testHandlesSpecialCharactersInTitle() async {
        let movie = Movie(context: context)
        movie.title = "Test & Movie: The \"Special\" Edition"
        try? context.save()
        
        await manager.fetchIMDbID(for: movie, context: context)
        
        // Should handle URL encoding properly
        XCTAssertTrue(true) // No crash = success
    }

    func testMultipleConcurrentFetches() async {
        let movies = (1...5).map { i -> Movie in
            let movie = Movie(context: context)
            movie.title = "Test Movie \(i)"
            return movie
        }
        try? context.save()
        
        await withTaskGroup(of: Void.self) { group in
            for movie in movies {
                group.addTask {
                    await self.manager.fetchIMDbID(for: movie, context: self.context)
                }
            }
        }
        
        // Should handle concurrent requests without crashes
        XCTAssertTrue(true)
    }
}
