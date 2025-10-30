import CoreData
import Foundation
@testable import StreamHaven

/// A helper class for creating file-based Core Data test containers.
/// This enables testing of features that require SQLite stores (batch operations, FTS5, file I/O).
enum FileBasedTestCoreDataModelBuilder {
    
    /// Creates a test container with a temporary SQLite database.
    /// - Parameter withFTS: If true, enables Full-Text Search (FTS5) support.
    /// - Returns: A configured NSPersistentContainer with a temporary SQLite store.
    /// - Throws: Error if the persistent store fails to load.
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
        
        // Enable automatic lightweight migration
        description.shouldMigrateStoreAutomatically = true
        description.shouldInferMappingModelAutomatically = true
        
        // Aggressive SQLite performance optimizations for testing
        var pragmas: [String: String] = [:]
        
        if withFTS {
            // FTS requires more standard SQLite settings
            pragmas = [
                "journal_mode": "WAL",
                "synchronous": "NORMAL",    // Can't be OFF with WAL for FTS
                "temp_store": "MEMORY",
                "cache_size": "10000"
            ]
        } else {
            // Maximum speed for non-FTS tests
            pragmas = [
                "journal_mode": "MEMORY",
                "synchronous": "OFF",
                "temp_store": "MEMORY",
                "cache_size": "10000",
                "locking_mode": "EXCLUSIVE"
            ]
        }
        
        description.setOption(pragmas as NSDictionary, forKey: NSSQLitePragmasOption)
        
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
        
        // Configure the context for testing
        container.viewContext.automaticallyMergesChangesFromParent = true
        container.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        container.viewContext.undoManager = nil  // Disable undo for performance
        
        return container
    }
    
    /// Destroys a test container and removes all associated files.
    /// - Parameter container: The container to destroy.
    static func destroyTestContainer(_ container: NSPersistentContainer) {
        guard let storeURL = container.persistentStoreDescriptions.first?.url else { return }
        
        // Remove all persistent stores from the coordinator
        for store in container.persistentStoreCoordinator.persistentStores {
            try? container.persistentStoreCoordinator.remove(store)
        }
        
        // Delete database files (SQLite creates multiple files)
        let fileManager = FileManager.default
        try? fileManager.removeItem(at: storeURL)
        try? fileManager.removeItem(at: storeURL.appendingPathExtension("shm"))
        try? fileManager.removeItem(at: storeURL.appendingPathExtension("wal"))
        
        // Also try to remove the -shm and -wal files with standard naming
        if let baseURL = storeURL.deletingPathExtension().path as String? {
            try? fileManager.removeItem(atPath: baseURL + "-shm")
            try? fileManager.removeItem(atPath: baseURL + "-wal")
        }
    }
    
    /// Creates a temporary directory for test file operations.
    /// - Returns: URL to a unique temporary directory.
    static func createTempDirectory() -> URL {
        let tempDir = FileManager.default.temporaryDirectory
        let testDir = tempDir.appendingPathComponent("StreamHavenTest_\(UUID().uuidString)")
        try? FileManager.default.createDirectory(at: testDir, withIntermediateDirectories: true)
        return testDir
    }
    
    /// Removes a temporary directory and all its contents.
    /// - Parameter url: The directory URL to remove.
    static func removeTempDirectory(_ url: URL) {
        try? FileManager.default.removeItem(at: url)
    }
}
