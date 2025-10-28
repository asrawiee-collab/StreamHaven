import Foundation
import CoreData

/// An enumeration of the supported playlist types.
public enum PlaylistType {
    /// An M3U playlist.
    case m3u
    /// An Xtream Codes playlist.
    case xtreamCodes
    /// An unknown or unsupported playlist type.
    case unknown
}

/// A class responsible for detecting and parsing different types of playlists.
public final class PlaylistParser {

    /// Detects the type of a playlist from its URL.
    /// - Parameter url: The URL of the playlist.
    /// - Returns: The detected `PlaylistType`.
    public static func detectPlaylistType(from url: URL) -> PlaylistType {
        if url.pathExtension.lowercased() == "m3u" || url.pathExtension.lowercased() == "m3u8" {
            return .m3u
        } else if let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
                  let queryItems = components.queryItems,
                  queryItems.contains(where: { $0.name == "username" && ($0.value?.isEmpty == false) }),
                  queryItems.contains(where: { $0.name == "password" && ($0.value?.isEmpty == false) }) {
            return .xtreamCodes
        }
        return .unknown
    }

    /// Parses a playlist from a URL and imports its content into Core Data.
    ///
    /// - Parameters:
    ///   - url: The URL of the playlist.
    ///   - context: The `NSManagedObjectContext` to perform the import on.
    ///   - data: Optional pre-fetched playlist data to avoid downloading twice for M3U sources.
    public static func parse(url: URL, context: NSManagedObjectContext, data: Data? = nil) async throws {
        let type = detectPlaylistType(from: url)

        let payload: Data
        if let data {
            payload = data
        } else {
            let (downloadedData, _) = try await URLSession.shared.data(from: url)
            payload = downloadedData
        }

        switch type {
        case .m3u:
            var parseError: Error?
            context.performAndWait {
                do {
                    try M3UPlaylistParser.parse(data: payload, context: context)
                } catch {
                    parseError = error
                }
            }
            if let parseError {
                throw parseError
            }
        case .xtreamCodes:
            guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
                  let username = components.queryItems?.first(where: { $0.name == "username" })?.value,
                  let password = components.queryItems?.first(where: { $0.name == "password" })?.value else {
                throw PlaylistImportError.invalidURL
            }

            let service = "StreamHaven.XtreamCodes"
            KeychainHelper.savePassword(password: password, for: username, service: service)

            try await XtreamCodesParser.parse(url: url, username: username, password: password, context: context)
        case .unknown:
            throw PlaylistImportError.unsupportedPlaylistType
        }
    }
}
