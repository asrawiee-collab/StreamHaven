import AVKit
import CoreData
import Combine

class PlaybackController: ObservableObject {

    @Published var player: AVPlayer?
    @Published var isPlaying: Bool = false
    @Published var playbackState: PlaybackState = .stopped

    enum PlaybackState {
        case playing
        case paused
        case buffering
        case stopped
        case failed(Error)
    }

    private var currentItem: NSManagedObject?
    private var currentProfile: Profile?
    private var context: NSManagedObjectContext

    private var cancellables = Set<AnyCancellable>()

    init(context: NSManagedObjectContext) {
        self.context = context
    }

    func loadMedia(for item: NSManagedObject, profile: Profile) {
        guard let streamURLString = getStreamURL(for: item),
              let streamURL = URL(string: streamURLString) else {
            self.playbackState = .failed(NSError(domain: "PlaybackController", code: 1, userInfo: [NSLocalizedDescriptionKey: "Invalid stream URL"]))
            return
        }

        self.currentItem = item
        self.currentProfile = profile

        let playerItem = AVPlayerItem(url: streamURL)
        self.player = AVPlayer(playerItem: playerItem)

        setupPlayerObservers()

        if let history = findWatchHistory(for: item, profile: profile) {
            let resumeTime = CMTime(seconds: Double(history.progress), preferredTimescale: 1)
            player?.seek(to: resumeTime)
        }

        play()
    }

    private func getStreamURL(for item: NSManagedObject) -> String? {
        if let movie = item as? Movie {
            return movie.streamURL
        } else if let episode = item as? Episode {
            return episode.streamURL
        } else if let variant = item as? ChannelVariant {
            return variant.streamURL
        }
        return nil
    }

    func play() {
        player?.play()
        isPlaying = true
        playbackState = .playing
    }

    func pause() {
        player?.pause()
        isPlaying = false
        playbackState = .paused
    }

    func seek(to time: CMTime) {
        player?.seek(to: time)
    }

    func stop() {
        player?.pause()
        player = nil
        currentItem = nil
        currentProfile = nil
        isPlaying = false
        playbackState = .stopped
        cancellables.removeAll()
    }

    private func findWatchHistory(for item: NSManagedObject, profile: Profile) -> WatchHistory? {
        let request: NSFetchRequest<WatchHistory> = WatchHistory.fetchRequest()

        var predicates: [NSPredicate] = [NSPredicate(format: "profile == %@", profile)]

        if let movie = item as? Movie {
            predicates.append(NSPredicate(format: "movie == %@", movie))
        } else if let episode = item as? Episode {
            predicates.append(NSPredicate(format: "episode == %@", episode))
        } else {
            return nil
        }

        request.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: predicates)

        do {
            return try context.fetch(request).first
        } catch {
            print("Failed to fetch watch history: \\(error)")
            return nil
        }
    }

    private func setupPlayerObservers() {
        guard let player = player else { return }

        player.publisher(for: \\.timeControlStatus)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] status in
                switch status {
                case .playing:
                    self?.isPlaying = true
                    self?.playbackState = .playing
                case .paused:
                    self?.isPlaying = false
                    self?.playbackState = .paused
                case .waitingToPlayAtSpecifiedRate:
                    self?.playbackState = .buffering
                @unknown default:
                    break
                }
            }
            .store(in: &cancellables)
    }
}
