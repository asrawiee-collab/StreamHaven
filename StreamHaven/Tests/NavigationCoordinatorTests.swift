import XCTest
import SwiftUI
import CoreData
@testable import StreamHaven

@MainActor
final class NavigationCoordinatorTests: XCTestCase {
    var coordinator: NavigationCoordinator!
    var provider: PersistenceProviding!
    var context: NSManagedObjectContext!

    override func setUpWithError() throws {
        coordinator = NavigationCoordinator()
        
        let controller = PersistenceController(inMemory: true)
        provider = DefaultPersistenceProvider(controller: controller)
        context = provider.container.viewContext
    }

    func testInitialPathIsEmpty() {
        XCTAssertEqual(coordinator.path.count, 0)
    }

    func testGoToMovieDetail() {
        let movie = Movie(context: context)
        movie.title = "Test Movie"
        
        coordinator.goTo(.movieDetail(movie))
        
        XCTAssertEqual(coordinator.path.count, 1)
    }

    func testGoToSeriesDetail() {
        let series = Series(context: context)
        series.title = "Test Series"
        
        coordinator.goTo(.seriesDetail(series))
        
        XCTAssertEqual(coordinator.path.count, 1)
    }

    func testMultipleNavigations() {
        let movie = Movie(context: context)
        movie.title = "Movie 1"
        
        let series = Series(context: context)
        series.title = "Series 1"
        
        coordinator.goTo(.movieDetail(movie))
        coordinator.goTo(.seriesDetail(series))
        
        XCTAssertEqual(coordinator.path.count, 2)
    }

    func testPopRemovesLastDestination() {
        let movie = Movie(context: context)
        movie.title = "Test Movie"
        
        coordinator.goTo(.movieDetail(movie))
        XCTAssertEqual(coordinator.path.count, 1)
        
        coordinator.pop()
        XCTAssertEqual(coordinator.path.count, 0)
    }

    func testPopToRootClearsAllDestinations() {
        let movie1 = Movie(context: context)
        movie1.title = "Movie 1"
        let movie2 = Movie(context: context)
        movie2.title = "Movie 2"
        let series = Series(context: context)
        series.title = "Series"
        
        coordinator.goTo(.movieDetail(movie1))
        coordinator.goTo(.movieDetail(movie2))
        coordinator.goTo(.seriesDetail(series))
        
        XCTAssertEqual(coordinator.path.count, 3)
        
        coordinator.popToRoot()
        XCTAssertEqual(coordinator.path.count, 0)
    }

    func testPopOnEmptyPathDoesNotCrash() {
        XCTAssertEqual(coordinator.path.count, 0)
        
        // Should handle gracefully
        coordinator.popToRoot()
        XCTAssertEqual(coordinator.path.count, 0)
    }

    func testDestinationEquality() {
        let movie1 = Movie(context: context)
        movie1.title = "Movie"
        let movie2 = Movie(context: context)
        movie2.title = "Movie"
        
        let dest1 = Destination.movieDetail(movie1)
        let dest2 = Destination.movieDetail(movie1)
        let dest3 = Destination.movieDetail(movie2)
        
        XCTAssertEqual(dest1, dest2) // Same object ID
        XCTAssertNotEqual(dest1, dest3) // Different object IDs
    }

    func testDestinationHashable() {
        let movie = Movie(context: context)
        movie.title = "Movie"
        
        let dest1 = Destination.movieDetail(movie)
        let dest2 = Destination.movieDetail(movie)
        
        var hasher1 = Hasher()
        var hasher2 = Hasher()
        dest1.hash(into: &hasher1)
        dest2.hash(into: &hasher2)
        
        // Should produce same hash for same object
        XCTAssertEqual(hasher1.finalize(), hasher2.finalize())
    }

    func testMovieAndSeriesDestinationsNotEqual() {
        let movie = Movie(context: context)
        movie.title = "Content"
        let series = Series(context: context)
        series.title = "Content"
        
        let movieDest = Destination.movieDetail(movie)
        let seriesDest = Destination.seriesDetail(series)
        
        XCTAssertNotEqual(movieDest, seriesDest)
    }

    func testNavigationPathPersistence() {
        let movie = Movie(context: context)
        movie.title = "Movie"
        
        coordinator.goTo(.movieDetail(movie))
        let initialCount = coordinator.path.count
        
        // Simulate view reconstruction
        let newCoordinator = NavigationCoordinator()
        
        // New coordinator starts fresh
        XCTAssertEqual(newCoordinator.path.count, 0)
        XCTAssertEqual(initialCount, 1)
    }

    func testDeepNavigation() {
        let movies = (1...10).map { i -> Movie in
            let movie = Movie(context: context)
            movie.title = "Movie \(i)"
            return movie
        }
        
        for movie in movies {
            coordinator.goTo(.movieDetail(movie))
        }
        
        XCTAssertEqual(coordinator.path.count, 10)
        
        coordinator.popToRoot()
        XCTAssertEqual(coordinator.path.count, 0)
    }
}
