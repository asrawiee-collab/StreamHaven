import CoreData
#if canImport(Sentry)
import Sentry
#endif
import os.log

/// Manages the Core Data stack for the application.
public final class PersistenceController {
    /// The persistent container for the Core Data stack.
    public let container: NSPersistentContainer

    /// Initializes a new `PersistenceController`.
    ///
    /// - Parameter inMemory: A boolean indicating whether to create an in-memory store. Defaults to `false`.
    public init(inMemory: Bool = false) {
        container = NSPersistentContainer(name: "StreamHaven")
        if inMemory {
            if let description = container.persistentStoreDescriptions.first {
                description.url = URL(fileURLWithPath: "/dev/null")
            }
        }
        container.persistentStoreDescriptions.first?.shouldMigrateStoreAutomatically = true
        container.persistentStoreDescriptions.first?.shouldInferMappingModelAutomatically = true
        container.loadPersistentStores(completionHandler: { (storeDescription, error) in
            if let error = error as NSError? {
                // Attempt to recover by removing the persistent store and retrying
                os_log("Core Data store load failed: %{public}@", type: .error, error.localizedDescription)
#if canImport(Sentry)
                SentrySDK.capture(error: error)
#endif
                if let url = storeDescription.url {
                    do {
                        try self.destroyStore(at: url)
                        self.container.loadPersistentStores(completionHandler: { (_, retryError) in
                            if let retryError = retryError as NSError? {
                                os_log("Core Data store recovery failed: %{public}@", type: .fault, retryError.localizedDescription)
#if canImport(Sentry)
                                SentrySDK.capture(error: retryError)
#endif
                            }
                        })
                    } catch {
                        os_log("Failed to destroy corrupt Core Data store: %{public}@", type: .fault, error.localizedDescription)
                    }
                }
            }
        })
        container.viewContext.automaticallyMergesChangesFromParent = true
    }
}

// MARK: - Dependency Injection

public protocol PersistenceProviding {
    var container: NSPersistentContainer { get }
}

public struct DefaultPersistenceProvider: PersistenceProviding {
    public let container: NSPersistentContainer
    public init(controller: PersistenceController) {
        self.container = controller.container
    }

    public init() {
        self.container = PersistenceController.shared.container
    }
}

private extension PersistenceController {
    func destroyStore(at url: URL) throws {
        let coordinator = container.persistentStoreCoordinator
        if coordinator.persistentStore(for: url) != nil {
            try coordinator.destroyPersistentStore(at: url, ofType: NSSQLiteStoreType, options: nil)
        } else {
            // Remove SQLite files if present
            let fm = FileManager.default
            try? fm.removeItem(at: url)
            try? fm.removeItem(at: url.appendingPathExtension("-shm"))
            try? fm.removeItem(at: url.appendingPathExtension("-wal"))
        }
    }
}

public extension PersistenceController {
    static let shared: PersistenceController = {
        PersistenceController()
    }()

    static let preview: PersistenceController = {
        PersistenceController(inMemory: true)
    }()
}
