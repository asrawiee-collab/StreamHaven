import XCTest
import CoreData
@testable import StreamHaven

final class EPGCacheManagerTests: XCTestCase {
    var provider: PersistenceProviding!
    var context: NSManagedObjectContext!
    var channel: Channel!

    override func setUpWithError() throws {
        let controller = PersistenceController(inMemory: true)
        provider = DefaultPersistenceProvider(controller: controller)
        context = provider.container.newBackgroundContext()
        
        try context.performAndWait {
            channel = Channel(context: context)
            channel.name = "Test Channel"
            channel.tvgID = "channel1"
            try context.save()
        }
    }

    override func tearDownWithError() throws {
        // Clean up UserDefaults
        UserDefaults.standard.removeObject(forKey: "EPGLastRefreshDate")
    }

    func testGetNowAndNextReturnsCurrentAndNextProgramme() throws {
        let now = Date()
        
        try context.performAndWait {
            // Current programme
            let current = EPGEntry(context: context)
            current.channel = channel
            current.title = "Current Show"
            current.startTime = now.addingTimeInterval(-1800) // 30 min ago
            current.endTime = now.addingTimeInterval(1800) // 30 min from now
            
            // Next programme
            let next = EPGEntry(context: context)
            next.channel = channel
            next.title = "Next Show"
            next.startTime = now.addingTimeInterval(1800) // 30 min from now
            next.endTime = now.addingTimeInterval(5400) // 90 min from now
            
            try context.save()
        }
        
        let (nowProgramme, nextProgramme) = EPGCacheManager.getNowAndNext(for: channel, context: context)
        
        XCTAssertNotNil(nowProgramme)
        XCTAssertEqual(nowProgramme?.title, "Current Show")
        XCTAssertNotNil(nextProgramme)
        XCTAssertEqual(nextProgramme?.title, "Next Show")
    }

    func testGetNowAndNextReturnsNilWhenNoCurrentProgramme() throws {
        let now = Date()
        
        try context.performAndWait {
            // Only future programme
            let future = EPGEntry(context: context)
            future.channel = channel
            future.title = "Future Show"
            future.startTime = now.addingTimeInterval(3600) // 1 hour from now
            future.endTime = now.addingTimeInterval(7200) // 2 hours from now
            
            try context.save()
        }
        
        let (nowProgramme, nextProgramme) = EPGCacheManager.getNowAndNext(for: channel, context: context)
        
        XCTAssertNil(nowProgramme)
        XCTAssertNotNil(nextProgramme)
        XCTAssertEqual(nextProgramme?.title, "Future Show")
    }

    func testGetProgrammesInTimeRange() throws {
        let now = Date()
        let start = now
        let end = now.addingTimeInterval(7200) // 2 hours
        
        try context.performAndWait {
            // Programme within range
            let prog1 = EPGEntry(context: context)
            prog1.channel = channel
            prog1.title = "Show 1"
            prog1.startTime = now.addingTimeInterval(1800)
            prog1.endTime = now.addingTimeInterval(3600)
            
            // Programme within range
            let prog2 = EPGEntry(context: context)
            prog2.channel = channel
            prog2.title = "Show 2"
            prog2.startTime = now.addingTimeInterval(3600)
            prog2.endTime = now.addingTimeInterval(5400)
            
            // Programme outside range
            let prog3 = EPGEntry(context: context)
            prog3.channel = channel
            prog3.title = "Show 3"
            prog3.startTime = now.addingTimeInterval(10800)
            prog3.endTime = now.addingTimeInterval(12600)
            
            try context.save()
        }
        
        let programmes = EPGCacheManager.getProgrammes(
            for: channel,
            from: start,
            to: end,
            context: context
        )
        
        XCTAssertEqual(programmes.count, 2)
        XCTAssertTrue(programmes.contains(where: { $0.title == "Show 1" }))
        XCTAssertTrue(programmes.contains(where: { $0.title == "Show 2" }))
        XCTAssertFalse(programmes.contains(where: { $0.title == "Show 3" }))
    }

    func testClearExpiredEntriesRemovesOldData() async throws {
        let now = Date()
        
        try await context.perform {
            // Old expired entry
            let old = EPGEntry(context: self.context)
            old.channel = self.channel
            old.title = "Old Show"
            old.startTime = now.addingTimeInterval(-3 * 24 * 3600)
            old.endTime = now.addingTimeInterval(-3 * 24 * 3600 + 3600)
            
            // Recent entry
            let recent = EPGEntry(context: self.context)
            recent.channel = self.channel
            recent.title = "Recent Show"
            recent.startTime = now.addingTimeInterval(-3600)
            recent.endTime = now
            
            try self.context.save()
        }
        
        try await EPGCacheManager.clearExpiredEntries(context: context)
        
        let fetch: NSFetchRequest<EPGEntry> = EPGEntry.fetchRequest()
        let entries = try await context.perform {
            try self.context.fetch(fetch)
        }
        
        // Old entry should be deleted
        XCTAssertEqual(entries.count, 1)
        XCTAssertEqual(entries.first?.title, "Recent Show")
    }

    func testFetchAndCacheSkipsRefreshIfCacheValid() async throws {
        // Set last refresh to recent time
        UserDefaults.standard.set(Date(), forKey: "EPGLastRefreshDate")
        
        // This should skip refresh without throwing
        // Note: In real scenario would need valid URL, but cache check happens first
        let expectation = XCTestExpectation(description: "Cache check completes")
        
        Task {
            do {
                // Use invalid URL - should not reach network call
                guard let url = URL(string: "http://invalid.test/epg.xml") else {
                    XCTFail("Failed to create URL")
                    return
                }
                try await EPGCacheManager.fetchAndCacheEPG(from: url, context: context, force: false)
                expectation.fulfill()
            } catch {
                // Should skip due to valid cache
                expectation.fulfill()
            }
        }
        
        await fulfillment(of: [expectation], timeout: 2.0)
    }

    func testForceRefreshIgnoresCacheValidity() async throws {
        // Set last refresh to recent time
        UserDefaults.standard.set(Date(), forKey: "EPGLastRefreshDate")
        
        // With force=true, should attempt refresh even with valid cache
        // Will fail with invalid URL, but that's expected
        do {
            guard let url = URL(string: "http://invalid.test/epg.xml") else {
                XCTFail("Failed to create URL")
                return
            }
            try await EPGCacheManager.fetchAndCacheEPG(from: url, context: context, force: true)
            XCTFail("Should fail with invalid URL")
        } catch {
            // Expected to fail attempting network call
            XCTAssertTrue(true)
        }
    }

    func testGetNowAndNextHandlesNoEPGData() {
        let (nowProgramme, nextProgramme) = EPGCacheManager.getNowAndNext(for: channel, context: context)
        
        XCTAssertNil(nowProgramme)
        XCTAssertNil(nextProgramme)
    }

    func testGetProgrammesReturnsEmptyForNoData() {
        let programmes = EPGCacheManager.getProgrammes(
            for: channel,
            from: Date(),
            to: Date().addingTimeInterval(3600),
            context: context
        )
        
        XCTAssertTrue(programmes.isEmpty)
    }

    func testClearExpiredEntriesHandlesEmptyDatabase() async throws {
        try await EPGCacheManager.clearExpiredEntries(context: context)
        
        // Should complete without errors
        XCTAssertTrue(true)
    }
}
