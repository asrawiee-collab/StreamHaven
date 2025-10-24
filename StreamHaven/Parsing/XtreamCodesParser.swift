import Foundation
import CoreData

/// A parser for processing Xtream Codes playlists and importing their content into Core Data.
public class XtreamCodesParser {

    /// A struct representing a single VOD (Video on Demand) item from an Xtream Codes API response.
    public struct XtreamCodesVOD: Decodable {
        /// The name of the VOD item.
        let name: String
        /// The stream ID of the VOD item.
        let streamId: Int
        /// The URL of the VOD item's icon.
        let streamIcon: String?
        /// The rating of the VOD item.
        let rating: String?
        /// The category ID of the VOD item.
        let categoryId: Int?
        /// The container extension of the VOD item (e.g., "mp4", "mkv").
        let containerExtension: String?
    }

    /// A struct representing a single series from an Xtream Codes API response.
    public struct XtreamCodesSeries: Decodable {
        /// The name of the series.
        let name: String
        /// The series ID.
        let seriesId: Int
        /// The URL of the series' cover art.
        let cover: String?
        /// A summary of the series' plot.
        let plot: String?
        /// The cast of the series.
        let cast: String?
        /// The director of the series.
        let director: String?
        /// The genre of the series.
        let genre: String?
        /// The release date of the series.
        let releaseDate: String?
        /// The rating of the series.
        let rating: String?
        /// The category ID of the series.
        let categoryId: Int?
    }

    /// A struct representing a single live stream channel from an Xtream Codes API response.
    public struct XtreamCodesLive: Decodable {
        /// The name of the live stream.
        let name: String
        /// The stream ID of the live stream.
        let streamId: Int
        /// The URL of the live stream's icon.
        let streamIcon: String?
        /// The category ID of the live stream.
        let categoryId: Int?
    }

    /// Fetches and parses all content types (VOD, series, live streams) from an Xtream Codes playlist URL.
    ///
    /// - Parameters:
    ///   - url: The base URL of the Xtream Codes playlist.
    ///   - context: The `NSManagedObjectContext` to perform the import on.
    /// - Throws: A `PlaylistImportError` if the URL is invalid, a network request fails, or parsing fails.
    public static func parse(url: URL, username: String, password: String, context: NSManagedObjectContext) async throws {
        let actions = ["get_vod_streams", "get_series", "get_live_streams"]

        for action in actions {
            guard var components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
                throw PlaylistImportError.invalidURL
            }

            components.path = "/player_api.php"
            components.queryItems = [
                URLQueryItem(name: "username", value: username),
                URLQueryItem(name: "password", value: password),
                URLQueryItem(name: "action", value: action)
            ]

            guard let actionURL = components.url else {
                throw PlaylistImportError.invalidURL
            }

            do {
                let (data, _) = try await URLSession.shared.data(from: actionURL)
                let decoder = JSONDecoder()
                decoder.keyDecodingStrategy = .convertFromSnakeCase

                try await context.perform {
                    switch action {
                    case "get_vod_streams":
                        let items = try decoder.decode([XtreamCodesVOD].self, from: data)
                        try self.batchInsertVOD(items: items, baseURL: url, username: username, password: password, context: context)
                    case "get_series":
                        let items = try decoder.decode([XtreamCodesSeries].self, from: data)
                        try self.batchInsertSeries(items: items, baseURL: url, context: context)
                    case "get_live_streams":
                        let items = try decoder.decode([XtreamCodesLive].self, from: data)
                        try self.importLiveStreams(items: items, baseURL: url, username: username, password: password, context: context)
                    default:
                        break
                    }
                }
            } catch let error as URLError {
                throw PlaylistImportError.networkError(error)
            } catch {
                throw PlaylistImportError.parsingFailed(error)
            }
        }
    }

    private static func batchInsertVOD(items: [XtreamCodesVOD], baseURL: URL, username: String, password: String, context: NSManagedObjectContext) throws {
        guard !items.isEmpty else { return }

        let existingTitles: Set<String> = try {
            let fetchRequest: NSFetchRequest<Movie> = Movie.fetchRequest()
            fetchRequest.propertiesToFetch = ["title"]
            return Set(try context.fetch(fetchRequest).compactMap { $0.title })
        }()

        let uniqueItems = items.filter { !existingTitles.contains($0.name) }
        guard !uniqueItems.isEmpty else { return }

        let batchInsert = NSBatchInsertRequest(entityName: "Movie", objects: uniqueItems.map {
            let streamURL = buildStreamURL(baseURL: baseURL, type: "movie", username: username, password: password, id: $0.streamId, ext: $0.containerExtension ?? "mp4")
            return [
                "title": $0.name,
                "posterURL": $0.streamIcon ?? "",
                "rating": $0.rating ?? "",
                "streamURL": streamURL
            ]
        })

        try context.execute(batchInsert)
    }

    private static func batchInsertSeries(items: [XtreamCodesSeries], baseURL: URL, context: NSManagedObjectContext) throws {
        guard !items.isEmpty else { return }

        let existingTitles: Set<String> = try {
            let fetchRequest: NSFetchRequest<Series> = Series.fetchRequest()
            fetchRequest.propertiesToFetch = ["title"]
            return Set(try context.fetch(fetchRequest).compactMap { $0.title })
        }()

        let uniqueItems = items.filter { !existingTitles.contains($0.name) }
        guard !uniqueItems.isEmpty else { return }

        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"

        let batchInsert = NSBatchInsertRequest(entityName: "Series", objects: uniqueItems.map {
            var seriesDict: [String: Any] = [
                "title": $0.name,
                "posterURL": $0.cover ?? "",
                "summary": $0.plot ?? "",
                "rating": $0.rating ?? ""
            ]
            if let dateStr = $0.releaseDate, let date = dateFormatter.date(from: dateStr) {
                seriesDict["releaseDate"] = date
            }
            return seriesDict
        })

        try context.execute(batchInsert)
    }

    private static func importLiveStreams(items: [XtreamCodesLive], baseURL: URL, username: String, password: String, context: NSManagedObjectContext) throws {
        guard !items.isEmpty else { return }

        let existingChannels: [String: Channel] = try {
            let fetchRequest: NSFetchRequest<Channel> = Channel.fetchRequest()
            return Dictionary(try context.fetch(fetchRequest).map { ($0.name!, $0) }, uniquingKeysWith: { (first, _) in first })
        }()

        let existingVariantURLs: Set<String> = try {
            let fetchRequest: NSFetchRequest<ChannelVariant> = ChannelVariant.fetchRequest()
            return Set(try context.fetch(fetchRequest).compactMap { $0.streamURL })
        }()

        for item in items {
            let channel = existingChannels[item.name] ?? {
                let newChannel = Channel(context: context)
                newChannel.name = item.name
                newChannel.logoURL = item.streamIcon
                return newChannel
            }()

            let streamURL = buildStreamURL(baseURL: baseURL, type: "live", username: username, password: password, id: item.streamId, ext: "m3u8")
            if !existingVariantURLs.contains(streamURL) {
                let variant = ChannelVariant(context: context)
                variant.name = item.name
                variant.streamURL = streamURL
                variant.channel = channel
            }
        }

        if context.hasChanges {
            try context.save()
        }
    }

    private static func buildStreamURL(baseURL: URL, type: String, username: String, password: String, id: Int, ext: String) -> String {
        var components = URLComponents(url: baseURL, resolvingAgainstBaseURL: false)!
        components.query = nil
        components.path = ""
        var finalURL = components.url!
        finalURL.appendPathComponent(type)
        finalURL.appendPathComponent(username)
        finalURL.appendPathComponent(password)
        finalURL.appendPathComponent("\(id).\(ext)")
        return finalURL.absoluteString
    }
}
