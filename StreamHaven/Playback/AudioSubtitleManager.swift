import AVKit

/// A class for managing audio and subtitle tracks for a given `AVPlayer`.
public class AudioSubtitleManager {

    /// The `AVPlayer` instance to manage.
    private var player: AVPlayer?

    /// Initializes a new `AudioSubtitleManager`.
    /// - Parameter player: The `AVPlayer` to manage.
    public init(player: AVPlayer?) {
        self.player = player
    }

    /// Retrieves the available audio tracks for the current player item.
    /// - Returns: An array of `AVMediaSelectionOption` objects representing the available audio tracks.
    public func getAvailableAudioTracks() -> [AVMediaSelectionOption] {
        guard let playerItem = player?.currentItem,
              let group = playerItem.asset.mediaSelectionGroup(forMediaCharacteristic: .audible) else {
            return []
        }
        return group.options
    }

    /// Selects an audio track for the current player item.
    /// - Parameter track: The `AVMediaSelectionOption` of the audio track to select.
    public func selectAudioTrack(_ track: AVMediaSelectionOption) {
        guard let playerItem = player?.currentItem,
              let group = playerItem.asset.mediaSelectionGroup(forMediaCharacteristic: .audible) else {
            return
        }
        playerItem.select(track, in: group)
    }

    /// Retrieves the currently selected audio track.
    /// - Returns: The `AVMediaSelectionOption` of the currently selected audio track, or `nil` if no track is selected.
    public func getCurrentAudioTrack() -> AVMediaSelectionOption? {
        guard let playerItem = player?.currentItem,
              let group = playerItem.asset.mediaSelectionGroup(forMediaCharacteristic: .audible) else {
            return nil
        }
        return playerItem.selectedMediaOption(in: group)
    }

    /// Retrieves the available subtitle tracks for the current player item.
    /// - Returns: An array of `AVMediaSelectionOption` objects representing the available subtitle tracks.
    public func getAvailableSubtitleTracks() -> [AVMediaSelectionOption] {
        guard let playerItem = player?.currentItem,
              let group = playerItem.asset.mediaSelectionGroup(forMediaCharacteristic: .legible) else {
            return []
        }
        return group.options
    }

    /// Selects a subtitle track for the current player item.
    /// - Parameter track: The `AVMediaSelectionOption` of the subtitle track to select.
    public func selectSubtitleTrack(_ track: AVMediaSelectionOption?) {
        guard let playerItem = player?.currentItem,
              let group = playerItem.asset.mediaSelectionGroup(forMediaCharacteristic: .legible) else {
            return
        }
        playerItem.select(track, in: group)
    }

    /// Retrieves the currently selected subtitle track.
    /// - Returns: The `AVMediaSelectionOption` of the currently selected subtitle track, or `nil` if no track is selected.
    public func getCurrentSubtitleTrack() -> AVMediaSelectionOption? {
        guard let playerItem = player?.currentItem,
              let group = playerItem.asset.mediaSelectionGroup(forMediaCharacteristic: .legible) else {
            return nil
        }
        return playerItem.selectedMediaOption(in: group)
    }

    /// Disables subtitles for the current player item.
    public func disableSubtitles() {
        selectSubtitleTrack(nil)
    }

    /// Adds a subtitle track from a URL to the current player item.
    /// - Parameters:
    ///   - url: The URL of the subtitle file.
    ///   - playerItem: The `AVPlayerItem` to add the subtitle to.
    /// - Throws: An error if the subtitle file cannot be loaded.
    public func addSubtitle(from url: URL, for playerItem: AVPlayerItem?) async throws {
        guard let playerItem = playerItem else { return }

        let subtitleAsset = AVURLAsset(url: url)
        let subtitleTracks = try await subtitleAsset.load(.tracks)

        guard let subtitleTrack = subtitleTracks.first else {
            print("No tracks found in subtitle file.")
            return
        }

        let newSubtitleOption = AVMediaSelectionOption(for: [subtitleTrack], commonMetadata: [], hasMediaCharacteristic: .legible, locale: subtitleTrack.locale)

        if let legibleGroup = playerItem.asset.mediaSelectionGroup(forMediaCharacteristic: .legible) {
            let allOptions = legibleGroup.options + [newSubtitleOption]
            let newGroup = AVMediaSelectionGroup.mediaSelectionOptions(from: allOptions, with: legibleGroup.locale)

            // We need to create a mutable copy of the item's selection to modify it
            if let currentSelection = playerItem.currentMediaSelection {
                let newSelection = currentSelection.mutableCopy() as! AVMutableMediaSelection
                newSelection.select(newSubtitleOption, in: newGroup)
                playerItem.select(newSelection, in: newGroup)
            }

        } else {
            // If no legible group exists, we can't add our subtitle.
            // This is a limitation of AVFoundation's side-loading.
            print("No existing legible media selection group found.")
        }
    }
}
