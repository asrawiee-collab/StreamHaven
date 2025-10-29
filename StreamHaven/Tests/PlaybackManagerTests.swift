import XCTest
import CoreData
import Combine
@testable import StreamHaven

@MainActor
class PlaybackManagerTests: XCTestCase {

    var persistenceController: PersistenceController?
    var context: NSManagedObjectContext?
    var playbackManager: PlaybackManager?
    var watchHistoryManager: WatchHistoryManager?
    private var cancellables: Set<AnyCancellable>!

    override func setUp() {
        super.setUp()
        persistenceController = PersistenceController(inMemory: true)
        context = persistenceController?.container.viewContext
        
        guard let context = context else {
            XCTFail("Failed to create context")
            return
        }
        
        let profile = Profile(context: context)
        profile.name = "Test Profile"
        do { try context.save() } catch { XCTFail("Save failed: \(error)") }
        
        watchHistoryManager = WatchHistoryManager(context: context, profile: profile)
        if let watchHistoryManager = watchHistoryManager {
            playbackManager = PlaybackManager(context: context, settingsManager: SettingsManager(), watchHistoryManager: watchHistoryManager)
        }
        cancellables = []
    }

    override func tearDown() {
        playbackManager = nil
        context = nil
        persistenceController = nil
        cancellables = nil
        super.tearDown()
    }

    func testLoadMedia_withValidEpisode_shouldCreatePlayer() async {
        // Given
        guard let playbackManager = playbackManager, let context = context else { XCTFail("Missing dependencies"); return }
        let profile = Profile(context: context)
        profile.name = "Adult"

        let episode = Episode(context: context)
        episode.streamURL = "https://test-streams.mux.dev/x36xhzz/x36xhzz.m3u8"

        // When
        playbackManager.loadMedia(for: episode, profile: profile)

        // Then
        XCTAssertNotNil(playbackManager.player, "Player should be created for a valid media item.")
        XCTAssertTrue(playbackManager.isPlaying, "Playback should start automatically.")
    }

    func testLoadMedia_withValidMovie_shouldCreatePlayer() async {
        // Given
        guard let playbackManager2 = playbackManager, let context2 = context else { XCTFail("Missing dependencies"); return }
        let profile = Profile(context: context2)
        profile.name = "Adult"

        let movie = Movie(context: context!)
        movie.streamURL = "https://test-streams.mux.dev/x36xhzz/x36xhzz.m3u8"

        // When
        playbackManager2.loadMedia(for: movie, profile: profile)

        // Then
        XCTAssertNotNil(playbackManager2.player, "Player should be created for a valid movie item.")
        XCTAssertTrue(playbackManager2.isPlaying, "Playback should start automatically for movies.")
    }

    func testPlaybackState_whenPaused_shouldUpdateState() async {
        // Given
        guard let playbackManager3 = playbackManager, let context3 = context else { XCTFail("Missing dependencies"); return }
        let profile = Profile(context: context3)
        let episode = Episode(context: context3)
        episode.streamURL = "https://test-streams.mux.dev/x36xhzz/x36xhzz.m3u8"
        playbackManager3.loadMedia(for: episode, profile: profile)

        let expectation = XCTestExpectation(description: "Playback state updates to paused")

        playbackManager?.$playbackState
            .dropFirst()
            .sink { state in
                if case .paused = state {
                    expectation.fulfill()
                }
            }
            .store(in: &cancellables)

        // When
        playbackManager3.pause()

        // Then
        await fulfillment(of: [expectation], timeout: 5.0)
        XCTAssertFalse(playbackManager3.isPlaying, "isPlaying should be false when paused.")
    }

    func testStop_shouldResetPlayback() async {
        // Given
        guard let playbackManager4 = playbackManager, let context4 = context else { XCTFail("Missing dependencies"); return }
        let profile = Profile(context: context4)
        let episode = Episode(context: context4)
        episode.streamURL = "https://test-streams.mux.dev/x36xhzz/x36xhzz.m3u8"
        playbackManager4.loadMedia(for: episode, profile: profile)

        let expectation = XCTestExpectation(description: "Playback state updates to stopped")

        playbackManager?.$playbackState
            .dropFirst()
            .sink { state in
                if case .stopped = state {
                    expectation.fulfill()
                }
            }
            .store(in: &cancellables)

        // When
        playbackManager4.stop()

        // Then
        await fulfillment(of: [expectation], timeout: 5.0)
        XCTAssertNil(playbackManager4.player, "Player should be nil after stopping.")
        XCTAssertFalse(playbackManager4.isPlaying, "isPlaying should be false after stopping.")
    }
}