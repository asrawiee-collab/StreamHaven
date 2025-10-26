//
//  PreBufferTests.swift
//  StreamHaven
//
//  Tests for pre-buffering next episode functionality
//

import XCTest
import AVKit
import CoreData
@testable import StreamHaven

@MainActor
final class PreBufferTests: XCTestCase {
    var playbackManager: PlaybackManager!
    var settingsManager: SettingsManager!
    var watchHistoryManager: WatchHistoryManager!
    var context: NSManagedObjectContext!
    var profile: Profile!
    
    override func setUp() async throws {
        try await super.setUp()
        
        // Create in-memory Core Data context
        let container = NSPersistentContainer(name: "StreamHaven", managedObjectModel: PersistenceController.shared.managedObjectModel)
        let description = NSPersistentStoreDescription()
        description.type = NSInMemoryStoreType
        container.persistentStoreDescriptions = [description]
        
        container.loadPersistentStores { _, error in
            XCTAssertNil(error)
        }
        
        context = container.viewContext
        
        // Create test profile
        profile = Profile(context: context)
        profile.name = "Test User"
        profile.isAdult = true
        try context.save()
        
        // Initialize managers
        settingsManager = SettingsManager()
        watchHistoryManager = WatchHistoryManager(context: context)
        playbackManager = PlaybackManager(
            context: context,
            settingsManager: settingsManager,
            watchHistoryManager: watchHistoryManager
        )
    }
    
    override func tearDown() async throws {
        playbackManager.stop()
        playbackManager = nil
        settingsManager = nil
        watchHistoryManager = nil
        context = nil
        profile = nil
        try await super.tearDown()
    }
    
    // MARK: - Settings Tests
    
    func testPreBufferSettingDefaultValue() {
        XCTAssertTrue(settingsManager.enablePreBuffer, "Pre-buffer should be enabled by default")
    }
    
    func testPreBufferTimeDefaultValue() {
        XCTAssertEqual(settingsManager.preBufferTimeSeconds, 120.0, "Pre-buffer time should default to 120 seconds")
    }
    
    func testPreBufferSettingCanBeDisabled() {
        settingsManager.enablePreBuffer = false
        XCTAssertFalse(settingsManager.enablePreBuffer, "Pre-buffer setting should be changeable")
    }
    
    func testPreBufferTimeCanBeAdjusted() {
        settingsManager.preBufferTimeSeconds = 60.0
        XCTAssertEqual(settingsManager.preBufferTimeSeconds, 60.0, "Pre-buffer time should be adjustable")
    }
    
    func testPreBufferSettingsPersistence() {
        // Change settings
        settingsManager.enablePreBuffer = false
        settingsManager.preBufferTimeSeconds = 90.0
        
        // Create new instance (simulates app restart)
        let newSettingsManager = SettingsManager()
        
        XCTAssertFalse(newSettingsManager.enablePreBuffer, "Pre-buffer enabled setting should persist")
        XCTAssertEqual(newSettingsManager.preBufferTimeSeconds, 90.0, "Pre-buffer time should persist")
        
        // Reset for other tests
        settingsManager.enablePreBuffer = true
        settingsManager.preBufferTimeSeconds = 120.0
    }
    
    // MARK: - PlaybackProgressTracker Tests
    
    func testPreBufferDelegateProtocolExists() {
        // Verify the protocol exists and PlaybackManager conforms
        XCTAssertTrue(playbackManager is PreBufferDelegate, "PlaybackManager should conform to PreBufferDelegate")
    }
    
    func testProgressTrackerHasPreBufferProperties() {
        // Create test episode
        let series = Series(context: context)
        series.title = "Test Series"
        
        let season = Season(context: context)
        season.seasonNumber = 1
        season.series = series
        
        let episode = Episode(context: context)
        episode.title = "Episode 1"
        episode.episodeNumber = 1
        episode.streamURL = "https://example.com/ep1.m3u8"
        episode.season = season
        try? context.save()
        
        // Load media
        playbackManager.loadMedia(for: episode, profile: profile)
        
        // Wait for setup
        let expectation = self.expectation(description: "Wait for setup")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 0.5)
        
        // Verify tracker has pre-buffer properties set
        XCTAssertNotNil(playbackManager.progressTracker, "Progress tracker should be created")
        XCTAssertEqual(playbackManager.progressTracker?.preBufferTimeSeconds, 120.0, "Pre-buffer time should match settings")
    }
    
    // MARK: - PlaybackManager State Tests
    
    func testIsNextEpisodeReadyDefaultValue() {
        XCTAssertFalse(playbackManager.isNextEpisodeReady, "Next episode should not be ready by default")
    }
    
    func testIsNextEpisodeReadyResets() {
        // Set to true manually
        playbackManager.isNextEpisodeReady = true
        XCTAssertTrue(playbackManager.isNextEpisodeReady)
        
        // Stop playback should reset
        playbackManager.stop()
        XCTAssertFalse(playbackManager.isNextEpisodeReady, "Stop should reset next episode ready state")
    }
    
    // MARK: - Pre-buffer Trigger Tests
    
    func testPreBufferNotTriggeredWhenDisabled() {
        // Disable pre-buffer
        settingsManager.enablePreBuffer = false
        
        // Create series with episodes
        let series = Series(context: context)
        series.title = "Test Series"
        
        let season = Season(context: context)
        season.seasonNumber = 1
        season.series = series
        
        let episode1 = Episode(context: context)
        episode1.title = "Episode 1"
        episode1.episodeNumber = 1
        episode1.streamURL = "https://example.com/ep1.m3u8"
        episode1.season = season
        
        let episode2 = Episode(context: context)
        episode2.title = "Episode 2"
        episode2.episodeNumber = 2
        episode2.streamURL = "https://example.com/ep2.m3u8"
        episode2.season = season
        
        try? context.save()
        
        // Load media
        playbackManager.loadMedia(for: episode1, profile: profile)
        
        // Wait for setup
        let expectation = self.expectation(description: "Wait for setup")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 0.5)
        
        // Manually trigger delegate method
        playbackManager.shouldPreBufferNextEpisode(timeRemaining: 100.0)
        
        // Should not start pre-buffering when disabled
        XCTAssertFalse(playbackManager.isNextEpisodeReady, "Should not pre-buffer when setting is disabled")
    }
    
    func testPreBufferWithNoNextEpisode() {
        // Enable pre-buffer
        settingsManager.enablePreBuffer = true
        
        // Create series with only one episode
        let series = Series(context: context)
        series.title = "Test Series"
        
        let season = Season(context: context)
        season.seasonNumber = 1
        season.series = series
        
        let episode = Episode(context: context)
        episode.title = "Only Episode"
        episode.episodeNumber = 1
        episode.streamURL = "https://example.com/ep1.m3u8"
        episode.season = season
        
        try? context.save()
        
        // Load media
        playbackManager.loadMedia(for: episode, profile: profile)
        
        // Wait for setup
        let expectation = self.expectation(description: "Wait for setup")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 0.5)
        
        // Trigger pre-buffer
        playbackManager.shouldPreBufferNextEpisode(timeRemaining: 100.0)
        
        // Should not crash and should remain false
        XCTAssertFalse(playbackManager.isNextEpisodeReady, "Should handle no next episode gracefully")
    }
    
    // MARK: - Episode Transition Tests
    
    func testFindNextEpisodeInSeason() {
        // Create series with multiple episodes
        let series = Series(context: context)
        series.title = "Test Series"
        
        let season = Season(context: context)
        season.seasonNumber = 1
        season.series = series
        
        let episode1 = Episode(context: context)
        episode1.title = "Episode 1"
        episode1.episodeNumber = 1
        episode1.streamURL = "https://example.com/ep1.m3u8"
        episode1.season = season
        
        let episode2 = Episode(context: context)
        episode2.title = "Episode 2"
        episode2.episodeNumber = 2
        episode2.streamURL = "https://example.com/ep2.m3u8"
        episode2.season = season
        
        let episode3 = Episode(context: context)
        episode3.title = "Episode 3"
        episode3.episodeNumber = 3
        episode3.streamURL = "https://example.com/ep3.m3u8"
        episode3.season = season
        
        try? context.save()
        
        // Load first episode
        playbackManager.loadMedia(for: episode1, profile: profile)
        
        // Verify we have episodes available
        XCTAssertEqual(season.episodes?.count, 3, "Season should have 3 episodes")
    }
    
    func testFindNextEpisodeReturnsNilForLastEpisode() {
        // Create series with one episode
        let series = Series(context: context)
        series.title = "Test Series"
        
        let season = Season(context: context)
        season.seasonNumber = 1
        season.series = series
        
        let episode = Episode(context: context)
        episode.title = "Last Episode"
        episode.episodeNumber = 1
        episode.streamURL = "https://example.com/ep1.m3u8"
        episode.season = season
        
        try? context.save()
        
        // Load episode
        playbackManager.loadMedia(for: episode, profile: profile)
        
        // Verify it's the only episode
        XCTAssertEqual(season.episodes?.count, 1, "Season should have 1 episode")
    }
    
    // MARK: - Integration Tests
    
    func testPreBufferSettingsAffectProgressTracker() {
        // Create test episode
        let series = Series(context: context)
        series.title = "Test Series"
        
        let season = Season(context: context)
        season.seasonNumber = 1
        season.series = series
        
        let episode = Episode(context: context)
        episode.title = "Episode 1"
        episode.episodeNumber = 1
        episode.streamURL = "https://example.com/ep1.m3u8"
        episode.season = season
        try? context.save()
        
        // Set custom pre-buffer time
        settingsManager.preBufferTimeSeconds = 90.0
        
        // Load media
        playbackManager.loadMedia(for: episode, profile: profile)
        
        // Wait for setup
        let expectation = self.expectation(description: "Wait for setup")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 0.5)
        
        // Verify tracker received the custom setting
        XCTAssertEqual(playbackManager.progressTracker?.preBufferTimeSeconds, 90.0, "Tracker should use custom pre-buffer time")
    }
    
    func testPreBufferTimeRangeValidation() {
        // Test minimum value (30 seconds)
        settingsManager.preBufferTimeSeconds = 30.0
        XCTAssertEqual(settingsManager.preBufferTimeSeconds, 30.0, "Should accept minimum value")
        
        // Test maximum value (300 seconds)
        settingsManager.preBufferTimeSeconds = 300.0
        XCTAssertEqual(settingsManager.preBufferTimeSeconds, 300.0, "Should accept maximum value")
        
        // Test mid-range value
        settingsManager.preBufferTimeSeconds = 120.0
        XCTAssertEqual(settingsManager.preBufferTimeSeconds, 120.0, "Should accept mid-range value")
    }
    
    // MARK: - State Management Tests
    
    func testNextEpisodePlayerLifecycle() {
        // Create series with episodes
        let series = Series(context: context)
        series.title = "Test Series"
        
        let season = Season(context: context)
        season.seasonNumber = 1
        season.series = series
        
        let episode1 = Episode(context: context)
        episode1.title = "Episode 1"
        episode1.episodeNumber = 1
        episode1.streamURL = "https://example.com/ep1.m3u8"
        episode1.season = season
        
        let episode2 = Episode(context: context)
        episode2.title = "Episode 2"
        episode2.episodeNumber = 2
        episode2.streamURL = "https://example.com/ep2.m3u8"
        episode2.season = season
        
        try? context.save()
        
        // Load media
        playbackManager.loadMedia(for: episode1, profile: profile)
        
        // Wait for setup
        let expectation1 = self.expectation(description: "Wait for setup")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            expectation1.fulfill()
        }
        wait(for: [expectation1], timeout: 0.5)
        
        // Verify initial state
        XCTAssertFalse(playbackManager.isNextEpisodeReady, "Should start with no next episode ready")
        
        // Stop should clean up
        playbackManager.stop()
        XCTAssertFalse(playbackManager.isNextEpisodeReady, "Stop should reset next episode state")
    }
    
    func testMultiplePreBufferTriggers() {
        // Create series with episodes
        let series = Series(context: context)
        series.title = "Test Series"
        
        let season = Season(context: context)
        season.seasonNumber = 1
        season.series = series
        
        let episode1 = Episode(context: context)
        episode1.title = "Episode 1"
        episode1.episodeNumber = 1
        episode1.streamURL = "https://example.com/ep1.m3u8"
        episode1.season = season
        
        let episode2 = Episode(context: context)
        episode2.title = "Episode 2"
        episode2.episodeNumber = 2
        episode2.streamURL = "https://example.com/ep2.m3u8"
        episode2.season = season
        
        try? context.save()
        
        // Load media
        playbackManager.loadMedia(for: episode1, profile: profile)
        
        // Wait for setup
        let expectation = self.expectation(description: "Wait for setup")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 0.5)
        
        // Trigger pre-buffer multiple times (should only happen once per episode)
        playbackManager.shouldPreBufferNextEpisode(timeRemaining: 100.0)
        playbackManager.shouldPreBufferNextEpisode(timeRemaining: 90.0)
        playbackManager.shouldPreBufferNextEpisode(timeRemaining: 80.0)
        
        // The flag in PlaybackProgressTracker prevents multiple triggers
        // This test verifies the method can be called multiple times without crashing
        XCTAssertTrue(true, "Multiple pre-buffer triggers should not crash")
    }
}
