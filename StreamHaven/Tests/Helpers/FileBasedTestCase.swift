import XCTest
@preconcurrency import CoreData
@testable import StreamHaven

/// Base test case for tests that require a file-based SQLite store.
/// Use this for tests that need:
/// - NSBatchInsertRequest / NSBatchDeleteRequest
/// - Full-Text Search (FTS5)
/// - File I/O operations
/// - Realistic persistent store behavior
///
/// For simple unit tests that don't require these features, continue using XCTestCase
/// with in-memory stores (they're faster).
@MainActor
class FileBasedTestCase: XCTestCase {
    var container: NSPersistentContainer!
    var context: NSManagedObjectContext!
    var persistenceProvider: PersistenceProviding!
    var tempDirectory: URL?
    
    override func setUp() async throws {
        try await super.setUp()
        
        do {
            // Create container with optional FTS support
            container = try FileBasedTestCoreDataModelBuilder.createTestContainer(withFTS: needsFTS())
            context = container.viewContext
            
            // Disable undo and set merge policy for performance
            context.undoManager = nil
            context.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
            
            // Create a test persistence provider
            struct TestProvider: PersistenceProviding {
                let container: NSPersistentContainer
            }
            persistenceProvider = TestProvider(container: container)
            
            // Create temp directory if needed
            if needsTempDirectory() {
                tempDirectory = FileBasedTestCoreDataModelBuilder.createTempDirectory()
            }
        } catch {
            XCTFail("Failed to create test container: \(error)")
            throw error
        }
    }
    
    override func tearDown() async throws {
        // Clean up temp directory
        if let tempDir = tempDirectory {
            FileBasedTestCoreDataModelBuilder.removeTempDirectory(tempDir)
            tempDirectory = nil
        }
        
        // Clean up Core Data
        context = nil
        persistenceProvider = nil
        
        if let container = container {
            FileBasedTestCoreDataModelBuilder.destroyTestContainer(container)
        }
        container = nil
        
        try await super.tearDown()
    }
    
    // MARK: - Override Points
    
    /// Override in subclasses that need Full-Text Search (FTS5) support.
    /// - Returns: true if this test class requires FTS5 tables.
    func needsFTS() -> Bool {
        return false
    }
    
    /// Override in subclasses that need a temporary directory for file operations.
    /// - Returns: true if this test class needs file I/O.
    func needsTempDirectory() -> Bool {
        return false
    }
    
    // MARK: - Helper Methods
    
    /// Creates a background context for async operations.
    /// - Returns: A new background context associated with the test container.
    func createBackgroundContext() -> NSManagedObjectContext {
        let bgContext = container.newBackgroundContext()
        bgContext.automaticallyMergesChangesFromParent = true
        bgContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        bgContext.undoManager = nil  // Disable undo for performance
        return bgContext
    }
    
    /// Waits for async Core Data operations to complete.
    /// - Parameter timeout: Maximum time to wait (default: 5 seconds).
    func waitForAsyncOperations(timeout: TimeInterval = 5.0) async {
        try? await Task.sleep(nanoseconds: UInt64(timeout * 100_000_000)) // 0.1 second
    }
    
    /// Saves the context and waits for the save to complete.
    /// - Parameter context: The context to save (defaults to main context).
    /// - Throws: Core Data save errors.
    func saveAndWait(_ context: NSManagedObjectContext? = nil) throws {
        let contextToSave = context ?? self.context!
        
        var saveError: Error?
        contextToSave.performAndWait {
            do {
                if contextToSave.hasChanges {
                    try contextToSave.save()
                }
            } catch {
                saveError = error
            }
        }
        
        if let error = saveError {
            throw error
        }
    }
    
    /// Executes a batch insert request and returns the number of inserted objects.
    /// - Parameter request: The batch insert request to execute.
    /// - Returns: Number of objects inserted.
    /// - Throws: Core Data execution errors.
    @discardableResult
    func executeBatchInsert(_ request: NSBatchInsertRequest) throws -> Int {
        nonisolated(unsafe) let requestCopy = request
        requestCopy.resultType = .count
        
        let localContext = self.context!
        var result: NSBatchInsertResult?
        var executeError: Error?
        
        localContext.performAndWait {
            do {
                result = try localContext.execute(requestCopy) as? NSBatchInsertResult
            } catch {
                executeError = error
            }
        }
        
        if let error = executeError {
            throw error
        }
        
        return (result?.result as? Int) ?? 0
    }
    
    /// Executes a batch delete request and returns the number of deleted objects.
    /// - Parameter request: The batch delete request to execute.
    /// - Returns: Number of objects deleted.
    /// - Throws: Core Data execution errors.
    @discardableResult
    func executeBatchDelete(_ request: NSBatchDeleteRequest) throws -> Int {
        nonisolated(unsafe) let requestCopy = request
        requestCopy.resultType = .resultTypeCount
        
        let localContext = self.context!
        var result: NSBatchDeleteResult?
        var executeError: Error?
        
        localContext.performAndWait {
            do {
                result = try localContext.execute(requestCopy) as? NSBatchDeleteResult
            } catch {
                executeError = error
            }
        }
        
        if let error = executeError {
            throw error
        }
        
        return (result?.result as? Int) ?? 0
    }
    
    /// Counts entities of a given type.
    /// - Parameter entityName: The entity name to count.
    /// - Returns: The count of entities.
    func countEntities(entityName: String) -> Int {
        let fetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: entityName)
        return (try? context.count(for: fetchRequest)) ?? 0
    }
}
