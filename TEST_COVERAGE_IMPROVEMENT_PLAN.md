# Test Coverage Improvement Plan

## Current Status

- **217 passing tests** (unit tests with in-memory stores)
- **~50 skipped tests** representing critical functionality
- **Estimated coverage**: 60-70% (significant gaps in batch operations, FTS, file I/O, integration flows)

## Problem Summary

The majority of skipped tests fail because they require features incompatible with in-memory NSPersistentStore:

1. **NSBatchInsertRequest/NSBatchDeleteRequest** - Not supported by in-memory stores
2. **SQLite FTS5 virtual tables** - Require file-based SQLite database
3. **File I/O operations** - PlaylistCacheManager writes to disk
4. **Performance tests** - Need realistic persistent store behavior

## Untested Components

### Critical (High Priority)

1. **EPGParser** (`EPGParser.swift`)
   - XML parsing logic
   - Batch delete operations for old entries
   - EPG entry creation and validation
   - **Files affected**: `EPGParserTests.swift`, `ErrorPropagationTests.swift`, `IntegrationTests.swift`

2. **M3UPlaylistParser** (`M3UPlaylistParser.swift`)
   - Batch insert operations (NSBatchInsertRequest)
   - Large playlist parsing (1000+ channels)
   - Duplicate detection
   - **Files affected**: `M3UPlaylistParserTests.swift`, `ParserPerformanceTests.swift`

3. **FullTextSearchManager** (`FullTextSearchManager.swift`)
   - FTS5 initialization
   - Search query execution
   - Index maintenance
   - **Files affected**: `FullTextSearchManagerTests.swift`, `FTSTriggerTests.swift`

4. **PlaylistCacheManager** (`PlaylistCacheManager.swift`)
   - File write/read operations
   - Cache expiration logic
   - Concurrent caching
   - **Files affected**: `PlaylistCacheManagerStressTests.swift`

### Important (Medium Priority)

5. **FranchiseGroupingManager** (`FranchiseGroupingManager.swift`)
   - Movie franchise detection
   - TMDb integration
   - **Files affected**: `FranchiseGroupingTests.swift`

6. **OptimizedFetchRequests** (`OptimizedFetchRequests.swift`)
   - Batch faulting
   - Prefetching strategies
   - **Files affected**: `OptimizedFetchTests.swift`

7. **PlaybackProgress/WatchHistory**
   - Multi-profile progress tracking
   - Progress persistence
   - **Files affected**: `PlaybackProgressTests.swift`

### Lower Priority

8. **Performance Regression Tests**
   - Parsing benchmarks
   - Memory usage monitoring
   - **Files affected**: `PerformanceRegressionTests.swift`

9. **Edge Cases**
   - Malformed M3U data
   - Invalid EPG XML
   - **Files affected**: `M3UPlaylistParserEdgeCasesTests.swift`

## Solution Strategy

### Phase 1: File-Based Test Infrastructure (2-3 hours)

#### 1.1 Create FileBasedTestCoreDataModelBuilder

```swift
// StreamHaven/Tests/Helpers/FileBasedTestCoreDataModelBuilder.swift

import CoreData

class FileBasedTestCoreDataModelBuilder {
    static func createTestContainer(withFTS: Bool = false) throws -> NSPersistentContainer {
        let container = NSPersistentContainer(
            name: "StreamHavenTest",
            managedObjectModel: TestCoreDataModelBuilder.sharedModel
        )
        
        // Create temporary directory for test database
        let tempDir = FileManager.default.temporaryDirectory
        let testDBURL = tempDir.appendingPathComponent("StreamHavenTest_\(UUID().uuidString).sqlite")
        
        let description = NSPersistentStoreDescription(url: testDBURL)
        description.type = NSSQLiteStoreType
        
        if withFTS {
            // Enable FTS5
            description.setOption(true as NSNumber, forKey: "enableFTS")
        }
        
        container.persistentStoreDescriptions = [description]
        
        var loadError: Error?
        let semaphore = DispatchSemaphore(value: 0)
        container.loadPersistentStores { _, error in
            loadError = error
            semaphore.signal()
        }
        semaphore.wait()
        
        if let error = loadError {
            throw error
        }
        
        return container
    }
    
    static func destroyTestContainer(_ container: NSPersistentContainer) {
        guard let storeURL = container.persistentStoreDescriptions.first?.url else { return }
        
        // Remove all persistent stores
        for store in container.persistentStoreCoordinator.persistentStores {
            try? container.persistentStoreCoordinator.remove(store)
        }
        
        // Delete files
        try? FileManager.default.removeItem(at: storeURL)
        try? FileManager.default.removeItem(at: storeURL.appendingPathExtension("shm"))
        try? FileManager.default.removeItem(at: storeURL.appendingPathExtension("wal"))
    }
}
```

#### 1.2 Create Base Test Classes

```swift
// StreamHaven/Tests/Helpers/FileBasedTestCase.swift

import XCTest
import CoreData
@testable import StreamHaven

class FileBasedTestCase: XCTestCase {
    var container: NSPersistentContainer!
    var context: NSManagedObjectContext!
    var persistenceProvider: PersistenceProviding!
    
    override func setUp() {
        super.setUp()
        do {
            container = try FileBasedTestCoreDataModelBuilder.createTestContainer(withFTS: needsFTS())
            context = container.viewContext
            
            struct TestProvider: PersistenceProviding {
                let container: NSPersistentContainer
            }
            persistenceProvider = TestProvider(container: container)
        } catch {
            XCTFail("Failed to create test container: \(error)")
        }
    }
    
    override func tearDown() {
        context = nil
        persistenceProvider = nil
        if let container = container {
            FileBasedTestCoreDataModelBuilder.destroyTestContainer(container)
        }
        container = nil
        super.tearDown()
    }
    
    /// Override in subclasses that need FTS
    func needsFTS() -> Bool {
        return false
    }
}
```

### Phase 2: Re-enable Critical Tests (3-4 hours)

#### 2.1 EPG Parser Tests

**File**: `EPGParserTests.swift`

**Changes needed**:

```swift
class EPGParserTests: FileBasedTestCase {
    // Remove XCTSkip from setUpWithError
    // Tests will now run with file-based store supporting NSBatchDeleteRequest
    
    override func needsFTS() -> Bool {
        return false // EPG doesn't need FTS
    }
}
```

**Test count**: ~15 tests covering EPG XML parsing, batch operations, date handling

#### 2.2 M3U Parser Tests

**File**: `M3UPlaylistParserTests.swift`

**Changes needed**:

```swift
class M3UPlaylistParserTests: FileBasedTestCase {
    // Remove XCTSkip
    // Use background context for async operations
    
    func testBatchInsertSmallPlaylist() throws {
        let expectation = XCTestExpectation(description: "Parse small playlist")
        let bgContext = container.newBackgroundContext()
        
        bgContext.perform {
            // Generate M3U data
            let m3uData = self.generateM3UPlaylist(channelCount: 100)
            
            do {
                try M3UPlaylistParser.parse(data: m3uData, context: bgContext)
                
                // Verify count
                let count = try bgContext.count(for: Channel.fetchRequest())
                XCTAssertEqual(count, 100)
                
                expectation.fulfill()
            } catch {
                XCTFail("Parse failed: \(error)")
            }
        }
        
        wait(for: [expectation], timeout: 10.0)
    }
}
```

**Test count**: ~20 tests covering batch inserts, parsing variations, duplicate handling

#### 2.3 Full-Text Search Tests

**Files**: `FullTextSearchManagerTests.swift`, `FTSTriggerTests.swift`

**Changes needed**:

```swift
class FullTextSearchManagerTests: FileBasedTestCase {
    override func needsFTS() -> Bool {
        return true // Enable FTS5
    }
    
    func testFTSInitialization() throws {
        let manager = FullTextSearchManager(persistenceProvider: persistenceProvider)
        
        // Verify FTS tables created
        let sql = "SELECT name FROM sqlite_master WHERE type='table' AND name LIKE '%_fts'"
        // Execute raw SQL to verify FTS tables exist
        
        XCTAssertTrue(manager.isReady)
    }
    
    func testSearchMovies() throws {
        // Create test movies
        let movie1 = Movie(context: context)
        movie1.title = "The Dark Knight"
        
        let movie2 = Movie(context: context)
        movie2.title = "The Dark Knight Rises"
        
        try context.save()
        
        // Search
        let results = FullTextSearchManager.search(query: "dark knight", context: context)
        XCTAssertEqual(results.count, 2)
    }
}
```

**Test count**: ~10 tests covering FTS initialization, search queries, triggers

#### 2.4 Playlist Cache Manager Tests

**File**: `PlaylistCacheManagerStressTests.swift`

**Changes needed**:

```swift
class PlaylistCacheManagerStressTests: FileBasedTestCase {
    var cacheDirectory: URL!
    
    override func setUp() {
        super.setUp()
        // Create temp cache directory
        cacheDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("TestCache_\(UUID().uuidString)")
        try? FileManager.default.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
    }
    
    override func tearDown() {
        // Clean up cache directory
        try? FileManager.default.removeItem(at: cacheDirectory)
        super.tearDown()
    }
    
    func testCacheAndRetrieve() throws {
        let url = URL(string: "https://example.com/test.m3u8")!
        let testData = "test playlist data".data(using: .utf8)!
        
        let expectation = XCTestExpectation(description: "Cache and retrieve")
        let bgContext = container.newBackgroundContext()
        
        bgContext.perform {
            // Cache
            let path = PlaylistCacheManager.cachePlaylist(
                url: url,
                data: testData,
                context: bgContext
            )
            XCTAssertNotNil(path)
            
            // Retrieve
            let retrieved = PlaylistCacheManager.getCachedPlaylist(
                url: url,
                context: bgContext
            )
            XCTAssertEqual(retrieved, testData)
            
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 5.0)
    }
}
```

**Test count**: ~8 tests covering caching, retrieval, expiration, concurrency

### Phase 3: Integration Tests (2-3 hours)

#### 3.1 End-to-End Integration Tests

**File**: `IntegrationTests.swift`

**Changes needed**:

```swift
@MainActor
class IntegrationTests: FileBasedTestCase {
    var dataManager: StreamHavenData!
    
    override func needsFTS() -> Bool {
        return true
    }
    
    override func setUp() {
        super.setUp()
        dataManager = StreamHavenData(persistenceProvider: persistenceProvider)
    }
    
    func testFullImportFlow() async throws {
        // 1. Import M3U playlist
        let m3uURL = URL(string: "https://example.com/test.m3u8")!
        let m3uData = generateTestM3U()
        
        // Cache playlist
        let bgContext = container.newBackgroundContext()
        await bgContext.perform {
            _ = PlaylistCacheManager.cachePlaylist(
                url: m3uURL,
                data: m3uData,
                context: bgContext
            )
        }
        
        // 2. Parse and save
        try await dataManager.importPlaylist(from: m3uURL)
        
        // 3. Verify entities created
        let channels = try context.fetch(Channel.fetchRequest())
        XCTAssertGreaterThan(channels.count, 0)
        
        // 4. Test FTS search
        let searchResults = FullTextSearchManager.search(
            query: "channel",
            context: context
        )
        XCTAssertGreaterThan(searchResults.count, 0)
    }
}
```

**Test count**: ~5 comprehensive integration tests

### Phase 4: Performance & Edge Cases (1-2 hours)

#### 4.1 Performance Tests

**File**: `ParserPerformanceTests.swift`

Re-enable with file-based stores and proper async execution:

- Measure parsing time for 1K, 10K, 50K channels
- Measure batch insert performance
- Memory usage monitoring

#### 4.2 Edge Case Tests

**File**: `M3UPlaylistParserEdgeCasesTests.swift`

Add timeout handling and error recovery:

- Malformed M3U data
- Missing required fields
- Invalid URLs
- Empty playlists

### Phase 5: Test Isolation & Cleanup (1 hour)

#### 5.1 Parallel Test Execution

Ensure tests can run in parallel:

- Each test gets unique database file
- Proper cleanup in tearDown
- No shared state between tests

#### 5.2 CI/CD Integration

Update test workflows:

```yaml
# .github/workflows/tests.yml
- name: Run Unit Tests (In-Memory)
  run: swift test --filter StreamHavenTests
  
- name: Run Integration Tests (File-Based)
  run: swift test --filter StreamHavenIntegrationTests
```

## Implementation Timeline

| Phase | Duration | Priority | Tests Recovered |
|-------|----------|----------|-----------------|
| Phase 1: Infrastructure | 2-3 hours | Critical | 0 (setup) |
| Phase 2.1: EPG Tests | 1 hour | Critical | ~15 tests |
| Phase 2.2: M3U Tests | 1 hour | Critical | ~20 tests |
| Phase 2.3: FTS Tests | 1 hour | Critical | ~10 tests |
| Phase 2.4: Cache Tests | 1 hour | High | ~8 tests |
| Phase 3: Integration | 2-3 hours | High | ~5 tests |
| Phase 4: Performance | 1-2 hours | Medium | ~10 tests |
| Phase 5: Cleanup | 1 hour | Medium | 0 (polish) |

**Total Time**: 10-14 hours
**Expected Coverage**: 95-100%

## Expected Outcomes

### Before Implementation

- ✅ 217 passing tests
- ⏭️ ~50 skipped tests
- 📊 ~65% code coverage
- ❌ Critical features untested

### After Implementation

- ✅ 265+ passing tests
- ⏭️ 2-3 skipped tests (platform-specific only)
- 📊 95-100% code coverage
- ✅ All critical paths tested

## Risk Mitigation

### Potential Issues

1. **Test execution time**
   - File-based tests slower than in-memory (~2-3x)
   - **Solution**: Run critical tests in CI, full suite nightly

2. **Test flakiness**
   - File I/O can be unpredictable
   - **Solution**: Proper timeouts, retry logic, isolated temp directories

3. **Disk space**
   - Multiple test databases can consume space
   - **Solution**: Aggressive cleanup in tearDown, tmpfs for CI

4. **FTS configuration**
   - FTS5 may not be enabled in all SQLite builds
   - **Solution**: Runtime check, graceful skip if unavailable

## Maintenance Plan

1. **Add helper for new tests**:

   ```swift
   // Always extend FileBasedTestCase for new integration tests
   class NewFeatureTests: FileBasedTestCase { }
   ```

2. **Monitor test duration**:
   - Keep individual tests under 5 seconds
   - Use `measure {}` blocks for performance tests

3. **Update documentation**:
   - Document which tests require file-based stores
   - Add comments explaining async patterns

4. **Regular coverage checks**:

   ```bash
   swift test --enable-code-coverage
   xcrun llvm-cov report .build/debug/StreamHavenPackageTests.xctest/Contents/MacOS/StreamHavenPackageTests
   ```

## Quick Start Commands

```bash
# Run all tests (will take longer with file-based tests)
swift test

# Run only fast unit tests (in-memory)
swift test --filter InMemoryTests

# Run integration tests (file-based)
swift test --filter FileBasedTests

# Generate coverage report
swift test --enable-code-coverage
```

## Notes

- **Don't skip tests without documentation**: Every XCTSkip should have a clear reason
- **Prefer file-based for integration**: Use in-memory for pure unit tests only
- **Async is your friend**: All file/network operations should be async with expectations
- **Cleanup is critical**: Always destroy test containers and remove temp files

My Plan to Address Testing Gaps
Immediate Priorities (Based on Your Document)
Phase 1: File-Based Test Infrastructure ⚡ START HERE (2-3 hours)
Why First: This is the foundation that unblocks all other skipped tests.

Actions:

Create FileBasedTestCoreDataModelBuilder.swift helper class

Generates temporary SQLite databases per test
Supports FTS5 enablement flag
Proper cleanup in tearDown
Create FileBasedTestCase.swift base class

Handles container lifecycle
Automatic database cleanup
Override point for FTS requirements
Update existing TestCoreDataModelBuilder to include Actor/Credit entities (✅ Already done!)

Deliverable: Foundation that supports NSBatchInsertRequest, NSBatchDeleteRequest, FTS5, and file I/O

Phase 2.1: EPG Parser Tests 🔴 CRITICAL (1 hour)
Current Status: ~15 tests skipped
Blocker: NSBatchDeleteRequest requires file-based store

Actions:

Remove XCTSkip from EPGParserTests.swift
Extend FileBasedTestCase instead of base XCTestCase
Test coverage:
XML parsing with valid/invalid data
Batch delete of old entries
EPG entry creation and validation
Date range handling
Expected Result: +15 passing tests

Phase 2.2: M3U Parser Tests 🔴 CRITICAL (1 hour)
Current Status: ~20 tests skipped
Blocker: NSBatchInsertRequest requires file-based store

Actions:

Remove XCTSkip from M3UPlaylistParserTests.swift
Convert to FileBasedTestCase
Test batch operations with various playlist sizes:
Small (100 channels)
Medium (1,000 channels)
Large (10,000+ channels)
Test duplicate detection and merging
Expected Result: +20 passing tests

Phase 2.3: Full-Text Search Tests 🔴 CRITICAL (1 hour)
Current Status: ~10 tests skipped
Blocker: FTS5 virtual tables require SQLite file store

Actions:

Remove XCTSkip from FullTextSearchManagerTests.swift and FTSTriggerTests.swift
Override needsFTS() -> Bool { return true }
Test coverage:
FTS initialization and table creation
Search queries across movies, series, channels
FTS trigger firing on insert/update
Search ranking and relevance
Expected Result: +10 passing tests

Phase 2.4: Playlist Cache Manager Tests 🟡 HIGH (1 hour)
Current Status: ~8 tests skipped
Blocker: File I/O operations require actual filesystem

Actions:

Remove XCTSkip from PlaylistCacheManagerStressTests.swift
Create temporary cache directory per test
Test coverage:
Cache write and retrieval
Expiration logic
Concurrent access
Cache invalidation
Expected Result: +8 passing tests

Phase 3: Integration Tests 🟡 HIGH (2-3 hours)
Current Status: Several integration tests skipped
Blocker: Requires combination of file-based store + FTS + file I/O

Actions:

Update IntegrationTests.swift to use FileBasedTestCase with FTS
Test end-to-end flows:
Import M3U → Parse → Save → Search
EPG import → Update → Query
Multi-source playlist management
Profile switching with data isolation
Expected Result: +5 passing tests

Phase 4: Medium Priority Tests 🟢 MEDIUM (2-3 hours)
4.1 Franchise Grouping Tests

Remove XCTSkip from FranchiseGroupingTests.swift
May need to mock TMDb API calls or use test fixtures
Test franchise detection algorithms
4.2 Optimized Fetch Tests

Remove XCTSkip from OptimizedFetchTests.swift
Test batch faulting and prefetching strategies
Verify performance improvements
4.3 Playback Progress Tests

Remove XCTSkip from PlaybackProgressTests.swift
Test multi-profile progress tracking
Test progress persistence and denormalization
Expected Result: +15 passing tests

Phase 5: Performance & Edge Cases 🟢 MEDIUM (1-2 hours)
5.1 Performance Regression Tests

Benchmark parsing for various playlist sizes
Memory usage profiling
Response time validation
5.2 Edge Case Tests

Malformed M3U data handling
Invalid EPG XML recovery
Network timeout scenarios
Concurrent import conflicts
Expected Result: +10 passing tests

Phase 6: New Tests for Actor Filtering ✅ DONE
Status: Already implemented with 9 passing tests!

✅ Actor entity creation
✅ Credit relationships
✅ Filmography filtering
✅ Credit ordering
✅ Cascade deletion
Current: 198 passing tests (including new actor tests)

Summary & Timeline
Phase	|Duration	|Tests Added	|Priority	|Status|
Phase 1: Infrastructure	|2-3 hours	|0 (foundation)	|🔴 Critical	|Not Started|
Phase 2.1: EPG Tests	|1 hour	|+15 tests	|🔴 Critical	|Not Started|
Phase 2.2: M3U Tests	|1 hour	|+20 tests	|🔴 Critical	|Not Started|
Phase 2.3: FTS Tests	|1 hour	|+10 tests	|🔴 Critical	|Not Started|
Phase 2.4: Cache Tests	|1 hour	|+8 tests	|🟡 High	|Not Started|
Phase 3: Integration	|2-3 hours	|+5 tests	|🟡 High	|Not Started|
Phase 4: Medium Priority	|2-3 hours	|+15 tests	|🟢 Medium	|Not Started|
Phase 5: Performance	|1-2 hours	|+10 tests	|🟢 Medium	|Not Started|
Phase 6: Actor Tests	|✅ Done	|+9 tests	|✅ Complete	|✅ DONE|
Total Time: 11-15 hours
Current Tests: 198 passing
Expected Final: 290+ passing tests
Coverage Improvement: 65% → 95%+

Recommended Execution Order
Week 1 - Critical Foundation:

Day 1: Phase 1 (Infrastructure)
Day 2: Phase 2.1 (EPG) + Phase 2.2 (M3U)
Day 3: Phase 2.3 (FTS) + Phase 2.4 (Cache)
Checkpoint: ~50 tests recovered, core functionality validated
Week 2 - Integration & Polish:

Day 4-5: Phase 3 (Integration Tests)
Day 6: Phase 4 (Medium Priority)
Day 7: Phase 5 (Performance & Edge Cases)
Final Checkpoint: 95%+ coverage achieved
My Recommendations
Start with Phase 1 immediately - It's the foundation for everything else
Use CI/CD separation - Run in-memory tests on every commit, file-based tests nightly
Add the Actor filtering tests to documentation - They're new and should be tracked
Consider test categories for easier filtering:
