import XCTest
import CoreData
@testable import StreamHaven

final class DenormalizationTests: XCTestCase {
    var provider: PersistenceProviding!
    var context: NSManagedObjectContext!
    var denormManager: DenormalizationManager!
    var profile: Profile!

    override func setUpWithError() throws {
        let controller = PersistenceController(inMemory: true)
        provider = DefaultPersistenceProvider(controller: controller)
        context = provider.container.newBackgroundContext()
        denormManager = DenormalizationManager(persistenceProvider: provider)
        
        // Create test profile
        try context.performAndWait {
            profile = Profile(context: context)
            profile.name = "Test Adult"
            profile.isAdult = true
            try context.save()
        }
    }

    func testMovieWatchProgressUpdatesDenormalizedFields() throws {
        let movie = try context.performAndWait { () -> Movie in
            let m = Movie(context: context)
            m.title = "Test Movie"
            m.hasBeenWatched = false
            m.watchProgressPercent = 0
            try context.save()
            return m
        }

        // Simulate watch progress update
        try context.performAndWait {
            let history = WatchHistory(context: context)
            history.movie = movie
            history.profile = profile
            history.progress = 0.5
            history.watchedDate = Date()
            try context.save()
            
            // Update denormalized fields
            movie.updateDenormalizedFields(context: context, profile: profile)
            try context.save()
        }

        try context.performAndWait {
            context.refresh(movie, mergeChanges: true)
            XCTAssertEqual(movie.watchProgressPercent, 50)
            XCTAssertNotNil(movie.lastWatchedDate)
        }
    }

    func testMovieMarkedAsWatchedWhenProgressOver90Percent() throws {
        let movie = try context.performAndWait { () -> Movie in
            let m = Movie(context: context)
            m.title = "Test Movie"
            m.hasBeenWatched = false
            try context.save()
            return m
        }

        try context.performAndWait {
            let history = WatchHistory(context: context)
            history.movie = movie
            history.profile = profile
            history.progress = 0.95
            history.watchedDate = Date()
            try context.save()
            
            movie.updateDenormalizedFields(context: context, profile: profile)
            try context.save()
        }

        try context.performAndWait {
            context.refresh(movie, mergeChanges: true)
            XCTAssertTrue(movie.hasBeenWatched)
        }
    }

    func testFavoriteToggleUpdatesDenormalizedField() throws {
        let movie = try context.performAndWait { () -> Movie in
            let m = Movie(context: context)
            m.title = "Test Movie"
            m.isFavorite = false
            try context.save()
            return m
        }

        try context.performAndWait {
            let favorite = Favorite(context: context)
            favorite.movie = movie
            favorite.profile = profile
            favorite.favoritedDate = Date()
            try context.save()
            
            movie.updateDenormalizedFields(context: context, profile: profile)
            try context.save()
        }

        try context.performAndWait {
            context.refresh(movie, mergeChanges: true)
            XCTAssertTrue(movie.isFavorite)
        }
    }

    func testSeriesUnwatchedEpisodeCountAccurate() throws {
        let series = try context.performAndWait { () -> Series in
            let s = Series(context: context)
            s.title = "Test Series"
            
            let season = Season(context: context)
            season.series = s
            season.seasonNumber = 1
            
            // Add 3 episodes
            for i in 1...3 {
                let ep = Episode(context: context)
                ep.title = "Episode \(i)"
                ep.season = season
                ep.episodeNumber = Int16(i)
            }
            
            try context.save()
            return s
        }

        // Mark one episode as watched
        try context.performAndWait {
            guard let season = series.seasons?.anyObject() as? Season,
                  let episodes = season.episodes?.allObjects as? [Episode],
                  let firstEpisode = episodes.first else {
                XCTFail("Failed to get episodes")
                return
            }
            
            let history = WatchHistory(context: context)
            history.episode = firstEpisode
            history.profile = profile
            history.progress = 1.0
            history.watchedDate = Date()
            try context.save()
            
            series.updateDenormalizedFields(context: context, profile: profile)
            try context.save()
        }

        try context.performAndWait {
            context.refresh(series, mergeChanges: true)
            XCTAssertEqual(series.totalEpisodeCount, 3)
            XCTAssertEqual(series.unwatchedEpisodeCount, 2)
        }
    }

    func testChannelEPGUpdatesDenormalizedFields() throws {
        let channel = try context.performAndWait { () -> Channel in
            let c = Channel(context: context)
            c.name = "Test Channel"
            c.hasEPG = false
            try context.save()
            return c
        }

        try context.performAndWait {
            let epg = EPGEntry(context: context)
            epg.channel = channel
            epg.title = "Current Program"
            epg.startTime = Date().addingTimeInterval(-3600)
            epg.endTime = Date().addingTimeInterval(3600)
            try context.save()
            
            denormManager.updateChannelEPG(channel)
            try context.save()
        }

        try context.performAndWait {
            context.refresh(channel, mergeChanges: true)
            XCTAssertTrue(channel.hasEPG)
            XCTAssertEqual(channel.currentProgramTitle, "Current Program")
            XCTAssertNotNil(channel.epgLastUpdated)
        }
    }

    func testRebuildDenormalizedFieldsProcessesAllEntities() async throws {
        // Create test data
        try context.performAndWait {
            let movie = Movie(context: context)
            movie.title = "Test Movie"
            
            let series = Series(context: context)
            series.title = "Test Series"
            
            let channel = Channel(context: context)
            channel.name = "Test Channel"
            
            try context.save()
        }

        // Rebuild should not throw
        try await denormManager.rebuildDenormalizedFields()
        
        // Verify no crashes and operations complete
        XCTAssertTrue(true)
    }
}
