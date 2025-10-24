import SwiftUI
import AVKit

/// A view that represents a playback view controller.
public struct PlaybackViewController: UIViewControllerRepresentable {

    /// The `AVPlayer` to use for playback.
    public var player: AVPlayer

    @EnvironmentObject var subtitleManager: SubtitleManager
    @EnvironmentObject var audioSubtitleManager: AudioSubtitleManager
    @EnvironmentObject var playbackManager: PlaybackManager

    /// The IMDb ID of the media being played.
    public var imdbID: String?
    /// The channel being played (for EPG overlay)
    public var channel: Channel?

    /// Creates a `CustomPlayerViewController`.
    public func makeUIViewController(context: Context) -> CustomPlayerViewController {
        let controller = CustomPlayerViewController()
        controller.player = player
        controller.subtitleManager = subtitleManager
        controller.audioSubtitleManager = audioSubtitleManager
        controller.playbackManager = playbackManager
        controller.imdbID = imdbID
        controller.channel = channel
        return controller
    }

    /// Updates the `CustomPlayerViewController`.
    public func updateUIViewController(_ uiViewController: CustomPlayerViewController, context: Context) {
        uiViewController.player = player
        uiViewController.channel = channel
    }
}

/// A custom `AVPlayerViewController` that adds subtitle search functionality.
public class CustomPlayerViewController: AVPlayerViewController {

    /// The `SubtitleManager` for searching for subtitles.
    public var subtitleManager: SubtitleManager?
    /// The `AudioSubtitleManager` for managing audio and subtitle tracks.
    public var audioSubtitleManager: AudioSubtitleManager?
    /// The `PlaybackManager` for managing playback.
    public var playbackManager: PlaybackManager?
    /// The IMDb ID of the media being played.
    public var imdbID: String?
    /// The channel being played (for EPG overlay)
    public var channel: Channel?

    /// Called after the controller's view is loaded into memory.
    public override func viewDidLoad() {
        super.viewDidLoad()

        let subtitleSearchButton = UIBarButtonItem(
            image: UIImage(systemName: "captions.bubble"),
            style: .plain,
            target: self,
            action: #selector(searchForSubtitles)
        )

        let variantSelectorButton = UIBarButtonItem(
            image: UIImage(systemName: "tv.and.hifispeaker.fill"),
            style: .plain,
            target: self,
            action: #selector(selectVariant)
        )

        // Add the button to the navigation item
        parent?.navigationItem.rightBarButtonItems = [subtitleSearchButton, variantSelectorButton]

        // Add Now/Next EPG overlay if channel is available
        if let channel = channel, let epgEntries = channel.epgEntries as? Set<EPGEntry> {
            let now = Date()
            let nowEntry = epgEntries.first(where: { ($0.startTime ?? .distantPast) <= now && ($0.endTime ?? .distantFuture) > now })
            let nextEntry = epgEntries.filter { ($0.startTime ?? .distantPast) > now }.sorted { ($0.startTime ?? .distantPast) < ($1.startTime ?? .distantPast) }.first
            if let nowEntry = nowEntry {
                let epgLabel = UILabel()
                epgLabel.text = "Now: \(nowEntry.title ?? "")"
                epgLabel.font = UIFont.systemFont(ofSize: 14, weight: .semibold)
                epgLabel.textColor = .white
                epgLabel.backgroundColor = UIColor.black.withAlphaComponent(0.7)
                epgLabel.layer.cornerRadius = 6
                epgLabel.layer.masksToBounds = true
                epgLabel.translatesAutoresizingMaskIntoConstraints = false
                view.addSubview(epgLabel)
                NSLayoutConstraint.activate([
                    epgLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
                    epgLabel.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -60)
                ])
                if let nextEntry = nextEntry {
                    let nextLabel = UILabel()
                    nextLabel.text = "Next: \(nextEntry.title ?? "")"
                    nextLabel.font = UIFont.systemFont(ofSize: 13)
                    nextLabel.textColor = .white
                    nextLabel.backgroundColor = UIColor.black.withAlphaComponent(0.5)
                    nextLabel.layer.cornerRadius = 6
                    nextLabel.layer.masksToBounds = true
                    nextLabel.translatesAutoresizingMaskIntoConstraints = false
                    view.addSubview(nextLabel)
                    NSLayoutConstraint.activate([
                        nextLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
                        nextLabel.bottomAnchor.constraint(equalTo: epgLabel.topAnchor, constant: -4)
                    ])
                }
            }
        }
    }

    /// Searches for subtitles.
    @objc private func searchForSubtitles() {
        guard let imdbID = imdbID, let subtitleManager = subtitleManager else {
            print("IMDb ID or SubtitleManager not available.")
            return
        }

        Task {
            do {
                let subtitles = try await subtitleManager.searchSubtitles(for: imdbID)
                presentSubtitleOptions(subtitles)
            } catch {
                presentError(error)
            }
        }
    }

    @objc private func selectVariant() {
        guard let playbackManager = playbackManager else { return }

        let alert = UIAlertController(title: "Select Stream", message: nil, preferredStyle: .actionSheet)

        for (index, variant) in playbackManager.availableVariants.enumerated() {
            let action = UIAlertAction(title: variant.name, style: .default) { [weak self] _ in
                self?.playbackManager?.currentVariantIndex = index
                self?.playbackManager?.loadCurrentVariant()
            }
            alert.addAction(action)
        }

        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        present(alert, animated: true)
    }

    /// Presents a list of subtitle options to the user.
    /// - Parameter subtitles: An array of `Subtitle` objects.
    private func presentSubtitleOptions(_ subtitles: [Subtitle]) {
        let alert = UIAlertController(title: "Select Subtitle", message: nil, preferredStyle: .actionSheet)

        for subtitle in subtitles {
            let action = UIAlertAction(title: subtitle.attributes.language, style: .default) { [weak self] _ in
                self?.downloadAndApplySubtitle(subtitle)
            }
            alert.addAction(action)
        }

        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        present(alert, animated: true)
    }

    /// Downloads and applies a subtitle.
    /// - Parameter subtitle: The `Subtitle` to download and apply.
    private func downloadAndApplySubtitle(_ subtitle: Subtitle) {
        guard let fileID = subtitle.attributes.files.first?.fileId,
              let subtitleManager = subtitleManager,
              let audioSubtitleManager = audioSubtitleManager else {
            return
        }

        Task {
            do {
                let localURL = try await subtitleManager.downloadSubtitle(for: fileID)
                try await audioSubtitleManager.addSubtitle(from: localURL, for: player?.currentItem)
            } catch {
                presentError(error)
            }
        }
    }

    /// Presents an error to the user.
    /// - Parameter error: The `Error` to present.
    private func presentError(_ error: Error) {
        let alert = UIAlertController(title: "Error", message: error.localizedDescription, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
}
