import Foundation
import CoreData

/// Manages all data operations for the StreamHaven application, including importing playlists and managing the Core Data stack.
public class StreamHavenData {

    /// The main persistence controller for the Core Data stack.
    public let persistenceController: PersistenceController

    /// A background context for performing data import and processing tasks without blocking the main thread.
    public let backgroundContext: NSManagedObjectContext

    /// Initializes a new data manager with the specified persistence controller.
    /// - Parameter persistenceController: The `PersistenceController` to use for Core Data operations. Defaults to the shared instance.
    public init(persistenceController: PersistenceController = .shared) {
        self.persistenceController = persistenceController
        self.backgroundContext = persistenceController.container.newBackgroundContext()
        self.backgroundContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(contextDidSave),
            name: .NSManagedObjectContextDidSave,
            object: backgroundContext
        )
    }

    @objc private func contextDidSave(notification: Notification) {
        // Indexing is handled via Core Data's standard querying.
    }

    /// Downloads, parses, and imports a playlist from a remote URL.
    ///
    /// This function performs the entire import process, including:
    /// 1. Downloading the playlist data from the specified URL.
    /// 2. Caching the downloaded data to the file system.
    /// 3. Detecting the playlist type (M3U or Xtream Codes).
    /// 4. Parsing the data and saving the content to Core Data.
    ///
    /// - Parameters:
    ///   - url: The URL of the playlist to import.
    ///   - progress: A closure that is called with status updates during the import process.
    /// - Throws: A `PlaylistImportError` if the import fails at any stage.
    public func importPlaylist(from url: URL, progress: @escaping (String) -> Void) async throws {
        progress(NSLocalizedString("Downloading...", comment: "Playlist import status"))
        let (data, _) = try await URLSession.shared.data(from: url)

        try await backgroundContext.perform {
            progress(NSLocalizedString("Caching playlist...", comment: "Playlist import status"))
            _ = PlaylistCacheManager.cachePlaylist(url: url, data: data, context: self.backgroundContext)

            progress(NSLocalizedString("Parsing playlist...", comment: "Playlist import status"))
            try await PlaylistParser.parse(url: url, context: self.backgroundContext)
        }
    }
}
