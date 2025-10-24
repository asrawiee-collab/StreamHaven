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
public class PlaylistParser {

    /// Detects the type of a playlist from its URL.
    /// - Parameter url: The URL of the playlist.
    /// - Returns: The detected `PlaylistType`.
    public static func detectPlaylistType(from url: URL) -> PlaylistType {
        if url.pathExtension.lowercased() == "m3u" || url.pathExtension.lowercased() == "m3u8" {
            return .m3u
        } else if let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
                  let queryItems = components.queryItems,
                  queryItems.contains(where: { $0.name == "username" && !$0.value!.isEmpty }),
                  queryItems.contains(where: { $0.name == "password" && !$0.value!.isEmpty }) {
            return .xtreamCodes
        }
        return .unknown
    }

    /// Parses a playlist from a URL and imports its content into Core Data.
    ///
    /// - Parameters:
    ///   - url: The URL of the playlist.
    ///   - context: The `NSManagedObjectContext` to perform the import on.
    ///   - completion: A closure that is called when the parsing is complete.
    ///   - error: An optional `Error` object if an error occurred during parsing.
    public static func parse(url: URL, context: NSManagedObjectContext, completion: @escaping (_ error: Error?) -> Void) {
        let type = detectPlaylistType(from: url)

        let task = URLSession.shared.dataTask(with: url) { data, response, error in
            if let error = error {
                completion(error)
                return
            }

            guard let data = data else {
                completion(NSError(domain: "PlaylistParser", code: 1, userInfo: [NSLocalizedDescriptionKey: "No data received from URL."]))
                return
            }

            // Playlist data can be large, so we perform parsing on a background thread.
            context.perform {
                do {
                    switch type {
                    case .m3u:
                        try M3UPlaylistParser.parse(data: data, context: context)
                        completion(nil)
                    case .xtreamCodes:
                        XtreamCodesParser.parse(url: url, context: context) { error in
                            completion(error)
                        }
                    case .unknown:
                        completion(NSError(domain: "PlaylistParser", code: 2, userInfo: [NSLocalizedDescriptionKey: "Unknown playlist type."]))
                    }
                } catch {
                    completion(error)
                }
            }
        }
        task.resume()
    }
}
