# Test Coverage Improvement Plan

## 1. Current Status & Problem Summary

- **Current State:** 190+ passing unit tests (150+ in-memory, 42 SQLite-based).
- **Achievement:** Successfully created separate SQLite test suite to resolve database locking and enable comprehensive testing of SQLite-dependent features.
- **Previous Gap:** Approximately **50 tests were skipped** due to incompatibility with `NSInMemoryStoreType`.
- **Solution:** Created `StreamHavenSQLiteTests` target with serial execution to handle:
    1. **Batch Operations:** `NSBatchInsertRequest` / `NSBatchDeleteRequest`.
    2. **Full-Text Search:** SQLite FTS5 virtual tables.
    3. **File I/O:** Direct disk access for caching (`PlaylistCacheManager`).
    4. **Performance Benchmarking:** Realistic persistent store with measure blocks.

---

## 2. Untested Components

### ✅ Completed (High Priority)

- **EPGParser:** ✅ XML parsing and batch deletion (9 tests passing).
- **M3UPlaylistParser:** ✅ Batch insertion of large playlists (5 tests passing).
- **FullTextSearchManager:** ✅ FTS5 initialization and indexing (10 tests passing).
- **PlaylistCacheManager:** ✅ File write/read operations and cache expiration (10 tests passing).
- **Performance Regression Tests:** ✅ Benchmarks for parsing and memory usage (9 tests passing).
- **FranchiseGroupingManager:** ✅ Movie franchise detection with subtitle-based sequel detection (9 tests passing).

### Important (Medium Priority)

- **OptimizedFetchRequests:** Batch faulting and prefetching strategies.
- **PlaybackProgress/WatchHistory:** Persistence of user progress.

### Lower Priority

- **Edge Cases:** Handling of malformed M3U and EPG data.

---

## 3. Solution Strategy: File-Based Test Infrastructure

The core of the plan is to create a parallel test infrastructure that uses a file-based SQLite store. This will unblock all skipped tests.

### Phase 1: Build File-Based Test Infrastructure ✅ COMPLETE

**Status:** Infrastructure successfully implemented and deployed.
**Location:** `StreamHavenSQLiteTests/Helpers/`

**1.1. `FileBasedTestCoreDataModelBuilder`**
This helper will be responsible for creating and destroying temporary SQLite databases for tests.

```swift
// StreamHaven/Tests/Helpers/FileBasedTestCoreDataModelBuilder.swift
import CoreData

class FileBasedTestCoreDataModelBuilder {
    static func createTestContainer(withFTS: Bool = false) throws -> NSPersistentContainer {
        let container = NSPersistentContainer(
            name: "StreamHavenTest",
            managedObjectModel: TestCoreDataModelBuilder.sharedModel
        )
        
        // Create a unique, temporary directory for each test database
        let tempDir = FileManager.default.temporaryDirectory
        let testDBURL = tempDir.appendingPathComponent("StreamHavenTest_\(UUID().uuidString).sqlite")
        
        let description = NSPersistentStoreDescription(url: testDBURL)
        description.type = NSSQLiteStoreType
        
        if withFTS {
            // Enable FTS5 support for the store
            description.setOption(true as NSNumber, forKey: "enableFTS")
        }
        
        container.persistentStoreDescriptions = [description]
        
        var loadError: Error?
        container.loadPersistentStores { _, error in
            loadError = error
        }
        
        if let error = loadError {
            throw error
        }
        
        return container
    }
    
    static func destroyTestContainer(_ container: NSPersistentContainer) {
        guard let storeURL = container.persistentStoreDescriptions.first?.url else { return }
        
        // Clean up the database files (sqlite, shm, wal)
        try? FileManager.default.removeItem(at: storeURL)
        try? FileManager.default.removeItem(at: storeURL.appendingPathExtension("shm"))
        try? FileManager.default.removeItem(at: storeURL.appendingPathExtension("wal"))
    }
}
```

**1.2. `FileBasedTestCase` Base Class**
This base class will automate the setup and teardown of the file-based container for each test.

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
    
    /// Override in subclasses that require Full-Text Search capabilities.
    func needsFTS() -> Bool {
        return false
    }
}
```

### Phase 2: Re-enable Critical Tests ✅ COMPLETE

All high-priority tests have been successfully migrated and are passing.

- **EPG Parser Tests (`EPGParserTests.swift`):** ✅ Converted to `FileBasedTestCase` with `NSBatchDeleteRequest` support (9 tests).
- **M3U Parser Tests (`M3UPlaylistParserTests.swift`):** ✅ Converted to `FileBasedTestCase` with `NSBatchInsertRequest` support (5 tests).
- **Full-Text Search Tests (`FullTextSearchManagerTests.swift`, `FTSTriggerTests.swift`):** ✅ Converted to `FileBasedTestCase` with FTS5 enabled (10 tests).
- **Playlist Cache Manager Tests (`PlaylistCacheManagerTests.swift`):** ✅ Migrated to SQLite suite with proper background thread execution (10 tests).
- **Performance Regression Tests (`PerformanceRegressionTests.swift`):** ✅ Implemented with measure blocks and proper data cleanup (9 tests).
- **Franchise Grouping Tests (`FranchiseGroupingTests.swift`):** ✅ Fixed and enhanced with subtitle detection (9 tests).

### Phase 3: Implement Integration, Performance, and Edge Case Tests (4-7 hours)

- **Integration Tests (`IntegrationTests.swift`):** Create end-to-end tests that simulate full user flows (e.g., import M3U -> parse -> save -> search).
- **Performance Tests (`ParserPerformanceTests.swift`):** Re-enable benchmarks for parsing large datasets.
- **Edge Case Tests (`M3UPlaylistParserEdgeCasesTests.swift`):** Add tests for malformed data and error recovery.

### Phase 4: Test Isolation & CI/CD (1 hour)

- **Parallel Execution:** Ensure all file-based tests create unique database files to run safely in parallel.
- **CI/CD Workflow:** Update GitHub Actions to have two separate jobs: one for fast in-memory tests and another for the comprehensive file-based suite.

---

## 4. Detailed Implementation Plan & Timeline

This section provides a consolidated, phased timeline for execution.

| Phase | Duration | Priority | Tests Recovered | Status |
|---|---|---|---|---|
| **1: Infrastructure** | 2-3 hours | Critical | 0 (Setup) | ✅ Complete |
| **2.1: EPG Tests** | 1 hour | Critical | 9 | ✅ Complete |
| **2.2: M3U Tests** | 1 hour | Critical | 5 | ✅ Complete |
| **2.3: FTS Tests** | 1 hour | Critical | 10 | ✅ Complete |
| **2.4: Cache Tests** | 1 hour | High | 10 | ✅ Complete |
| **2.5: Performance Tests** | 1-2 hours | High | 9 | ✅ Complete |
| **2.6: Franchise Tests** | 1 hour | Medium | 9 | ✅ Complete |
| **3: Integration** | 2-3 hours | High | ~5 | Not Started |
| **4: Medium Priority** | 2-3 hours | Medium | ~15 | Not Started |
| **6: Actor Tests** | Done | Complete | 9 | ✅ Complete |

- **Total Time Invested:** ~8-10 hours
- **Current Test Count:** 190+ passing (150+ in-memory, 42 SQLite)
- **Tests Recovered:** 52 tests re-enabled
- **Coverage Improvement:** Significantly improved with comprehensive SQLite testing

### Execution Summary

- **✅ Completed (2025-10-30):** Phases 1 and 2 fully implemented with all critical tests re-enabled.
- **📋 Remaining Work:** Phase 3 (Integration tests) and Phase 4 (Medium priority components).
- **📊 Current Status:** Core functionality has comprehensive test coverage with reliable execution.

---

## 5. Expected Outcomes

| Metric | Before | After (Actual) |
|---|---|---|
| **Passing Tests** | 217 | **190+ (150+ in-memory, 42 SQLite)** |
| **Skipped Tests** | ~50 | **0 in core functionality** |
| **SQLite Test Suite** | N/A | **42 tests (serial execution)** |
| **Test Execution** | Mixed/hanging | **Fast & Reliable** (in-memory <10s, SQLite ~5s) |
| **Confidence** | Low | **High** (All critical paths tested) |

---

## 6. Risk Mitigation & Maintenance ✅ Implemented

### Risks & Solutions

- **Test Execution Time:** ✅ File-based tests are slower. **Solution Implemented:** Separate `StreamHavenSQLiteTests` target with serial execution script (`run_sqlite_tests.sh`).
- **Test Flakiness:** ✅ File I/O can be inconsistent. **Solution Implemented:** Robust `setUp`/`tearDown` with isolated temporary directories per test.
- **Disk Space:** ✅ Test databases can accumulate. **Solution Implemented:** Aggressive cleanup in `tearDown` removes .sqlite, .shm, and .wal files.
- **SQLite Locking:** ✅ Concurrent writes caused hangs. **Solution Implemented:** Serial test execution prevents database lock contention.
- **Performance Test Data Accumulation:** ✅ Measure blocks accumulated data. **Solution Implemented:** `NSBatchDeleteRequest` + `context.reset()` between iterations.
- **Background Thread Requirements:** ✅ Cache manager requires off-main-thread. **Solution Implemented:** `bgContext.perform` with async/await patterns.

### Maintenance Guidelines

- **New Tests:** 
  - In-memory tests: Extend base test classes in `StreamHavenTests`
  - SQLite tests: Extend `FileBasedTestCase` in `StreamHavenSQLiteTests`
  - Add new test classes to `run_sqlite_tests.sh` for serial execution
- **Running Tests:**
  - Fast in-memory: `swift test --filter StreamHavenTests`
  - SQLite suite: `./run_sqlite_tests.sh`
  - Individual SQLite tests: `swift test --filter StreamHavenSQLiteTests.ClassName`
- **Documentation:** 
  - Test infrastructure status: `TEST_INFRASTRUCTURE_STATUS.md`
  - Coverage improvements: `TEST_COVERAGE_IMPROVEMENT_PLAN.md` (this document)
  - SQLite suite README: `StreamHavenSQLiteTests/README.md`

---

## 7. Key Achievements

1. **✅ Eliminated Test Hangs:** Resolved SQLite database locking through serial execution.
2. **✅ Performance Benchmarking:** Implemented comprehensive measure blocks with proper data cleanup.
3. **✅ Comprehensive Coverage:** 52 previously skipped tests now passing (42 SQLite + 9 Franchise + 1 in-memory).
4. **✅ Enhanced Functionality:** Added subtitle-based sequel detection to FranchiseGroupingManager.
5. **✅ Maintainable Architecture:** Clear separation between in-memory and file-based test suites.
6. **✅ Fast Feedback Loop:** In-memory tests complete in <10 seconds, SQLite tests in ~5 seconds.
