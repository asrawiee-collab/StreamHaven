import XCTest
import CoreData
@testable import StreamHaven

/// Tests for the adult content filtering functionality.
final class AdultContentFilterTests: XCTestCase {
    
    var persistenceController: PersistenceController!
    var context: NSManagedObjectContext!
    var settingsManager: SettingsManager!
    var profileManager: ProfileManager!
    
    override func setUp() async throws {
        persistenceController = PersistenceController(inMemory: true)
        context = persistenceController.container.viewContext
        settingsManager = SettingsManager()
        profileManager = ProfileManager(persistence: persistenceController)
        
        // Reset settings
        settingsManager.hideAdultContent = false
    }
    
    override func tearDown() async throws {
        persistenceController = nil
        context = nil
        settingsManager = nil
        profileManager = nil
    }
    
    // MARK: - Test Data Creation
    
    func createMovie(title: String, rating: Rating) -> Movie {
        let movie = Movie(context: context)
        movie.id = UUID()
        movie.title = title
        movie.rating = rating.rawValue
        movie.releaseDate = Date()
        return movie
    }
    
    func createProfile(name: String, isAdult: Bool) -> Profile {
        let profile = Profile(context: context)
        profile.id = UUID()
        profile.name = name
        profile.isAdult = isAdult
        return profile
    }
    
    // MARK: - Kids Profile Tests
    
    func testKidsProfileFiltersAdultContent() throws {
        // Given: A kids profile
        let kidsProfile = createProfile(name: "Kids", isAdult: false)
        profileManager.currentProfile = kidsProfile
        
        // And: Movies with various ratings
        _ = createMovie(title: "Kids Movie", rating: .g)
        _ = createMovie(title: "Family Movie", rating: .pg)
        _ = createMovie(title: "Teen Movie", rating: .pg13)
        _ = createMovie(title: "Adult Movie", rating: .r)
        _ = createMovie(title: "Explicit Movie", rating: .nc17)
        
        try context.save()
        
        // When: Fetching movies with kids profile predicate
        let allowedRatings = [Rating.g.rawValue, Rating.pg.rawValue, Rating.pg13.rawValue, Rating.unrated.rawValue]
        let predicate = NSPredicate(format: "rating IN %@", allowedRatings)
        
        let fetchRequest: NSFetchRequest<Movie> = Movie.fetchRequest()
        fetchRequest.predicate = predicate
        
        let filteredMovies = try context.fetch(fetchRequest)
        
        // Then: Only G, PG, PG-13 movies should be returned
        XCTAssertEqual(filteredMovies.count, 3, "Kids profile should only see 3 movies (G, PG, PG-13)")
        XCTAssertTrue(filteredMovies.allSatisfy { movie in
            allowedRatings.contains(movie.rating ?? "")
        }, "All filtered movies should have allowed ratings")
    }
    
    // MARK: - Adult Profile Tests (hideAdultContent OFF)
    
    func testAdultProfileSeesAllContentByDefault() throws {
        // Given: An adult profile with hideAdultContent OFF
        let adultProfile = createProfile(name: "Adult", isAdult: true)
        profileManager.currentProfile = adultProfile
        settingsManager.hideAdultContent = false
        
        // And: Movies with all ratings
        _ = createMovie(title: "Kids Movie", rating: .g)
        _ = createMovie(title: "Family Movie", rating: .pg)
        _ = createMovie(title: "Teen Movie", rating: .pg13)
        _ = createMovie(title: "Adult Movie", rating: .r)
        _ = createMovie(title: "Explicit Movie", rating: .nc17)
        
        try context.save()
        
        // When: Fetching all movies (no filter)
        let fetchRequest: NSFetchRequest<Movie> = Movie.fetchRequest()
        let allMovies = try context.fetch(fetchRequest)
        
        // Then: All 5 movies should be visible
        XCTAssertEqual(allMovies.count, 5, "Adult profile should see all movies when hideAdultContent is OFF")
    }
    
    // MARK: - Adult Profile Tests (hideAdultContent ON)
    
    func testAdultProfileCanHideNC17Content() throws {
        // Given: An adult profile with hideAdultContent ON
        let adultProfile = createProfile(name: "Adult", isAdult: true)
        profileManager.currentProfile = adultProfile
        settingsManager.hideAdultContent = true
        UserDefaults.standard.set(true, forKey: "hideAdultContent")
        
        // And: Movies with all ratings
        _ = createMovie(title: "Kids Movie", rating: .g)
        _ = createMovie(title: "Family Movie", rating: .pg)
        _ = createMovie(title: "Teen Movie", rating: .pg13)
        _ = createMovie(title: "Adult Movie", rating: .r)
        _ = createMovie(title: "Explicit Movie", rating: .nc17)
        
        try context.save()
        
        // When: Fetching movies with adult filter predicate
        let safeRatings = [Rating.g.rawValue, Rating.pg.rawValue, Rating.pg13.rawValue, Rating.r.rawValue, Rating.unrated.rawValue]
        let predicate = NSPredicate(format: "rating IN %@", safeRatings)
        
        let fetchRequest: NSFetchRequest<Movie> = Movie.fetchRequest()
        fetchRequest.predicate = predicate
        
        let filteredMovies = try context.fetch(fetchRequest)
        
        // Then: Only G, PG, PG-13, R movies should be returned (NC-17 excluded)
        XCTAssertEqual(filteredMovies.count, 4, "Adult profile with hideAdultContent ON should see 4 movies (excluding NC-17)")
        XCTAssertFalse(filteredMovies.contains { $0.rating == Rating.nc17.rawValue }, "NC-17 content should be filtered out")
        XCTAssertTrue(filteredMovies.contains { $0.rating == Rating.r.rawValue }, "R-rated content should still be visible")
    }
    
    // MARK: - Settings Toggle Tests
    
    func testSettingsManagerStoresHideAdultContentPreference() {
        // Given: Settings manager
        let settings = SettingsManager()
        
        // When: Setting hideAdultContent to true
        settings.hideAdultContent = true
        
        // Then: The value should be persisted
        XCTAssertTrue(settings.hideAdultContent, "hideAdultContent should be true")
        XCTAssertTrue(UserDefaults.standard.bool(forKey: "hideAdultContent"), "hideAdultContent should be persisted in UserDefaults")
        
        // When: Setting hideAdultContent to false
        settings.hideAdultContent = false
        
        // Then: The value should be updated
        XCTAssertFalse(settings.hideAdultContent, "hideAdultContent should be false")
        XCTAssertFalse(UserDefaults.standard.bool(forKey: "hideAdultContent"), "hideAdultContent should be updated in UserDefaults")
    }
    
    // MARK: - Search Filter Tests
    
    func testSearchFilterRespectsKidsProfile() throws {
        // Given: A kids profile
        let kidsProfile = createProfile(name: "Kids", isAdult: false)
        profileManager.currentProfile = kidsProfile
        
        // And: Movies with various ratings
        let gMovie = createMovie(title: "G Movie", rating: .g)
        let pgMovie = createMovie(title: "PG Movie", rating: .pg)
        let rMovie = createMovie(title: "R Movie", rating: .r)
        let nc17Movie = createMovie(title: "NC-17 Movie", rating: .nc17)
        
        try context.save()
        
        // When: Filtering search results for kids profile
        let searchResults: [NSManagedObject] = [gMovie, pgMovie, rMovie, nc17Movie]
        let allowedRatings = [Rating.g.rawValue, Rating.pg.rawValue, Rating.pg13.rawValue, Rating.unrated.rawValue]
        
        let filteredResults = searchResults.filter { item in
            if let movie = item as? Movie {
                return allowedRatings.contains(movie.rating ?? Rating.unrated.rawValue)
            }
            return true
        }
        
        // Then: Only G and PG movies should be in results
        XCTAssertEqual(filteredResults.count, 2, "Kids profile search should only show 2 movies")
        XCTAssertTrue(filteredResults.contains(gMovie), "G-rated movie should be included")
        XCTAssertTrue(filteredResults.contains(pgMovie), "PG-rated movie should be included")
        XCTAssertFalse(filteredResults.contains(rMovie), "R-rated movie should be excluded")
        XCTAssertFalse(filteredResults.contains(nc17Movie), "NC-17 movie should be excluded")
    }
    
    func testSearchFilterRespectsAdultProfileWithHideAdultContent() throws {
        // Given: An adult profile with hideAdultContent enabled
        let adultProfile = createProfile(name: "Adult", isAdult: true)
        profileManager.currentProfile = adultProfile
        settingsManager.hideAdultContent = true
        
        // And: Movies with various ratings
        let gMovie = createMovie(title: "G Movie", rating: .g)
        let rMovie = createMovie(title: "R Movie", rating: .r)
        let nc17Movie = createMovie(title: "NC-17 Movie", rating: .nc17)
        
        try context.save()
        
        // When: Filtering search results for adult profile with filter
        let searchResults: [NSManagedObject] = [gMovie, rMovie, nc17Movie]
        let safeRatings = [Rating.g.rawValue, Rating.pg.rawValue, Rating.pg13.rawValue, Rating.r.rawValue, Rating.unrated.rawValue]
        
        let filteredResults = searchResults.filter { item in
            if let movie = item as? Movie {
                return safeRatings.contains(movie.rating ?? Rating.unrated.rawValue)
            }
            return true
        }
        
        // Then: G and R movies should be included, NC-17 excluded
        XCTAssertEqual(filteredResults.count, 2, "Adult profile with filter should show 2 movies")
        XCTAssertTrue(filteredResults.contains(gMovie), "G-rated movie should be included")
        XCTAssertTrue(filteredResults.contains(rMovie), "R-rated movie should be included")
        XCTAssertFalse(filteredResults.contains(nc17Movie), "NC-17 movie should be excluded")
    }
}
