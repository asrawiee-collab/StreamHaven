import Foundation
import CoreData

enum PlaylistType {
    case m3u
    case xtreamCodes
    case unknown
}

class PlaylistParser {

    static func detectPlaylistType(from url: URL) -> PlaylistType {
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

    static func parse(url: URL, context: NSManagedObjectContext, completion: @escaping (Error?) -> Void) {
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
                switch type {
                case .m3u:
                    M3UPlaylistParser.parse(data: data, context: context)
                    completion(nil)
                case .xtreamCodes:
                    XtreamCodesParser.parse(url: url, context: context) { error in
                        completion(error)
                    }
                case .unknown:
                    completion(NSError(domain: "PlaylistParser", code: 2, userInfo: [NSLocalizedDescriptionKey: "Unknown playlist type."]))
                }
            }
        }
        task.resume()
    }
}
