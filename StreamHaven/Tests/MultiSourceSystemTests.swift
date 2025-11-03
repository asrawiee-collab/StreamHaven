import CoreData
import XCTest
@testable import StreamHaven

/// Tests for the multi-source playlist system.
@MainActor
final class MultiSourceSystemTests: XCTestCase {
    
    var persistenceController: PersistenceController!
    var context: NSManagedObjectContext!
    var profile: Profile!
    var sourceManager: PlaylistSourceManager!
    var contentManager: MultiSourceContentManager!
    
    override func setUp() async throws {
        try await super.setUp()
        persistenceController = PersistenceController(inMemory: true)
        context = persistenceController.container.viewContext
        sourceManager = PlaylistSourceManager(persistenceController: persistenceController)
        contentManager = MultiSourceContentManager(context: context)
        
        // Create a test profile
        profile = Profile(context: context)
        profile.name = "Test Profile"
        profile.isAdult = false
        profile.sourceMode = Profile.SourceMode.combined.rawValue
        try context.save()
    }
    
    override func tearDown() async throws {
        context = nil
        persistenceController = nil
        sourceManager = nil
        contentManager = nil
        profile = nil
        try await super.tearDown()
    }
    
    // MARK: - Source Management Tests
    
    func testAddM3USource() throws {
        let source = try sourceManager.addM3USource(
            name: "Test M3U", url: "https://example.com/playlist.m3u", to: profile
        )
        
        XCTAssertNotNil(source.sourceID)
        XCTAssertEqual(source.name, "Test M3U")
        XCTAssertEqual(source.sourceType, "m3u")
        XCTAssertEqual(source.url, "https://example.com/playlist.m3u")
        XCTAssertTrue(source.isActive)
        XCTAssertEqual(profile.allSources.count, 1)
    }
    
    func testAddXtreamSource() throws {
        let source = try sourceManager.addXtreamSource(
            name: "Test Xtream", url: "https://example.com", username: "user", password: "pass", to: profile
        )
        
        XCTAssertNotNil(source.sourceID)
        XCTAssertEqual(source.name, "Test Xtream")
        XCTAssertEqual(source.sourceType, "xtream")
        XCTAssertEqual(source.url, "https://example.com")
        XCTAssertEqual(source.username, "user")
        XCTAssertEqual(source.password, "pass")
        XCTAssertTrue(source.isActive)
    }
    
    func testRemoveSource() throws {
        let source = try sourceManager.addM3USource(
            name: "Test", url: "https://example.com/test.m3u", to: profile
        )
        
        XCTAssertEqual(profile.allSources.count, 1)
        
        try sourceManager.removeSource(source, from: profile)
        
        XCTAssertEqual(profile.allSources.count, 0)
    }
    
    func testActivateDeactivateSource() throws {
        let source = try sourceManager.addM3USource(
            name: "Test", url: "https://example.com/test.m3u", to: profile
        )
        
        XCTAssertTrue(source.isActive)
        XCTAssertEqual(profile.activeSources.count, 1)
        
        try sourceManager.deactivateSource(source)
        
        XCTAssertFalse(source.isActive)
        XCTAssertEqual(profile.activeSources.count, 0)
        
        try sourceManager.activateSource(source)
        
        XCTAssertTrue(source.isActive)
        XCTAssertEqual(profile.activeSources.count, 1)
    }
    
    func testReorderSources() throws {
        let source1 = try sourceManager.addM3USource(
            name: "Source 1", url: "https://example.com/1.m3u", to: profile
        )
        
        let source2 = try sourceManager.addM3USource(
            name: "Source 2", url: "https://example.com/2.m3u", to: profile
        )
        
        let source3 = try sourceManager.addM3USource(
            name: "Source 3", url: "https://example.com/3.m3u", to: profile
        )
        
        XCTAssertEqual(profile.allSources[0].displayOrder, 0)
        XCTAssertEqual(profile.allSources[1].displayOrder, 1)
        XCTAssertEqual(profile.allSources[2].displayOrder, 2)
        
        try sourceManager.reorderSources([source3, source1, source2], for: profile)
        
        XCTAssertEqual(source3.displayOrder, 0)
        XCTAssertEqual(source1.displayOrder, 1)
        XCTAssertEqual(source2.displayOrder, 2)
    }
    
    func testSourceMode() throws {
        XCTAssertEqual(profile.mode, .combined)
        
        try sourceManager.setSourceMode(.single, for: profile)
        
        XCTAssertEqual(profile.mode, .single)
    }
    
    // MARK: - Content Grouping Tests
    
    func testGroupMoviesByCombinedMode() throws {
        // Create test sources
        let source1 = try sourceManager.addM3USource(
            name: "Source 1", url: "https://example.com/1.m3u", to: profile
        )
        
        let source2 = try sourceManager.addM3USource(
            name: "Source 2", url: "https://example.com/2.m3u", to: profile
        )
        
        // Create duplicate movies from different sources
        let movie1 = Movie(context: context)
        movie1.title = "The Matrix"
        movie1.sourceID = source1.sourceID
        movie1.streamURL = "https://example.com/1/matrix.mp4"
        movie1.posterURL = ""
        movie1.rating = "R"
        movie1.releaseDate = Date()
        movie1.summary = "A sci-fi classic"
        
        let movie2 = Movie(context: context)
        movie2.title = "The Matrix"
        movie2.sourceID = source2.sourceID
        movie2.streamURL = "https://example.com/2/matrix.mp4"
        movie2.posterURL = ""
        movie2.rating = "R"
        movie2.releaseDate = Date()
        movie2.summary = "A sci-fi classic"
        
        try context.save()
        
        // Set combined mode
        try sourceManager.setSourceMode(.combined, for: profile)
        
        let groups = try contentManager.groupMovies(for: profile)
        
        XCTAssertEqual(groups.count, 1)
        XCTAssertEqual(groups[0].itemCount, 2)
    }
    
    func testGroupMoviesBySingleMode() throws {
        // Create test sources
        let source1 = try sourceManager.addM3USource(
            name: "Source 1", url: "https://example.com/1.m3u", to: profile
        )
        
        let source2 = try sourceManager.addM3USource(
            name: "Source 2", url: "https://example.com/2.m3u", to: profile
        )
        
        // Create duplicate movies
        let movie1 = Movie(context: context)
        movie1.title = "The Matrix"
        movie1.sourceID = source1.sourceID
        movie1.streamURL = "https://example.com/1/matrix.mp4"
        movie1.posterURL = ""
        movie1.rating = "R"
        movie1.releaseDate = Date()
        movie1.summary = "A sci-fi classic"
        
        let movie2 = Movie(context: context)
        movie2.title = "The Matrix"
        movie2.sourceID = source2.sourceID
        movie2.streamURL = "https://example.com/2/matrix.mp4"
        movie2.posterURL = ""
        movie2.rating = "R"
        movie2.releaseDate = Date()
        movie2.summary = "A sci-fi classic"
        
        try context.save()
        
        // Set single mode
        try sourceManager.setSourceMode(.single, for: profile)
        
        let groups = try contentManager.groupMovies(for: profile)
        
        // In single mode, each movie should be in its own group
        XCTAssertEqual(groups.count, 2)
        XCTAssertEqual(groups[0].itemCount, 1)
        XCTAssertEqual(groups[1].itemCount, 1)
    }
    
    func testQualityAssessment() {
        XCTAssertEqual(contentManager.assessQuality(streamURL: "https://example.com/movie_4k.mp4", name: nil), 5)
        XCTAssertEqual(contentManager.assessQuality(streamURL: "https://example.com/movie_1080p.mp4", name: nil), 4)
        XCTAssertEqual(contentManager.assessQuality(streamURL: "https://example.com/movie_720p.mp4", name: nil), 3)
        XCTAssertEqual(contentManager.assessQuality(streamURL: "https://example.com/movie_480p.mp4", name: nil), 2)
        XCTAssertEqual(contentManager.assessQuality(streamURL: "https://example.com/movie.mp4", name: nil), 1)
    }
    
    func testSelectBestItem() throws {
        let source = try sourceManager.addM3USource(
            name: "Source 1", url: "https://example.com/1.m3u", to: profile
        )
        
        let movie1 = Movie(context: context)
        movie1.title = "Test"
        movie1.sourceID = source.sourceID
        movie1.streamURL = "https://example.com/test.mp4"
        movie1.posterURL = ""
        movie1.rating = ""
        movie1.releaseDate = Date()
        movie1.summary = ""
        
        let movie2 = Movie(context: context)
        movie2.title = "Test"
        movie2.sourceID = source.sourceID
        movie2.streamURL = "https://example.com/test_hd.mp4"
        movie2.posterURL = ""
        movie2.rating = ""
        movie2.releaseDate = Date()
        movie2.summary = ""
        
        let group = MultiSourceContentManager.ContentGroup(
            primaryItem: movie1, alternativeItems: [movie2], sourceIDs: [source.sourceID].compactMap { $0 }
        )
        
        let best = contentManager.selectBestItem(from: group)
        
        // Should return primary item for now
        XCTAssertEqual(best.streamURL, movie1.streamURL)
    }
    
    // MARK: - Source Metadata Tests
    
    func testGetSourceMetadata() throws {
        let source = try sourceManager.addM3USource(
            name: "Test Source", url: "https://example.com/test.m3u", to: profile
        )
        
        guard let sourceID = source.sourceID else {
            XCTFail("Source ID should not be nil")
            return
        }
        
        let metadata = contentManager.getSourceMetadata(for: sourceID, in: profile)
        
        XCTAssertNotNil(metadata)
        XCTAssertEqual(metadata?.sourceName, "Test Source")
        XCTAssertEqual(metadata?.isActive, true)
    }
    
}
