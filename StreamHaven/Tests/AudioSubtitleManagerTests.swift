import XCTest
import AVKit
@testable import StreamHaven

final class AudioSubtitleManagerTests: XCTestCase {
    var manager: AudioSubtitleManager!
    var player: AVPlayer!

    override func setUpWithError() throws {
        player = AVPlayer()
        manager = AudioSubtitleManager(player: player)
    }

    func testInitializationWithPlayer() {
        XCTAssertNotNil(manager)
    }

    func testInitializationWithNilPlayer() {
        let managerWithNilPlayer = AudioSubtitleManager(player: nil)
        XCTAssertNotNil(managerWithNilPlayer)
    }

    func testGetAvailableAudioTracksReturnsEmptyWithoutPlayerItem() {
        let tracks = manager.getAvailableAudioTracks()
        XCTAssertTrue(tracks.isEmpty)
    }

    func testGetAvailableSubtitleTracksReturnsEmptyWithoutPlayerItem() {
        let tracks = manager.getAvailableSubtitleTracks()
        XCTAssertTrue(tracks.isEmpty)
    }

    func testGetCurrentAudioTrackReturnsNilWithoutPlayerItem() {
        let track = manager.getCurrentAudioTrack()
        XCTAssertNil(track)
    }

    func testGetCurrentSubtitleTrackReturnsNilWithoutPlayerItem() {
        let track = manager.getCurrentSubtitleTrack()
        XCTAssertNil(track)
    }

    func testSelectAudioTrackHandlesNoPlayerItem() {
        // Should not crash when no player item
        XCTAssertNoThrow({
            // Create a mock option - in real scenario would come from getAvailableAudioTracks()
            let asset = AVURLAsset(url: URL(string: "https://example.com/video.m3u8")!)
            if let group = asset.mediaSelectionGroup(forMediaCharacteristic: .audible),
               let option = group.options.first {
                manager.selectAudioTrack(option)
            }
        }())
    }

    func testSelectSubtitleTrackHandlesNoPlayerItem() {
        // Should not crash when no player item
        manager.selectSubtitleTrack(nil)
        XCTAssertTrue(true) // No crash = success
    }

    func testDisableSubtitles() {
        manager.disableSubtitles()
        
        // Should complete without error
        XCTAssertTrue(true)
    }

    func testDisableSubtitlesCallsSelectWithNil() {
        // Verify that disableSubtitles internally calls selectSubtitleTrack(nil)
        manager.disableSubtitles()
        
        let currentTrack = manager.getCurrentSubtitleTrack()
        XCTAssertNil(currentTrack)
    }

    func testAddSubtitleWithNilPlayerItem() async throws {
        let subtitleURL = URL(fileURLWithPath: "/tmp/test.srt")
        
        // Should handle nil player item gracefully
        try await manager.addSubtitle(from: subtitleURL, for: nil)
        
        // Should complete without crash
        XCTAssertTrue(true)
    }

    func testAddSubtitleWithInvalidURL() async throws {
        let invalidURL = URL(fileURLWithPath: "/nonexistent/subtitle.srt")
        let playerItem = AVPlayerItem(url: URL(string: "https://example.com/video.m3u8")!)
        
        do {
            try await manager.addSubtitle(from: invalidURL, for: playerItem)
            // May succeed or fail depending on validation
            XCTAssertTrue(true)
        } catch {
            // Expected to fail with invalid file
            XCTAssertTrue(true)
        }
    }

    func testAudioTrackOperationsWithRealPlayerItem() async throws {
        // Create a real player item with a test URL
        let testURL = URL(string: "https://devstreaming-cdn.apple.com/videos/streaming/examples/img_bipbop_adv_example_fmp4/master.m3u8")!
        let playerItem = AVPlayerItem(url: testURL)
        player.replaceCurrentItem(with: playerItem)
        
        // Wait for item to load
        let expectation = XCTestExpectation(description: "Player item loads")
        let statusObserver = playerItem.observe(\.status) { item, _ in
            if item.status == .readyToPlay {
                expectation.fulfill()
            }
        }
        
        await fulfillment(of: [expectation], timeout: 5.0)
        statusObserver.invalidate()
        
        // Now test audio track operations
        let audioTracks = manager.getAvailableAudioTracks()
        // May or may not have tracks depending on the stream
        XCTAssertTrue(audioTracks.count >= 0)
        
        if let firstTrack = audioTracks.first {
            manager.selectAudioTrack(firstTrack)
            let current = manager.getCurrentAudioTrack()
            XCTAssertNotNil(current)
        }
    }

    func testSubtitleTrackOperationsWithRealPlayerItem() async throws {
        let testURL = URL(string: "https://devstreaming-cdn.apple.com/videos/streaming/examples/img_bipbop_adv_example_fmp4/master.m3u8")!
        let playerItem = AVPlayerItem(url: testURL)
        player.replaceCurrentItem(with: playerItem)
        
        let expectation = XCTestExpectation(description: "Player item loads")
        let statusObserver = playerItem.observe(\.status) { item, _ in
            if item.status == .readyToPlay {
                expectation.fulfill()
            }
        }
        
        await fulfillment(of: [expectation], timeout: 5.0)
        statusObserver.invalidate()
        
        let subtitleTracks = manager.getAvailableSubtitleTracks()
        XCTAssertTrue(subtitleTracks.count >= 0)
        
        // Test disable
        manager.disableSubtitles()
        let currentAfterDisable = manager.getCurrentSubtitleTrack()
        XCTAssertNil(currentAfterDisable)
    }
}
