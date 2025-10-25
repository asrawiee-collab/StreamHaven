//
//  HoverPreviewTests.swift
//  StreamHaven
//
//  Tests for tvOS hover preview functionality
//

#if os(tvOS)
import XCTest
import CoreData
import AVKit
@testable import StreamHaven

@MainActor
final class HoverPreviewTests: XCTestCase {
    
    var persistenceController: PersistenceController!
    var context: NSManagedObjectContext!
    var settingsManager: SettingsManager!
    var previewManager: HoverPreviewManager!
    
    override func setUp() async throws {
        persistenceController = PersistenceController(inMemory: true)
        context = persistenceController.container.viewContext
        settingsManager = SettingsManager()
        previewManager = HoverPreviewManager(settingsManager: settingsManager)
    }
    
    override func tearDown() {
        previewManager = nil
        settingsManager = nil
        context = nil
        persistenceController = nil
    }
    
    // MARK: - Settings Integration Tests
    
    func testPreviewManagerRespectsEnabledSetting() async {
        // Given: Previews are disabled
        settingsManager.enableHoverPreviews = false
        
        // When: Focus event occurs
        previewManager.onFocus(contentID: "test-content", previewURL: "https://example.com/preview.mp4")
        
        // Wait for potential delay
        try? await Task.sleep(nanoseconds: 100_000_000) // 0.1s
        
        // Then: No preview should start
        XCTAssertNil(previewManager.currentPlayer)
        XCTAssertFalse(previewManager.isPlaying)
        XCTAssertNil(previewManager.currentPreviewURL)
    }
    
    func testPreviewManagerRespectsDelaySetting() async {
        // Given: Custom delay setting
        settingsManager.enableHoverPreviews = true
        settingsManager.hoverPreviewDelay = 0.5
        
        // When: Focus event occurs
        previewManager.onFocus(contentID: "test-content", previewURL: "https://example.com/preview.mp4")
        
        // Then: Preview should not start immediately
        XCTAssertNil(previewManager.currentPlayer)
        
        // Wait for less than the delay
        try? await Task.sleep(nanoseconds: 200_000_000) // 0.2s
        XCTAssertNil(previewManager.currentPlayer, "Preview should not start before delay")
        
        // Wait for the full delay + processing time
        try? await Task.sleep(nanoseconds: 400_000_000) // 0.4s more (0.6s total)
        
        // Then: Preview should have started
        XCTAssertNotNil(previewManager.currentPreviewURL)
        XCTAssertEqual(previewManager.currentPreviewURL, "test-content")
    }
    
    // MARK: - Focus/Blur Handler Tests
    
    func testOnFocusIgnoresEmptyURL() async {
        // Given: Previews enabled
        settingsManager.enableHoverPreviews = true
        
        // When: Focus with empty URL
        previewManager.onFocus(contentID: "test-content", previewURL: "")
        
        // Wait
        try? await Task.sleep(nanoseconds: 200_000_000)
        
        // Then: No preview should start
        XCTAssertNil(previewManager.currentPlayer)
        XCTAssertNil(previewManager.currentPreviewURL)
    }
    
    func testOnFocusIgnoresNilURL() async {
        // Given: Previews enabled
        settingsManager.enableHoverPreviews = true
        
        // When: Focus with nil URL
        previewManager.onFocus(contentID: "test-content", previewURL: nil)
        
        // Wait
        try? await Task.sleep(nanoseconds: 200_000_000)
        
        // Then: No preview should start
        XCTAssertNil(previewManager.currentPlayer)
        XCTAssertNil(previewManager.currentPreviewURL)
    }
    
    func testOnBlurCancelsPendingPreview() async {
        // Given: Previews enabled with delay
        settingsManager.enableHoverPreviews = true
        settingsManager.hoverPreviewDelay = 1.0
        
        // When: Focus then immediate blur
        previewManager.onFocus(contentID: "test-content", previewURL: "https://example.com/preview.mp4")
        try? await Task.sleep(nanoseconds: 100_000_000) // 0.1s
        previewManager.onBlur(contentID: "test-content")
        
        // Wait for original delay
        try? await Task.sleep(nanoseconds: 1_000_000_000) // 1s
        
        // Then: Preview should not have started
        XCTAssertNil(previewManager.currentPlayer)
        XCTAssertNil(previewManager.currentPreviewURL)
    }
    
    func testOnBlurStopsCurrentPreview() async {
        // Given: Active preview
        settingsManager.enableHoverPreviews = true
        settingsManager.hoverPreviewDelay = 0.1
        
        previewManager.onFocus(contentID: "test-content", previewURL: "https://example.com/preview.mp4")
        try? await Task.sleep(nanoseconds: 200_000_000) // Wait for preview to start
        
        // Verify preview started
        let hadPreview = previewManager.currentPreviewURL != nil
        
        // When: Blur event
        previewManager.onBlur(contentID: "test-content")
        
        // Then: Preview should stop
        XCTAssertTrue(hadPreview, "Preview should have started before blur")
        XCTAssertFalse(previewManager.isPlaying)
    }
    
    func testRapidFocusChangeCancelsPrevious() async {
        // Given: Previews enabled
        settingsManager.enableHoverPreviews = true
        settingsManager.hoverPreviewDelay = 0.5
        
        // When: Rapid focus changes
        previewManager.onFocus(contentID: "content-1", previewURL: "https://example.com/preview1.mp4")
        try? await Task.sleep(nanoseconds: 100_000_000) // 0.1s
        previewManager.onFocus(contentID: "content-2", previewURL: "https://example.com/preview2.mp4")
        
        // Wait for second preview delay
        try? await Task.sleep(nanoseconds: 600_000_000) // 0.6s
        
        // Then: Should show second preview, not first
        if let currentID = previewManager.currentPreviewURL {
            XCTAssertEqual(currentID, "content-2")
        }
    }
    
    // MARK: - Core Data Integration Tests
    
    func testFetchMovieVideosStoresPreviewURL() async {
        // Note: This test would require mocking URLSession or using a test TMDb API key
        // For now, we'll test the Core Data storage part
        
        // Given: A movie without preview URL
        let movie = Movie(context: context)
        movie.title = "Test Movie"
        movie.posterURL = "https://example.com/poster.jpg"
        movie.releaseDate = Date()
        movie.summary = "Test summary"
        movie.rating = Rating.g.rawValue
        
        try? context.save()
        
        // When: Manually setting preview URL (simulating TMDb fetch)
        movie.previewURL = "https://youtube.com/watch?v=test123"
        try? context.save()
        
        // Then: Preview URL should be stored
        XCTAssertEqual(movie.previewURL, "https://youtube.com/watch?v=test123")
        
        // Verify persistence
        context.refreshAllObjects()
        XCTAssertEqual(movie.previewURL, "https://youtube.com/watch?v=test123")
    }
    
    func testFetchSeriesVideosStoresPreviewURL() async {
        // Given: A series without preview URL
        let series = Series(context: context)
        series.title = "Test Series"
        series.posterURL = "https://example.com/poster.jpg"
        series.releaseDate = Date()
        series.summary = "Test summary"
        series.rating = Rating.tvPG.rawValue
        
        try? context.save()
        
        // When: Manually setting preview URL (simulating TMDb fetch)
        series.previewURL = "https://youtube.com/watch?v=test456"
        try? context.save()
        
        // Then: Preview URL should be stored
        XCTAssertEqual(series.previewURL, "https://youtube.com/watch?v=test456")
        
        // Verify persistence
        context.refreshAllObjects()
        XCTAssertEqual(series.previewURL, "https://youtube.com/watch?v=test456")
    }
    
    // MARK: - Player Management Tests
    
    func testPlayerCreationWithValidURL() async {
        // Given: Valid preview URL
        settingsManager.enableHoverPreviews = true
        settingsManager.hoverPreviewDelay = 0.1
        
        // When: Focus event
        let validURL = "https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/BigBuckBunny.mp4"
        previewManager.onFocus(contentID: "test-content", previewURL: validURL)
        
        // Wait for delay
        try? await Task.sleep(nanoseconds: 200_000_000)
        
        // Then: Player should be created
        XCTAssertNotNil(previewManager.currentPlayer)
        XCTAssertEqual(previewManager.currentPreviewURL, "test-content")
    }
    
    func testCleanupRemovesPlayers() async {
        // Given: Active preview
        settingsManager.enableHoverPreviews = true
        settingsManager.hoverPreviewDelay = 0.1
        
        previewManager.onFocus(contentID: "test-content", previewURL: "https://example.com/preview.mp4")
        try? await Task.sleep(nanoseconds: 200_000_000)
        
        // When: Cleanup called (happens in deinit, but we can test the effect)
        let hadPlayer = previewManager.currentPlayer != nil
        previewManager.onBlur(contentID: "test-content")
        
        // Then: Player should be cleaned up
        XCTAssertTrue(hadPlayer, "Should have had a player before cleanup")
        XCTAssertFalse(previewManager.isPlaying)
    }
    
    // MARK: - Settings Boundary Tests
    
    func testMinimumDelayValue() async {
        // Given: Minimum delay (0.5s)
        settingsManager.enableHoverPreviews = true
        settingsManager.hoverPreviewDelay = 0.5
        
        // When: Focus event
        previewManager.onFocus(contentID: "test-content", previewURL: "https://example.com/preview.mp4")
        
        // Then: Should respect minimum delay
        try? await Task.sleep(nanoseconds: 400_000_000) // 0.4s
        XCTAssertNil(previewManager.currentPlayer, "Should not start before minimum delay")
        
        try? await Task.sleep(nanoseconds: 200_000_000) // 0.6s total
        XCTAssertNotNil(previewManager.currentPreviewURL)
    }
    
    func testMaximumDelayValue() async {
        // Given: Maximum delay (3.0s)
        settingsManager.enableHoverPreviews = true
        settingsManager.hoverPreviewDelay = 3.0
        
        // When: Focus event
        let startTime = Date()
        previewManager.onFocus(contentID: "test-content", previewURL: "https://example.com/preview.mp4")
        
        // Wait for delay
        try? await Task.sleep(nanoseconds: 3_100_000_000) // 3.1s
        
        let elapsedTime = Date().timeIntervalSince(startTime)
        
        // Then: Should respect maximum delay
        XCTAssertGreaterThanOrEqual(elapsedTime, 3.0)
        XCTAssertNotNil(previewManager.currentPreviewURL)
    }
    
    // MARK: - Edge Case Tests
    
    func testMultipleBlurEventsDoNotCrash() {
        // When: Multiple blur events
        previewManager.onBlur(contentID: "test-1")
        previewManager.onBlur(contentID: "test-2")
        previewManager.onBlur(contentID: "test-3")
        
        // Then: Should not crash (test passes if no crash)
        XCTAssertFalse(previewManager.isPlaying)
    }
    
    func testBlurWithoutFocusDoesNotCrash() {
        // When: Blur without prior focus
        previewManager.onBlur(contentID: "non-existent")
        
        // Then: Should not crash
        XCTAssertNil(previewManager.currentPlayer)
    }
    
    func testFocusWithSpecialCharactersInID() async {
        // Given: Content ID with special characters
        settingsManager.enableHoverPreviews = true
        settingsManager.hoverPreviewDelay = 0.1
        
        let specialID = "test-content-123!@#$%^&*()"
        
        // When: Focus event
        previewManager.onFocus(contentID: specialID, previewURL: "https://example.com/preview.mp4")
        
        try? await Task.sleep(nanoseconds: 200_000_000)
        
        // Then: Should handle special characters
        XCTAssertEqual(previewManager.currentPreviewURL, specialID)
    }
}
#endif
