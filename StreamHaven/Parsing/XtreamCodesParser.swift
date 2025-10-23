import Foundation
import CoreData

enum XtreamCodesParserError: Error, LocalizedError {
    case invalidURL
    case networkError(Error)
    case noDataReceived
    case jsonDecodingError(Error)
    case coreDataSaveFailed(Error)

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return NSLocalizedString("The provided URL is invalid.", comment: "Xtream Codes parser error for invalid URL")
        case .networkError(let underlyingError):
            return NSLocalizedString("A network error occurred: \(underlyingError.localizedDescription)", comment: "Xtream Codes parser error for network issues")
        case .noDataReceived:
            return NSLocalizedString("No data was received from the server.", comment: "Xtream Codes parser error for empty response")
        case .jsonDecodingError:
            return NSLocalizedString("Failed to decode the server's response. The playlist format may be incorrect.", comment: "Xtream Codes parser error for JSON decoding failure")
        case .coreDataSaveFailed(let underlyingError):
            return NSLocalizedString("Failed to save playlist data: \(underlyingError.localizedDescription)", comment: "Xtream Codes parser error for Core Data save failure")
        }
    }
}

class XtreamCodesParser {

    struct XtreamCodesVOD: Decodable {
        let name: String
        let streamId: Int
        let streamIcon: String?
        let rating: String?
        let categoryId: Int?
        let containerExtension: String?
    }

    struct XtreamCodesSeries: Decodable {
        let name: String
        let seriesId: Int
        let cover: String?
        let plot: String?
        let cast: String?
        let director: String?
        let genre: String?
        let releaseDate: String?
        let rating: String?
        let categoryId: Int?
    }

    struct XtreamCodesLive: Decodable {
        let name: String
        let streamId: Int
        let streamIcon: String?
        let categoryId: Int?
    }

    static func parse(url: URL, context: NSManagedObjectContext) async throws {
        let actions = ["get_vod_streams", "get_series", "get_live_streams"]

        for action in actions {
            guard var components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
                throw XtreamCodesParserError.invalidURL
            }

            components.path = "/player_api.php"

            var queryItems = components.queryItems ?? []
            queryItems.append(URLQueryItem(name: "action", value: action))
            components.queryItems = queryItems

            guard let actionURL = components.url else {
                throw XtreamCodesParserError.invalidURL
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
                throw XtreamCodesParserError.networkError(error)
            } catch {
                throw XtreamCodesParserError.jsonDecodingError(error)
            }
        }

        do {
            try await context.perform {
                try context.save()
            }
        } catch {
            throw XtreamCodesParserError.coreDataSaveFailed(error)
        }
    }

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
