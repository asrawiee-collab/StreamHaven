import Foundation
import CoreData
import Combine
import os.log

/// Manages the Up Next queue for automated content continuation.
@MainActor
public class UpNextQueueManager: ObservableObject {
    
    // MARK: - Published Properties
    
    @Published public var queueItems: [UpNextQueueItem] = []
    @Published public var nextItem: UpNextQueueItem?
    
    // MARK: - Properties
    
    private let context: NSManagedObjectContext
    private let watchHistoryManager: WatchHistoryManager
    private let logger = Logger(subsystem: "com.streamhaven.queue", category: "UpNextQueueManager")
    
    /// Maximum queue size
    public var maxQueueSize: Int = 50
    
    /// Enable auto-queue suggestions
    public var enableAutoQueue: Bool = true
    
    /// Number of suggestions to auto-add
    public var autoQueueSuggestions: Int = 3
    
    // MARK: - Initialization
    
    public init(context: NSManagedObjectContext, watchHistoryManager: WatchHistoryManager) {
        self.context = context
        self.watchHistoryManager = watchHistoryManager
    }
    
    // MARK: - Queue Operations
    
    /// Loads the queue for the current profile.
    /// - Parameter profile: The profile to load the queue for.
    public func loadQueue(for profile: Profile) {
        let fetchRequest: NSFetchRequest<UpNextQueueItem> = UpNextQueueItem.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "profile == %@", profile)
        fetchRequest.sortDescriptors = [NSSortDescriptor(key: "position", ascending: true)]
        
        do {
            queueItems = try context.fetch(fetchRequest)
            nextItem = queueItems.first
            logger.info("Loaded \(self.queueItems.count) items for profile: \(profile.name ?? "Unknown")")
        } catch {
            logger.error("Failed to load queue: \(error.localizedDescription)")
            queueItems = []
            nextItem = nil
        }
    }
    
    /// Adds content to the queue.
    /// - Parameters:
    ///   - content: The content to add (Movie, Episode, or Series).
    ///   - profile: The profile to add to.
    ///   - autoAdded: Whether this was automatically added.
    /// - Throws: UpNextQueueError if operation fails.
    public func addToQueue(_ content: NSManagedObject, profile: Profile, autoAdded: Bool = false) throws {
        // Check if already in queue
        if isInQueue(content, profile: profile) {
            throw UpNextQueueError.alreadyInQueue
        }
        
        // Check queue size limit
        if queueItems.count >= maxQueueSize {
            throw UpNextQueueError.queueFull
        }
        
        // Get next position
        let nextPosition = Int32(queueItems.count)
        
        // Create queue item
        guard let queueItem = UpNextQueueItem.create(
            for: content,
            profile: profile,
            position: nextPosition,
            autoAdded: autoAdded,
            context: context
        ) else {
            throw UpNextQueueError.unsupportedContentType
        }
        
        try context.save()
        
        loadQueue(for: profile)
        
        logger.info("Added to queue: \(queueItem.contentType) at position \(nextPosition)")
    }
    
    /// Removes content from the queue.
    /// - Parameters:
    ///   - queueItem: The queue item to remove.
    ///   - profile: The profile to reload queue for.
    public func removeFromQueue(_ queueItem: UpNextQueueItem, profile: Profile) {
        context.delete(queueItem)
        
        do {
            try context.save()
            loadQueue(for: profile)
            reorderQueue(profile: profile)
            logger.info("Removed from queue: \(queueItem.contentType)")
        } catch {
            logger.error("Failed to remove from queue: \(error.localizedDescription)")
        }
    }
    
    /// Clears the entire queue for a profile.
    /// - Parameter profile: The profile to clear queue for.
    public func clearQueue(for profile: Profile) {
        for item in queueItems {
            context.delete(item)
        }
        
        do {
            try context.save()
            queueItems = []
            nextItem = nil
            logger.info("Cleared queue for profile: \(profile.name ?? "Unknown")")
        } catch {
            logger.error("Failed to clear queue: \(error.localizedDescription)")
        }
    }
    
    /// Clears only auto-added items from the queue.
    /// - Parameter profile: The profile to clear auto-added items for.
    public func clearAutoAddedItems(for profile: Profile) {
        let autoAddedItems = queueItems.filter { $0.autoAdded }
        
        for item in autoAddedItems {
            context.delete(item)
        }
        
        do {
            try context.save()
            loadQueue(for: profile)
            reorderQueue(profile: profile)
            logger.info("Cleared \(autoAddedItems.count) auto-added items")
        } catch {
            logger.error("Failed to clear auto-added items: \(error.localizedDescription)")
        }
    }
    
    /// Reorders the queue items after a deletion.
    /// - Parameter profile: The profile to reorder queue for.
    public func reorderQueue(profile: Profile) {
        for (index, item) in queueItems.enumerated() {
            item.position = Int32(index)
        }
        
        do {
            try context.save()
        } catch {
            logger.error("Failed to reorder queue: \(error.localizedDescription)")
        }
    }
    
    /// Moves a queue item to a new position.
    /// - Parameters:
    ///   - queueItem: The item to move.
    ///   - newPosition: The new position (0-based).
    ///   - profile: The profile to reload queue for.
    public func moveItem(_ queueItem: UpNextQueueItem, to newPosition: Int, profile: Profile) {
        guard newPosition >= 0 && newPosition < queueItems.count else { return }
        
        let oldPosition = Int(queueItem.position)
        
        if oldPosition < newPosition {
            // Moving down
            for item in queueItems where item.position > oldPosition && item.position <= newPosition {
                item.position -= 1
            }
        } else {
            // Moving up
            for item in queueItems where item.position >= newPosition && item.position < oldPosition {
                item.position += 1
            }
        }
        
        queueItem.position = Int32(newPosition)
        
        do {
            try context.save()
            loadQueue(for: profile)
            logger.info("Moved item from \(oldPosition) to \(newPosition)")
        } catch {
            logger.error("Failed to move item: \(error.localizedDescription)")
        }
    }
    
    /// Gets the next item in the queue.
    /// - Returns: The next UpNextQueueItem, or nil if queue is empty.
    public func getNextItem() -> UpNextQueueItem? {
        return queueItems.first
    }
    
    /// Checks if content is already in the queue.
    /// - Parameters:
    ///   - content: The content to check.
    ///   - profile: The profile to check in.
    /// - Returns: True if content is in queue, false otherwise.
    public func isInQueue(_ content: NSManagedObject, profile: Profile) -> Bool {
        let contentID = content.objectID.uriRepresentation().absoluteString
        return queueItems.contains { $0.contentID == contentID }
    }
    
    // MARK: - Auto-Queue Logic
    
    /// Generates and adds suggestions to the queue.
    /// - Parameter profile: The profile to generate suggestions for.
    public func generateSuggestions(for profile: Profile) {
        guard enableAutoQueue else { return }
        
        // Count existing auto-added items
        let existingAutoAdded = queueItems.filter { $0.autoAdded }.count
        let neededSuggestions = autoQueueSuggestions - existingAutoAdded
        
        guard neededSuggestions > 0 else { return }
        
        var suggestions: [NSManagedObject] = []
        
        // 1. Continue watching series (next unwatched episode)
        suggestions.append(contentsOf: getContinueWatchingSuggestions(for: profile))
        
        // 2. Similar content based on watch history
        if suggestions.count < neededSuggestions {
            suggestions.append(contentsOf: getSimilarContentSuggestions(for: profile))
        }
        
        // Add suggestions to queue
        let toAdd = min(suggestions.count, neededSuggestions)
        for i in 0..<toAdd {
            do {
                try addToQueue(suggestions[i], profile: profile, autoAdded: true)
            } catch {
                logger.error("Failed to add suggestion: \(error.localizedDescription)")
            }
        }
        
        logger.info("Generated \(toAdd) suggestions for profile: \(profile.name ?? "Unknown")")
    }
    
    /// Gets continue watching suggestions (next unwatched episodes).
    /// - Parameter profile: The profile to get suggestions for.
    /// - Returns: Array of Episode objects.
    private func getContinueWatchingSuggestions(for profile: Profile) -> [NSManagedObject] {
        var suggestions: [NSManagedObject] = []
        
        // Get watched episodes
        let watchedEpisodes = getWatchedEpisodes(for: profile)
        
        // Find series with watched episodes
        var seriesMap: [Series: [Episode]] = [:]
        for episode in watchedEpisodes {
            if let series = episode.season?.series {
                seriesMap[series, default: []].append(episode)
            }
        }
        
        // For each series, find next unwatched episode
        for (series, episodes) in seriesMap {
            if let nextEpisode = findNextUnwatchedEpisode(in: series, after: episodes, profile: profile) {
                if !isInQueue(nextEpisode, profile: profile) {
                    suggestions.append(nextEpisode)
                }
            }
        }
        
        return suggestions
    }
    
    /// Gets similar content suggestions based on watch history.
    /// - Parameter profile: The profile to get suggestions for.
    /// - Returns: Array of Movie/Series objects.
    private func getSimilarContentSuggestions(for profile: Profile) -> [NSManagedObject] {
        var suggestions: [NSManagedObject] = []
        
        // Get recently watched movies
        let recentMovies = getRecentlyWatchedMovies(for: profile)
        
        // Find similar movies (same genre, similar rating)
        for movie in recentMovies {
            if let similarMovies = findSimilarMovies(to: movie, profile: profile) {
                suggestions.append(contentsOf: similarMovies)
                if suggestions.count >= 10 { break } // Limit suggestions
            }
        }
        
        return suggestions
    }
    
    /// Gets watched episodes for a profile.
    /// - Parameter profile: The profile to get watched episodes for.
    /// - Returns: Array of watched Episode objects.
    private func getWatchedEpisodes(for profile: Profile) -> [Episode] {
        let fetchRequest: NSFetchRequest<WatchHistory> = WatchHistory.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "profile == %@ AND episode != nil AND progress >= 0.9", profile)
        fetchRequest.sortDescriptors = [NSSortDescriptor(key: "lastWatched", ascending: false)]
        fetchRequest.fetchLimit = 10
        
        do {
            let history = try context.fetch(fetchRequest)
            return history.compactMap { $0.episode }
        } catch {
            logger.error("Failed to fetch watched episodes: \(error.localizedDescription)")
            return []
        }
    }
    
    /// Finds the next unwatched episode in a series.
    /// - Parameters:
    ///   - series: The series to search in.
    ///   - watchedEpisodes: Episodes already watched.
    ///   - profile: The profile to check watch history for.
    /// - Returns: The next unwatched Episode, or nil.
    private func findNextUnwatchedEpisode(in series: Series, after watchedEpisodes: [Episode], profile: Profile) -> Episode? {
        // Get all episodes sorted by season and episode number
        guard let seasons = series.seasons as? Set<Season> else { return nil }
        
        let sortedSeasons = seasons.sorted { ($0.seasonNumber) < ($1.seasonNumber) }
        
        for season in sortedSeasons {
            guard let episodes = season.episodes as? Set<Episode> else { continue }
            let sortedEpisodes = episodes.sorted { ($0.episodeNumber) < ($1.episodeNumber) }
            
            for episode in sortedEpisodes {
                // Check if episode is watched
                let isWatched = watchedEpisodes.contains(episode) || 
                               watchHistoryManager.hasWatched(episode, profile: profile, threshold: 0.9)
                
                if !isWatched {
                    return episode
                }
            }
        }
        
        return nil
    }
    
    /// Gets recently watched movies for a profile.
    /// - Parameter profile: The profile to get watched movies for.
    /// - Returns: Array of recently watched Movie objects.
    private func getRecentlyWatchedMovies(for profile: Profile) -> [Movie] {
        let fetchRequest: NSFetchRequest<WatchHistory> = WatchHistory.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "profile == %@ AND movie != nil", profile)
        fetchRequest.sortDescriptors = [NSSortDescriptor(key: "lastWatched", ascending: false)]
        fetchRequest.fetchLimit = 5
        
        do {
            let history = try context.fetch(fetchRequest)
            return history.compactMap { $0.movie }
        } catch {
            logger.error("Failed to fetch watched movies: \(error.localizedDescription)")
            return []
        }
    }
    
    /// Finds similar movies to a given movie.
    /// - Parameters:
    ///   - movie: The movie to find similar content for.
    ///   - profile: The profile to check against.
    /// - Returns: Array of similar Movie objects.
    private func findSimilarMovies(to movie: Movie, profile: Profile) -> [Movie]? {
        // Find movies with same rating (genre approximation)
        let fetchRequest: NSFetchRequest<Movie> = Movie.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "rating == %@ AND self != %@", movie.rating ?? "", movie)
        fetchRequest.fetchLimit = 3
        
        do {
            let similar = try context.fetch(fetchRequest)
            // Filter out already watched or in queue
            return similar.filter { movie in
                !watchHistoryManager.hasWatched(movie, profile: profile, threshold: 0.9) &&
                !isInQueue(movie, profile: profile)
            }
        } catch {
            logger.error("Failed to find similar movies: \(error.localizedDescription)")
            return nil
        }
    }
    
    /// Processes queue after content completion.
    /// - Parameters:
    ///   - completedContent: The content that was just completed.
    ///   - profile: The current profile.
    public func processCompletion(of completedContent: NSManagedObject, profile: Profile) {
        // Remove completed item from queue
        if let queueItem = queueItems.first(where: { $0.contentID == completedContent.objectID.uriRepresentation().absoluteString }) {
            removeFromQueue(queueItem, profile: profile)
        }
        
        // Generate new suggestions if needed
        generateSuggestions(for: profile)
    }
}

// MARK: - Error Types

public enum UpNextQueueError: LocalizedError {
    case alreadyInQueue
    case queueFull
    case unsupportedContentType
    case itemNotFound
    
    public var errorDescription: String? {
        switch self {
        case .alreadyInQueue:
            return "This content is already in your Up Next queue."
        case .queueFull:
            return "Your Up Next queue is full. Please remove some items."
        case .unsupportedContentType:
            return "This content type is not supported in the queue."
        case .itemNotFound:
            return "Queue item not found."
        }
    }
}
