import XCTest
import CoreData
import Combine
@testable import StreamHaven

class PlaybackManagerTests: XCTestCase {

    var persistenceController: PersistenceController!
    var context: NSManagedObjectContext!
    var playbackManager: PlaybackManager!
    private var cancellables: Set<AnyCancellable>!

    @MainActor
    override func setUp() {
        super.setUp()
        persistenceController = PersistenceController(inMemory: true)
        context = persistenceController.container.viewContext
        playbackManager = PlaybackManager(context: context, settingsManager: SettingsManager())
        cancellables = []
    }

    override func tearDown() {
        playbackManager = nil
        context = nil
        persistenceController = nil
        cancellables = nil
        super.tearDown()
    }

    func testLoadMedia_withValidEpisode_shouldCreatePlayer() {
        // Given
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

    func testLoadMedia_withValidMovie_shouldCreatePlayer() {
        // Given
        let profile = Profile(context: context)
        profile.name = "Adult"

        let movie = Movie(context: context)
        movie.streamURL = "https://test-streams.mux.dev/x36xhzz/x36xhzz.m3u8"

        // When
        playbackManager.loadMedia(for: movie, profile: profile)

        // Then
        XCTAssertNotNil(playbackManager.player, "Player should be created for a valid movie item.")
        XCTAssertTrue(playbackManager.isPlaying, "Playback should start automatically for movies.")
    }

    func testPlaybackState_whenPaused_shouldUpdateState() {
        // Given
        let profile = Profile(context: context)
        let episode = Episode(context: context)
        episode.streamURL = "https://test-streams.mux.dev/x36xhzz/x36xhzz.m3u8"
        playbackManager.loadMedia(for: episode, profile: profile)

        let expectation = XCTestExpectation(description: "Playback state updates to paused")

        playbackManager.$playbackState
            .dropFirst()
            .sink { state in
                if case .paused = state {
                    expectation.fulfill()
                }
            }
            .store(in: &cancellables)

        // When
        playbackManager.pause()

        // Then
        wait(for: [expectation], timeout: 5.0)
        XCTAssertFalse(playbackManager.isPlaying, "isPlaying should be false when paused.")
    }

    func testStop_shouldResetPlayback() {
        // Given
        let profile = Profile(context: context)
        let episode = Episode(context: context)
        episode.streamURL = "https://test-streams.mux.dev/x36xhzz/x36xhzz.m3u8"
        playbackManager.loadMedia(for: episode, profile: profile)

        let expectation = XCTestExpectation(description: "Playback state updates to stopped")

        playbackManager.$playbackState
            .dropFirst()
            .sink { state in
                if case .stopped = state {
                    expectation.fulfill()
                }
            }
            .store(in: &cancellables)

        // When
        playbackManager.stop()

        // Then
        wait(for: [expectation], timeout: 5.0)
        XCTAssertNil(playbackManager.player, "Player should be nil after stopping.")
        XCTAssertFalse(playbackManager.isPlaying, "isPlaying should be false after stopping.")
    }
}
