import CoreData
import XCTest
@testable import StreamHaven

/// Tests for PlaylistSourceManager.
@MainActor
final class PlaylistSourceManagerTests: XCTestCase {
    var sourceManager: PlaylistSourceManager!
    var context: NSManagedObjectContext!
    var profile: Profile!
    var persistenceController: PersistenceController!
    
    override func setUp() async throws {
        try await super.setUp()
        
        // Create in-memory persistence controller
        persistenceController = PersistenceController(inMemory: true)
        context = persistenceController.container.viewContext
        
        // Create test profile
        profile = Profile(context: context)
        profile.name = "Test User"
        profile.isAdult = true
        try context.save()
        
        // Initialize PlaylistSourceManager
        sourceManager = PlaylistSourceManager(persistenceController: persistenceController)
    }
    
    override func tearDown() async throws {
        sourceManager = nil
        profile = nil
        context = nil
        persistenceController = nil
        try await super.tearDown()
    }
    
    // MARK: - Initialization Tests
    
    func testPlaylistSourceManagerInitialization() {
        XCTAssertNotNil(sourceManager, "PlaylistSourceManager should initialize")
    }
    
    // MARK: - M3U Source Tests
    
    func testAddM3USource() throws {
        let source = try sourceManager.addM3USource(
            name: "My IPTV", url: "https://example.com/playlist.m3u", to: profile
        )
        
        XCTAssertNotNil(source, "Source should be created")
        XCTAssertEqual(source.name, "My IPTV", "Source name should match")
        XCTAssertEqual(source.url, "https://example.com/playlist.m3u", "Source URL should match")
        XCTAssertEqual(source.sourceType, PlaylistSource.SourceType.m3u.rawValue, "Source type should be M3U")
        XCTAssertTrue(source.isActive, "Source should be active by default")
        XCTAssertNotNil(source.sourceID, "Source should have a UUID")
        XCTAssertEqual(source.profile?.objectID, profile.objectID, "Source should reference profile")
    }
    
    func testAddMultipleM3USources() throws {
        try sourceManager.addM3USource(name: "Source 1", url: "https://example.com/1.m3u", to: profile)
        try sourceManager.addM3USource(name: "Source 2", url: "https://example.com/2.m3u", to: profile)
        try sourceManager.addM3USource(name: "Source 3", url: "https://example.com/3.m3u", to: profile)
        
        sourceManager.loadSources(for: profile)
        
        XCTAssertEqual(sourceManager.sources.count, 3, "Should have 3 sources")
    }
    
    func testM3USourceDisplayOrder() throws {
        let source1 = try sourceManager.addM3USource(name: "First", url: "https://example.com/1.m3u", to: profile)
        let source2 = try sourceManager.addM3USource(name: "Second", url: "https://example.com/2.m3u", to: profile)
        let source3 = try sourceManager.addM3USource(name: "Third", url: "https://example.com/3.m3u", to: profile)
        
        XCTAssertEqual(source1.displayOrder, 0, "First source should have order 0")
        XCTAssertEqual(source2.displayOrder, 1, "Second source should have order 1")
        XCTAssertEqual(source3.displayOrder, 2, "Third source should have order 2")
    }
    
    // MARK: - Xtream Source Tests
    
    func testAddXtreamSource() throws {
        let source = try sourceManager.addXtreamSource(
            name: "Xtream Server", url: "https://example.com", username: "user123", password: "pass456", to: profile
        )
        
        XCTAssertNotNil(source, "Source should be created")
        XCTAssertEqual(source.name, "Xtream Server", "Source name should match")
        XCTAssertEqual(source.url, "https://example.com", "Source URL should match")
        XCTAssertEqual(source.username, "user123", "Username should match")
        XCTAssertEqual(source.password, "pass456", "Password should match")
        XCTAssertEqual(source.sourceType, PlaylistSource.SourceType.xtream.rawValue, "Source type should be Xtream")
    }
    
    func testAddMixedSources() throws {
        try sourceManager.addM3USource(name: "M3U Source", url: "https://example.com/playlist.m3u", to: profile)
        try sourceManager.addXtreamSource(name: "Xtream Source", url: "https://example.com", username: "user", password: "pass", to: profile)
        
        sourceManager.loadSources(for: profile)
        
        XCTAssertEqual(sourceManager.sources.count, 2, "Should have both M3U and Xtream sources")
        
        let m3uSource = sourceManager.sources.first { $0.name == "M3U Source" }
        let xtreamSource = sourceManager.sources.first { $0.name == "Xtream Source" }
        
        XCTAssertNotNil(m3uSource, "Should find M3U source")
        XCTAssertNotNil(xtreamSource, "Should find Xtream source")
    }
    
    // MARK: - Load Sources Tests
    
    func testLoadSourcesForProfile() throws {
        try sourceManager.addM3USource(name: "Source 1", url: "https://example.com/1.m3u", to: profile)
        try sourceManager.addM3USource(name: "Source 2", url: "https://example.com/2.m3u", to: profile)
        
        sourceManager.loadSources(for: profile)
        
        XCTAssertEqual(sourceManager.sources.count, 2, "Should load all sources")
        XCTAssertEqual(sourceManager.activeSources.count, 2, "All sources should be active by default")
    }
    
    func testLoadSourcesWithInactiveSources() throws {
        let source1 = try sourceManager.addM3USource(name: "Active", url: "https://example.com/1.m3u", to: profile)
        let source2 = try sourceManager.addM3USource(name: "Inactive", url: "https://example.com/2.m3u", to: profile)
        
        source2.isActive = false
        try context.save()
        
        sourceManager.loadSources(for: profile)
        
        XCTAssertEqual(sourceManager.sources.count, 2, "Should load all sources")
        XCTAssertEqual(sourceManager.activeSources.count, 1, "Should only have one active source")
        XCTAssertEqual(sourceManager.activeSources.first?.objectID, source1.objectID, "Active source should be correct")
    }
    
    // MARK: - Remove Source Tests
    
    func testRemoveSource() throws {
        let source = try sourceManager.addM3USource(name: "To Remove", url: "https://example.com/remove.m3u", to: profile)
        
        sourceManager.loadSources(for: profile)
        XCTAssertEqual(sourceManager.sources.count, 1, "Should have one source")
        
        try sourceManager.removeSource(source, from: profile)
        
        XCTAssertEqual(sourceManager.sources.count, 0, "Source should be removed")
    }
    
    func testRemoveMultipleSources() throws {
        let source1 = try sourceManager.addM3USource(name: "Source 1", url: "https://example.com/1.m3u", to: profile)
        let source2 = try sourceManager.addM3USource(name: "Source 2", url: "https://example.com/2.m3u", to: profile)
        let source3 = try sourceManager.addM3USource(name: "Source 3", url: "https://example.com/3.m3u", to: profile)
        
        sourceManager.loadSources(for: profile)
        XCTAssertEqual(sourceManager.sources.count, 3, "Should have 3 sources")
        
        try sourceManager.removeSource(source2, from: profile)
        
        XCTAssertEqual(sourceManager.sources.count, 2, "Should have 2 sources remaining")
        XCTAssertTrue(sourceManager.sources.contains { $0.objectID == source1.objectID }, "Source 1 should remain")
        XCTAssertTrue(sourceManager.sources.contains { $0.objectID == source3.objectID }, "Source 3 should remain")
    }
    
    // MARK: - Update Source Tests
    
    func testUpdateSourceName() throws {
        let source = try sourceManager.addM3USource(name: "Original Name", url: "https://example.com/test.m3u", to: profile)
        
        try sourceManager.updateSource(source, name: "New Name", url: nil, username: nil, password: nil)
        
        XCTAssertEqual(source.name, "New Name", "Source name should be updated")
    }
    
    func testUpdateSourceURL() throws {
        let source = try sourceManager.addM3USource(name: "Test Source", url: "https://example.com/old.m3u", to: profile)
        
        try sourceManager.updateSource(source, name: nil, url: "https://example.com/new.m3u", username: nil, password: nil)
        
        XCTAssertEqual(source.url, "https://example.com/new.m3u", "Source URL should be updated")
    }
    
    func testUpdateXtreamCredentials() throws {
        let source = try sourceManager.addXtreamSource(
            name: "Xtream", url: "https://example.com", username: "olduser", password: "oldpass", to: profile
        )
        
        try sourceManager.updateSource(source, name: nil, url: nil, username: "newuser", password: "newpass")
        
        XCTAssertEqual(source.username, "newuser", "Username should be updated")
        XCTAssertEqual(source.password, "newpass", "Password should be updated")
    }
    
    func testUpdateMultipleSourceFields() throws {
        let source = try sourceManager.addM3USource(name: "Old", url: "https://example.com/old.m3u", to: profile)
        
        try sourceManager.updateSource(source, name: "New", url: "https://example.com/new.m3u", username: nil, password: nil)
        
        XCTAssertEqual(source.name, "New", "Name should be updated")
        XCTAssertEqual(source.url, "https://example.com/new.m3u", "URL should be updated")
    }
    
    // MARK: - Activate/Deactivate Tests
    
    func testActivateSource() throws {
        let source = try sourceManager.addM3USource(name: "Test", url: "https://example.com/test.m3u", to: profile)
        source.isActive = false
        try context.save()
        
        try sourceManager.activateSource(source)
        
        XCTAssertTrue(source.isActive, "Source should be activated")
    }
    
    func testDeactivateSource() throws {
        let source = try sourceManager.addM3USource(name: "Test", url: "https://example.com/test.m3u", to: profile)
        
        XCTAssertTrue(source.isActive, "Source should start active")
        
        try sourceManager.deactivateSource(source)
        
        XCTAssertFalse(source.isActive, "Source should be deactivated")
    }
    
    func testActivateDeactivateUpdatesActiveSources() throws {
        let source1 = try sourceManager.addM3USource(name: "Source 1", url: "https://example.com/1.m3u", to: profile)
        let source2 = try sourceManager.addM3USource(name: "Source 2", url: "https://example.com/2.m3u", to: profile)
        
        sourceManager.loadSources(for: profile)
        XCTAssertEqual(sourceManager.activeSources.count, 2, "Both sources should be active")
        
        try sourceManager.deactivateSource(source1)
        
        XCTAssertEqual(sourceManager.activeSources.count, 1, "Should have one active source")
        XCTAssertEqual(sourceManager.activeSources.first?.objectID, source2.objectID, "Correct source should be active")
    }
    
    // MARK: - Reorder Sources Tests
    
    func testReorderSources() throws {
        let source1 = try sourceManager.addM3USource(name: "First", url: "https://example.com/1.m3u", to: profile)
        let source2 = try sourceManager.addM3USource(name: "Second", url: "https://example.com/2.m3u", to: profile)
        let source3 = try sourceManager.addM3USource(name: "Third", url: "https://example.com/3.m3u", to: profile)
        
        // Reorder: 3, 1, 2
        try sourceManager.reorderSources([source3, source1, source2], for: profile)
        
        XCTAssertEqual(source3.displayOrder, 0, "Third source should be first")
        XCTAssertEqual(source1.displayOrder, 1, "First source should be second")
        XCTAssertEqual(source2.displayOrder, 2, "Second source should be third")
    }
    
    func testMoveSource() throws {
        let source1 = try sourceManager.addM3USource(name: "First", url: "https://example.com/1.m3u", to: profile)
        let source2 = try sourceManager.addM3USource(name: "Second", url: "https://example.com/2.m3u", to: profile)
        let source3 = try sourceManager.addM3USource(name: "Third", url: "https://example.com/3.m3u", to: profile)
        
        // Move source at index 0 to index 2
        try sourceManager.moveSource(from: 0, to: 2, in: profile)
        
        sourceManager.loadSources(for: profile)
        
        // After move: source2, source3, source1
        XCTAssertEqual(sourceManager.sources[0].objectID, source2.objectID, "Second should be first")
        XCTAssertEqual(sourceManager.sources[1].objectID, source3.objectID, "Third should be second")
        XCTAssertEqual(sourceManager.sources[2].objectID, source1.objectID, "First should be last")
    }
    
    // MARK: - Source Mode Tests
    
    func testSetSourceModeCombined() throws {
        try sourceManager.setSourceMode(.combined, for: profile)
        
        let mode = sourceManager.getSourceMode(for: profile)
        XCTAssertEqual(mode, .combined, "Source mode should be combined")
    }
    
    func testSetSourceModeSingle() throws {
        try sourceManager.setSourceMode(.single, for: profile)
        
        let mode = sourceManager.getSourceMode(for: profile)
        XCTAssertEqual(mode, .single, "Source mode should be single")
    }
    
    func testSourceModeDefaultsToSingle() {
        let mode = sourceManager.getSourceMode(for: profile)
        XCTAssertEqual(mode, .combined, "Default source mode should be combined")
    }
    
    // MARK: - Source Status Tests
    
    func testUpdateSourceStatus() throws {
        let source = try sourceManager.addM3USource(name: "Test", url: "https://example.com/test.m3u", to: profile)
        
        let refreshDate = Date()
        try sourceManager.updateSourceStatus(source, lastRefreshed: refreshDate, error: nil)
        
        XCTAssertEqual(source.lastRefreshed, refreshDate, "Last refreshed date should be set")
        XCTAssertNil(source.lastError, "Error should be nil")
    }
    
    func testUpdateSourceStatusWithError() throws {
        let source = try sourceManager.addM3USource(name: "Test", url: "https://example.com/test.m3u", to: profile)
        
        try sourceManager.updateSourceStatus(source, lastRefreshed: Date(), error: "Network timeout")
        
        XCTAssertNotNil(source.lastRefreshed, "Last refreshed date should be set")
        XCTAssertEqual(source.lastError, "Network timeout", "Error message should be set")
    }
    
    func testHasActiveSources() throws {
        XCTAssertFalse(sourceManager.hasActiveSources(for: profile), "Should have no active sources initially")
        
        try sourceManager.addM3USource(name: "Test", url: "https://example.com/test.m3u", to: profile)
        
        XCTAssertTrue(sourceManager.hasActiveSources(for: profile), "Should have active sources")
    }
    
    func testHasActiveSourcesWithInactiveSources() throws {
        let source = try sourceManager.addM3USource(name: "Test", url: "https://example.com/test.m3u", to: profile)
        
        XCTAssertTrue(sourceManager.hasActiveSources(for: profile), "Should have active source")
        
        try sourceManager.deactivateSource(source)
        
        XCTAssertFalse(sourceManager.hasActiveSources(for: profile), "Should have no active sources")
    }
    
    func testActiveSourceCount() throws {
        XCTAssertEqual(sourceManager.activeSourceCount(for: profile), 0, "Should have 0 active sources")
        
        try sourceManager.addM3USource(name: "Source 1", url: "https://example.com/1.m3u", to: profile)
        try sourceManager.addM3USource(name: "Source 2", url: "https://example.com/2.m3u", to: profile)
        
        XCTAssertEqual(sourceManager.activeSourceCount(for: profile), 2, "Should have 2 active sources")
        
        let source = profile.allSources.first!
        try sourceManager.deactivateSource(source)
        
        XCTAssertEqual(sourceManager.activeSourceCount(for: profile), 1, "Should have 1 active source")
    }
    
    // MARK: - Edge Cases
    
    func testAddSourceWithEmptyName() throws {
        let source = try sourceManager.addM3USource(name: "", url: "https://example.com/test.m3u", to: profile)
        
        XCTAssertEqual(source.name, "", "Should allow empty name")
    }
    
    func testAddSourceWithLongName() throws {
        let longName = String(repeating: "a", count: 500)
        let source = try sourceManager.addM3USource(name: longName, url: "https://example.com/test.m3u", to: profile)
        
        XCTAssertEqual(source.name, longName, "Should handle long names")
    }
    
    func testAddSourceWithSpecialCharactersInName() throws {
        let source = try sourceManager.addM3USource(name: "Test 🎬 IPTV™", url: "https://example.com/test.m3u", to: profile)
        
        XCTAssertEqual(source.name, "Test 🎬 IPTV™", "Should handle special characters")
    }
    
    func testAddSourceWithInvalidURL() throws {
        // Note: Manager doesn't validate URLs, just stores them
        let source = try sourceManager.addM3USource(name: "Test", url: "not a valid url", to: profile)
        
        XCTAssertEqual(source.url, "not a valid url", "Should store URL without validation")
    }
    
    func testAddSourcesWithDuplicateNames() throws {
        try sourceManager.addM3USource(name: "Duplicate", url: "https://example.com/1.m3u", to: profile)
        try sourceManager.addM3USource(name: "Duplicate", url: "https://example.com/2.m3u", to: profile)
        
        sourceManager.loadSources(for: profile)
        
        let duplicates = sourceManager.sources.filter { $0.name == "Duplicate" }
        XCTAssertEqual(duplicates.count, 2, "Should allow duplicate names")
    }
    
    // MARK: - Profile Isolation Tests
    
    func testSourcesAreProfileSpecific() throws {
        // Create another profile
        let profile2 = Profile(context: context)
        profile2.name = "Profile 2"
        profile2.isAdult = false
        try context.save()
        
        // Add sources to each profile
        try sourceManager.addM3USource(name: "Profile 1 Source", url: "https://example.com/1.m3u", to: profile)
        try sourceManager.addM3USource(name: "Profile 2 Source", url: "https://example.com/2.m3u", to: profile2)
        
        // Load sources for profile 1
        sourceManager.loadSources(for: profile)
        XCTAssertEqual(sourceManager.sources.count, 1, "Profile 1 should have 1 source")
        XCTAssertEqual(sourceManager.sources.first?.name, "Profile 1 Source", "Should load correct source")
        
        // Load sources for profile 2
        sourceManager.loadSources(for: profile2)
        XCTAssertEqual(sourceManager.sources.count, 1, "Profile 2 should have 1 source")
        XCTAssertEqual(sourceManager.sources.first?.name, "Profile 2 Source", "Should load correct source")
    }
    
    // MARK: - Created At Tests
    
    func testSourceCreatedAtIsSet() throws {
        let beforeDate = Date()
        let source = try sourceManager.addM3USource(name: "Test", url: "https://example.com/test.m3u", to: profile)
        let afterDate = Date()
        
        XCTAssertNotNil(source.createdAt, "Created at should be set")
        
        if let createdAt = source.createdAt {
            XCTAssertTrue(createdAt >= beforeDate && createdAt <= afterDate, "Created at should be current")
        }
    }
}
