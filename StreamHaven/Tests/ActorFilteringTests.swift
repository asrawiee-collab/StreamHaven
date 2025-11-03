import CoreData
import XCTest
@testable import StreamHaven

/// Tests for the Actor filtering feature.
@MainActor
final class ActorFilteringTests: XCTestCase {
    var container: NSPersistentContainer!
    var context: NSManagedObjectContext!
    var tmdbManager: TMDbManager!
    
    override func setUp() async throws {
        // Use TestCoreDataModelBuilder with Actor/Credit entities
        container = NSPersistentContainer(name: "Test", managedObjectModel: TestCoreDataModelBuilder.sharedModel)
        let description = NSPersistentStoreDescription()
        description.type = NSInMemoryStoreType
        container.persistentStoreDescriptions = [description]
        
        container.loadPersistentStores { _, error in
            if let error = error {
                XCTFail("Failed to load persistent store: \(error)")
            }
        }
        
        context = container.viewContext
        tmdbManager = TMDbManager(apiKey: "test_key")
    }
    
    override func tearDown() async throws {
        context = nil
        container = nil
        tmdbManager = nil
    }
    
    /// Tests that Actor entities can be created.
    func testActorEntityCreation() {
        let actor = Actor(context: context)
        actor.tmdbID = 123
        actor.name = "Test Actor"
        actor.photoURL = "https://example.com/photo.jpg"
        actor.biography = "A test actor"
        actor.popularity = 7.5
        
        XCTAssertEqual(actor.tmdbID, 123)
        XCTAssertEqual(actor.name, "Test Actor")
        XCTAssertEqual(actor.photoURL, "https://example.com/photo.jpg")
        XCTAssertEqual(actor.biography, "A test actor")
        XCTAssertEqual(actor.popularity, 7.5)
    }
    
    /// Tests that Credit entities can be created with relationships.
    func testCreditRelationships() {
        let movie = Movie(context: context)
        movie.title = "Test Movie"
        
        let actor = Actor(context: context)
        actor.name = "Test Actor"
        actor.tmdbID = 456
        
        let credit = Credit(context: context)
        credit.actor = actor
        credit.movie = movie
        credit.character = "Hero"
        credit.order = 0
        credit.creditType = "cast"
        
        try? context.save()
        
        XCTAssertEqual(movie.credits?.count, 1)
        XCTAssertEqual(actor.credits?.count, 1)
        
        let movieCredits = movie.credits as? Set<Credit>
        XCTAssertNotNil(movieCredits)
        XCTAssertEqual(movieCredits?.first?.character, "Hero")
        XCTAssertEqual(movieCredits?.first?.actor?.name, "Test Actor")
    }
    
    /// Tests that Credits can be linked to Series.
    func testSeriesCreditRelationships() {
        let series = Series(context: context)
        series.title = "Test Series"
        
        let actor = Actor(context: context)
        actor.name = "Series Actor"
        actor.tmdbID = 789
        
        let credit = Credit(context: context)
        credit.actor = actor
        credit.series = series
        credit.character = "Main Character"
        credit.order = 0
        credit.creditType = "cast"
        
        try? context.save()
        
        XCTAssertEqual(series.credits?.count, 1)
        XCTAssertEqual(actor.credits?.count, 1)
    }
    
    /// Tests filmography filtering for an actor.
    func testActorFilmographyFiltering() {
        let actor = Actor(context: context)
        actor.name = "Test Actor"
        actor.tmdbID = 999
        
        // Create 3 movies
        for i in 1...3 {
            let movie = Movie(context: context)
            movie.title = "Movie \(i)"
            
            let credit = Credit(context: context)
            credit.actor = actor
            credit.movie = movie
            credit.creditType = "cast"
            credit.order = Int16(i - 1)
        }
        
        // Create 2 series
        for i in 1...2 {
            let series = Series(context: context)
            series.title = "Series \(i)"
            
            let credit = Credit(context: context)
            credit.actor = actor
            credit.series = series
            credit.creditType = "cast"
            credit.order = Int16(i - 1)
        }
        
        try? context.save()
        
        let credits = actor.credits as? Set<Credit>
        let movies = credits?.compactMap { $0.movie }
        let series = credits?.compactMap { $0.series }
        
        XCTAssertEqual(movies?.count, 3)
        XCTAssertEqual(series?.count, 2)
    }
    
    /// Tests that credits can be sorted by order.
    func testCreditOrdering() {
        let movie = Movie(context: context)
        movie.title = "Ensemble Movie"
        
        let actors = ["Lead Actor", "Supporting Actor", "Cameo"]
        for (index, name) in actors.enumerated() {
            let actor = Actor(context: context)
            actor.name = name
            actor.tmdbID = Int64(index + 1)
            
            let credit = Credit(context: context)
            credit.actor = actor
            credit.movie = movie
            credit.order = Int16(index)
            credit.creditType = "cast"
        }
        
        try? context.save()
        
        let movieCredits = movie.credits as? Set<Credit>
        let sortedCredits = movieCredits?.sorted { $0.order < $1.order }
        
        XCTAssertEqual(sortedCredits?.count, 3)
        XCTAssertEqual(sortedCredits?[0].actor?.name, "Lead Actor")
        XCTAssertEqual(sortedCredits?[1].actor?.name, "Supporting Actor")
        XCTAssertEqual(sortedCredits?[2].actor?.name, "Cameo")
    }
    
    /// Tests that the same actor can appear in multiple movies.
    func testActorMultipleMovies() {
        let actor = Actor(context: context)
        actor.name = "Prolific Actor"
        actor.tmdbID = 555
        
        let movieTitles = ["Movie A", "Movie B", "Movie C", "Movie D"]
        for title in movieTitles {
            let movie = Movie(context: context)
            movie.title = title
            
            let credit = Credit(context: context)
            credit.actor = actor
            credit.movie = movie
            credit.creditType = "cast"
        }
        
        try? context.save()
        
        XCTAssertEqual(actor.credits?.count, 4)
    }
    
    /// Tests filtering cast vs crew credits.
    func testCastVsCrewFiltering() {
        let movie = Movie(context: context)
        movie.title = "Test Movie"
        
        let actor = Actor(context: context)
        actor.name = "Actor"
        actor.tmdbID = 111
        
        let director = Actor(context: context)
        director.name = "Director"
        director.tmdbID = 222
        
        let castCredit = Credit(context: context)
        castCredit.actor = actor
        castCredit.movie = movie
        castCredit.creditType = "cast"
        castCredit.character = "Lead"
        
        let crewCredit = Credit(context: context)
        crewCredit.actor = director
        crewCredit.movie = movie
        crewCredit.creditType = "crew"
        crewCredit.job = "Director"
        
        try? context.save()
        
        let movieCredits = movie.credits as? Set<Credit>
        let castOnly = movieCredits?.filter { $0.creditType == "cast" }
        let crewOnly = movieCredits?.filter { $0.creditType == "crew" }
        
        XCTAssertEqual(castOnly?.count, 1)
        XCTAssertEqual(crewOnly?.count, 1)
        XCTAssertEqual(castOnly?.first?.character, "Lead")
        XCTAssertEqual(crewOnly?.first?.job, "Director")
    }
    
    /// Tests that deleting a movie cascades to credits but not actors.
    func testCascadeDeletionOnMovie() {
        let movie = Movie(context: context)
        movie.title = "Delete Me"
        
        let actor = Actor(context: context)
        actor.name = "Survivor"
        actor.tmdbID = 333
        
        let credit = Credit(context: context)
        credit.actor = actor
        credit.movie = movie
        credit.creditType = "cast"
        
        try? context.save()
        
        // Delete the movie
        context.delete(movie)
        try? context.save()
        
        // Credit should be deleted (cascade)
        let fetchRequest: NSFetchRequest<Credit> = Credit.fetchRequest()
        let remainingCredits = try? context.fetch(fetchRequest)
        XCTAssertEqual(remainingCredits?.count, 0)
        
        // Actor should still exist (nullify)
        let actorFetch: NSFetchRequest<Actor> = Actor.fetchRequest()
        let remainingActors = try? context.fetch(actorFetch)
        XCTAssertEqual(remainingActors?.count, 1)
        XCTAssertEqual(remainingActors?.first?.name, "Survivor")
    }
}
