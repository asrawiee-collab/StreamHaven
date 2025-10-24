import Foundation
import CoreData

class StreamHavenData {

    let persistenceController: PersistenceController
    let backgroundContext: NSManagedObjectContext

    init(persistenceController: PersistenceController = .shared) {
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

    func importPlaylist(from url: URL, progress: @escaping (String) -> Void) async throws {
        let data: Data
        do {
            let (sessionData, _) = try await URLSession.shared.data(from: url)
            data = sessionData
        } catch {
            throw PlaylistImportError.networkError(error)
        }

        try await backgroundContext.perform {
            do {
                progress(NSLocalizedString("Caching playlist...", comment: "Playlist import status"))
                _ = PlaylistCacheManager.cachePlaylist(url: url, data: data, context: self.backgroundContext)

                progress(NSLocalizedString("Parsing playlist...", comment: "Playlist import status"))
                let type = PlaylistParser.detectPlaylistType(from: url)
                switch type {
                case .m3u:
                    try M3UPlaylistParser.parse(data: data, context: self.backgroundContext)
                case .xtreamCodes:
                    try await XtreamCodesParser.parse(url: url, context: self.backgroundContext)
                case .unknown:
                    throw PlaylistImportError.unsupportedPlaylistType
                }
            } catch let error as PlaylistImportError {
                throw error
            } catch {
                throw PlaylistImportError.parsingFailed(error)
            }
        }
    }
}
