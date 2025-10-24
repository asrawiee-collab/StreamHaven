import AVKit

class AudioSubtitleManager {

    private var player: AVPlayer?

    init(player: AVPlayer?) {
        self.player = player
    }

    func getAvailableAudioTracks() -> [AVMediaSelectionOption] {
        guard let playerItem = player?.currentItem,
              let group = playerItem.asset.mediaSelectionGroup(forMediaCharacteristic: .audible) else {
            return []
        }
        return group.options
    }

    func selectAudioTrack(_ track: AVMediaSelectionOption) {
        guard let playerItem = player?.currentItem,
              let group = playerItem.asset.mediaSelectionGroup(forMediaCharacteristic: .audible) else {
            return
        }
        playerItem.select(track, in: group)
    }

    func getCurrentAudioTrack() -> AVMediaSelectionOption? {
        guard let playerItem = player?.currentItem,
              let group = playerItem.asset.mediaSelectionGroup(forMediaCharacteristic: .audible) else {
            return nil
        }
        return playerItem.selectedMediaOption(in: group)
    }

    func getAvailableSubtitleTracks() -> [AVMediaSelectionOption] {
        guard let playerItem = player?.currentItem,
              let group = playerItem.asset.mediaSelectionGroup(forMediaCharacteristic: .legible) else {
            return []
        }
        return group.options
    }

    func selectSubtitleTrack(_ track: AVMediaSelectionOption?) {
        guard let playerItem = player?.currentItem,
              let group = playerItem.asset.mediaSelectionGroup(forMediaCharacteristic: .legible) else {
            return
        }
        playerItem.select(track, in: group)
    }

    func getCurrentSubtitleTrack() -> AVMediaSelectionOption? {
        guard let playerItem = player?.currentItem,
              let group = playerItem.asset.mediaSelectionGroup(forMediaCharacteristic: .legible) else {
            return nil
        }
        return playerItem.selectedMediaOption(in: group)
    }

    func disableSubtitles() {
        selectSubtitleTrack(nil)
    }

    func addSubtitle(from url: URL, for playerItem: AVPlayerItem?) async throws {
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
