import XCTest
import CoreData
import Combine
@testable import StreamHaven

class PlaybackControllerTests: XCTestCase {

    var persistenceController: PersistenceController!
    var context: NSManagedObjectContext!
    var playbackController: PlaybackController!
    private var cancellables: Set<AnyCancellable>!

    override func setUp() {
        super.setUp()
        persistenceController = PersistenceController(inMemory: true)
        context = persistenceController.container.viewContext
        playbackController = PlaybackController(context: context)
        cancellables = []
    }

    override func tearDown() {
        playbackController = nil
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
        playbackController.loadMedia(for: episode, profile: profile)

        // Then
        XCTAssertNotNil(playbackController.player, "Player should be created for a valid media item.")
        XCTAssertTrue(playbackController.isPlaying, "Playback should start automatically.")
    }

    func testLoadMedia_withValidMovie_shouldCreatePlayer() {
        // Given
        let profile = Profile(context: context)
        profile.name = "Adult"

        let movie = Movie(context: context)
        movie.streamURL = "https://test-streams.mux.dev/x36xhzz/x36xhzz.m3u8"

        // When
        playbackController.loadMedia(for: movie, profile: profile)

        // Then
        XCTAssertNotNil(playbackController.player, "Player should be created for a valid movie item.")
        XCTAssertTrue(playbackController.isPlaying, "Playback should start automatically for movies.")
    }

    func testPlaybackState_whenPaused_shouldUpdateState() {
        // Given
        let profile = Profile(context: context)
        let episode = Episode(context: context)
        episode.streamURL = "https://test-streams.mux.dev/x36xhzz/x36xhzz.m3u8"
        playbackController.loadMedia(for: episode, profile: profile)

        let expectation = XCTestExpectation(description: "Playback state updates to paused")

        playbackController.$playbackState
            .dropFirst() // Ignore the initial state
            .sink { state in
                if case .paused = state {
                    expectation.fulfill()
                }
            }
            .store(in: &cancellables)

        // When
        playbackController.pause()

        // Then
        wait(for: [expectation], timeout: 5.0)
        XCTAssertFalse(playbackController.isPlaying, "isPlaying should be false when paused.")
    }

    func testStop_shouldResetPlayback() {
        // Given
        let profile = Profile(context: context)
        let episode = Episode(context: context)
        episode.streamURL = "https://test-streams.mux.dev/x36xhzz/x36xhzz.m3u8"
        playbackController.loadMedia(for: episode, profile: profile)

        let expectation = XCTestExpectation(description: "Playback state updates to stopped")

        playbackController.$playbackState
            .dropFirst()
            .sink { state in
                if case .stopped = state {
                    expectation.fulfill()
                }
            }
            .store(in: &cancellables)

        // When
        playbackController.stop()

        // Then
        wait(for: [expectation], timeout: 5.0)
        XCTAssertNil(playbackController.player, "Player should be nil after stopping.")
        XCTAssertFalse(playbackController.isPlaying, "isPlaying should be false after stopping.")
    }
}
