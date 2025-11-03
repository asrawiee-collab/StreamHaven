import AVKit
import Combine
import CoreData
import Foundation

// MARK: - TMDb Protocol

/// Protocol for managing TMDb API interactions.
@MainActor
public protocol TMDbManaging {
    /// Fetches the IMDb ID for a movie from the TMDb API and saves it to the Core Data object.
    ///
    /// - Parameters:
    ///   - movie: The `Movie` object to fetch the IMDb ID for.
    ///   - context: The `NSManagedObjectContext` to perform the save on.
    func fetchIMDbID(for movie: Movie, context: NSManagedObjectContext) async
}

// MARK: - Subtitle Protocol

/// Protocol for managing subtitle interactions.
@MainActor
public protocol SubtitleManaging {
    /// Searches for subtitles for a given IMDb ID.
    ///
    /// - Parameter imdbID: The IMDb ID of the movie or series to search for.
    /// - Returns: An array of `Subtitle` objects.
    /// - Throws: An error if the search fails.
    func searchSubtitles(for imdbID: String) async throws -> [Subtitle]
    
    /// Downloads a subtitle file.
    ///
    /// - Parameter fileID: The ID of the file to download.
    /// - Returns: The local URL of the downloaded subtitle file.
    /// - Throws: An error if the download fails.
    func downloadSubtitle(for fileID: Int) async throws -> URL
}

// MARK: - Favorites Protocol

/// Protocol for managing user favorites.
public protocol FavoritesManaging {
    /// Checks if an item is a favorite.
    ///
    /// - Parameter item: The `NSManagedObject` to check (e.g., `Movie`, `Series`, `Channel`).
    /// - Returns: `true` if the item is a favorite, `false` otherwise.
    func isFavorite(item: NSManagedObject) -> Bool
    
    /// Toggles the favorite status of an item.
    ///
    /// - Parameter item: The `NSManagedObject` to toggle (e.g., `Movie`, `Series`, `Channel`).
    func toggleFavorite(for item: NSManagedObject)
}

// MARK: - Watch History Protocol

/// Protocol for managing user watch history.
@MainActor
public protocol WatchHistoryManaging {
    /// Finds the `WatchHistory` object for a given item.
    ///
    /// - Parameter item: The `NSManagedObject` to find the watch history for (e.g., `Movie`, `Episode`).
    /// - Returns: The `WatchHistory` object, or `nil` if no watch history is found.
    func findWatchHistory(for item: NSManagedObject) -> WatchHistory?
    
    /// Updates the watch history for a given item.
    ///
    /// - Parameters:
    ///   - item: The `NSManagedObject` to update the watch history for.
    ///   - progress: The watch progress as a percentage (0.0 to 1.0).
    func updateWatchHistory(for item: NSManagedObject, progress: Float)
}

// MARK: - Playback Protocol

/// Protocol for managing media playback.
@MainActor
public protocol PlaybackManaging: AnyObject, ObservableObject {
    /// The `AVPlayer` instance.
    var player: AVPlayer? { get }
    /// A boolean indicating whether the player is currently playing.
    var isPlaying: Bool { get }
    /// The current playback state.
    var playbackState: PlaybackManager.PlaybackState { get }
    
    /// Loads media for a given item and profile.
    ///
    /// - Parameters:
    ///   - item: The `NSManagedObject` to play (e.g., `Movie`, `Episode`, `ChannelVariant`).
    ///   - profile: The `Profile` of the current user.
    func loadMedia(for item: NSManagedObject, profile: Profile)
    
    /// Starts playback.
    func play()
    
    /// Pauses playback.
    func pause()
    
    /// Seeks to a specific time in the media.
    /// - Parameter time: The `CMTime` to seek to.
    func seek(to time: CMTime)
    
    /// Stops playback and resets the player.
    func stop()
}
