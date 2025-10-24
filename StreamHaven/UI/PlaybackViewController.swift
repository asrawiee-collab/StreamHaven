import SwiftUI
import AVKit

/// A view that represents a playback view controller.
public struct PlaybackViewController: UIViewControllerRepresentable {

    /// The `AVPlayer` to use for playback.
    public var player: AVPlayer

    @EnvironmentObject var subtitleManager: SubtitleManager
    @EnvironmentObject var audioSubtitleManager: AudioSubtitleManager

    /// The IMDb ID of the media being played.
    public var imdbID: String?

    /// Creates a `CustomPlayerViewController`.
    public func makeUIViewController(context: Context) -> CustomPlayerViewController {
        let controller = CustomPlayerViewController()
        controller.player = player
        controller.subtitleManager = subtitleManager
        controller.audioSubtitleManager = audioSubtitleManager
        controller.imdbID = imdbID
        return controller
    }

    /// Updates the `CustomPlayerViewController`.
    public func updateUIViewController(_ uiViewController: CustomPlayerViewController, context: Context) {
        uiViewController.player = player
    }
}

/// A custom `AVPlayerViewController` that adds subtitle search functionality.
public class CustomPlayerViewController: AVPlayerViewController {

    /// The `SubtitleManager` for searching for subtitles.
    public var subtitleManager: SubtitleManager?
    /// The `AudioSubtitleManager` for managing audio and subtitle tracks.
    public var audioSubtitleManager: AudioSubtitleManager?
    /// The IMDb ID of the media being played.
    public var imdbID: String?

    /// Called after the controller's view is loaded into memory.
    public override func viewDidLoad() {
        super.viewDidLoad()

        let subtitleSearchButton = UIBarButtonItem(
            image: UIImage(systemName: "captions.bubble"),
            style: .plain,
            target: self,
            action: #selector(searchForSubtitles)
        )

        // Add the button to the navigation item
        parent?.navigationItem.rightBarButtonItems = [subtitleSearchButton]
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
