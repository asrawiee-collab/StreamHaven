import SwiftUI
import AVKit

struct PlaybackViewController: UIViewControllerRepresentable {

    var player: AVPlayer

    @EnvironmentObject var subtitleManager: SubtitleManager
    @EnvironmentObject var audioSubtitleManager: AudioSubtitleManager

    var imdbID: String?

    func makeUIViewController(context: Context) -> CustomPlayerViewController {
        let controller = CustomPlayerViewController()
        controller.player = player
        controller.subtitleManager = subtitleManager
        controller.audioSubtitleManager = audioSubtitleManager
        controller.imdbID = imdbID
        return controller
    }

    func updateUIViewController(_ uiViewController: CustomPlayerViewController, context: Context) {
        uiViewController.player = player
    }
}

class CustomPlayerViewController: AVPlayerViewController {

    var subtitleManager: SubtitleManager?
    var audioSubtitleManager: AudioSubtitleManager?
    var imdbID: String?

    override func viewDidLoad() {
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

    private func presentError(_ error: Error) {
        let alert = UIAlertController(title: "Error", message: error.localizedDescription, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
}
