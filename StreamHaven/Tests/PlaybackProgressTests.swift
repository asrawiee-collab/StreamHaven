import XCTest
import CoreData
import AVKit
@testable import StreamHaven

@MainActor
final class PlaybackProgressTests: XCTestCase {
    var provider: PersistenceProviding!
    var context: NSManagedObjectContext!
    var profile: Profile!
    var watchHistoryManager: WatchHistoryManager!

    override func setUpWithError() throws {
        let container = NSPersistentContainer(
            name: "PlaybackProgressTest",
            managedObjectModel: TestCoreDataModelBuilder.sharedModel
        )
        let description = NSPersistentStoreDescription()
        description.type = NSInMemoryStoreType
        container.persistentStoreDescriptions = [description]
        
        var loadError: Error?
        container.loadPersistentStores { _, error in
            loadError = error
        }
        
        if let error = loadError {
            throw error
        }
        
        provider = TestPersistenceProvider(container: container)
        context = provider.container.viewContext
        
        profile = Profile(context: context)
        profile.name = "Test"
        profile.isAdult = true
        try context.save()
        
        watchHistoryManager = WatchHistoryManager(context: context, profile: profile)
    }

    func testSavesProgressForMovie() throws {
        let movie = Movie(context: context)
        movie.title = "Test Movie"
        try context.save()
        
        watchHistoryManager.updateWatchHistory(for: movie, progress: 0.5)
        
        let history = watchHistoryManager.findWatchHistory(for: movie)
        
        XCTAssertNotNil(history)
        XCTAssertEqual(history?.progress, 0.5)
    }

    func testUpdatesExistingProgress() throws {
        let movie = Movie(context: context)
        movie.title = "Test Movie"
        try context.save()
        
        watchHistoryManager.updateWatchHistory(for: movie, progress: 0.3)
        watchHistoryManager.updateWatchHistory(for: movie, progress: 0.7)
        
        let history = watchHistoryManager.findWatchHistory(for: movie)
        
        XCTAssertEqual(history?.progress, 0.7)
    }

    func testRestoresProgressForMovie() throws {
        let movie = Movie(context: context)
        movie.title = "Test Movie"
        try context.save()
        
        watchHistoryManager.updateWatchHistory(for: movie, progress: 0.45)
        
        let history = watchHistoryManager.findWatchHistory(for: movie)
        
        XCTAssertEqual(Double(history?.progress ?? 0), 0.45, accuracy: 0.01)
    }

    func testReturnsZeroProgressForUnwatchedContent() throws {
        let movie = Movie(context: context)
        movie.title = "Unwatched Movie"
        try context.save()
        
        let history = watchHistoryManager.findWatchHistory(for: movie)
        
        XCTAssertNil(history)
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
        
        watchHistoryManager.updateWatchHistory(for: episode, progress: 0.6)
        
        let history = watchHistoryManager.findWatchHistory(for: episode)
        XCTAssertEqual(Double(history?.progress ?? 0), 0.6, accuracy: 0.01)
    }

    func testLastWatchedDateUpdates() throws {
        let movie = Movie(context: context)
        movie.title = "Test Movie"
        try context.save()
        
        let before = Date()
        watchHistoryManager.updateWatchHistory(for: movie, progress: 0.5)
        
        let history = watchHistoryManager.findWatchHistory(for: movie)
        
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
        
        let watchHistoryManager2 = WatchHistoryManager(context: context, profile: profile2)
        
        watchHistoryManager.updateWatchHistory(for: movie, progress: 0.3)
        watchHistoryManager2.updateWatchHistory(for: movie, progress: 0.8)
        
        let history1 = watchHistoryManager.findWatchHistory(for: movie)
        let history2 = watchHistoryManager2.findWatchHistory(for: movie)
        
        XCTAssertEqual(Double(history1?.progress ?? 0), 0.3, accuracy: 0.01)
        XCTAssertEqual(Double(history2?.progress ?? 0), 0.8, accuracy: 0.01)
    }
}

private struct TestPersistenceProvider: PersistenceProviding {
    let container: NSPersistentContainer
}
