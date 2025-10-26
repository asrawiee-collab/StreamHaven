import Foundation
import CoreData

/// Extensions providing optimized fetch requests that leverage denormalized fields.
/// These eliminate expensive joins and computations for hot code paths.
extension NSManagedObjectContext {
    
    // MARK: - Channel Queries
    
    /// Fetches channels sorted by variant count (cached field).
    /// Much faster than counting relationships in-query.
    func fetchPopularChannels(limit: Int = 50) throws -> [Channel] {
        let request: NSFetchRequest<Channel> = Channel.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(key: "variantCount", ascending: false)]
        request.fetchLimit = limit
        return try fetch(request)
    }
    
    /// Fetches channels that have EPG data without loading relationships.
    func fetchChannelsWithEPG() throws -> [Channel] {
        let request: NSFetchRequest<Channel> = Channel.fetchRequest()
        request.predicate = NSPredicate(format: "hasEPG == YES")
        request.sortDescriptors = [NSSortDescriptor(key: "name", ascending: true)]
        return try fetch(request)
    }
    
    /// Fetches channels with their current program (cached).
    /// No need to fetch and filter EPG entries.
    func fetchChannelsWithCurrentProgram() throws -> [Channel] {
        let request: NSFetchRequest<Channel> = Channel.fetchRequest()
        request.predicate = NSPredicate(format: "currentProgramTitle != nil")
        request.sortDescriptors = [NSSortDescriptor(key: "name", ascending: true)]
        return try fetch(request)
    }
    
    // MARK: - Movie Queries
    
    /// Fetches favorited movies without join to Favorite table.
    func fetchFavoriteMovies(for profile: Profile) throws -> [Movie] {
        let request: NSFetchRequest<Movie> = Movie.fetchRequest()
        request.predicate = NSPredicate(format: "isFavorite == YES")
        request.sortDescriptors = [NSSortDescriptor(key: "lastWatchedDate", ascending: false)]
        return try fetch(request)
    }
    
    /// Fetches unwatched movies efficiently.
    func fetchUnwatchedMovies() throws -> [Movie] {
        let request: NSFetchRequest<Movie> = Movie.fetchRequest()
        request.predicate = NSPredicate(format: "hasBeenWatched == NO")
        request.sortDescriptors = [NSSortDescriptor(key: "releaseDate", ascending: false)]
        return try fetch(request)
    }
    
    /// Fetches in-progress movies (partially watched).
    func fetchInProgressMovies() throws -> [Movie] {
        let request: NSFetchRequest<Movie> = Movie.fetchRequest()
        request.predicate = NSPredicate(format: "watchProgressPercent > 0 AND watchProgressPercent < 90")
        request.sortDescriptors = [NSSortDescriptor(key: "lastWatchedDate", ascending: false)]
        return try fetch(request)
    }
    
    /// Fetches recently watched movies (fast query on denormalized date).
    func fetchRecentlyWatchedMovies(limit: Int = 20) throws -> [Movie] {
        let request: NSFetchRequest<Movie> = Movie.fetchRequest()
        request.predicate = NSPredicate(format: "lastWatchedDate != nil")
        request.sortDescriptors = [NSSortDescriptor(key: "lastWatchedDate", ascending: false)]
        request.fetchLimit = limit
        return try fetch(request)
    }
    
    // MARK: - Series Queries
    
    /// Fetches series with unwatched episodes without complex subqueries.
    func fetchSeriesWithUnwatchedEpisodes() throws -> [Series] {
        let request: NSFetchRequest<Series> = Series.fetchRequest()
        request.predicate = NSPredicate(format: "unwatchedEpisodeCount > 0")
        request.sortDescriptors = [
            NSSortDescriptor(key: "unwatchedEpisodeCount", ascending: false),
            NSSortDescriptor(key: "title", ascending: true)
        ]
        return try fetch(request)
    }
    
    /// Fetches favorite series efficiently.
    func fetchFavoriteSeries() throws -> [Series] {
        let request: NSFetchRequest<Series> = Series.fetchRequest()
        request.predicate = NSPredicate(format: "isFavorite == YES")
        request.sortDescriptors = [NSSortDescriptor(key: "title", ascending: true)]
        return try fetch(request)
    }
    
    /// Fetches long-running series (many episodes) without counting relationships.
    func fetchLongRunningSeries(minimumEpisodes: Int = 50, limit: Int = 20) throws -> [Series] {
        let request: NSFetchRequest<Series> = Series.fetchRequest()
        request.predicate = NSPredicate(format: "totalEpisodeCount >= %d", minimumEpisodes)
        request.sortDescriptors = [NSSortDescriptor(key: "totalEpisodeCount", ascending: false)]
        request.fetchLimit = limit
        return try fetch(request)
    }
    
    /// Fetches series by season count efficiently.
    func fetchSeriesBySeasonCount(minimumSeasons: Int = 5, limit: Int = 20) throws -> [Series] {
        let request: NSFetchRequest<Series> = Series.fetchRequest()
        request.predicate = NSPredicate(format: "seasonCount >= %d", minimumSeasons)
        request.sortDescriptors = [NSSortDescriptor(key: "seasonCount", ascending: false)]
        request.fetchLimit = limit
        return try fetch(request)
    }
    
    // MARK: - Mixed Content Queries
    
    /// Statistics about content library using denormalized fields.
    /// Much faster than counting individual relationships.
    func fetchContentStatistics() throws -> ContentStatistics {
        let movieCount = try count(for: Movie.fetchRequest())
        let seriesCount = try count(for: Series.fetchRequest())
        let channelCount = try count(for: Channel.fetchRequest())
        
        // Sum denormalized episode counts
        let episodeCountRequest: NSFetchRequest<NSDictionary> = NSFetchRequest(entityName: "Series")
        episodeCountRequest.resultType = .dictionaryResultType
        
        let sumExpression = NSExpression(forFunction: "sum:", arguments: [NSExpression(forKeyPath: "totalEpisodeCount")])
        let sumExpressionDesc = NSExpressionDescription()
        sumExpressionDesc.name = "totalEpisodes"
        sumExpressionDesc.expression = sumExpression
        sumExpressionDesc.expressionResultType = .integer32AttributeType
        
        episodeCountRequest.propertiesToFetch = [sumExpressionDesc]
        
        let episodeResults = try fetch(episodeCountRequest)
        let totalEpisodes = (episodeResults.first?["totalEpisodes"] as? Int) ?? 0
        
        // Count favorited items (no joins needed)
        let favMoviesRequest: NSFetchRequest<Movie> = Movie.fetchRequest()
        favMoviesRequest.predicate = NSPredicate(format: "isFavorite == YES")
        let favMovieCount = try count(for: favMoviesRequest)
        
        let favSeriesRequest: NSFetchRequest<Series> = Series.fetchRequest()
        favSeriesRequest.predicate = NSPredicate(format: "isFavorite == YES")
        let favSeriesCount = try count(for: favSeriesRequest)
        
        return ContentStatistics(
            totalMovies: movieCount,
            totalSeries: seriesCount,
            totalEpisodes: totalEpisodes,
            totalChannels: channelCount,
            favoriteMovies: favMovieCount,
            favoriteSeries: favSeriesCount
        )
    }
}

/// Statistics about the content library.
public struct ContentStatistics {
    public let totalMovies: Int
    public let totalSeries: Int
    public let totalEpisodes: Int
    public let totalChannels: Int
    public let favoriteMovies: Int
    public let favoriteSeries: Int
}
