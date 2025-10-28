#if os(iOS) || os(tvOS)
import AVKit
import SwiftUI

/// A view that represents a playback view controller.
public struct PlaybackViewController: UIViewControllerRepresentable {

    /// The `AVPlayer` to use for playback.
    public var player: AVPlayer

    @EnvironmentObject var subtitleManager: SubtitleManager
    @EnvironmentObject var audioSubtitleManager: AudioSubtitleManager
    @EnvironmentObject var playbackManager: PlaybackManager
    @EnvironmentObject var settingsManager: SettingsManager

    /// The IMDb ID of the media being played.
    public var imdbID: String?
    /// The channel being played (for EPG overlay)
    public var channel: Channel?
    /// The episode being played (for skip intro functionality)
    public var episode: Episode?

    /// Creates a `CustomPlayerViewController`.
    public func makeUIViewController(context: Context) -> CustomPlayerViewController {
        let controller = CustomPlayerViewController()
        controller.player = player
        controller.subtitleManager = subtitleManager
        controller.audioSubtitleManager = audioSubtitleManager
        controller.playbackManager = playbackManager
        controller.settingsManager = settingsManager
        controller.imdbID = imdbID
        controller.channel = channel
        controller.episode = episode
        return controller
    }

    /// Updates the `CustomPlayerViewController`.
    public func updateUIViewController(_ uiViewController: CustomPlayerViewController, context: Context) {
        uiViewController.player = player
        uiViewController.channel = channel
        uiViewController.episode = episode
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
    /// The episode being played (for skip intro functionality)
    public var episode: Episode?
    /// The intro skipper manager
    private var introSkipperManager: IntroSkipperManager?
    /// The settings manager
    private var settingsManager: SettingsManager?
    /// Time observer for skip intro button
    private var introTimeObserver: Any?
    /// Skip intro button
    private var skipIntroButton: UIButton?

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

        #if os(iOS)
        let pipButton = UIBarButtonItem(
            image: UIImage(systemName: "pip.enter"),
            style: .plain,
            target: self,
            action: #selector(togglePiP)
        )
        
        // Add buttons to the navigation item (include PiP on iOS only)
        if AVPictureInPictureController.isPictureInPictureSupported() {
            parent?.navigationItem.rightBarButtonItems = [subtitleSearchButton, variantSelectorButton, pipButton]
        } else {
            parent?.navigationItem.rightBarButtonItems = [subtitleSearchButton, variantSelectorButton]
        }
        #else
        // tvOS doesn't support PiP
        parent?.navigationItem.rightBarButtonItems = [subtitleSearchButton, variantSelectorButton]
        #endif

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
        
        // Setup skip intro functionality if episode is available
        if let episode = episode {
            setupSkipIntroButton()
            setupIntroTimeObserver()
        }
    }
    
    /// Sets up the skip intro button.
    private func setupSkipIntroButton() {
        let button = UIButton(type: .system)
        button.setTitle("Skip Intro", for: .normal)
        button.titleLabel?.font = UIFont.systemFont(ofSize: 16, weight: .semibold)
        button.backgroundColor = UIColor.systemBlue
        button.setTitleColor(.white, for: .normal)
        button.layer.cornerRadius = 8
        button.layer.masksToBounds = true
        button.contentEdgeInsets = UIEdgeInsets(top: 10, left: 20, bottom: 10, right: 20)
        button.addTarget(self, action: #selector(skipIntro), for: .touchUpInside)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.isHidden = true // Hidden by default
        
        view.addSubview(button)
        NSLayoutConstraint.activate([
            button.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            button.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -100)
        ])
        
        skipIntroButton = button
    }
    
    /// Sets up time observer to show/hide skip intro button.
    private func setupIntroTimeObserver() {
        guard let episode = episode,
              let settingsManager = settingsManager,
              settingsManager.enableSkipIntro else { return }
        
        // Initialize intro skipper manager
        let tvdbAPIKey = settingsManager.tvdbAPIKey
        introSkipperManager = IntroSkipperManager(tvdbAPIKey: tvdbAPIKey)
        
        // Fetch intro timing data
        Task {
            guard let context = episode.managedObjectContext,
                  let timing = await introSkipperManager?.getIntroTiming(for: episode, context: context) else {
                return
            }
            
            // Setup time observer
            await MainActor.run {
                let interval = CMTime(seconds: 1, preferredTimescale: 1)
                introTimeObserver = player?.addPeriodicTimeObserver(forInterval: interval, queue: .main) { [weak self] time in
                    self?.checkIntroTiming(currentTime: time, introTiming: timing)
                }
            }
        }
    }
    
    /// Checks if current time is within intro range and shows/hides button.
    private func checkIntroTiming(currentTime: CMTime, introTiming: IntroSkipperManager.IntroTiming) {
        let currentSeconds = CMTimeGetSeconds(currentTime)
        
        guard let settingsManager = settingsManager else { return }
        
        // Check if we're in the intro range
        if currentSeconds >= introTiming.introStart && currentSeconds <= introTiming.introEnd {
            // Auto-skip if enabled
            if settingsManager.autoSkipIntro {
                skipToTime(introTiming.introEnd)
                return
            }
            
            // Show button if enabled
            if settingsManager.enableSkipIntro {
                skipIntroButton?.isHidden = false
            }
        } else {
            skipIntroButton?.isHidden = true
        }
    }
    
    /// Skips to the end of the intro.
    @objc private func skipIntro() {
        guard let episode = episode else { return }
        
        // Get stored intro timing
        let introEnd = episode.introEndTime
        skipToTime(introEnd)
        
        // Hide button after skipping
        skipIntroButton?.isHidden = true
    }
    
    /// Seeks player to specified time.
    private func skipToTime(_ seconds: Double) {
        let time = CMTime(seconds: seconds, preferredTimescale: 1)
        player?.seek(to: time, toleranceBefore: .zero, toleranceAfter: .zero)
        PerformanceLogger.logPlayback("Skipped to: \(String(format: "%.1f", seconds))s")
    }
    
    deinit {
        // Remove time observer
        if let observer = introTimeObserver {
            player?.removeTimeObserver(observer)
        }
    }

    /// Searches for subtitles.
    @objc private func searchForSubtitles() {
        guard let imdbID = imdbID, let subtitleManager = subtitleManager else {
            ErrorReporter.log(NSError(domain: "Playback", code: 0, userInfo: [NSLocalizedDescriptionKey: "IMDb ID or SubtitleManager not available."]), context: "Playback.searchForSubtitles")
            return
        }

        Task {
            do {
                let subtitles = try await subtitleManager.searchSubtitles(for: imdbID)
                presentSubtitleOptions(subtitles)
            } catch {
                ErrorReporter.log(error, context: "Playback.searchForSubtitles")
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
    
    /// Toggles Picture-in-Picture mode.
    @objc private func togglePiP() {
        #if os(iOS)
        guard let playbackManager = playbackManager else { return }
        
        if playbackManager.isPiPActive {
            playbackManager.stopPiP()
        } else {
            playbackManager.startPiP()
        }
        #endif
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
                ErrorReporter.log(error, context: "Playback.downloadAndApplySubtitle")
                presentError(error)
            }
        }
    }

    /// Presents an error to the user.
    /// - Parameter error: The `Error` to present.
    private func presentError(_ error: Error) {
        ErrorReporter.log(error, context: "Playback.presentError")
        let alert = UIAlertController(title: "Error", message: ErrorReporter.userMessage(for: error), preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
}

#endif
