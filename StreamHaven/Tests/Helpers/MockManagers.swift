import Foundation
import CoreData
import AVKit
import Combine
@testable import StreamHaven

// MARK: - Mock TMDb Manager

/// A mock TMDb manager for testing that doesn't make actual API calls
@MainActor
final class MockTMDbManager: TMDbManaging {
    var fetchedMovies: [Movie] = []
    var shouldFail = false
    
    func fetchIMDbID(for movie: Movie, context: NSManagedObjectContext) async {
        if shouldFail {
            return
        }
        fetchedMovies.append(movie)
        context.performAndWait {
            movie.imdbID = "tt1234567"
            try? context.save()
        }
    }
}

// MARK: - Mock Subtitle Manager

/// A mock subtitle manager for testing that doesn't make actual API calls
@MainActor
final class MockSubtitleManager: SubtitleManaging {
    var searchedIMDbIDs: [String] = []
    var downloadedFileIDs: [Int] = []
    var shouldFail = false
    
    func searchSubtitles(for imdbID: String) async throws -> [Subtitle] {
        if shouldFail {
            throw NSError(domain: "MockSubtitleManager", code: 1, userInfo: nil)
        }
        searchedIMDbIDs.append(imdbID)
        
        let file = SubtitleFile(fileId: 123, fileName: "test.srt")
        let attrs = SubtitleAttributes(language: "en", files: [file])
        return [Subtitle(attributes: attrs)]
    }
    
    func downloadSubtitle(for fileID: Int) async throws -> URL {
        if shouldFail {
            throw NSError(domain: "MockSubtitleManager", code: 2, userInfo: nil)
        }
        downloadedFileIDs.append(fileID)
        return URL(fileURLWithPath: "/tmp/subtitle.srt")
    }
}

// MARK: - Mock Favorites Manager

/// A mock favorites manager for testing
final class MockFavoritesManager: FavoritesManaging {
    var favorites: Set<NSManagedObjectID> = []
    
    func isFavorite(item: NSManagedObject) -> Bool {
        return favorites.contains(item.objectID)
    }
    
    func toggleFavorite(for item: NSManagedObject) {
        if favorites.contains(item.objectID) {
            favorites.remove(item.objectID)
        } else {
            favorites.insert(item.objectID)
        }
    }
}

// MARK: - Mock Watch History Manager

/// A mock watch history manager for testing
final class MockWatchHistoryManager: WatchHistoryManaging {
    var watchHistory: [NSManagedObjectID: (progress: Float, date: Date)] = [:]
    
    func findWatchHistory(for item: NSManagedObject) -> WatchHistory? {
        // Returns nil for mock - real implementation would return Core Data object
        return nil
    }
    
    func updateWatchHistory(for item: NSManagedObject, progress: Float) {
        watchHistory[item.objectID] = (progress, Date())
    }
}

// MARK: - Mock Playback Manager

/// A mock playback manager for testing
final class MockPlaybackManager: PlaybackManaging {
    @Published var player: AVPlayer?
    @Published var isPlaying: Bool = false
    @Published var playbackState: PlaybackManager.PlaybackState = .stopped
    
    var loadedItems: [NSManagedObject] = []
    
    func loadMedia(for item: NSManagedObject, profile: Profile) {
        loadedItems.append(item)
        player = AVPlayer()
        playbackState = .playing
        isPlaying = true
    }
    
    func play() {
        isPlaying = true
        playbackState = .playing
    }
    
    func pause() {
        isPlaying = false
        playbackState = .paused
    }
    
    func seek(to time: CMTime) {
        // No-op for mock
    }
    
    func stop() {
        player = nil
        isPlaying = false
        playbackState = .stopped
    }
}
