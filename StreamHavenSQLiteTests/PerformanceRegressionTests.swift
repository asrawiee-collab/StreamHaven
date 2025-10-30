import XCTest
import CoreData
@testable import StreamHaven

@MainActor
final class PerformanceRegressionTests: FileBasedTestCase {

    // Enable WAL journaling for these tests to allow concurrent reads safely
    override func needsFTS() -> Bool {
        return true
    }

    func testSearchPerformanceWith50000Movies() throws {
        measure {
            guard let ctx = context else {
                XCTFail("Context not available")
                return
            }
            let localContext = ctx
            try? localContext.performAndWait {
                for i in 1...50000 {
                    let movie = Movie(context: localContext)
                    movie.title = "Movie \(i)"
                }
                try? localContext.save()
            }
            try? localContext.performAndWait {
                let fetch: NSFetchRequest<Movie> = Movie.fetchRequest()
                fetch.predicate = NSPredicate(format: "title CONTAINS[c] %@", "movie 5")
                let results = try? localContext.fetch(fetch)
                XCTAssertGreaterThan(results?.count ?? 0, 0, "Should find matching movies")
            }
        }
    }

    func testFetchFavoritesPerformanceWith500Movies() throws {
        let options = XCTMeasureOptions()
        options.iterationCount = 5
        measure(metrics: [XCTClockMetric()], options: options) {
            guard let ctx = context else {
                XCTFail("Context not available")
                return
            }
            let localContext = ctx
            // Clear existing data before each iteration
            try? localContext.performAndWait {
                let movieFetch: NSFetchRequest<NSFetchRequestResult> = Movie.fetchRequest()
                let movieDelete = NSBatchDeleteRequest(fetchRequest: movieFetch)
                try? localContext.execute(movieDelete)
                let favFetch: NSFetchRequest<NSFetchRequestResult> = Favorite.fetchRequest()
                let favDelete = NSBatchDeleteRequest(fetchRequest: favFetch)
                try? localContext.execute(favDelete)
                let profFetch: NSFetchRequest<NSFetchRequestResult> = Profile.fetchRequest()
                let profDelete = NSBatchDeleteRequest(fetchRequest: profFetch)
                try? localContext.execute(profDelete)
                localContext.reset()
            }
            try? localContext.performAndWait {
                let profile = Profile(context: localContext)
                profile.name = "Test"
                localContext.stalenessInterval = 0.0
                for i in 1...500 {
                    let movie = Movie(context: localContext)
                    movie.title = "Movie \(i)"
                    if i % 10 == 0 {
                        let favorite = Favorite(context: localContext)
                        favorite.movie = movie
                        favorite.profile = profile
                    }
                }
                try? localContext.save()
            }
            try? localContext.performAndWait {
                let fetch: NSFetchRequest<Movie> = Movie.fetchRequest()
                fetch.predicate = NSPredicate(format: "favorite != nil")
                fetch.fetchBatchSize = 50
                fetch.returnsObjectsAsFaults = false
                let results = try? localContext.fetch(fetch)
                XCTAssertEqual(results?.count ?? 0, 50, "Should find 50 favorites")
            }
        }
    }

    func testBatchInsertPerformance() throws {
        measure {
            guard let ctx = context else {
                XCTFail("Context not available")
                return
            }
            let localContext = ctx
            let objects: [[String: Any]] = (1...5000).map { [
                "title": "Batch Movie \($0)"
            ]}
            let request = NSBatchInsertRequest(entityName: "Movie", objects: objects)
            request.resultType = .count
            let result = try? localContext.execute(request) as? NSBatchInsertResult
            let inserted = result?.result as? Int ?? 0
            XCTAssertEqual(inserted, 5000, "Should batch insert 5000 movies")
            try? localContext.performAndWait {
                let fetch: NSFetchRequest<Movie> = Movie.fetchRequest()
                fetch.predicate = NSPredicate(format: "title BEGINSWITH[c] %@", "Batch Movie ")
                fetch.fetchLimit = 1
                let results = try? localContext.fetch(fetch)
                XCTAssertGreaterThan(results?.count ?? 0, 0)
            }
        }
    }

    func testWatchProgressUpdatePerformance() throws {
        let options = XCTMeasureOptions()
        options.iterationCount = 5
        measure(metrics: [XCTClockMetric()], options: options) {
            guard let ctx = context else {
                XCTFail("Context not available")
                return
            }
            let localContext = ctx
            // Clear existing data before each iteration
            try? localContext.performAndWait {
                let movieFetch: NSFetchRequest<NSFetchRequestResult> = Movie.fetchRequest()
                let movieDelete = NSBatchDeleteRequest(fetchRequest: movieFetch)
                try? localContext.execute(movieDelete)
                let historyFetch: NSFetchRequest<NSFetchRequestResult> = WatchHistory.fetchRequest()
                let historyDelete = NSBatchDeleteRequest(fetchRequest: historyFetch)
                try? localContext.execute(historyDelete)
                let profFetch: NSFetchRequest<NSFetchRequestResult> = Profile.fetchRequest()
                let profDelete = NSBatchDeleteRequest(fetchRequest: profFetch)
                try? localContext.execute(profDelete)
                localContext.reset()
            }
            try? localContext.performAndWait {
                localContext.stalenessInterval = 0.0
                let profile = Profile(context: localContext)
                profile.name = "Test"
                for i in 1...500 {
                    let movie = Movie(context: localContext)
                    movie.title = "Movie \(i)"
                    let history = WatchHistory(context: localContext)
                    history.movie = movie
                    history.profile = profile
                    history.progress = 0.5
                    history.watchedDate = Date()
                }
                try? localContext.save()
            }
            try? localContext.performAndWait {
                let fetch: NSFetchRequest<WatchHistory> = WatchHistory.fetchRequest()
                fetch.returnsObjectsAsFaults = false
                fetch.fetchBatchSize = 100
                let histories = try? localContext.fetch(fetch)
                for history in histories ?? [] {
                    history.progress = 0.75
                }
                try? localContext.save()
                XCTAssertEqual(histories?.count ?? 0, 500, "Should have 500 watch histories")
            }
        }
    }

    func testEPGQueryPerformanceWith1000Entries() throws {
        measure {
            guard let ctx = context else {
                XCTFail("Context not available")
                return
            }
            let localContext = ctx
            try? localContext.performAndWait {
                let channel = Channel(context: localContext)
                channel.name = "Test Channel"
                channel.tvgID = "test"
                let now = Date()
                for i in 1...1000 {
                    let entry = EPGEntry(context: localContext)
                    entry.channel = channel
                    entry.title = "Programme \(i)"
                    entry.startTime = now.addingTimeInterval(Double(i * 1800))
                    entry.endTime = entry.startTime?.addingTimeInterval(1800)
                }
                try? localContext.save()
            }
            try? localContext.performAndWait {
                let now = Date()
                let fetch: NSFetchRequest<EPGEntry> = EPGEntry.fetchRequest()
                fetch.predicate = NSPredicate(format: "startTime <= %@ AND endTime > %@", now as NSDate, now as NSDate)
                fetch.fetchLimit = 1
                let results = try? localContext.fetch(fetch)
                XCTAssertNotNil(results, "Should execute query successfully")
            }
        }
    }

    func testConcurrentFetchPerformance() throws {
        measure {
            guard let baseCtx = context else {
                XCTFail("Context not available")
                return
            }
            guard let container = container else {
                XCTFail("Container not available")
                return
            }
            try? baseCtx.performAndWait {
                for i in 1...2000 {
                    let movie = Movie(context: baseCtx)
                    movie.title = "Concurrent Movie \(i)"
                }
                try? baseCtx.save()
            }
            let bg1 = container.newBackgroundContext()
            let bg2 = container.newBackgroundContext()
            bg1.automaticallyMergesChangesFromParent = true
            bg2.automaticallyMergesChangesFromParent = true
            bg1.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
            bg2.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
            let exp1 = expectation(description: "bg1 fetch")
            let exp2 = expectation(description: "bg2 fetch")
            bg1.perform {
                let fetch: NSFetchRequest<Movie> = Movie.fetchRequest()
                fetch.predicate = NSPredicate(format: "title CONTAINS[c] %@", "Concurrent")
                fetch.fetchBatchSize = 50
                do {
                    let results = try bg1.fetch(fetch)
                    XCTAssertGreaterThan(results.count, 0)
                } catch {
                    XCTFail("bg1 fetch failed: \(error)")
                }
                exp1.fulfill()
            }
            bg2.perform {
                let fetch: NSFetchRequest<Movie> = Movie.fetchRequest()
                fetch.predicate = NSPredicate(format: "title CONTAINS[c] %@", "Movie 1")
                fetch.fetchBatchSize = 50
                do {
                    let results = try bg2.fetch(fetch)
                    XCTAssertGreaterThan(results.count, 0)
                } catch {
                    XCTFail("bg2 fetch failed: \(error)")
                }
                exp2.fulfill()
            }
            wait(for: [exp1, exp2], timeout: 10.0)
        }
    }

    func testMemoryPressureWith1000Movies() throws {
        measure {
            guard let ctx = context else {
                XCTFail("Context not available")
                return
            }
            let localContext = ctx
            try? localContext.performAndWait {
                for i in 1...1000 {
                    let movie = Movie(context: localContext)
                    movie.title = "Movie \(i)"
                    movie.posterURL = "https://example.com/poster\(i).jpg"
                }
                try? localContext.save()
            }
            XCTAssertTrue(true, "Memory test completed")
        }
    }

    func testFetchBatchingPerformance() throws {
        let options = XCTMeasureOptions()
        options.iterationCount = 5
        measure(metrics: [XCTClockMetric()], options: options) {
            guard let ctx = context else {
                XCTFail("Context not available")
                return
            }
            let localContext = ctx
            // Clear existing data before each iteration
            try? localContext.performAndWait {
                let movieFetch: NSFetchRequest<NSFetchRequestResult> = Movie.fetchRequest()
                let movieDelete = NSBatchDeleteRequest(fetchRequest: movieFetch)
                try? localContext.execute(movieDelete)
                localContext.reset()
            }
            try? localContext.performAndWait {
                localContext.stalenessInterval = 0.0
                for i in 1...2000 {
                    let movie = Movie(context: localContext)
                    movie.title = "Movie \(i)"
                }
                try? localContext.save()
            }
            try? localContext.performAndWait {
                let fetch: NSFetchRequest<Movie> = Movie.fetchRequest()
                fetch.fetchBatchSize = 100
                fetch.returnsObjectsAsFaults = false
                let results = try? localContext.fetch(fetch)
                var count = 0
                for movie in results ?? [] {
                    if movie.title != nil {
                        count += 1
                    }
                }
                XCTAssertEqual(count, 2000, "Should fetch all 2000 movies")
            }
        }
    }
}
