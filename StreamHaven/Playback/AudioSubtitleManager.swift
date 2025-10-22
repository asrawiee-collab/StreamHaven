import AVKit

class AudioSubtitleManager {

    private var player: AVPlayer?

    init(player: AVPlayer?) {
        self.player = player
    }

    // MARK: - Audio Tracks

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

    // MARK: - Subtitle Tracks

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
}
