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
    public static func parse(url: URL, context: NSManagedObjectContext) async throws {
        let actions = ["get_vod_streams", "get_series", "get_live_streams"]

        for action in actions {
            guard var components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
                throw PlaylistImportError.invalidURL
            }

            components.path = "/player_api.php"

            var queryItems = components.queryItems ?? []
            queryItems.append(URLQueryItem(name: "action", value: action))
            components.queryItems = queryItems

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
                        try items.forEach { try self.saveVOD(from: $0, baseURL: url, context: context) }
                    case "get_series":
                        let items = try decoder.decode([XtreamCodesSeries].self, from: data)
                        try items.forEach { try self.saveSeries(from: $0, baseURL: url, context: context) }
                    case "get_live_streams":
                        let items = try decoder.decode([XtreamCodesLive].self, from: data)
                        try items.forEach { try self.saveLiveStream(from: $0, baseURL: url, context: context) }
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

        do {
            try await context.perform {
                try context.save()
            }
        } catch {
            throw PlaylistImportError.saveDataFailed(error)
        }
    }

    /// Saves a VOD item to Core Data as a `Movie`.
    /// - Parameters:
    ///   - vod: The `XtreamCodesVOD` to save.
    ///   - baseURL: The base URL of the Xtream Codes playlist.
    ///   - context: The `NSManagedObjectContext` to perform the save on.
    /// - Throws: An error if there is a problem saving to Core Data.
    private static func saveVOD(from vod: XtreamCodesVOD, baseURL: URL, context: NSManagedObjectContext) throws {
        let fetchRequest: NSFetchRequest<Movie> = Movie.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "title == %@", vod.name)

        if try context.fetch(fetchRequest).isEmpty {
            let movie = Movie(context: context)
            movie.title = vod.name
            movie.posterURL = vod.streamIcon
            movie.rating = vod.rating
            movie.streamURL = buildStreamURL(for: "movie", baseURL: baseURL, id: vod.streamId, ext: vod.containerExtension ?? "mp4")
        }
    }

    /// Saves a series to Core Data as a `Series`.
    /// - Parameters:
    ///   - seriesData: The `XtreamCodesSeries` to save.
    ///   - baseURL: The base URL of the Xtream Codes playlist.
    ///   - context: The `NSManagedObjectContext` to perform the save on.
    /// - Throws: An error if there is a problem saving to Core Data.
    private static func saveSeries(from seriesData: XtreamCodesSeries, baseURL: URL, context: NSManagedObjectContext) throws {
        let fetchRequest: NSFetchRequest<Series> = Series.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "title == %@", seriesData.name)

        if try context.fetch(fetchRequest).isEmpty {
            let series = Series(context: context)
            series.title = seriesData.name
            series.posterURL = seriesData.cover
            series.summary = seriesData.plot
            series.rating = seriesData.rating

            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyy-MM-dd"
            if let dateStr = seriesData.releaseDate {
                series.releaseDate = dateFormatter.date(from: dateStr)
            }
        }
    }

    /// Saves a live stream to Core Data as a `Channel`.
    /// - Parameters:
    ///   - live: The `XtreamCodesLive` to save.
    ///   - baseURL: The base URL of the Xtream Codes playlist.
    ///   - context: The `NSManagedObjectContext` to perform the save on.
    /// - Throws: An error if there is a problem saving to Core Data.
    private static func saveLiveStream(from live: XtreamCodesLive, baseURL: URL, context: NSManagedObjectContext) throws {
        let fetchRequest: NSFetchRequest<Channel> = Channel.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "name == %@", live.name)

        let existingChannels = try context.fetch(fetchRequest)
        let channel: Channel

        if let existingChannel = existingChannels.first {
            channel = existingChannel
        } else {
            channel = Channel(context: context)
            channel.name = live.name
            channel.logoURL = live.streamIcon
        }

        let streamURL = buildStreamURL(for: "live", baseURL: baseURL, id: live.streamId, ext: "m3u8")
        let variantFetchRequest: NSFetchRequest<ChannelVariant> = ChannelVariant.fetchRequest()
        variantFetchRequest.predicate = NSPredicate(format: "streamURL == %@", streamURL ?? "")

        let existingVariants = try context.fetch(variantFetchRequest)
        if existingVariants.isEmpty {
            let variant = ChannelVariant(context: context)
            variant.name = live.name
            variant.streamURL = streamURL
            variant.channel = channel
        }
    }

    /// Builds the full stream URL for a given content type.
    /// - Parameters:
    ///   - type: The type of content ("movie", "live").
    ///   - baseURL: The base URL of the Xtream Codes playlist.
    ///   - id: The stream ID.
    ///   - ext: The stream's container extension.
    /// - Returns: The full stream URL as a string.
    private static func buildStreamURL(for type: String, baseURL: URL, id: Int, ext: String) -> String? {
        guard var components = URLComponents(url: baseURL, resolvingAgainstBaseURL: false),
              let username = components.queryItems?.first(where: { $0.name == "username" })?.value,
              let password = components.queryItems?.first(where: { $0.name == "password" })?.value else {
            return nil
        }

        components.query = nil
        components.path = ""

        guard var finalURL = components.url else { return nil }

        finalURL.appendPathComponent(type)
        finalURL.appendPathComponent(username)
        finalURL.appendPathComponent(password)
        finalURL.appendPathComponent("\(id).\(ext)")

        return finalURL.absoluteString
    }
}
