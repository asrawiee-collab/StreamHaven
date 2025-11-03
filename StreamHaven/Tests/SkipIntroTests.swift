//
//  SkipIntroTests.swift
//  StreamHaven
//
//  Tests for Skip Intro functionality
//

import AVKit
import CoreData
import XCTest
@testable import StreamHaven

@MainActor
final class SkipIntroTests: XCTestCase {
    var introSkipperManager: IntroSkipperManager!
    var settingsManager: SettingsManager!
    var context: NSManagedObjectContext!
    
    override func setUp() async throws {
        try await super.setUp()
        
        // Create in-memory Core Data context
        let container = NSPersistentContainer(name: "StreamHaven", managedObjectModel: TestCoreDataModelBuilder.sharedModel)
        let description = NSPersistentStoreDescription()
        description.type = NSInMemoryStoreType
        container.persistentStoreDescriptions = [description]
        
        container.loadPersistentStores { _, error in
            XCTAssertNil(error)
        }
        
        context = container.viewContext
        
        // Initialize managers
        settingsManager = SettingsManager()
        introSkipperManager = IntroSkipperManager()
    }
    
    override func tearDown() async throws {
        introSkipperManager = nil
        settingsManager = nil
        context = nil
        try await super.tearDown()
    }
    
    // MARK: - Data Model Tests
    
    func testEpisodeHasIntroTimingProperties() {
        let series = Series(context: context)
        series.title = "Test Series"
        
        let season = Season(context: context)
        season.seasonNumber = 1
        season.series = series
        
        let episode = Episode(context: context)
        episode.title = "Test Episode"
        episode.episodeNumber = 1
        episode.streamURL = "https://example.com/ep1.m3u8"
        episode.season = season
        
        // Verify default values
        XCTAssertEqual(episode.introStartTime, 0, "introStartTime should default to 0")
        XCTAssertEqual(episode.introEndTime, 0, "introEndTime should default to 0")
        XCTAssertEqual(episode.creditStartTime, 0, "creditStartTime should default to 0")
        XCTAssertFalse(episode.hasIntroData, "hasIntroData should default to false")
    }
    
    func testEpisodeCanStoreIntroTiming() {
        let series = Series(context: context)
        series.title = "Test Series"
        
        let season = Season(context: context)
        season.seasonNumber = 1
        season.series = series
        
        let episode = Episode(context: context)
        episode.title = "Test Episode"
        episode.episodeNumber = 1
        episode.streamURL = "https://example.com/ep1.m3u8"
        episode.season = season
        
        // Set intro timing
        episode.introStartTime = 5.0
        episode.introEndTime = 95.0
        episode.creditStartTime = 2100.0
        episode.hasIntroData = true
        
        // Save and verify
        try? context.save()
        
        XCTAssertEqual(episode.introStartTime, 5.0)
        XCTAssertEqual(episode.introEndTime, 95.0)
        XCTAssertEqual(episode.creditStartTime, 2100.0)
        XCTAssertTrue(episode.hasIntroData)
    }
    
    // MARK: - Settings Tests
    
    func testSkipIntroSettingsDefaultValues() {
        XCTAssertTrue(settingsManager.enableSkipIntro, "Skip intro should be enabled by default")
        XCTAssertFalse(settingsManager.autoSkipIntro, "Auto-skip should be disabled by default")
        XCTAssertNil(settingsManager.tvdbAPIKey, "TheTVDB API key should be nil by default")
    }
    
    func testSkipIntroSettingsCanBeChanged() {
        settingsManager.enableSkipIntro = false
        XCTAssertFalse(settingsManager.enableSkipIntro)
        
        settingsManager.autoSkipIntro = true
        XCTAssertTrue(settingsManager.autoSkipIntro)
        
        settingsManager.tvdbAPIKey = "test_api_key"
        XCTAssertEqual(settingsManager.tvdbAPIKey, "test_api_key")
    }
    
    func testSkipIntroSettingsPersistence() {
        // Change settings
        settingsManager.enableSkipIntro = false
        settingsManager.autoSkipIntro = true
        settingsManager.tvdbAPIKey = "test_key"
        
        // Create new instance (simulates app restart)
        let newSettingsManager = SettingsManager()
        
        XCTAssertFalse(newSettingsManager.enableSkipIntro)
        XCTAssertTrue(newSettingsManager.autoSkipIntro)
        XCTAssertEqual(newSettingsManager.tvdbAPIKey, "test_key")
        
        // Reset for other tests
        settingsManager.enableSkipIntro = true
        settingsManager.autoSkipIntro = false
        settingsManager.tvdbAPIKey = nil
    }
    
    // MARK: - IntroSkipperManager Tests
    
    func testIntroSkipperManagerInitialization() {
        let manager = IntroSkipperManager()
        XCTAssertNotNil(manager, "IntroSkipperManager should initialize")
    }
    
    func testIntroSkipperManagerWithAPIKeys() {
        let manager = IntroSkipperManager(
            tvdbAPIKey: "test_tvdb_key", tmdbAPIKey: "test_tmdb_key"
        )
        XCTAssertNotNil(manager, "IntroSkipperManager should initialize with API keys")
    }
    
    func testHeuristicFallback() async {
        let series = Series(context: context)
        series.title = "Unknown Series"
        
        let season = Season(context: context)
        season.seasonNumber = 1
        season.series = series
        
        let episode = Episode(context: context)
        episode.title = "Episode 1"
        episode.episodeNumber = 1
        episode.streamURL = "https://example.com/ep1.m3u8"
        episode.season = season
        
        try? context.save()
        
        // Get intro timing (should use heuristic fallback since no API key)
        let timing = await introSkipperManager.getIntroTiming(for: episode, context: context)
        
        XCTAssertNotNil(timing, "Should return timing data")
        XCTAssertEqual(timing?.introStart, 0, "Heuristic should start at 0")
        XCTAssertEqual(timing?.introEnd, 90, "Heuristic should end at 90 seconds")
        XCTAssertEqual(timing?.source, .heuristic, "Source should be heuristic")
    }
    
    func testCachedIntroTiming() async {
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
        episode.introStartTime = 5.0
        episode.introEndTime = 95.0
        episode.creditStartTime = 2100.0
        episode.hasIntroData = true
        
        try? context.save()
        
        // Get intro timing (should use cached data)
        let timing = await introSkipperManager.getIntroTiming(for: episode, context: context)
        
        XCTAssertNotNil(timing, "Should return cached timing data")
        XCTAssertEqual(timing?.introStart, 5.0)
        XCTAssertEqual(timing?.introEnd, 95.0)
        XCTAssertEqual(timing?.creditStart, 2100.0)
        XCTAssertEqual(timing?.source, .cached, "Source should be cached")
    }
    
    func testManualIntroTimingSetting() async {
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
        
        // Manually set intro timing (e.g., from M3U metadata)
        await introSkipperManager.setIntroTiming(
            introStart: 10.0, introEnd: 80.0, creditStart: 2000.0, for: episode, context: context
        )
        
        // Verify timing was stored
        XCTAssertEqual(episode.introStartTime, 10.0)
        XCTAssertEqual(episode.introEndTime, 80.0)
        XCTAssertEqual(episode.creditStartTime, 2000.0)
        XCTAssertTrue(episode.hasIntroData)
    }
    
    // MARK: - IntroSource Tests
    
    func testIntroSourceTypes() {
        let tvdbSource = IntroSkipperManager.IntroSource.tvdb
        let m3uSource = IntroSkipperManager.IntroSource.m3uMetadata
        let heuristicSource = IntroSkipperManager.IntroSource.heuristic
        let cachedSource = IntroSkipperManager.IntroSource.cached
        
        // Verify all sources exist
        XCTAssertNotNil(tvdbSource)
        XCTAssertNotNil(m3uSource)
        XCTAssertNotNil(heuristicSource)
        XCTAssertNotNil(cachedSource)
    }
    
    // MARK: - Integration Tests
    
    func testIntroTimingWorkflow() async {
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
        
        // First fetch (should use heuristic)
        let timing1 = await introSkipperManager.getIntroTiming(for: episode, context: context)
        XCTAssertEqual(timing1?.source, .heuristic)
        
        // Second fetch (should use cached)
        let timing2 = await introSkipperManager.getIntroTiming(for: episode, context: context)
        XCTAssertEqual(timing2?.source, .cached)
        XCTAssertEqual(timing2?.introStart, timing1?.introStart)
        XCTAssertEqual(timing2?.introEnd, timing1?.introEnd)
    }
    
    func testIntroTimingPersistence() async {
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
        
        // Fetch intro timing
        let timing = await introSkipperManager.getIntroTiming(for: episode, context: context)
        
        // Verify it was saved
        XCTAssertTrue(episode.hasIntroData, "Intro data should be marked as fetched")
        XCTAssertEqual(episode.introStartTime, timing?.introStart ?? -1)
        XCTAssertEqual(episode.introEndTime, timing?.introEnd ?? -1)
    }
    
    func testMultipleEpisodesIndependentTiming() async {
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
        
        // Set different timing for each episode
        await introSkipperManager.setIntroTiming(
            introStart: 5.0, introEnd: 85.0, creditStart: nil, for: episode1, context: context
        )
        
        await introSkipperManager.setIntroTiming(
            introStart: 10.0, introEnd: 95.0, creditStart: 2000.0, for: episode2, context: context
        )
        
        // Verify each episode has its own timing
        XCTAssertEqual(episode1.introStartTime, 5.0)
        XCTAssertEqual(episode1.introEndTime, 85.0)
        XCTAssertEqual(episode1.creditStartTime, 0)
        
        XCTAssertEqual(episode2.introStartTime, 10.0)
        XCTAssertEqual(episode2.introEndTime, 95.0)
        XCTAssertEqual(episode2.creditStartTime, 2000.0)
    }
    
    // MARK: - Edge Case Tests
    
    func testIntroTimingWithZeroValues() async {
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
        
        // Set timing with zero values (no intro)
        await introSkipperManager.setIntroTiming(
            introStart: 0, introEnd: 0, creditStart: nil, for: episode, context: context
        )
        
        XCTAssertTrue(episode.hasIntroData, "Should mark as having data even with zeros")
        XCTAssertEqual(episode.introStartTime, 0)
        XCTAssertEqual(episode.introEndTime, 0)
    }
    
    func testIntroTimingWithoutSeries() async {
        // Episode without series/season (edge case)
        let episode = Episode(context: context)
        episode.title = "Standalone Episode"
        episode.episodeNumber = 1
        episode.streamURL = "https://example.com/ep1.m3u8"
        
        try? context.save()
        
        // Should still return heuristic fallback
        let timing = await introSkipperManager.getIntroTiming(for: episode, context: context)
        
        XCTAssertNotNil(timing, "Should return timing even without series")
        XCTAssertEqual(timing?.source, .heuristic)
    }
}
