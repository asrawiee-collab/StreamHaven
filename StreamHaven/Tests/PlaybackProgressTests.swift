import XCTest
import CoreData
import AVKit
@testable import StreamHaven

final class PlaybackProgressTests: XCTestCase {
    var provider: PersistenceProviding!
    var context: NSManagedObjectContext!
    var profile: Profile!
    var progressTracker: PlaybackProgressTracker!

    override func setUpWithError() throws {
        let controller = PersistenceController(inMemory: true)
        provider = DefaultPersistenceProvider(controller: controller)
        context = provider.container.viewContext
        
        profile = Profile(context: context)
        profile.name = "Test"
        profile.isAdult = true
        try context.save()
        
        progressTracker = PlaybackProgressTracker(context: context, profile: profile)
    }

    func testSavesProgressForMovie() throws {
        let movie = Movie(context: context)
        movie.title = "Test Movie"
        try context.save()
        
        progressTracker.saveProgress(for: movie, progress: 0.5)
        
        let history = WatchHistoryManager(context: context, profile: profile)
            .findWatchHistory(for: movie)
        
        XCTAssertNotNil(history)
        XCTAssertEqual(history?.progress, 0.5)
    }

    func testUpdatesExistingProgress() throws {
        let movie = Movie(context: context)
        movie.title = "Test Movie"
        try context.save()
        
        progressTracker.saveProgress(for: movie, progress: 0.3)
        progressTracker.saveProgress(for: movie, progress: 0.7)
        
        let history = WatchHistoryManager(context: context, profile: profile)
            .findWatchHistory(for: movie)
        
        XCTAssertEqual(history?.progress, 0.7)
    }

    func testRestoresProgressForMovie() throws {
        let movie = Movie(context: context)
        movie.title = "Test Movie"
        try context.save()
        
        progressTracker.saveProgress(for: movie, progress: 0.45)
        
        let restored = progressTracker.restoreProgress(for: movie)
        
        XCTAssertEqual(restored, 0.45, accuracy: 0.01)
    }

    func testReturnsZeroProgressForUnwatchedContent() throws {
        let movie = Movie(context: context)
        movie.title = "Unwatched Movie"
        try context.save()
        
        let progress = progressTracker.restoreProgress(for: movie)
        
        XCTAssertEqual(progress, 0.0)
    }

    func testTracksProgressForEpisodes() throws {
        let series = Series(context: context)
        series.title = "Test Series"
        
        let season = Season(context: context)
        season.series = series
        season.seasonNumber = 1
        
        let episode = Episode(context: context)
        episode.season = season
        episode.title = "Episode 1"
        episode.episodeNumber = 1
        
        try context.save()
        
        progressTracker.saveProgress(for: episode, progress: 0.6)
        
        let restored = progressTracker.restoreProgress(for: episode)
        XCTAssertEqual(restored, 0.6, accuracy: 0.01)
    }

    func testProgressClampedBetweenZeroAndOne() throws {
        let movie = Movie(context: context)
        movie.title = "Test Movie"
        try context.save()
        
        // Try to save invalid progress values
        progressTracker.saveProgress(for: movie, progress: 1.5)
        let progress1 = progressTracker.restoreProgress(for: movie)
        XCTAssertLessThanOrEqual(progress1, 1.0)
        
        progressTracker.saveProgress(for: movie, progress: -0.5)
        let progress2 = progressTracker.restoreProgress(for: movie)
        XCTAssertGreaterThanOrEqual(progress2, 0.0)
    }

    func testLastWatchedDateUpdates() throws {
        let movie = Movie(context: context)
        movie.title = "Test Movie"
        try context.save()
        
        let before = Date()
        progressTracker.saveProgress(for: movie, progress: 0.5)
        
        let history = WatchHistoryManager(context: context, profile: profile)
            .findWatchHistory(for: movie)
        
        XCTAssertNotNil(history?.watchedDate)
        
        if let watchedDate = history?.watchedDate {
            XCTAssertGreaterThanOrEqual(watchedDate, before)
        }
    }

    func testMultipleProfilesHaveIndependentProgress() throws {
        let movie = Movie(context: context)
        movie.title = "Test Movie"
        
        let profile2 = Profile(context: context)
        profile2.name = "Profile 2"
        profile2.isAdult = false
        
        try context.save()
        
        let tracker1 = PlaybackProgressTracker(context: context, profile: profile)
        let tracker2 = PlaybackProgressTracker(context: context, profile: profile2)
        
        tracker1.saveProgress(for: movie, progress: 0.3)
        tracker2.saveProgress(for: movie, progress: 0.8)
        
        let progress1 = tracker1.restoreProgress(for: movie)
        let progress2 = tracker2.restoreProgress(for: movie)
        
        XCTAssertEqual(progress1, 0.3, accuracy: 0.01)
        XCTAssertEqual(progress2, 0.8, accuracy: 0.01)
    }
}
