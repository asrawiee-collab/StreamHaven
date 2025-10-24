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

    func importPlaylist(from url: URL) async throws {
        let (data, _) = try await URLSession.shared.data(from: url)

        try await backgroundContext.perform {

            _ = PlaylistCacheManager.cachePlaylist(url: url, data: data, context: self.backgroundContext)

            let type = PlaylistParser.detectPlaylistType(from: url)
            switch type {
            case .m3u:
                try M3UPlaylistParser.parse(data: data, context: self.backgroundContext)
            case .xtreamCodes:
                try await XtreamCodesParser.parse(url: url, context: self.backgroundContext)
            case .unknown:
                throw StreamHavenError.unknownPlaylistType
            }
        }
    }
}

enum StreamHavenError: Error, LocalizedError {
    case noDataReceived
    case cachingFailed
    case unknownPlaylistType

    var errorDescription: String? {
        switch self {
        case .noDataReceived:
            return NSLocalizedString("No data was received from the playlist URL.", comment: "Error message for empty playlist data")
        case .cachingFailed:
            return NSLocalizedString("Failed to cache the playlist data locally.", comment: "Error message for playlist caching failure")
        case .unknownPlaylistType:
            return NSLocalizedString("The playlist type could not be determined. Please use a valid M3U or Xtream Codes URL.", comment: "Error message for unknown playlist type")
        }
    }
}
