import Foundation
import CoreData

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

    static func parse(url: URL, context: NSManagedObjectContext, completion: @escaping (Error?) -> Void) {
        let group = DispatchGroup()
        var lastError: Error?

        let actions = ["get_vod_streams", "get_series", "get_live_streams"]

        for action in actions {
            group.enter()

            guard var components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
                lastError = NSError(domain: "XtreamCodesParser", code: 1, userInfo: [NSLocalizedDescriptionKey: "Invalid URL"])
                group.leave()
                continue
            }

            components.path = "/player_api.php"

            var queryItems = components.queryItems ?? []
            queryItems.append(URLQueryItem(name: "action", value: action))
            components.queryItems = queryItems

            guard let actionURL = components.url else {
                lastError = NSError(domain: "XtreamCodesParser", code: 2, userInfo: [NSLocalizedDescriptionKey: "Failed to construct URL for action: \\(action)"])
                group.leave()
                continue
            }

            let task = URLSession.shared.dataTask(with: actionURL) { data, response, error in
                defer { group.leave() }

                if let error = error {
                    lastError = error
                    return
                }

                guard let data = data else {
                    lastError = NSError(domain: "XtreamCodesParser", code: 3, userInfo: [NSLocalizedDescriptionKey: "No data received for action: \\(action)"])
                    return
                }

                do {
                    let decoder = JSONDecoder()
                    decoder.keyDecodingStrategy = .convertFromSnakeCase

                    context.performAndWait {
                        do {
                            switch action {
                            case "get_vod_streams":
                                let items = try decoder.decode([XtreamCodesVOD].self, from: data)
                                items.forEach { self.saveVOD(from: $0, baseURL: url, context: context) }
                            case "get_series":
                                let items = try decoder.decode([XtreamCodesSeries].self, from: data)
                                items.forEach { self.saveSeries(from: $0, baseURL: url, context: context) }
                            case "get_live_streams":
                                let items = try decoder.decode([XtreamCodesLive].self, from: data)
                                items.forEach { self.saveLiveStream(from: $0, baseURL: url, context: context) }
                            default:
                                break
                            }
                            try context.save()
                        } catch {
                            lastError = error
                        }
                    }
                } catch {
                    lastError = error
                }
            }
            task.resume()
        }

        group.notify(queue: .main) {
            completion(lastError)
        }
    }

    private static func saveVOD(from vod: XtreamCodesVOD, baseURL: URL, context: NSManagedObjectContext) {
        let fetchRequest: NSFetchRequest<Movie> = Movie.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "title == %@", vod.name)

        do {
            if try context.fetch(fetchRequest).isEmpty {
                let movie = Movie(context: context)
                movie.title = vod.name
                movie.posterURL = vod.streamIcon
                movie.rating = vod.rating
                movie.streamURL = buildStreamURL(for: "movie", baseURL: baseURL, id: vod.streamId, ext: vod.containerExtension ?? "mp4")
            }
        } catch {
            print("Failed to process VOD: \\(vod.name). Error: \\(error)")
        }
    }

    private static func saveSeries(from seriesData: XtreamCodesSeries, baseURL: URL, context: NSManagedObjectContext) {
        let fetchRequest: NSFetchRequest<Series> = Series.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "title == %@", seriesData.name)

        do {
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
        } catch {
            print("Failed to process Series: \\(seriesData.name). Error: \\(error)")
        }
    }

    private static func saveLiveStream(from live: XtreamCodesLive, baseURL: URL, context: NSManagedObjectContext) {
        let fetchRequest: NSFetchRequest<Channel> = Channel.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "name == %@", live.name)

        do {
            if try context.fetch(fetchRequest).isEmpty {
                let channel = Channel(context: context)
                channel.name = live.name
                channel.logoURL = live.streamIcon

                let variant = ChannelVariant(context: context)
                variant.name = live.name
                variant.streamURL = buildStreamURL(for: "live", baseURL: baseURL, id: live.streamId, ext: "m3u8")
                variant.channel = channel
            }
        } catch {
            print("Failed to process Live Stream: \\(live.name). Error: \\(error)")
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

        guard let baseURL = components.url else { return nil }

        return "\\(baseURL)\\(type)/\\(username)/\\(password)/\\(id).\\(ext)"
    }
}
