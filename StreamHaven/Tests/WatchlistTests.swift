//
//  WatchlistTests.swift
//  StreamHaven
//
//  Created on October 25, 2025.
//

import CoreData
import XCTest
@testable import StreamHaven

@MainActor
class WatchlistTests: XCTestCase {
    
    var persistenceController: PersistenceController!
    var context: NSManagedObjectContext!
    var watchlistManager: WatchlistManager!
    var profile: Profile!
    
    override func setUp() async throws {
        persistenceController = PersistenceController(inMemory: true)
        context = persistenceController.container.viewContext
        watchlistManager = WatchlistManager(context: context)
        
        // Create test profile
        profile = Profile(context: context)
        profile.name = "Test Profile"
        profile.isAdult = false
        try context.save()
    }
    
    override func tearDown() {
        watchlistManager = nil
        context = nil
        persistenceController = nil
        profile = nil
    }
    
    // MARK: - Watchlist CRUD Tests
    
    func testCreateWatchlist() throws {
        // Given
        let name = "My Watchlist"
        let icon = "star.fill"
        
        // When
        let watchlist = try watchlistManager.createWatchlist(name: name, icon: icon, profile: profile)
        
        // Then
        XCTAssertEqual(watchlist.name, name)
        XCTAssertEqual(watchlist.icon, icon)
        XCTAssertEqual(watchlist.profile, profile)
        XCTAssertEqual(watchlist.itemCount, 0)
        XCTAssertNotNil(watchlist.createdAt)
        XCTAssertNotNil(watchlist.updatedAt)
    }
    
    func testCreateMultipleWatchlists() throws {
        // When
        let watchlist1 = try watchlistManager.createWatchlist(name: "Action", icon: "flame.fill", profile: profile)
        let watchlist2 = try watchlistManager.createWatchlist(name: "Comedy", icon: "face.smiling", profile: profile)
        let watchlist3 = try watchlistManager.createWatchlist(name: "Drama", icon: "heart.fill", profile: profile)
        
        // Then
        watchlistManager.loadWatchlists(for: profile)
        XCTAssertEqual(watchlistManager.watchlists.count, 3)
        XCTAssertTrue(watchlistManager.watchlists.contains(watchlist1))
        XCTAssertTrue(watchlistManager.watchlists.contains(watchlist2))
        XCTAssertTrue(watchlistManager.watchlists.contains(watchlist3))
    }
    
    func testCreateWatchlist_exceedsLimit() throws {
        // Given - Create 20 watchlists (the limit)
        for i in 1...20 {
            _ = try watchlistManager.createWatchlist(name: "Watchlist \(i)", profile: profile)
        }
        
        // When/Then - Attempting to create 21st should fail
        XCTAssertThrowsError(try watchlistManager.createWatchlist(name: "Watchlist 21", profile: profile)) { error in
            XCTAssertTrue(error is WatchlistManager.WatchlistError)
            XCTAssertEqual(error as? WatchlistManager.WatchlistError, .watchlistLimitReached)
        }
    }
    
    func testDeleteWatchlist() throws {
        // Given
        let watchlist = try watchlistManager.createWatchlist(name: "To Delete", profile: profile)
        watchlistManager.loadWatchlists(for: profile)
        XCTAssertEqual(watchlistManager.watchlists.count, 1)
        
        // When
        try watchlistManager.deleteWatchlist(watchlist, profile: profile)
        
        // Then
        XCTAssertEqual(watchlistManager.watchlists.count, 0)
    }
    
    func testRenameWatchlist() throws {
        // Given
        let watchlist = try watchlistManager.createWatchlist(name: "Old Name", profile: profile)
        let newName = "New Name"
        
        // When
        try watchlistManager.renameWatchlist(watchlist, newName: newName, profile: profile)
        
        // Then
        XCTAssertEqual(watchlist.name, newName)
    }
    
    func testUpdateWatchlistIcon() throws {
        // Given
        let watchlist = try watchlistManager.createWatchlist(name: "Test", icon: "list.bullet", profile: profile)
        let newIcon = "star.fill"
        
        // When
        try watchlistManager.updateIcon(watchlist, icon: newIcon, profile: profile)
        
        // Then
        XCTAssertEqual(watchlist.icon, newIcon)
    }
    
    // MARK: - Item Management Tests
    
    func testAddMovieToWatchlist() throws {
        // Given
        let watchlist = try watchlistManager.createWatchlist(name: "My Movies", profile: profile)
        let movie = Movie(context: context)
        movie.title = "Test Movie"
        movie.posterURL = "https://example.com/poster.jpg"
        movie.summary = "A test movie"
        movie.rating = "PG"
        movie.releaseDate = Date()
        movie.streamURL = "https://example.com/stream"
        try context.save()
        
        // When
        try watchlistManager.addToWatchlist(movie, watchlist: watchlist)
        
        // Then
        XCTAssertEqual(watchlist.itemCount, 1)
        XCTAssertTrue(watchlist.contains(contentID: movie.objectID.uriRepresentation().absoluteString))
    }
    
    func testAddMultipleItemsToWatchlist() throws {
        // Given
        let watchlist = try watchlistManager.createWatchlist(name: "Mixed Content", profile: profile)
        
        let movie = Movie(context: context)
        movie.title = "Movie 1"
        movie.posterURL = "https://example.com/poster1.jpg"
        movie.summary = "Movie 1"
        movie.rating = "PG"
        movie.releaseDate = Date()
        movie.streamURL = "https://example.com/stream1"
        
        let series = Series(context: context)
        series.title = "Series 1"
        series.posterURL = "https://example.com/poster2.jpg"
        series.summary = "Series 1"
        series.rating = "PG"
        series.releaseDate = Date()
        
        try context.save()
        
        // When
        try watchlistManager.addToWatchlist(movie, watchlist: watchlist)
        try watchlistManager.addToWatchlist(series, watchlist: watchlist)
        
        // Then
        XCTAssertEqual(watchlist.itemCount, 2)
    }
    
    func testAddDuplicateItemToWatchlist() throws {
        // Given
        let watchlist = try watchlistManager.createWatchlist(name: "Test", profile: profile)
        let movie = Movie(context: context)
        movie.title = "Test Movie"
        movie.posterURL = "https://example.com/poster.jpg"
        movie.summary = "Test"
        movie.rating = "PG"
        movie.releaseDate = Date()
        movie.streamURL = "https://example.com/stream"
        try context.save()
        
        try watchlistManager.addToWatchlist(movie, watchlist: watchlist)
        
        // When/Then - Adding again should fail
        XCTAssertThrowsError(try watchlistManager.addToWatchlist(movie, watchlist: watchlist)) { error in
            XCTAssertTrue(error is WatchlistManager.WatchlistError)
            XCTAssertEqual(error as? WatchlistManager.WatchlistError, .itemAlreadyExists)
        }
    }
    
    func testRemoveItemFromWatchlist() throws {
        // Given
        let watchlist = try watchlistManager.createWatchlist(name: "Test", profile: profile)
        let movie = Movie(context: context)
        movie.title = "Test Movie"
        movie.posterURL = "https://example.com/poster.jpg"
        movie.summary = "Test"
        movie.rating = "PG"
        movie.releaseDate = Date()
        movie.streamURL = "https://example.com/stream"
        try context.save()
        
        try watchlistManager.addToWatchlist(movie, watchlist: watchlist)
        let item = watchlist.sortedItems.first!
        
        // When
        try watchlistManager.removeFromWatchlist(item, watchlist: watchlist)
        
        // Then
        XCTAssertEqual(watchlist.itemCount, 0)
    }
    
    func testClearWatchlist() throws {
        // Given
        let watchlist = try watchlistManager.createWatchlist(name: "Test", profile: profile)
        
        for i in 1...5 {
            let movie = Movie(context: context)
            movie.title = "Movie \(i)"
            movie.posterURL = "https://example.com/poster\(i).jpg"
            movie.summary = "Movie \(i)"
            movie.rating = "PG"
            movie.releaseDate = Date()
            movie.streamURL = "https://example.com/stream\(i)"
            try context.save()
            try watchlistManager.addToWatchlist(movie, watchlist: watchlist)
        }
        
        XCTAssertEqual(watchlist.itemCount, 5)
        
        // When
        try watchlistManager.clearWatchlist(watchlist)
        
        // Then
        XCTAssertEqual(watchlist.itemCount, 0)
    }
    
    func testMoveItem() throws {
        // Given
        let watchlist = try watchlistManager.createWatchlist(name: "Test", profile: profile)
        
        // Create 3 movies
        var movies: [Movie] = []
        for i in 1...3 {
            let movie = Movie(context: context)
            movie.title = "Movie \(i)"
            movie.posterURL = "https://example.com/poster\(i).jpg"
            movie.summary = "Movie \(i)"
            movie.rating = "PG"
            movie.releaseDate = Date()
            movie.streamURL = "https://example.com/stream\(i)"
            try context.save()
            movies.append(movie)
            try watchlistManager.addToWatchlist(movie, watchlist: watchlist)
        }
        
        let items = watchlist.sortedItems
        XCTAssertEqual(items[0].position, 0)
        XCTAssertEqual(items[1].position, 1)
        XCTAssertEqual(items[2].position, 2)
        
        // When - Move item at position 0 to position 2
        try watchlistManager.moveItem(items[0], to: 2, in: watchlist)
        
        // Then
        let updatedItems = watchlist.sortedItems
        XCTAssertEqual(updatedItems[0].position, 0)
        XCTAssertEqual(updatedItems[1].position, 1)
        XCTAssertEqual(updatedItems[2].position, 2)
        XCTAssertEqual(updatedItems[2].contentID, movies[0].objectID.uriRepresentation().absoluteString)
    }
    
    // MARK: - Query Tests
    
    func testIsInAnyWatchlist() throws {
        // Given
        let watchlist1 = try watchlistManager.createWatchlist(name: "Watchlist 1", profile: profile)
        _ = try watchlistManager.createWatchlist(name: "Watchlist 2", profile: profile)
        
        let movie = Movie(context: context)
        movie.title = "Test Movie"
        movie.posterURL = "https://example.com/poster.jpg"
        movie.summary = "Test"
        movie.rating = "PG"
        movie.releaseDate = Date()
        movie.streamURL = "https://example.com/stream"
        try context.save()
        
        // When/Then - Not in any watchlist initially
        XCTAssertFalse(watchlistManager.isInAnyWatchlist(movie, profile: profile))
        
        // Add to watchlist1
        try watchlistManager.addToWatchlist(movie, watchlist: watchlist1)
        XCTAssertTrue(watchlistManager.isInAnyWatchlist(movie, profile: profile))
    }
    
    func testGetWatchlistsContaining() throws {
        // Given
        let watchlist1 = try watchlistManager.createWatchlist(name: "Watchlist 1", profile: profile)
        let watchlist2 = try watchlistManager.createWatchlist(name: "Watchlist 2", profile: profile)
        let watchlist3 = try watchlistManager.createWatchlist(name: "Watchlist 3", profile: profile)
        
        let movie = Movie(context: context)
        movie.title = "Test Movie"
        movie.posterURL = "https://example.com/poster.jpg"
        movie.summary = "Test"
        movie.rating = "PG"
        movie.releaseDate = Date()
        movie.streamURL = "https://example.com/stream"
        try context.save()
        
        try watchlistManager.addToWatchlist(movie, watchlist: watchlist1)
        try watchlistManager.addToWatchlist(movie, watchlist: watchlist3)
        
        // When
        let containingWatchlists = watchlistManager.getWatchlistsContaining(movie, profile: profile)
        
        // Then
        XCTAssertEqual(containingWatchlists.count, 2)
        XCTAssertTrue(containingWatchlists.contains(watchlist1))
        XCTAssertTrue(containingWatchlists.contains(watchlist3))
        XCTAssertFalse(containingWatchlists.contains(watchlist2))
    }
    
    func testGetTotalItemCount() throws {
        // Given
        let watchlist1 = try watchlistManager.createWatchlist(name: "Watchlist 1", profile: profile)
        let watchlist2 = try watchlistManager.createWatchlist(name: "Watchlist 2", profile: profile)
        
        for i in 1...3 {
            let movie = Movie(context: context)
            movie.title = "Movie \(i)"
            movie.posterURL = "https://example.com/poster\(i).jpg"
            movie.summary = "Movie \(i)"
            movie.rating = "PG"
            movie.releaseDate = Date()
            movie.streamURL = "https://example.com/stream\(i)"
            try context.save()
            try watchlistManager.addToWatchlist(movie, watchlist: i <= 2 ? watchlist1: watchlist2)
        }
        
        // When
        let totalCount = watchlistManager.getTotalItemCount(for: profile)
        
        // Then
        XCTAssertEqual(totalCount, 3)
    }
    
    func testSearchWatchlists() throws {
        // Given
        _ = try watchlistManager.createWatchlist(name: "Action Movies", profile: profile)
        _ = try watchlistManager.createWatchlist(name: "Comedy Shows", profile: profile)
        _ = try watchlistManager.createWatchlist(name: "Action Series", profile: profile)
        
        // When
        let results = watchlistManager.searchWatchlists(query: "Action", profile: profile)
        
        // Then
        XCTAssertEqual(results.count, 2)
        XCTAssertTrue(results.allSatisfy { $0.name.contains("Action") })
    }
    
    // MARK: - Profile Isolation Tests
    
    func testProfileIsolation() throws {
        // Given
        let profile2 = Profile(context: context)
        profile2.name = "Profile 2"
        profile2.isAdult = true
        try context.save()
        
        let watchlist1 = try watchlistManager.createWatchlist(name: "Profile 1 List", profile: profile)
        let watchlist2 = try watchlistManager.createWatchlist(name: "Profile 2 List", profile: profile2)
        
        // When
        watchlistManager.loadWatchlists(for: profile)
        
        // Then
        XCTAssertEqual(watchlistManager.watchlists.count, 1)
        XCTAssertEqual(watchlistManager.watchlists.first, watchlist1)
        
        // When - Load for profile2
        watchlistManager.loadWatchlists(for: profile2)
        
        // Then
        XCTAssertEqual(watchlistManager.watchlists.count, 1)
        XCTAssertEqual(watchlistManager.watchlists.first, watchlist2)
    }
    
    // MARK: - WatchlistItem Tests
    
    func testWatchlistItemContentType() throws {
        // Given
        let watchlist = try watchlistManager.createWatchlist(name: "Test", profile: profile)
        
        let movie = Movie(context: context)
        movie.title = "Test Movie"
        movie.posterURL = "https://example.com/poster.jpg"
        movie.summary = "Test"
        movie.rating = "PG"
        movie.releaseDate = Date()
        movie.streamURL = "https://example.com/stream"
        try context.save()
        
        // When
        try watchlistManager.addToWatchlist(movie, watchlist: watchlist)
        let item = watchlist.sortedItems.first!
        
        // Then
        XCTAssertEqual(item.itemContentType, .movie)
    }
    
    func testWatchlistItemFetchContent() throws {
        // Given
        let watchlist = try watchlistManager.createWatchlist(name: "Test", profile: profile)
        
        let movie = Movie(context: context)
        movie.title = "Test Movie"
        movie.posterURL = "https://example.com/poster.jpg"
        movie.summary = "Test"
        movie.rating = "PG"
        movie.releaseDate = Date()
        movie.streamURL = "https://example.com/stream"
        try context.save()
        
        try watchlistManager.addToWatchlist(movie, watchlist: watchlist)
        let item = watchlist.sortedItems.first!
        
        // When
        let fetchedContent = item.fetchContent(context: context)
        
        // Then
        XCTAssertNotNil(fetchedContent)
        XCTAssertTrue(fetchedContent is Movie)
        XCTAssertEqual((fetchedContent as? Movie)?.title, "Test Movie")
    }
}
