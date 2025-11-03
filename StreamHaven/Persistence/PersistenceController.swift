import CoreData
import Foundation
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
        let model = inMemory ? PersistenceController.createIsolatedModel() : PersistenceController.loadManagedObjectModel()
        container = NSPersistentContainer(name: "StreamHaven", managedObjectModel: model)

        if inMemory {
            let description = NSPersistentStoreDescription()
            description.type = NSInMemoryStoreType
            container.persistentStoreDescriptions = [description]
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

    /// Creates an isolated copy of the model for in-memory testing to avoid entity conflicts
    private static func createIsolatedModel() -> NSManagedObjectModel {
        let sourceModel = loadManagedObjectModel()
        let model = sourceModel.copy() as! NSManagedObjectModel
        return model
    }
    
    private static func loadManagedObjectModel() -> NSManagedObjectModel {
#if SWIFT_PACKAGE
        let primaryBundles: [Bundle] = [Bundle.module, Bundle(for: PersistenceController.self)]
#else
        let primaryBundles: [Bundle] = [Bundle(for: PersistenceController.self), Bundle.main]
#endif
        let candidateBundles = primaryBundles + Bundle.allBundles + Bundle.allFrameworks

        for bundle in candidateBundles {
            if let url = bundle.url(forResource: "StreamHaven", withExtension: "momd") ??
                bundle.url(forResource: "StreamHaven", withExtension: "mom"), let model = NSManagedObjectModel(contentsOf: url) {
                patchManagedObjectClasses(in: model)
                let missingEntities = missingEntities(in: model)
                if missingEntities.isEmpty {
#if DEBUG
                    let entitySummary = model.entities.map { entity in
                        "\(entity.name ?? "<nil>") -> \(entity.managedObjectClassName ?? "<nil>")"
                    }.joined(separator: ", ")
                    print("PersistenceController loaded Core Data model from \(bundle.bundlePath): \(entitySummary)")
#endif
                    return model
                }
#if DEBUG
                print("PersistenceController model from \(bundle.bundlePath) missing entities: \(missingEntities)")
#endif
            }
        }

        if let merged = NSManagedObjectModel.mergedModel(from: candidateBundles) {
            patchManagedObjectClasses(in: merged)
            let missingEntities = missingEntities(in: merged)
            if missingEntities.isEmpty {
#if DEBUG
                let entityKeys = merged.entitiesByName.keys.sorted()
                print("PersistenceController merged model entity keys: \(entityKeys)")
                let entitySummary = merged.entities.map { entity in
                    "\(entity.name ?? "<nil>") -> \(entity.managedObjectClassName ?? "<nil>")"
                }.joined(separator: ", ")
                print("PersistenceController loaded merged Core Data model: \(entitySummary)")
#endif
                return merged
            }
#if DEBUG
            print("PersistenceController merged model missing entities: \(missingEntities)")
#endif
        }

        guard let fallbackModel = LightweightCoreDataModelBuilder.sharedModel.copy() as? NSManagedObjectModel else {
            fatalError("Failed to copy lightweight Core Data model.")
        }
        patchManagedObjectClasses(in: fallbackModel)
#if DEBUG
        print("PersistenceController falling back to LightweightCoreDataModelBuilder with entities: \(fallbackModel.entities.compactMap { $0.name }.sorted())")
#endif
        return fallbackModel
    }
}

// MARK: - Entity Class Patching

private extension PersistenceController {
    static func patchManagedObjectClasses(in model: NSManagedObjectModel) {
        for entity in model.entities {
            guard let name = entity.name, let mappedClass = entityClassMap[name] else { continue }
            entity.managedObjectClassName = NSStringFromClass(mappedClass)
        }
    }

    static func missingEntities(in model: NSManagedObjectModel) -> [String] {
        let expected = Set(entityClassMap.keys)
        let available = Set(model.entities.compactMap { $0.name })
        return Array(expected.subtracting(available)).sorted()
    }

    static let entityClassMap: [String: NSManagedObject.Type] = [
        "Movie": Movie.self, "Series": Series.self, "Season": Season.self, "Episode": Episode.self, "Channel": Channel.self, "ChannelVariant": ChannelVariant.self, "Profile": Profile.self, "WatchHistory": WatchHistory.self, "Favorite": Favorite.self, "StreamCache": StreamCache.self, "PlaylistCache": PlaylistCache.self, "PlaylistSource": PlaylistSource.self, "Download": Download.self, "UpNextQueueItem": UpNextQueueItem.self, "Watchlist": Watchlist.self, "WatchlistItem": WatchlistItem.self, "EPGEntry": EPGEntry.self
    ]
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
