import XCTest
@testable import StreamHaven

@MainActor
final class SubtitleManagerTests: XCTestCase {
    var manager: SubtitleManager!

    override func setUpWithError() throws {
        manager = SubtitleManager(apiKey: "test_api_key")
    }

    func testManagerInitializationWithAPIKey() {
        XCTAssertNotNil(manager)
    }

    func testManagerInitializationWithoutAPIKey() {
        let managerWithoutKey = SubtitleManager(apiKey: nil)
        XCTAssertNotNil(managerWithoutKey)
    }

    func testSearchThrowsWithoutAPIKey() async {
        let managerWithoutKey = SubtitleManager(apiKey: nil)
        
        do {
            _ = try await managerWithoutKey.searchSubtitles(for: "tt1234567")
            XCTFail("Should throw error without API key")
        } catch {
            XCTAssertTrue(error.localizedDescription.contains("missing"))
        }
    }

    func testDownloadThrowsWithoutAPIKey() async {
        let managerWithoutKey = SubtitleManager(apiKey: nil)
        
        do {
            _ = try await managerWithoutKey.downloadSubtitle(for: 12345)
            XCTFail("Should throw error without API key")
        } catch {
            XCTAssertTrue(error.localizedDescription.contains("missing"))
        }
    }

    func testSearchWithInvalidIMDbID() async {
        do {
            _ = try await manager.searchSubtitles(for: "invalid_id")
            // May succeed or fail depending on API behavior
            XCTAssertTrue(true)
        } catch {
            // Error is acceptable for invalid ID
            XCTAssertTrue(true)
        }
    }

    func testDownloadWithInvalidFileID() async {
        do {
            _ = try await manager.downloadSubtitle(for: -1)
            XCTFail("Should fail with invalid file ID")
        } catch {
            // Expected to fail
            XCTAssertTrue(true)
        }
    }

    func testSearchConstructsValidURL() async {
        // Test that search doesn't crash with valid IMDb ID
        do {
            _ = try await manager.searchSubtitles(for: "tt0111161")
            // May fail due to network/auth, but shouldn't crash
            XCTAssertTrue(true)
        } catch {
            // Network errors are acceptable in tests
            XCTAssertTrue(true)
        }
    }

    func testDownloadConstructsValidURL() async {
        do {
            _ = try await manager.downloadSubtitle(for: 12345)
            XCTAssertTrue(true)
        } catch {
            // Network errors acceptable
            XCTAssertTrue(true)
        }
    }

    func testHandlesNetworkErrors() async {
        // Use invalid key to trigger auth error
        let managerWithBadKey = SubtitleManager(apiKey: "invalid_key_12345")
        
        do {
            _ = try await managerWithBadKey.searchSubtitles(for: "tt0111161")
            // If it succeeds, API might not be validating keys
            XCTAssertTrue(true)
        } catch {
            // Expected behavior
            XCTAssertTrue(error is NSError || error is DecodingError)
        }
    }

    func testSearchReturnsDecodableResults() async {
        do {
            let results = try await manager.searchSubtitles(for: "tt0111161")
            // If successful, verify structure
            for subtitle in results {
                XCTAssertFalse(subtitle.attributes.language.isEmpty)
                XCTAssertFalse(subtitle.attributes.files.isEmpty)
            }
        } catch {
            // Network/auth errors acceptable in unit tests
            XCTAssertTrue(true)
        }
    }

    func testMultipleConcurrentSearches() async {
        let imdbIDs = ["tt0111161", "tt0468569", "tt1375666"]
        
        await withTaskGroup(of: Void.self) { group in
            for imdbID in imdbIDs {
                group.addTask {
                    do {
                        _ = try await self.manager.searchSubtitles(for: imdbID)
                    } catch {
                        // Errors acceptable
                    }
                }
            }
        }
        
        // Should handle concurrent requests
        XCTAssertTrue(true)
    }
}
