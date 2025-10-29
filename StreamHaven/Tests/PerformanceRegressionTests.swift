import XCTest
import CoreData
@testable import StreamHaven

final class PerformanceRegressionTests: XCTestCase {
    var provider: PersistenceProviding!
    var context: NSManagedObjectContext!

    override func setUpWithError() throws {
        throw XCTSkip("PerformanceRegressionTests require file-based Core Data store")
        let controller = PersistenceController(inMemory: true)
        provider = DefaultPersistenceProvider(controller: controller)
        context = provider.container.newBackgroundContext()
    }

    func testSearchPerformanceWith10KMovies() throws {
        measure {
            try! context.performAndWait {
                // Create 10K movies
                for i in 1...10_000 {
                    let movie = Movie(context: context)
                    movie.title = "Movie \(i)"
                }
                try context.save()
                
                // Search benchmark
                let fetch: NSFetchRequest<Movie> = Movie.fetchRequest()
                fetch.predicate = NSPredicate(format: "title CONTAINS[c] %@", "movie 5")
                
                _ = try context.fetch(fetch)
            }
        }
    }

    func testFTSSearchPerformanceWith50KEntries() throws {
        // TODO: Update this test to use the new FTS implementation
    }

    func testFetchFavoritesPerformanceWith100KMovies() throws {
        try context.performAndWait {
            let profile = Profile(context: context)
            profile.name = "Test"
            
            // Create 100K movies, mark 10K as favorites
            for i in 1...100_000 {
                let movie = Movie(context: context)
                movie.title = "Movie \(i)"
                if i % 10 == 0 {
                    let favorite = Favorite(context: context)
                    favorite.movie = movie
                    favorite.profile = profile
                }
                
                if i % 1000 == 0 {
                    try context.save()
                }
            }
            try context.save()
        }
        
        measure {
            try! context.performAndWait {
                let fetch: NSFetchRequest<Movie> = Movie.fetchRequest()
                fetch.predicate = NSPredicate(format: "favorite != nil")
                
                let results = try context.fetch(fetch)
                XCTAssertEqual(results.count, 10_000)
            }
        }
    }

    func testBatchInsertPerformance() throws {
        measure {
            try! context.performAndWait {
                let batchInsert = NSBatchInsertRequest(entity: Movie.entity()) { (managedObject: NSManagedObject) -> Bool in
                    let movie = managedObject as! Movie
                    movie.title = "Batch Movie"
                    return false
                }
                batchInsert.resultType = .count
                
                _ = try context.execute(batchInsert)
            }
        }
    }

    func testWatchProgressUpdatePerformance() throws {
        // Create test data
        try context.performAndWait {
            let profile = Profile(context: context)
            profile.name = "Test"
            
            for i in 1...1000 {
                let movie = Movie(context: context)
                movie.title = "Movie \(i)"
                
                let history = WatchHistory(context: context)
                history.movie = movie
                history.profile = profile
                history.progress = 0.5
                history.watchedDate = Date()
            }
            try context.save()
        }
        
        measure {
            try! context.performAndWait {
                let fetch: NSFetchRequest<WatchHistory> = WatchHistory.fetchRequest()
                let histories = try context.fetch(fetch)
                
                // Update all watch progress
                for history in histories {
                    history.progress = 0.75
                }
                
                try context.save()
            }
        }
    }

    func testDenormalizationRebuildPerformance() throws {
        // TODO: Update this test to use the new data model
    }

    func testEPGQueryPerformanceWith100KEntries() throws {
        try context.performAndWait {
            let channel = Channel(context: context)
            channel.name = "Test Channel"
            channel.tvgID = "test"
            
            let now = Date()
            
            // Create 100K EPG entries (1 week of programming every 30 min = ~336 entries per day * 7)
            for i in 1...100_000 {
                let entry = EPGEntry(context: context)
                entry.channel = channel
                entry.title = "Programme \(i)"
                entry.startTime = now.addingTimeInterval(Double(i * 1800)) // 30 min intervals
                entry.endTime = entry.startTime?.addingTimeInterval(1800)
                
                if i % 1000 == 0 {
                    try context.save()
                }
            }
            try context.save()
        }
        
        measure {
            try! context.performAndWait {
                let now = Date()
                let fetch: NSFetchRequest<EPGEntry> = EPGEntry.fetchRequest()
                fetch.predicate = NSPredicate(format: "startTime <= %@ AND endTime > %@", now as NSDate, now as NSDate)
                fetch.fetchLimit = 1
                
                _ = try context.fetch(fetch)
            }
        }
    }

    func testConcurrentFetchPerformance() throws {
        // Create test data
        try context.performAndWait {
            for i in 1...5000 {
                let movie = Movie(context: context)
                movie.title = "Movie \(i)"
            }
            try context.save()
        }
        
        measure {
            let expectation = XCTestExpectation(description: "Concurrent fetches")
            expectation.expectedFulfillmentCount = 10
            
            for _ in 1...10 {
                Task {
                    let bgContext = self.provider.container.newBackgroundContext()
                    try! bgContext.performAndWait {
                        let fetch: NSFetchRequest<Movie> = Movie.fetchRequest()
                        fetch.predicate = NSPredicate(format: "title == %@", "Movie 1")
                        _ = try bgContext.fetch(fetch)
                    }
                    expectation.fulfill()
                }
            }
            
            self.wait(for: [expectation], timeout: 10.0)
        }
    }

    func testMemoryPressureWith100KMovies() throws {
        measure(metrics: [XCTMemoryMetric()]) {
            try! context.performAndWait {
                // Create 100K movies
                for i in 1...100_000 {
                    let movie = Movie(context: context)
                    movie.title = "Movie \(i)"
                    movie.posterURL = "https://example.com/poster\(i).jpg"
                    
                    if i % 1000 == 0 {
                        try context.save()
                        context.reset() // Free memory
                    }
                }
                try context.save()
            }
        }
    }

    func testFetchBatchingPerformance() throws {
        try context.performAndWait {
            for i in 1...50_000 {
                let movie = Movie(context: context)
                movie.title = "Movie \(i)"
            }
            try context.save()
        }
        
        measure {
            try! context.performAndWait {
                let fetch: NSFetchRequest<Movie> = Movie.fetchRequest()
                fetch.fetchBatchSize = 100
                
                let results = try context.fetch(fetch)
                
                // Access all to trigger faulting
                var count = 0
                for movie in results {
                    if movie.title != nil {
                        count += 1
                    }
                }
                
                XCTAssertEqual(count, 50_000)
            }
        }
    }
}
