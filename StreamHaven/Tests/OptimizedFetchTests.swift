import CoreData
import XCTest
@testable import StreamHaven

@MainActor
final class OptimizedFetchTests: XCTestCase {
    var container: NSPersistentContainer!
    var context: NSManagedObjectContext!
    var profile: Profile!

    override func setUp() async throws {
        try await super.setUp()
        
        let localContext = context!
        let createdProfile = try localContext.performAndWait {
            let p = Profile(context: localContext)
            p.name = "Test"
            p.isAdult = true
            try localContext.save()
            return p
        }
        profile = createdProfile
    }

    func testFetchFavoriteMoviesReturnsOnlyFavorites() throws {
        try context.performAndWait {
            let favoriteMovie = Movie(context: context)
            favoriteMovie.title = "Favorite"
            favoriteMovie.isFavorite = true
            
            let regularMovie = Movie(context: context)
            regularMovie.title = "Regular"
            regularMovie.isFavorite = false
            
            try context.save()
            
            let favorites = try context.fetchFavoriteMovies(for: profile)
            XCTAssertEqual(favorites.count, 1)
            XCTAssertEqual(favorites.first?.title, "Favorite")
        }
    }

    func testFetchUnwatchedMoviesExcludesWatched() throws {
        try context.performAndWait {
            let unwatchedMovie = Movie(context: context)
            unwatchedMovie.title = "Unwatched"
            unwatchedMovie.hasBeenWatched = false
            
            let watchedMovie = Movie(context: context)
            watchedMovie.title = "Watched"
            watchedMovie.hasBeenWatched = true
            
            try context.save()
            
            let unwatched = try context.fetchUnwatchedMovies()
            XCTAssertEqual(unwatched.count, 1)
            XCTAssertEqual(unwatched.first?.title, "Unwatched")
        }
    }

    func testFetchInProgressMoviesReturnsPartiallyWatched() throws {
        try context.performAndWait {
            let inProgressMovie = Movie(context: context)
            inProgressMovie.title = "In Progress"
            inProgressMovie.watchProgressPercent = 50
            
            let notStartedMovie = Movie(context: context)
            notStartedMovie.title = "Not Started"
            notStartedMovie.watchProgressPercent = 0
            
            let completeMovie = Movie(context: context)
            completeMovie.title = "Complete"
            completeMovie.watchProgressPercent = 100
            
            try context.save()
            
            let inProgress = try context.fetchInProgressMovies()
            XCTAssertEqual(inProgress.count, 1)
            XCTAssertEqual(inProgress.first?.title, "In Progress")
        }
    }

    func testFetchRecentlyWatchedMoviesOrdersByDate() throws {
        try context.performAndWait {
            let oldMovie = Movie(context: context)
            oldMovie.title = "Old"
            oldMovie.lastWatchedDate = Date().addingTimeInterval(-86400) // 1 day ago
            
            let recentMovie = Movie(context: context)
            recentMovie.title = "Recent"
            recentMovie.lastWatchedDate = Date()
            
            try context.save()
            
            let recent = try context.fetchRecentlyWatchedMovies(limit: 10)
            XCTAssertGreaterThanOrEqual(recent.count, 2)
            XCTAssertEqual(recent.first?.title, "Recent")
        }
    }

    func testFetchSeriesWithUnwatchedEpisodesFiltersCorrectly() throws {
        try context.performAndWait {
            let seriesWithUnwatched = Series(context: context)
            seriesWithUnwatched.title = "Has Unwatched"
            seriesWithUnwatched.unwatchedEpisodeCount = 5
            
            let seriesAllWatched = Series(context: context)
            seriesAllWatched.title = "All Watched"
            seriesAllWatched.unwatchedEpisodeCount = 0
            
            try context.save()
            
            let result = try context.fetchSeriesWithUnwatchedEpisodes()
            XCTAssertEqual(result.count, 1)
            XCTAssertEqual(result.first?.title, "Has Unwatched")
        }
    }

    func testFetchLongRunningSeriesUsesEpisodeThreshold() throws {
        try context.performAndWait {
            let longSeries = Series(context: context)
            longSeries.title = "Long Series"
            longSeries.totalEpisodeCount = 100
            
            let shortSeries = Series(context: context)
            shortSeries.title = "Short Series"
            shortSeries.totalEpisodeCount = 10
            
            try context.save()
            
            let result = try context.fetchLongRunningSeries(minimumEpisodes: 50)
            XCTAssertEqual(result.count, 1)
            XCTAssertEqual(result.first?.title, "Long Series")
        }
    }

    func testFetchChannelsWithEPGReturnsOnlyChannelsWithGuide() throws {
        try context.performAndWait {
            let channelWithEPG = Channel(context: context)
            channelWithEPG.name = "With EPG"
            channelWithEPG.hasEPG = true
            
            let channelNoEPG = Channel(context: context)
            channelNoEPG.name = "No EPG"
            channelNoEPG.hasEPG = false
            
            try context.save()
            
            let result = try context.fetchChannelsWithEPG()
            XCTAssertEqual(result.count, 1)
            XCTAssertEqual(result.first?.name, "With EPG")
        }
    }

    func testFetchPopularChannelsRespectsLimit() throws {
        try context.performAndWait {
            for i in 1...20 {
                let channel = Channel(context: context)
                channel.name = "Channel \(i)"
                channel.variantCount = Int32(i)
            }
            try context.save()
            
            let result = try context.fetchPopularChannels(limit: 5)
            XCTAssertEqual(result.count, 5)
        }
    }

    func testFetchContentStatisticsReturnsAccurateCounts() throws {
        try context.performAndWait {
            // Create test data
            for _ in 1...3 {
                let movie = Movie(context: context)
                movie.title = "Movie"
            }
            
            for _ in 1...2 {
                let series = Series(context: context)
                series.title = "Series"
            }
            
            for _ in 1...5 {
                let channel = Channel(context: context)
                channel.name = "Channel"
            }
            
            try context.save()
            
            let stats = try context.fetchContentStatistics()
            XCTAssertEqual(stats.totalMovies, 3)
            XCTAssertEqual(stats.totalSeries, 2)
            XCTAssertEqual(stats.totalChannels, 5)
        }
    }
}
