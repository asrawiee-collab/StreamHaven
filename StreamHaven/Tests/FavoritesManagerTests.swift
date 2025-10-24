import XCTest
import CoreData
@testable import StreamHaven

class FavoritesManagerTests: XCTestCase {

    var persistenceController: PersistenceController?
    var context: NSManagedObjectContext?
    var profile: Profile?
    var favoritesManager: FavoritesManager?

    override func setUp() {
        super.setUp()
        persistenceController = PersistenceController(inMemory: true)
        context = persistenceController?.container.viewContext

        guard let context = context else { XCTFail("Missing context"); return }
        profile = Profile(context: context)
        profile.name = "Test Profile"

        if let profile = profile {
            favoritesManager = FavoritesManager(context: context, profile: profile)
        }
    }

    override func tearDown() {
        super.tearDown()
        persistenceController = nil
        context = nil
        profile = nil
        favoritesManager = nil
    }

    func testToggleFavorite() {
        guard let context = context, let favoritesManager = favoritesManager else { XCTFail("Missing dependencies"); return }
        let movie = Movie(context: context)
        movie.title = "Test Movie"

        favoritesManager.toggleFavorite(for: movie)
        XCTAssertTrue(favoritesManager.isFavorite(item: movie))

        favoritesManager.toggleFavorite(for: movie)
        XCTAssertFalse(favoritesManager.isFavorite(item: movie))
    }
}
