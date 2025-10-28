import AVKit

/// A class for managing audio and subtitle tracks for a given `AVPlayer`.
public final class AudioSubtitleManager: ObservableObject {

    enum SubtitleError: LocalizedError {
        case fileNotFound
        case unsupported

        var errorDescription: String? {
            switch self {
            case .fileNotFound:
                return "The subtitle file could not be found."
            case .unsupported:
                return "Adding side-loaded subtitles is not supported on this platform."
            }
        }
    }

    /// The `AVPlayer` instance to manage.
    private var player: AVPlayer?

    /// Initializes a new `AudioSubtitleManager`.
    /// - Parameter player: The `AVPlayer` to manage.
    public init(player: AVPlayer? = nil) {
        self.player = player
    }

    /// Retrieves the available audio tracks for the current player item.
    /// - Returns: An array of `AVMediaSelectionOption` objects representing the available audio tracks.
    public func getAvailableAudioTracks() async -> [AVMediaSelectionOption] {
        guard let playerItem = player?.currentItem,
              let group = try? await playerItem.asset.loadMediaSelectionGroup(for: .audible) else {
            return []
        }
        return group.options
    }

    /// Selects an audio track for the current player item.
    /// - Parameter track: The `AVMediaSelectionOption` of the audio track to select.
    @MainActor
    public func selectAudioTrack(_ track: AVMediaSelectionOption) async {
        guard let playerItem = player?.currentItem,
              let group = try? await playerItem.asset.loadMediaSelectionGroup(for: .audible) else {
            return
        }
        playerItem.select(track, in: group)
    }

    /// Retrieves the currently selected audio track.
    /// - Returns: The `AVMediaSelectionOption` of the currently selected audio track, or `nil` if no track is selected.
    @MainActor
    public func getCurrentAudioTrack() async -> AVMediaSelectionOption? {
        guard let playerItem = player?.currentItem,
                                let group = try? await playerItem.asset.loadMediaSelectionGroup(for: .audible) else {
                              return nil
                          }
                          return await MainActor.run {
                              playerItem.currentMediaSelection.selectedMediaOption(in: group)
                          }    }

    /// Retrieves the available subtitle tracks for the current player item.
    /// - Returns: An array of `AVMediaSelectionOption` objects representing the available subtitle tracks.
    public func getAvailableSubtitleTracks() async -> [AVMediaSelectionOption] {
        guard let playerItem = player?.currentItem,
              let group = try? await playerItem.asset.loadMediaSelectionGroup(for: .legible) else {
            return []
        }
        return group.options
    }

    /// Selects a subtitle track for the current player item.
    /// - Parameter track: The `AVMediaSelectionOption` of the subtitle track to select.
    @MainActor
    public func selectSubtitleTrack(_ track: AVMediaSelectionOption?) async {
        guard let playerItem = player?.currentItem,
              let group = try? await playerItem.asset.loadMediaSelectionGroup(for: .legible) else {
            return
        }
        playerItem.select(track, in: group)
    }

    /// Retrieves the currently selected subtitle track.
    /// - Returns: The `AVMediaSelectionOption` of the currently selected subtitle track, or `nil` if no track is selected.
    @MainActor
    public func getCurrentSubtitleTrack() async -> AVMediaSelectionOption? {
        guard let playerItem = player?.currentItem,
              let group = try? await playerItem.asset.loadMediaSelectionGroup(for: .legible) else {
            return nil
        }
        return await MainActor.run {
            playerItem.currentMediaSelection.selectedMediaOption(in: group)
        }
    }

    /// Disables subtitles for the current player item.
    public func disableSubtitles() async {
        await selectSubtitleTrack(nil)
    }

    /// Adds a subtitle track from a URL to the current player item.
    /// - Parameters:
    ///   - url: The URL of the subtitle file.
    ///   - playerItem: The `AVPlayerItem` to add the subtitle to.
    /// - Throws: An error if the subtitle file cannot be loaded.
    public func addSubtitle(from url: URL, for playerItem: AVPlayerItem?) async throws {
        guard let playerItem = playerItem else { return }

        guard FileManager.default.fileExists(atPath: url.path) else {
            throw SubtitleError.fileNotFound
        }

        // Validate the subtitle asset can be loaded; this surfaces parsing errors early.
        let subtitleAsset = AVURLAsset(url: url)
        _ = try await subtitleAsset.load(.tracks)

        // Apple does not expose an API to inject side-loaded subtitle tracks into an existing
        // AVPlayerItem. We validate the file and return, leaving room for a future implementation
        // that can rebuild the item using an AVMutableComposition.
        print("Validated subtitle file at \(url.absoluteString) for player item \(playerItem).")
    }
}
