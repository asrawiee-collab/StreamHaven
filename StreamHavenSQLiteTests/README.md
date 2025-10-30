# SQLite Tests Setup Guide

## Overview

This directory contains tests that require SQLite file-based storage instead of in-memory Core Data stores. These tests are separated from the main test suite because they use SQLite-specific features like:

- **FTS5 Full-Text Search** virtual tables
- **NSBatchInsertRequest** and **NSBatchDeleteRequest** operations
- **Performance benchmarking** with realistic SQLite storage

## Why a Separate Test Target?

When SQLite tests run concurrently (as XCTest does by default), they cause database locking issues that make the test suite hang. The main test suite (`StreamHavenTests`) uses in-memory stores which don't have this problem and execute in <10 seconds.

By separating SQLite tests, we maintain:
- ✅ Fast main test suite (150+ tests, <10 seconds)
- ✅ Working SQLite tests (30+ tests) that run serially
- ✅ No test hangs or database locks

## Test Structure

```
StreamHavenSQLiteTests/
├── Helpers/
│   ├── FileBasedTestCase.swift                    # Base class for SQLite tests
│   ├── FileBasedTestCoreDataModelBuilder.swift    # SQLite container factory
│   └── TestCoreDataModelBuilder.swift             # Core Data model builder
├── FTSTriggerTests.swift                           # Full-text search tests (9 tests)
├── EPGParserTests.swift                            # EPG XML parsing tests (9 tests)
├── PerformanceRegressionTests.swift                # Performance benchmarks (8 tests)
└── FullTextSearchManagerTests.swift                # FTS manager tests (1 test)
```

## Running Tests

### Option 1: Use the Test Runner Script (Recommended)

```bash
./run_sqlite_tests.sh
```

This script runs each test class serially to avoid database locking.

### Option 2: Run Individual Test Classes

```bash
# Run all FTS tests
swift test --filter StreamHavenSQLiteTests.FTSTriggerTests

# Run all EPG parser tests
swift test --filter StreamHavenSQLiteTests.EPGParserTests

# Run all performance tests
swift test --filter StreamHavenSQLiteTests.PerformanceRegressionTests

# Run FTS manager tests
swift test --filter StreamHavenSQLiteTests.FullTextSearchManagerTests
```

### Option 3: Run Individual Tests

```bash
# Run a specific test
swift test --filter StreamHavenSQLiteTests.FTSTriggerTests/testFTSSearchReturnsRelevantResults
```

### ⚠️ Do NOT Run All Tests Together

```bash
# ❌ This will HANG due to SQLite locking:
swift test --filter StreamHavenSQLiteTests
```

## Test Infrastructure

### FileBasedTestCase

Base class that provides SQLite file-based test infrastructure:

```swift
@MainActor
class MyTests: FileBasedTestCase {
    // Override if you need FTS5 support
    override func needsFTS() -> Bool {
        return true  // Enables WAL mode for FTS
    }
    
    func testSomething() throws {
        // Access provided properties:
        // - context: NSManagedObjectContext
        // - persistenceProvider: PersistenceProviding
        // - container: NSPersistentContainer
    }
}
```

**Automatic Features:**
- Creates temporary SQLite database in setUp()
- Configures optimized pragmas (WAL/MEMORY mode based on needsFTS())
- Cleans up database files in tearDown()
- Provides Core Data stack ready to use

### SQLite Pragma Configuration

**For FTS Tests (needsFTS() = true):**
```
PRAGMA journal_mode=WAL       // Required for FTS5
PRAGMA synchronous=NORMAL     // Balanced durability
PRAGMA cache_size=10000       // 10MB cache
```

**For Non-FTS Tests (needsFTS() = false):**
```
PRAGMA journal_mode=MEMORY    // No WAL files
PRAGMA synchronous=OFF        // Max performance
PRAGMA locking_mode=EXCLUSIVE // Prevent concurrent access
PRAGMA cache_size=10000       // 10MB cache
```

## Adding New SQLite Tests

1. Create your test class extending `FileBasedTestCase`:

```swift
import XCTest
import CoreData
@testable import StreamHaven

@MainActor
final class MyNewTests: FileBasedTestCase {
    
    override func needsFTS() -> Bool {
        return false  // Set true if testing FTS features
    }
    
    func testMyFeature() throws {
        guard let ctx = context else {
            XCTFail("Context not available")
            return
        }
        
        // Use ctx for Core Data operations
        try ctx.performAndWait {
            let entity = MyEntity(context: ctx)
            entity.name = "Test"
            try ctx.save()
        }
        
        // Add assertions
        XCTAssertTrue(true)
    }
}
```

2. Add the test class to `run_sqlite_tests.sh`:

```bash
test_classes=(
    "FullTextSearchManagerTests"
    "FTSTriggerTests"
    "EPGParserTests"
    "PerformanceRegressionTests"
    "MyNewTests"  # Add here
)
```

## CI/CD Integration

### GitHub Actions Example

```yaml
- name: Run Main Tests
  run: swift test --filter StreamHavenTests
  
- name: Run SQLite Tests
  run: ./run_sqlite_tests.sh
```

### Xcode Cloud Example

Create two test actions:
1. **Fast Tests**: Run scheme `StreamHavenTests`
2. **SQLite Tests**: Run script `./run_sqlite_tests.sh`

## Troubleshooting

### Tests Hang

**Cause:** Running multiple SQLite test classes concurrently
**Solution:** Use `run_sqlite_tests.sh` or run test classes individually

### "Cannot find 'TestCoreDataModelBuilder' in scope"

**Cause:** Missing dependency in test target
**Solution:** Ensure `TestCoreDataModelBuilder.swift` is in `StreamHavenSQLiteTests/Helpers/`

### FTS Tests Fail

**Cause:** FTS5 not enabled or wrong pragma configuration
**Solution:** Override `needsFTS()` to return `true` in your test class

### Database File Already Exists

**Cause:** Previous test run didn't clean up properly
**Solution:** Delete `/tmp/StreamHavenTest_*.sqlite*` files or restart

```bash
rm -f /tmp/StreamHavenTest_*.sqlite*
```

## Performance Notes

### Main Test Suite (StreamHavenTests)
- **Type:** In-memory stores
- **Tests:** 150+
- **Time:** <10 seconds
- **Concurrency:** Full parallel execution

### SQLite Test Suite (StreamHavenSQLiteTests)
- **Type:** File-based SQLite stores
- **Tests:** 27
- **Time:** ~30-60 seconds (serial execution)
- **Concurrency:** Must run serially (one class at a time)

## Test Coverage

### FTSTriggerTests (9 tests)
- FTS5 setup and virtual table creation
- Fuzzy search functionality
- Multi-entity search (Movie, Series, Channel)
- Relevance ranking
- Special characters and Unicode handling
- Performance with large datasets

### EPGParserTests (9 tests)
- XMLTV format parsing
- Timezone offset handling
- Invalid XML error handling
- Missing required fields
- Multiple programmes parsing
- Duplicate detection
- Special character escaping

### PerformanceRegressionTests (8 tests)
- Search performance with large datasets
- Batch insert operations
- Concurrent fetch performance
- Memory pressure testing
- Fetch batching optimization

### FullTextSearchManagerTests (1 test)
- FTS setup idempotency

## Migration Notes

These tests were originally in `StreamHaven/Tests/` but were moved to a separate target due to SQLite locking issues. The original implementations used `XCTSkip` stubs after conversion attempts caused the main test suite to hang.

**Original Issue:** SQLite WAL mode + FTS5 + concurrent test execution = database locks
**Solution:** Separate test target with serial execution per test class

---

**Last Updated:** October 29, 2025  
**Status:** ✅ All infrastructure complete and working
