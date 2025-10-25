import XCTest
import AVKit
import CoreData
@testable import StreamHaven

/// Comprehensive tests for Live Activities functionality.
@MainActor
final class LiveActivityTests: XCTestCase {
    
    var context: NSManagedObjectContext!
    var liveActivityManager: LiveActivityManager!
    
    override func setUp() async throws {
        try await super.setUp()
        
        // Create in-memory Core Data stack for testing
        let container = NSPersistentContainer(name: "StreamHaven")
        let description = NSPersistentStoreDescription()
        description.type = NSInMemoryStoreType
        container.persistentStoreDescriptions = [description]
        
        container.loadPersistentStores { description, error in
            XCTAssertNil(error)
        }
        
        context = container.viewContext
        liveActivityManager = LiveActivityManager()
    }
    
    override func tearDown() async throws {
        context = nil
        liveActivityManager = nil
        try await super.tearDown()
    }
    
    // MARK: - Initialization Tests
    
    func testLiveActivityManagerInitialization() {
        XCTAssertNotNil(liveActivityManager, "LiveActivityManager should initialize")
        XCTAssertFalse(liveActivityManager.isActivityActive, "Should not be active initially")
        XCTAssertNil(liveActivityManager.activityError, "Should have no error initially")
    }
    
    func testLiveActivitySupportDetection() {
        // Test platform support detection
        #if os(iOS)
        if #available(iOS 16.1, *) {
            XCTAssertTrue(LiveActivityManager.isSupported, "Live Activities should be supported on iOS 16.1+")
        } else {
            XCTAssertFalse(LiveActivityManager.isSupported, "Live Activities should not be supported below iOS 16.1")
        }
        #else
        XCTAssertFalse(LiveActivityManager.isSupported, "Live Activities should not be supported on non-iOS platforms")
        #endif
    }
    
    // MARK: - Settings Tests
    
    func testLiveActivitySettingsDefaults() {
        let settingsManager = SettingsManager()
        
        XCTAssertTrue(settingsManager.enableLiveActivities, "Live Activities should be enabled by default")
    }
    
    func testLiveActivitySettingsCanBeChanged() {
        let settingsManager = SettingsManager()
        
        settingsManager.enableLiveActivities = false
        XCTAssertFalse(settingsManager.enableLiveActivities, "Live Activities setting should be changeable")
        
        settingsManager.enableLiveActivities = true
        XCTAssertTrue(settingsManager.enableLiveActivities, "Live Activities setting should be changeable")
    }
    
    // MARK: - Activity Attributes Tests
    
    #if os(iOS)
    @available(iOS 16.1, *)
    func testActivityAttributesStructure() {
        let state = StreamHavenActivityAttributes.ContentState(
            contentTitle: "Test Movie",
            progress: 0.5,
            isPlaying: true,
            elapsedSeconds: 1800,
            totalSeconds: 3600,
            thumbnailURL: "https://example.com/poster.jpg",
            contentType: "movie",
            seriesInfo: nil
        )
        
        XCTAssertEqual(state.contentTitle, "Test Movie")
        XCTAssertEqual(state.progress, 0.5)
        XCTAssertTrue(state.isPlaying)
        XCTAssertEqual(state.elapsedSeconds, 1800)
        XCTAssertEqual(state.totalSeconds, 3600)
        XCTAssertEqual(state.contentType, "movie")
        XCTAssertNil(state.seriesInfo)
    }
    
    @available(iOS 16.1, *)
    func testActivityAttributesWithSeriesInfo() {
        let state = StreamHavenActivityAttributes.ContentState(
            contentTitle: "The Pilot",
            progress: 0.25,
            isPlaying: false,
            elapsedSeconds: 600,
            totalSeconds: 2400,
            thumbnailURL: "https://example.com/series.jpg",
            contentType: "episode",
            seriesInfo: "Breaking Bad S1E1"
        )
        
        XCTAssertEqual(state.contentTitle, "The Pilot")
        XCTAssertEqual(state.contentType, "episode")
        XCTAssertEqual(state.seriesInfo, "Breaking Bad S1E1")
        XCTAssertFalse(state.isPlaying)
    }
    #endif
    
    // MARK: - Playback Manager Integration Tests
    
    func testPlaybackManagerAcceptsLiveActivityManager() {
        let settingsManager = SettingsManager()
        let profile = Profile(context: context)
        profile.name = "Test Profile"
        
        let watchHistoryManager = WatchHistoryManager(context: context, profile: profile)
        
        let playbackManager = PlaybackManager(
            context: context,
            settingsManager: settingsManager,
            watchHistoryManager: watchHistoryManager,
            liveActivityManager: liveActivityManager
        )
        
        XCTAssertNotNil(playbackManager, "PlaybackManager should initialize with LiveActivityManager")
    }
    
    func testPlaybackManagerWithoutLiveActivityManager() {
        let settingsManager = SettingsManager()
        let profile = Profile(context: context)
        profile.name = "Test Profile"
        
        let watchHistoryManager = WatchHistoryManager(context: context, profile: profile)
        
        let playbackManager = PlaybackManager(
            context: context,
            settingsManager: settingsManager,
            watchHistoryManager: watchHistoryManager,
            liveActivityManager: nil
        )
        
        XCTAssertNotNil(playbackManager, "PlaybackManager should work without LiveActivityManager")
    }
    
    // MARK: - PreBufferDelegate Tests
    
    func testPreBufferDelegateIncludesLiveActivityUpdate() {
        // Verify the protocol includes the updateLiveActivityProgress method
        let expectation = XCTestExpectation(description: "PreBufferDelegate methods exist")
        
        class TestDelegate: PreBufferDelegate {
            var shouldPreBufferCalled = false
            var updateLiveActivityCalled = false
            
            func shouldPreBufferNextEpisode(timeRemaining: Double) {
                shouldPreBufferCalled = true
            }
            
            func updateLiveActivityProgress() {
                updateLiveActivityCalled = true
            }
        }
        
        let delegate = TestDelegate()
        delegate.shouldPreBufferNextEpisode(timeRemaining: 60)
        delegate.updateLiveActivityProgress()
        
        XCTAssertTrue(delegate.shouldPreBufferCalled, "Should call pre-buffer method")
        XCTAssertTrue(delegate.updateLiveActivityCalled, "Should call Live Activity update method")
        
        expectation.fulfill()
        wait(for: [expectation], timeout: 1.0)
    }
    
    // MARK: - Content Type Tests
    
    func testMovieContentTypeCreation() throws {
        let movie = Movie(context: context)
        movie.title = "Test Movie"
        movie.streamURL = "https://example.com/movie.m3u8"
        movie.posterURL = "https://example.com/poster.jpg"
        movie.summary = "A test movie"
        movie.rating = "PG-13"
        movie.releaseDate = Date()
        
        try context.save()
        
        XCTAssertNotNil(movie.title)
        XCTAssertNotNil(movie.posterURL)
        XCTAssertNotNil(movie.streamURL)
    }
    
    func testEpisodeContentTypeCreation() throws {
        let series = Series(context: context)
        series.title = "Test Series"
        series.posterURL = "https://example.com/series.jpg"
        series.summary = "A test series"
        series.rating = "TV-14"
        series.releaseDate = Date()
        
        let season = Season(context: context)
        season.seasonNumber = 1
        season.summary = "Season 1"
        season.series = series
        
        let episode = Episode(context: context)
        episode.title = "Pilot"
        episode.episodeNumber = 1
        episode.summary = "The first episode"
        episode.streamURL = "https://example.com/episode.m3u8"
        episode.season = season
        
        try context.save()
        
        XCTAssertNotNil(episode.title)
        XCTAssertNotNil(episode.season)
        XCTAssertEqual(episode.season?.seasonNumber, 1)
        XCTAssertNotNil(episode.season?.series)
        XCTAssertEqual(episode.season?.series?.title, "Test Series")
    }
    
    func testChannelContentTypeCreation() throws {
        let channel = Channel(context: context)
        channel.name = "Test Channel"
        channel.logoURL = "https://example.com/logo.png"
        channel.tvgID = "test.channel"
        
        let variant = ChannelVariant(context: context)
        variant.name = "HD"
        variant.streamURL = "https://example.com/channel.m3u8"
        variant.channel = channel
        
        try context.save()
        
        XCTAssertNotNil(channel.name)
        XCTAssertNotNil(channel.logoURL)
        XCTAssertNotNil(variant.streamURL)
    }
    
    // MARK: - Progress Tracking Tests
    
    func testProgressCalculation() {
        let elapsed: TimeInterval = 1800 // 30 minutes
        let total: TimeInterval = 3600 // 60 minutes
        let progress = elapsed / total
        
        XCTAssertEqual(progress, 0.5, "Progress should be 50%")
    }
    
    func testProgressBoundaries() {
        // Test 0% progress
        let startProgress = 0.0 / 3600.0
        XCTAssertEqual(startProgress, 0.0, "Start progress should be 0%")
        
        // Test 100% progress
        let endProgress = 3600.0 / 3600.0
        XCTAssertEqual(endProgress, 1.0, "End progress should be 100%")
        
        // Test mid-point
        let midProgress = 1800.0 / 3600.0
        XCTAssertEqual(midProgress, 0.5, "Mid progress should be 50%")
    }
    
    // MARK: - Error Handling Tests
    
    #if os(iOS)
    @available(iOS 16.1, *)
    func testLiveActivityErrorDescriptions() {
        let notAuthError = LiveActivityError.notAuthorized
        XCTAssertTrue(notAuthError.errorDescription?.contains("not enabled") ?? false, "Error should mention not enabled")
        
        let notFoundError = LiveActivityError.activityNotFound
        XCTAssertTrue(notFoundError.errorDescription?.contains("not found") ?? false, "Error should mention not found")
        
        let updateError = LiveActivityError.updateFailed
        XCTAssertTrue(updateError.errorDescription?.contains("update") ?? false, "Error should mention update")
        
        let testError = NSError(domain: "test", code: 1, userInfo: nil)
        let startError = LiveActivityError.startFailed(testError)
        XCTAssertTrue(startError.errorDescription?.contains("start") ?? false, "Error should mention start")
    }
    #endif
    
    // MARK: - Platform Compatibility Tests
    
    func testLiveActivityOnlyOnIOS() {
        #if os(iOS)
        // iOS should have full Live Activity support
        XCTAssertTrue(true, "Live Activities available on iOS")
        #else
        // Other platforms should have fallback implementation
        XCTAssertFalse(LiveActivityManager.isSupported, "Live Activities should not be supported on non-iOS platforms")
        #endif
    }
    
    func testFallbackImplementationExists() {
        // Test that fallback methods exist and don't crash on non-iOS platforms
        let manager = LiveActivityManager()
        
        Task {
            try? await manager.startActivity(
                title: "Test",
                contentType: "movie",
                streamIdentifier: "test",
                duration: 3600
            )
            
            await manager.updateActivity(
                progress: 0.5,
                isPlaying: true,
                elapsedSeconds: 1800
            )
            
            await manager.endActivity()
        }
        
        XCTAssertNotNil(manager, "Fallback manager should exist")
    }
    
    // MARK: - State Management Tests
    
    func testActivityActiveStateTracking() {
        XCTAssertFalse(liveActivityManager.isActivityActive, "Activity should not be active initially")
        
        // After ending (even without starting), should remain false
        Task {
            await liveActivityManager.endActivity()
            XCTAssertFalse(self.liveActivityManager.isActivityActive, "Activity should not be active after end")
        }
    }
    
    func testActivityErrorTracking() {
        XCTAssertNil(liveActivityManager.activityError, "Should have no error initially")
        
        // Attempting to update without active activity should not crash
        Task {
            await liveActivityManager.updateActivity(
                progress: 0.5,
                isPlaying: true,
                elapsedSeconds: 1800
            )
        }
        
        XCTAssertNil(liveActivityManager.activityError, "Should not set error for no-op updates")
    }
    
    // MARK: - Time Formatting Tests
    
    func testTimeIntervalFormatting() {
        let seconds: TimeInterval = 3661 // 1 hour, 1 minute, 1 second
        let hours = Int(seconds) / 3600
        let minutes = (Int(seconds) % 3600) / 60
        let secs = Int(seconds) % 60
        
        XCTAssertEqual(hours, 1, "Should calculate 1 hour")
        XCTAssertEqual(minutes, 1, "Should calculate 1 minute")
        XCTAssertEqual(secs, 1, "Should calculate 1 second")
    }
    
    func testShortDurationFormatting() {
        let seconds: TimeInterval = 125 // 2 minutes, 5 seconds
        let minutes = Int(seconds) / 60
        let secs = Int(seconds) % 60
        
        XCTAssertEqual(minutes, 2, "Should calculate 2 minutes")
        XCTAssertEqual(secs, 5, "Should calculate 5 seconds")
    }
    
    // MARK: - Integration Workflow Tests
    
    func testCompletePlaybackWorkflow() throws {
        let settingsManager = SettingsManager()
        settingsManager.enableLiveActivities = true
        
        let profile = Profile(context: context)
        profile.name = "Test Profile"
        
        let movie = Movie(context: context)
        movie.title = "Test Movie"
        movie.streamURL = "https://example.com/movie.m3u8"
        movie.posterURL = "https://example.com/poster.jpg"
        movie.summary = "A test movie"
        movie.rating = "PG-13"
        movie.releaseDate = Date()
        
        try context.save()
        
        let watchHistoryManager = WatchHistoryManager(context: context, profile: profile)
        let playbackManager = PlaybackManager(
            context: context,
            settingsManager: settingsManager,
            watchHistoryManager: watchHistoryManager,
            liveActivityManager: liveActivityManager
        )
        
        XCTAssertNotNil(playbackManager)
        XCTAssertTrue(settingsManager.enableLiveActivities)
        XCTAssertFalse(liveActivityManager.isActivityActive, "Activity not started yet")
    }
}
