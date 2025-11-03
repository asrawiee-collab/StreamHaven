import CoreData
import Foundation

/// Extension to add denormalized/cached properties for hot paths.
extension Channel {
    
    /// Cached count of variants (denormalized for performance).
    /// Updated automatically via Core Data derived attribute or manually.
    @NSManaged public var variantCount: Int32
    
    /// Cached flag indicating if channel has EPG data (denormalized).
    @NSManaged public var hasEPG: Bool
    
    /// Cached current program title (denormalized, updated periodically).
    @NSManaged public var currentProgramTitle: String?
    
    /// Timestamp of last EPG update for cache invalidation.
    @NSManaged public var epgLastUpdated: Date?
    
    /// Updates denormalized fields based on current relationships.
    /// Call this after modifying variants or EPG entries.
    public func updateDenormalizedFields() {
        if let variants = self.variants as? Set<ChannelVariant> {
            self.variantCount = Int32(variants.count)
        }
        
        if let epgEntries = self.epgEntries as? Set<EPGEntry>, !epgEntries.isEmpty {
            self.hasEPG = true
            self.epgLastUpdated = Date()
            
            // Find current program
            let now = Date()
            if let currentProgram = epgEntries.first(where: {
                guard let start = $0.startTime, let end = $0.endTime else { return false }
                return start <= now && end >= now
            }) {
                self.currentProgramTitle = currentProgram.title
            }
        } else {
            self.hasEPG = false
            self.currentProgramTitle = nil
        }
    }
}

extension Movie {
    
    /// Cached flag for whether movie has been watched (denormalized).
    @NSManaged public var hasBeenWatched: Bool
    
    /// Cached watch progress percentage (0-100, denormalized).
    @NSManaged public var watchProgressPercent: Int16
    
    /// Cached flag for favorite status (denormalized).
    @NSManaged public var isFavorite: Bool
    
    /// Last watched timestamp (denormalized from WatchHistory).
    @NSManaged public var lastWatchedDate: Date?
    
    /// Updates denormalized fields from related entities.
    public func updateDenormalizedFields(context: NSManagedObjectContext, profile: Profile) {
        // Check favorite status
        let favFetch: NSFetchRequest<Favorite> = Favorite.fetchRequest()
        favFetch.predicate = NSPredicate(format: "movie == %@ AND profile == %@", self, profile)
        favFetch.fetchLimit = 1
        
        if let count = try? context.count(for: favFetch), count > 0 {
            self.isFavorite = true
        } else {
            self.isFavorite = false
        }
        
        // Check watch history
        let histFetch: NSFetchRequest<WatchHistory> = WatchHistory.fetchRequest()
        histFetch.predicate = NSPredicate(format: "movie == %@ AND profile == %@", self, profile)
        histFetch.fetchLimit = 1
        
        if let history = try? context.fetch(histFetch).first {
            self.hasBeenWatched = true
            self.watchProgressPercent = Int16(history.progress * 100)
            self.lastWatchedDate = history.watchedDate
        } else {
            self.hasBeenWatched = false
            self.watchProgressPercent = 0
            self.lastWatchedDate = nil
        }
    }
}

extension Series {
    
    /// Cached total episode count across all seasons (denormalized).
    @NSManaged public var totalEpisodeCount: Int32
    
    /// Cached season count (denormalized).
    @NSManaged public var seasonCount: Int16
    
    /// Cached flag for favorite status (denormalized).
    @NSManaged public var isFavorite: Bool
    
    /// Cached unwatched episode count (denormalized).
    @NSManaged public var unwatchedEpisodeCount: Int32
    
    /// Updates denormalized fields from relationships.
    public func updateDenormalizedFields(context: NSManagedObjectContext, profile: Profile? = nil) {
        if let seasons = self.seasons as? Set<Season> {
            self.seasonCount = Int16(seasons.count)
            
            var totalEpisodes = 0
            var unwatchedCount = 0
            
            for season in seasons {
                if let episodes = season.episodes as? Set<Episode> {
                    totalEpisodes += episodes.count
                    
                    // Count unwatched if profile provided
                    if let profile = profile {
                        for episode in episodes {
                            let histFetch: NSFetchRequest<WatchHistory> = WatchHistory.fetchRequest()
                            histFetch.predicate = NSPredicate(format: "episode == %@ AND profile == %@", episode, profile)
                            histFetch.fetchLimit = 1
                            
                            if (try? context.count(for: histFetch)) == 0 {
                                unwatchedCount += 1
                            }
                        }
                    }
                }
            }
            
            self.totalEpisodeCount = Int32(totalEpisodes)
            self.unwatchedEpisodeCount = Int32(unwatchedCount)
        }
        
        // Check favorite status
        if let profile = profile {
            let favFetch: NSFetchRequest<Favorite> = Favorite.fetchRequest()
            favFetch.predicate = NSPredicate(format: "series == %@ AND profile == %@", self, profile)
            favFetch.fetchLimit = 1
            
            if let count = try? context.count(for: favFetch), count > 0 {
                self.isFavorite = true
            } else {
                self.isFavorite = false
            }
        }
    }
}

/// Manager for maintaining denormalized data consistency.
public final class DenormalizationManager {
    
    private let persistenceProvider: PersistenceProviding
    
    public init(persistenceProvider: PersistenceProviding) {
        self.persistenceProvider = persistenceProvider
    }
    
    /// Rebuilds all denormalized fields for optimal query performance.
    /// Should be called periodically or after bulk imports.
    public func rebuildDenormalizedFields(for profile: Profile? = nil) async throws {
        let context = persistenceProvider.container.newBackgroundContext()
        
        try await context.perform {
            // Update channels
            let channelFetch: NSFetchRequest<Channel> = Channel.fetchRequest()
            let channels = try context.fetch(channelFetch)
            
            for channel in channels {
                channel.updateDenormalizedFields()
            }
            
            // Update movies if profile provided
            if let profile = profile {
                let movieFetch: NSFetchRequest<Movie> = Movie.fetchRequest()
                let movies = try context.fetch(movieFetch)
                
                for movie in movies {
                    movie.updateDenormalizedFields(context: context, profile: profile)
                }
                
                // Update series
                let seriesFetch: NSFetchRequest<Series> = Series.fetchRequest()
                let series = try context.fetch(seriesFetch)
                
                for show in series {
                    show.updateDenormalizedFields(context: context, profile: profile)
                }
            }
            
            if context.hasChanges {
                try context.save()
            }
        }
    }
    
    /// Updates denormalized fields for a specific channel after EPG refresh.
    public func updateChannelEPG(_ channel: Channel) {
        channel.updateDenormalizedFields()
    }
    
    /// Updates denormalized fields after watch progress changes.
    public func updateWatchProgress(for item: NSManagedObject, profile: Profile, context: NSManagedObjectContext) {
        if let movie = item as? Movie {
            movie.updateDenormalizedFields(context: context, profile: profile)
        } else if let episode = item as? Episode, let series = episode.season?.series {
            series.updateDenormalizedFields(context: context, profile: profile)
        }
    }
}
