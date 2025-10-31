import XCTest
import CoreData
@testable import StreamHaven

/// Tests for MultiSourceContentManager.
@MainActor
final class MultiSourceContentManagerTests: XCTestCase {
    var contentManager: MultiSourceContentManager!
    var context: NSManagedObjectContext!
    var profile: Profile!
    var persistenceProvider: PersistenceProviding!
    
    override func setUp() async throws {
        try await super.setUp()
        
        // Create in-memory Core Data stack
        let container = NSPersistentContainer(
            name: "StreamHavenTest",
            managedObjectModel: TestCoreDataModelBuilder.sharedModel
        )
        
        let description = NSPersistentStoreDescription()
        description.type = NSInMemoryStoreType
        container.persistentStoreDescriptions = [description]
        
        var loadError: Error?
        container.loadPersistentStores { _, error in
            loadError = error
        }
        
        if let error = loadError {
            throw XCTSkip("Failed to load in-memory store: \(error)")
        }
        
        context = container.viewContext
        
        struct TestProvider: PersistenceProviding {
            let container: NSPersistentContainer
        }
        persistenceProvider = TestProvider(container: container)
        
        // Create test profile with sources
        profile = Profile(context: context)
        profile.name = "Test User"
        profile.isAdult = true
        profile.sourceMode = Profile.SourceMode.combined.rawValue
        
        // Create test sources
        let source1 = PlaylistSource(context: context)
        source1.sourceID = UUID()
        source1.name = "Source 1"
        source1.isActive = true
        source1.profile = profile
        
        let source2 = PlaylistSource(context: context)
        source2.sourceID = UUID()
        source2.name = "Source 2"
        source2.isActive = true
        source2.profile = profile
        
        try context.save()
        
        // Initialize MultiSourceContentManager
        contentManager = MultiSourceContentManager(context: context)
    }
    
    override func tearDown() async throws {
        contentManager = nil
        profile = nil
        context = nil
        persistenceProvider = nil
        try await super.tearDown()
    }
    
    // MARK: - Initialization Tests
    
    func testMultiSourceContentManagerInitialization() {
        XCTAssertNotNil(contentManager, "MultiSourceContentManager should initialize")
    }
    
    // MARK: - Movie Grouping Tests
    
    func testGroupMoviesInCombinedMode() throws {
        let sources = profile.activeSources
        guard sources.count >= 2 else {
            XCTFail("Should have at least 2 sources")
            return
        }
        
        // Create same movie from different sources
        let movie1 = Movie(context: context)
        movie1.title = "The Matrix"
        movie1.sourceID = sources[0].sourceID
        
        let movie2 = Movie(context: context)
        movie2.title = "The Matrix"
        movie2.sourceID = sources[1].sourceID
        
        try context.save()
        
        let groups = try contentManager.groupMovies(for: profile)
        
        XCTAssertFalse(groups.isEmpty, "Should have movie groups")
        
        let matrixGroup = groups.first { $0.primaryItem.title == "The Matrix" }
        XCTAssertNotNil(matrixGroup, "Should find Matrix group")
        XCTAssertEqual(matrixGroup?.itemCount, 2, "Should group both movies together")
    }
    
    func testGroupMoviesInSingleMode() throws {
        // Switch to single mode
        profile.sourceMode = Profile.SourceMode.single.rawValue
        try context.save()
        
        let sources = profile.activeSources
        
        let movie1 = Movie(context: context)
        movie1.title = "Movie 1"
        movie1.sourceID = sources[0].sourceID
        
        let movie2 = Movie(context: context)
        movie2.title = "Movie 1"
        movie2.sourceID = sources[1].sourceID
        
        try context.save()
        
        let groups = try contentManager.groupMovies(for: profile)
        
        // In single mode, should not group
        XCTAssertEqual(groups.count, 2, "Should have ungrouped movies in single mode")
        XCTAssertTrue(groups.allSatisfy { $0.alternativeItems.isEmpty }, "Should have no alternatives in single mode")
    }
    
    func testGroupMoviesWithSimilarTitles() throws {
        let source = profile.activeSources[0]
        
        // Create movies with minor title variations
        let movie1 = Movie(context: context)
        movie1.title = "The Dark Knight"
        movie1.sourceID = source.sourceID
        
        let movie2 = Movie(context: context)
        movie2.title = "The   Dark  Knight" // Extra spaces
        movie2.sourceID = source.sourceID
        
        let movie3 = Movie(context: context)
        movie3.title = "Dark Knight" // Missing "The"
        movie3.sourceID = source.sourceID
        
        try context.save()
        
        let groups = try contentManager.groupMovies(for: profile)
        
        // All three should be grouped together due to title normalization
        let darkKnightGroup = groups.first { group in
            let title = group.primaryItem.title?.lowercased() ?? ""
            return title.contains("dark knight")
        }
        
        XCTAssertNotNil(darkKnightGroup, "Should find Dark Knight group")
        XCTAssertEqual(darkKnightGroup?.itemCount, 3, "Should group all variations")
    }
    
    // MARK: - Series Grouping Tests
    
    func testGroupSeriesInCombinedMode() throws {
        let sources = profile.activeSources
        
        let series1 = Series(context: context)
        series1.title = "Breaking Bad"
        series1.sourceID = sources[0].sourceID
        
        let series2 = Series(context: context)
        series2.title = "Breaking Bad"
        series2.sourceID = sources[1].sourceID
        
        try context.save()
        
        let groups = try contentManager.groupSeries(for: profile)
        
        let breakingBadGroup = groups.first { $0.primaryItem.title == "Breaking Bad" }
        XCTAssertNotNil(breakingBadGroup, "Should find Breaking Bad group")
        XCTAssertEqual(breakingBadGroup?.itemCount, 2, "Should group both series")
    }
    
    func testGroupSeriesWithDifferentTitles() throws {
        let source = profile.activeSources[0]
        
        let series1 = Series(context: context)
        series1.title = "Series A"
        series1.sourceID = source.sourceID
        
        let series2 = Series(context: context)
        series2.title = "Series B"
        series2.sourceID = source.sourceID
        
        try context.save()
        
        let groups = try contentManager.groupSeries(for: profile)
        
        XCTAssertEqual(groups.count, 2, "Should have separate groups for different titles")
    }
    
    // MARK: - Channel Grouping Tests
    
    func testGroupChannelsInCombinedMode() throws {
        let sources = profile.activeSources
        
        let channel1 = Channel(context: context)
        channel1.name = "HBO"
        channel1.sourceID = sources[0].sourceID
        
        let channel2 = Channel(context: context)
        channel2.name = "HBO"
        channel2.sourceID = sources[1].sourceID
        
        try context.save()
        
        let groups = try contentManager.groupChannels(for: profile)
        
        let hboGroup = groups.first { $0.primaryItem.name == "HBO" }
        XCTAssertNotNil(hboGroup, "Should find HBO group")
        XCTAssertEqual(hboGroup?.itemCount, 2, "Should group both channels")
    }
    
    // MARK: - Title Normalization Tests
    
    func testTitleNormalizationRemovesSpecialCharacters() throws {
        let source = profile.activeSources[0]
        
        let movie1 = Movie(context: context)
        movie1.title = "Movie: The Beginning!"
        movie1.sourceID = source.sourceID
        
        let movie2 = Movie(context: context)
        movie2.title = "Movie The Beginning"
        movie2.sourceID = source.sourceID
        
        try context.save()
        
        let groups = try contentManager.groupMovies(for: profile)
        
        // Should normalize to same title
        XCTAssertEqual(groups.count, 1, "Should group movies with normalized titles")
        XCTAssertEqual(groups.first?.itemCount, 2, "Should group both movies")
    }
    
    func testTitleNormalizationRemovesArticles() throws {
        let source = profile.activeSources[0]
        
        let movie1 = Movie(context: context)
        movie1.title = "The Godfather"
        movie1.sourceID = source.sourceID
        
        let movie2 = Movie(context: context)
        movie2.title = "Godfather"
        movie2.sourceID = source.sourceID
        
        try context.save()
        
        let groups = try contentManager.groupMovies(for: profile)
        
        XCTAssertEqual(groups.count, 1, "Should group movies ignoring 'The' prefix")
        XCTAssertEqual(groups.first?.itemCount, 2, "Should group both movies")
    }
    
    func testTitleNormalizationCaseInsensitive() throws {
        let source = profile.activeSources[0]
        
        let movie1 = Movie(context: context)
        movie1.title = "INCEPTION"
        movie1.sourceID = source.sourceID
        
        let movie2 = Movie(context: context)
        movie2.title = "inception"
        movie2.sourceID = source.sourceID
        
        let movie3 = Movie(context: context)
        movie3.title = "Inception"
        movie3.sourceID = source.sourceID
        
        try context.save()
        
        let groups = try contentManager.groupMovies(for: profile)
        
        XCTAssertEqual(groups.count, 1, "Should group movies case-insensitively")
        XCTAssertEqual(groups.first?.itemCount, 3, "Should group all variations")
    }
    
    // MARK: - Source Metadata Tests
    
    func testGetSourceMetadata() {
        let source = profile.activeSources.first!
        
        let metadata = contentManager.getSourceMetadata(for: source.sourceID!, in: profile)
        
        XCTAssertNotNil(metadata, "Should return metadata")
        XCTAssertEqual(metadata?.sourceID, source.sourceID, "Should have correct source ID")
        XCTAssertEqual(metadata?.sourceName, source.name, "Should have correct source name")
        XCTAssertTrue(metadata?.isActive == true, "Should be active")
    }
    
    func testGetSourceMetadataForNonexistentSource() {
        let fakeID = UUID()
        
        let metadata = contentManager.getSourceMetadata(for: fakeID, in: profile)
        
        XCTAssertNil(metadata, "Should return nil for nonexistent source")
    }
    
    func testGetSourceMetadataForGroup() throws {
        let sources = profile.activeSources
        
        let movie1 = Movie(context: context)
        movie1.title = "Test Movie"
        movie1.sourceID = sources[0].sourceID
        
        let movie2 = Movie(context: context)
        movie2.title = "Test Movie"
        movie2.sourceID = sources[1].sourceID
        
        try context.save()
        
        let groups = try contentManager.groupMovies(for: profile)
        guard let group = groups.first else {
            XCTFail("Should have at least one group")
            return
        }
        
        let metadata = contentManager.getSourceMetadata(for: group, in: profile)
        
        XCTAssertEqual(metadata.count, 2, "Should have metadata for both sources")
    }
    
    // MARK: - Quality Assessment Tests
    
    func testAssessQuality4K() {
        let quality = contentManager.assessQuality(streamURL: "http://example.com/stream_4k.m3u8", name: nil)
        XCTAssertEqual(quality, 5, "Should detect 4K quality")
    }
    
    func testAssessQuality2160p() {
        let quality = contentManager.assessQuality(streamURL: "http://example.com/stream_2160p.m3u8", name: nil)
        XCTAssertEqual(quality, 5, "Should detect 2160p as 4K quality")
    }
    
    func testAssessQuality1080p() {
        let quality = contentManager.assessQuality(streamURL: "http://example.com/stream_1080p.m3u8", name: nil)
        XCTAssertEqual(quality, 4, "Should detect 1080p quality")
    }
    
    func testAssessQualityFHD() {
        let quality = contentManager.assessQuality(streamURL: nil, name: "FHD Stream")
        XCTAssertEqual(quality, 4, "Should detect FHD quality")
    }
    
    func testAssessQuality720p() {
        let quality = contentManager.assessQuality(streamURL: "http://example.com/stream_720p.m3u8", name: nil)
        XCTAssertEqual(quality, 3, "Should detect 720p quality")
    }
    
    func testAssessQualityHD() {
        let quality = contentManager.assessQuality(streamURL: nil, name: "HD Channel")
        XCTAssertEqual(quality, 3, "Should detect HD quality")
    }
    
    func testAssessQuality480p() {
        let quality = contentManager.assessQuality(streamURL: "http://example.com/stream_480p.m3u8", name: nil)
        XCTAssertEqual(quality, 2, "Should detect 480p quality")
    }
    
    func testAssessQualitySD() {
        let quality = contentManager.assessQuality(streamURL: nil, name: "SD Stream")
        XCTAssertEqual(quality, 2, "Should detect SD quality")
    }
    
    func testAssessQualityUnknown() {
        let quality = contentManager.assessQuality(streamURL: "http://example.com/stream.m3u8", name: "Unknown")
        XCTAssertEqual(quality, 1, "Should default to low quality")
    }
    
    func testAssessQualityFromBothURLAndName() {
        let quality = contentManager.assessQuality(streamURL: "http://example.com/hd_stream.m3u8", name: "1080p Channel")
        XCTAssertEqual(quality, 4, "Should detect quality from either URL or name")
    }
    
    // MARK: - Best Item Selection Tests
    
    func testSelectBestItemReturnsPrimaryItem() throws {
        let sources = profile.activeSources
        
        let movie1 = Movie(context: context)
        movie1.title = "Test Movie"
        movie1.sourceID = sources[0].sourceID
        
        let movie2 = Movie(context: context)
        movie2.title = "Test Movie"
        movie2.sourceID = sources[1].sourceID
        
        try context.save()
        
        let groups = try contentManager.groupMovies(for: profile)
        guard let group = groups.first else {
            XCTFail("Should have a group")
            return
        }
        
        let bestItem = contentManager.selectBestItem(from: group)
        
        XCTAssertEqual(bestItem.objectID, group.primaryItem.objectID, "Should select primary item")
    }
    
    // MARK: - Empty Data Tests
    
    func testGroupMoviesWithNoMovies() throws {
        let groups = try contentManager.groupMovies(for: profile)
        XCTAssertTrue(groups.isEmpty, "Should return empty array when no movies")
    }
    
    func testGroupSeriesWithNoSeries() throws {
        let groups = try contentManager.groupSeries(for: profile)
        XCTAssertTrue(groups.isEmpty, "Should return empty array when no series")
    }
    
    func testGroupChannelsWithNoChannels() throws {
        let groups = try contentManager.groupChannels(for: profile)
        XCTAssertTrue(groups.isEmpty, "Should return empty array when no channels")
    }
    
    // MARK: - Inactive Source Tests
    
    func testGroupMoviesIgnoresInactiveSources() throws {
        let sources = profile.activeSources
        
        // Deactivate one source
        sources[1].isActive = false
        try context.save()
        
        let movie1 = Movie(context: context)
        movie1.title = "Test Movie"
        movie1.sourceID = sources[0].sourceID
        
        let movie2 = Movie(context: context)
        movie2.title = "Test Movie"
        movie2.sourceID = sources[1].sourceID
        
        try context.save()
        
        let groups = try contentManager.groupMovies(for: profile)
        
        // Should only include movie from active source
        XCTAssertEqual(groups.count, 1, "Should have one group")
        XCTAssertEqual(groups.first?.itemCount, 1, "Should only include movie from active source")
    }
    
    // MARK: - ContentGroup Tests
    
    func testContentGroupAllItems() {
        let movie1 = Movie(context: context)
        movie1.title = "Movie 1"
        
        let movie2 = Movie(context: context)
        movie2.title = "Movie 2"
        
        let group = MultiSourceContentManager.ContentGroup(
            primaryItem: movie1,
            alternativeItems: [movie2],
            sourceIDs: [UUID(), UUID()]
        )
        
        XCTAssertEqual(group.allItems.count, 2, "All items should include primary and alternatives")
        XCTAssertEqual(group.itemCount, 2, "Item count should be correct")
    }
    
    func testContentGroupWithNoAlternatives() {
        let movie = Movie(context: context)
        movie.title = "Movie"
        
        let group = MultiSourceContentManager.ContentGroup(
            primaryItem: movie,
            alternativeItems: [],
            sourceIDs: [UUID()]
        )
        
        XCTAssertEqual(group.itemCount, 1, "Item count should be 1 with no alternatives")
        XCTAssertTrue(group.alternativeItems.isEmpty, "Should have no alternatives")
    }
    
    // MARK: - Large Dataset Tests
    
    func testGroupLargeNumberOfMovies() throws {
        let source = profile.activeSources[0]
        
        // Create 100 movies
        for i in 1...100 {
            let movie = Movie(context: context)
            movie.title = "Movie \(i)"
            movie.sourceID = source.sourceID
        }
        
        try context.save()
        
        let groups = try contentManager.groupMovies(for: profile)
        
        XCTAssertEqual(groups.count, 100, "Should handle large number of movies")
    }
    
    func testGroupMoviesWithManyDuplicates() throws {
        let sources = profile.activeSources
        
        // Create 10 copies of the same movie from different sources
        for _ in 1...5 {
            let movie1 = Movie(context: context)
            movie1.title = "Popular Movie"
            movie1.sourceID = sources[0].sourceID
            
            let movie2 = Movie(context: context)
            movie2.title = "Popular Movie"
            movie2.sourceID = sources[1].sourceID
        }
        
        try context.save()
        
        let groups = try contentManager.groupMovies(for: profile)
        
        XCTAssertEqual(groups.count, 1, "Should group all duplicates")
        XCTAssertEqual(groups.first?.itemCount, 10, "Should have all 10 copies in one group")
    }
}
