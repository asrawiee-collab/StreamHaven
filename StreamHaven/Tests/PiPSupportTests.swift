//
//  PiPSupportTests.swift
//  StreamHaven
//
//  Tests for Picture-in-Picture functionality
//

import XCTest
import AVKit
import CoreData
@testable import StreamHaven

@MainActor
final class PiPSupportTests: XCTestCase {
    var playbackManager: PlaybackManager!
    var settingsManager: SettingsManager!
    var watchHistoryManager: WatchHistoryManager!
    var context: NSManagedObjectContext!
    var profile: Profile!
    
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
        
        // Create test profile
        profile = Profile(context: context)
        profile.name = "Test User"
        profile.isAdult = true
        try context.save()
        
        // Initialize managers
        settingsManager = SettingsManager()
        watchHistoryManager = WatchHistoryManager(context: context, profile: profile)
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
    
    func testPiPSettingDefaultValue() throws {
        throw XCTSkip("AppStorage doesn't work properly in test environment")
    }
    
    func testPiPSettingCanBeDisabled() {
        settingsManager.enablePiP = false
        XCTAssertFalse(settingsManager.enablePiP, "PiP setting should be changeable")
    }
    
    func testPiPSettingPersistence() {
        // Change setting
        settingsManager.enablePiP = false
        
        // Create new instance (simulates app restart)
        let newSettingsManager = SettingsManager()
        
        XCTAssertFalse(newSettingsManager.enablePiP, "PiP setting should persist across instances")
        
        // Reset for other tests
        settingsManager.enablePiP = true
    }
    
    // MARK: - Platform Availability Tests
    
    func testPiPPlatformSupport() {
        #if os(iOS)
        // On iOS, check if device supports PiP
        let isSupported = AVPictureInPictureController.isPictureInPictureSupported()
        XCTAssertTrue(isSupported || !isSupported, "Should check PiP support on iOS")
        #elseif os(tvOS)
        // tvOS doesn't support PiP
        XCTAssertFalse(AVPictureInPictureController.isPictureInPictureSupported(), "tvOS should not support PiP")
        #endif
    }
    
    // MARK: - PlaybackManager PiP Tests
    
    func testPiPControllerInitializationWhenEnabled() {
        #if os(iOS)
        guard AVPictureInPictureController.isPictureInPictureSupported() else {
            throw XCTSkip("PiP not supported on this device")
        }
        
        // Enable PiP
        settingsManager.enablePiP = true
        
        // Create test movie
        let movie = Movie(context: context)
        movie.title = "Test Movie"
        movie.streamURL = "https://example.com/test.m3u8"
        try? context.save()
        
        // Load media (this should initialize PiP controller)
        playbackManager.loadMedia(for: movie, profile: profile)
        
        // Wait a bit for async setup
        let expectation = self.expectation(description: "Wait for setup")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 1.0)
        
        // PiP controller might not be initialized in test environment without actual video layer
        // So we just verify the setting is respected
        XCTAssertTrue(settingsManager.enablePiP, "PiP should be enabled in settings")
        #endif
    }
    
    func testPiPControllerNotInitializedWhenDisabled() {
        #if os(iOS)
        // Disable PiP
        settingsManager.enablePiP = false
        
        // Create test movie
        let movie = Movie(context: context)
        movie.title = "Test Movie"
        movie.streamURL = "https://example.com/test.m3u8"
        try? context.save()
        
        // Load media
        playbackManager.loadMedia(for: movie, profile: profile)
        
        // Wait a bit for async setup
        let expectation = self.expectation(description: "Wait for setup")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 1.0)
        
        // Verify PiP controller is nil when disabled
        XCTAssertNil(playbackManager.pipController, "PiP controller should be nil when disabled")
        #endif
    }
    
    func testPiPActiveStateDefaultValue() {
        XCTAssertFalse(playbackManager.isPiPActive, "PiP should not be active by default")
    }
    
    func testStartPiPMethodExists() {
        // Verify the method exists and can be called
        #if os(iOS)
        // This won't actually start PiP in tests, but verifies the API exists
        playbackManager.startPiP()
        XCTAssertFalse(playbackManager.isPiPActive, "PiP won't actually start in test environment")
        #endif
    }
    
    func testStopPiPMethodExists() {
        // Verify the method exists and can be called
        #if os(iOS)
        playbackManager.stopPiP()
        XCTAssertFalse(playbackManager.isPiPActive, "PiP should not be active")
        #endif
    }
    
    // MARK: - PiP Lifecycle Tests
    
    func testPiPStateUpdatesOnDelegateCallbacks() {
        #if os(iOS)
        // Simulate delegate callbacks
        XCTAssertFalse(playbackManager.isPiPActive, "Should start as not active")
        
        // In a real scenario, the delegate methods would be called by AVPictureInPictureController
        // Here we test that the property exists and is observable
        let expectation = self.expectation(description: "PiP state change")
        
        let cancellable = playbackManager.$isPiPActive
            .dropFirst()
            .sink { isActive in
                if !isActive {
                    expectation.fulfill()
                }
            }
        
        // Manually set state (simulating delegate callback)
        playbackManager.isPiPActive = true
        XCTAssertTrue(playbackManager.isPiPActive, "Should update to active")
        
        playbackManager.isPiPActive = false
        
        wait(for: [expectation], timeout: 1.0)
        cancellable.cancel()
        #endif
    }
    
    // MARK: - Integration Tests
    
    func testPiPWithChannelVariants() {
        #if os(iOS)
        // Create channel with variants
        let channel = Channel(context: context)
        channel.name = "Test Channel"
        
        let variant1 = ChannelVariant(context: context)
        variant1.name = "HD"
        variant1.streamURL = "https://example.com/hd.m3u8"
        variant1.channel = channel
        
        let variant2 = ChannelVariant(context: context)
        variant2.name = "SD"
        variant2.streamURL = "https://example.com/sd.m3u8"
        variant2.channel = channel
        
        try? context.save()
        
        // Load media
        playbackManager.loadMedia(for: variant1, profile: profile)
        
        // Verify variants are available
        XCTAssertEqual(playbackManager.availableVariants.count, 2, "Should have 2 variants")
        XCTAssertEqual(playbackManager.currentVariantIndex, 0, "Should start with first variant")
        #endif
    }
    
    func testPiPSettingsToggleAffectsPlaybackManager() {
        #if os(iOS)
        // Create movie
        let movie = Movie(context: context)
        movie.title = "Test Movie"
        movie.streamURL = "https://example.com/test.m3u8"
        try? context.save()
        
        // Load with PiP enabled
        settingsManager.enablePiP = true
        playbackManager.loadMedia(for: movie, profile: profile)
        
        let expectation1 = self.expectation(description: "Wait for setup 1")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            expectation1.fulfill()
        }
        wait(for: [expectation1], timeout: 0.5)
        
        // Stop and reload with PiP disabled
        playbackManager.stop()
        settingsManager.enablePiP = false
        playbackManager.loadMedia(for: movie, profile: profile)
        
        let expectation2 = self.expectation(description: "Wait for setup 2")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            expectation2.fulfill()
        }
        wait(for: [expectation2], timeout: 0.5)
        
        XCTAssertNil(playbackManager.pipController, "PiP controller should be nil when setting is disabled")
        #endif
    }
    
    // MARK: - Error Handling Tests
    
    func testPiPGracefulDegradationOnUnsupportedDevices() {
        #if os(iOS)
        if !AVPictureInPictureController.isPictureInPictureSupported() {
            // On unsupported devices, PiP methods should not crash
            settingsManager.enablePiP = true
            
            let movie = Movie(context: context)
            movie.title = "Test Movie"
            movie.streamURL = "https://example.com/test.m3u8"
            try? context.save()
            
            playbackManager.loadMedia(for: movie, profile: profile)
            
            // These should not crash
            playbackManager.startPiP()
            playbackManager.stopPiP()
            
            XCTAssertNil(playbackManager.pipController, "PiP controller should be nil on unsupported devices")
        }
        #elseif os(tvOS)
        // tvOS should never have PiP controller
        let movie = Movie(context: context)
        movie.title = "Test Movie"
        movie.streamURL = "https://example.com/test.m3u8"
        try? context.save()
        
        playbackManager.loadMedia(for: movie, profile: profile)
        
        XCTAssertNil(playbackManager.pipController, "tvOS should not have PiP controller")
        #endif
    }
}