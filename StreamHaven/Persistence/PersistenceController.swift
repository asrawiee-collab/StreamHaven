import CoreData

/// A struct that manages the Core Data stack for the application.
public struct PersistenceController {
    /// The shared singleton instance of the `PersistenceController`.
    public static let shared = PersistenceController()

    /// The persistent container for the Core Data stack.
    public let container: NSPersistentContainer

    /// Initializes a new `PersistenceController`.
    ///
    /// - Parameter inMemory: A boolean indicating whether to create an in-memory store. Defaults to `false`.
    public init(inMemory: Bool = false) {
        container = NSPersistentContainer(name: "StreamHaven")
        if inMemory {
            container.persistentStoreDescriptions.first!.url = URL(fileURLWithPath: "/dev/null")
        }
        container.persistentStoreDescriptions.first?.shouldMigrateStoreAutomatically = true
        container.persistentStoreDescriptions.first?.shouldInferMappingModelAutomatically = true
        container.loadPersistentStores(completionHandler: { (storeDescription, error) in
            if let error = error as NSError? {
                fatalError("Unresolved error \(error), \(error.userInfo)")
            }
        })
        container.viewContext.automaticallyMergesChangesFromParent = true
    }
}
