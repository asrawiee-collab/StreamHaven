import Foundation
import CoreData

/// A parser for processing Xtream Codes playlists and importing their content into Core Data.
public final class XtreamCodesParser {
    /// Dependency-injected URL loading for testability.
    public static var urlSession: URLSession = .shared

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
    ///   - username: The username for authentication.
    ///   - password: The password for authentication.
    ///   - sourceID: Optional source ID to associate with imported content.
    ///   - context: The `NSManagedObjectContext` to perform the import on.
    /// - Throws: A `PlaylistImportError` if the URL is invalid, a network request fails, or parsing fails.
    public static func parse(url: URL, username: String, password: String, sourceID: UUID? = nil, context: NSManagedObjectContext) async throws {
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
                let (data, _) = try await urlSession.data(from: actionURL)
                let decoder = JSONDecoder()
                decoder.keyDecodingStrategy = .convertFromSnakeCase

                try await context.perform {
                    switch action {
                    case "get_vod_streams":
                        let items = try decoder.decode([XtreamCodesVOD].self, from: data)
                        try self.batchInsertVOD(items: items, baseURL: url, username: username, password: password, sourceID: sourceID, context: context)
                    case "get_series":
                        let items = try decoder.decode([XtreamCodesSeries].self, from: data)
                        try self.batchInsertSeries(items: items, baseURL: url, sourceID: sourceID, context: context)
                    case "get_live_streams":
                        let items = try decoder.decode([XtreamCodesLive].self, from: data)
                        try self.importLiveStreams(items: items, baseURL: url, username: username, password: password, sourceID: sourceID, context: context)
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

    private static func batchInsertVOD(items: [XtreamCodesVOD], baseURL: URL, username: String, password: String, sourceID: UUID? = nil, context: NSManagedObjectContext) throws {
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
            var movieDict: [String: Any] = [
                "title": $0.name,
                "posterURL": $0.streamIcon ?? "",
                "rating": $0.rating ?? "",
                "streamURL": streamURL
            ]
            if let sourceID = sourceID {
                movieDict["sourceID"] = sourceID
            }
            return movieDict
        })

        try context.execute(batchInsert)
    }

    private static func batchInsertSeries(items: [XtreamCodesSeries], baseURL: URL, sourceID: UUID? = nil, context: NSManagedObjectContext) throws {
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
            if let sourceID = sourceID {
                seriesDict["sourceID"] = sourceID
            }
            return seriesDict
        })

        try context.execute(batchInsert)
    }

    private static func importLiveStreams(items: [XtreamCodesLive], baseURL: URL, username: String, password: String, sourceID: UUID? = nil, context: NSManagedObjectContext) throws {
        guard !items.isEmpty else { return }

        // Fetch existing channels
        let existingChannelNames: Set<String> = try {
            let fetchRequest: NSFetchRequest<Channel> = Channel.fetchRequest()
            fetchRequest.propertiesToFetch = ["name"]
            return Set(try context.fetch(fetchRequest).compactMap { $0.name })
        }()

        let existingVariantURLs: Set<String> = try {
            let fetchRequest: NSFetchRequest<ChannelVariant> = ChannelVariant.fetchRequest()
            fetchRequest.propertiesToFetch = ["streamURL"]
            return Set(try context.fetch(fetchRequest).compactMap { $0.streamURL })
        }()

        // Batch insert new channels
        let newChannels = items.filter { !existingChannelNames.contains($0.name) }
        if !newChannels.isEmpty {
            let channelBatchInsert = NSBatchInsertRequest(entityName: "Channel", objects: newChannels.map { item in
                var channelDict: [String: Any] = [
                    "name": item.name,
                    "logoURL": item.streamIcon ?? ""
                ]
                if let sourceID = sourceID {
                    channelDict["sourceID"] = sourceID
                }
                return channelDict
            })
            try context.execute(channelBatchInsert)
            print("Successfully batch inserted \(newChannels.count) live channels.")
        }

        // Refresh channel map after batch insertion
        let channelsByName: [String: Channel] = try {
            let fetchRequest: NSFetchRequest<Channel> = Channel.fetchRequest()
            let channels = try context.fetch(fetchRequest)
            let pairs: [(String, Channel)] = channels.compactMap { channel in
                guard let name = channel.name, !name.isEmpty else { return nil }
                return (name, channel)
            }
            return Dictionary(pairs, uniquingKeysWith: { (first, _) in first })
        }()

        // Batch insert new variants
        let newVariants = items.filter { item in
            let streamURL = buildStreamURL(baseURL: baseURL, type: "live", username: username, password: password, id: item.streamId, ext: "m3u8")
            return !existingVariantURLs.contains(streamURL)
        }
        
        if !newVariants.isEmpty {
            var variantDicts: [[String: Any]] = []
            for item in newVariants {
                if let channel = channelsByName[item.name] {
                    let streamURL = buildStreamURL(baseURL: baseURL, type: "live", username: username, password: password, id: item.streamId, ext: "m3u8")
                    var variantDict: [String: Any] = [
                        "name": item.name,
                        "streamURL": streamURL,
                        "channel": channel
                    ]
                    if let sourceID = sourceID {
                        variantDict["sourceID"] = sourceID
                    }
                    variantDicts.append(variantDict)
                }
            }
            
            if !variantDicts.isEmpty {
                let variantBatchInsert = NSBatchInsertRequest(entityName: "ChannelVariant", objects: variantDicts)
                try context.execute(variantBatchInsert)
                print("Successfully batch inserted \(variantDicts.count) live stream variants.")
            }
        }

        if context.hasChanges {
            try context.save()
        }
    }

    private static func buildStreamURL(baseURL: URL, type: String, username: String, password: String, id: Int, ext: String) -> String {
        guard var components = URLComponents(url: baseURL, resolvingAgainstBaseURL: false) else {
            return baseURL.absoluteString
        }
        components.query = nil
        components.path = ""
        guard var finalURL = components.url else {
            return baseURL.absoluteString
        }
        finalURL.appendPathComponent(type)
        finalURL.appendPathComponent(username)
        finalURL.appendPathComponent(password)
        finalURL.appendPathComponent("\(id).\(ext)")
        return finalURL.absoluteString
    }
}
