import Foundation
import CoreData

/// A parser for processing M3U playlists and importing their content into Core Data.
public class M3UPlaylistParser {

    /// A struct representing a single channel parsed from an M3U playlist.
    public struct M3UChannel {
        /// The title of the channel.
        let title: String
        /// The URL of the channel's logo.
        let logoURL: String?
        /// The group or category of the channel.
        let group: String?
        /// The URL of the channel's stream.
        let url: String
    }

    // This regex handles attributes with double quotes, single quotes, or no quotes.
    private static let attributeRegex: NSRegularExpression = {
        do {
            return try NSRegularExpression(pattern: "([\\w-]+)=(\"[^\"]*\"|'[^']*'|[^,\\s]+)", options: .caseInsensitive)
        } catch {
            fatalError("Failed to compile attribute regex: \(error)")
        }
    }()

    /// Parses the content of an M3U playlist and saves the channels and movies to Core Data.
    ///
    /// - Parameters:
    ///   - data: The raw `Data` of the M3U playlist file.
    ///   - context: The `NSManagedObjectContext` to perform the import on.
    /// - Throws: An error if the data cannot be decoded or if there is a problem saving to Core Data.
    public static func parse(data: Data, context: NSManagedObjectContext) throws {
        guard let content = String(data: data, encoding: .utf8) else {
            throw PlaylistImportError.parsingFailed(NSError(domain: "M3UParser", code: 1, userInfo: [NSLocalizedDescriptionKey: "Invalid data encoding"]))
        }

        let lines = content.components(separatedBy: .newlines)
        var movieItems: [M3UChannel] = []
        var channelItems: [M3UChannel] = []
        var currentChannelInfo: [String: String] = [:]

        for i in 0..<lines.count {
            let line = lines[i].trimmingCharacters(in: .whitespaces)

            if line.uppercased().hasPrefix("#EXTINF:") {
                currentChannelInfo = [:]

                guard let infoString = line.split(separator: ",", maxSplits: 1).last.map(String.init) else { continue }

                let matches = attributeRegex.matches(in: infoString, range: NSRange(infoString.startIndex..., in: infoString))

                for match in matches {
                    if let keyRange = Range(match.range(at: 1), in: infoString),
                       let valueRange = Range(match.range(at: 2), in: infoString) {
                        let key = String(infoString[keyRange])
                        var value = String(infoString[valueRange])

                        // Trim quotes
                        if value.hasPrefix("\"") && value.hasSuffix("\"") || value.hasPrefix("'") && value.hasSuffix("'") {
                            value = String(value.dropFirst().dropLast())
                        }

                        currentChannelInfo[key] = value
                    }
                }

                if let commaIndex = infoString.lastIndex(of: ",") {
                    let title = String(infoString.suffix(from: infoString.index(after: commaIndex))).trimmingCharacters(in: .whitespaces)
                    currentChannelInfo["title"] = title
                }

            } else if !line.isEmpty && !line.hasPrefix("#") {
                if var title = currentChannelInfo["title"] {
                    if title.isEmpty {
                        title = currentChannelInfo["tvg-name"] ?? "Unknown"
                    }
                    let logo = currentChannelInfo["tvg-logo"]
                    let group = currentChannelInfo["group-title"]
                    let url = line

                    let channel = M3UChannel(title: title, logoURL: logo, group: group, url: url)

                    if let groupTitle = channel.group, groupTitle.localizedCaseInsensitiveContains("Movie") {
                        movieItems.append(channel)
                    } else {
                        channelItems.append(channel)
                    }
                }
            }
        }

        try batchInsertMovies(items: movieItems, context: context)
        try importChannels(items: channelItems, context: context)

        if context.hasChanges {
            do {
                try context.save()
            } catch {
                throw PlaylistImportError.saveDataFailed(error)
            }
        }
    }

    private static func batchInsertMovies(items: [M3UChannel], context: NSManagedObjectContext) throws {
        guard !items.isEmpty else { return }

        // Fetch existing movie titles to avoid duplicates
        let existingTitles: Set<String> = try {
            let fetchRequest: NSFetchRequest<Movie> = Movie.fetchRequest()
            fetchRequest.propertiesToFetch = ["title"]
            let existingMovies = try context.fetch(fetchRequest)
            return Set(existingMovies.compactMap { $0.title })
        }()

        let uniqueItems = items.filter { !existingTitles.contains($0.title) }

        guard !uniqueItems.isEmpty else { return }

        let batchInsertRequest = NSBatchInsertRequest(entityName: "Movie", objects: uniqueItems.map { item in
            [
                "title": item.title,
                "posterURL": item.logoURL ?? "",
                "streamURL": item.url
            ]
        })

        do {
            try context.execute(batchInsertRequest)
            print("Successfully batch inserted \(uniqueItems.count) movies.")
        } catch {
            throw PlaylistImportError.saveDataFailed(error)
        }
    }

    private static func importChannels(items: [M3UChannel], context: NSManagedObjectContext) throws {
        guard !items.isEmpty else { return }

        // Fetch existing channels and variants to avoid duplicates
        let existingChannels: [String: Channel] = try {
            let fetchRequest: NSFetchRequest<Channel> = Channel.fetchRequest()
            let channels = try context.fetch(fetchRequest)
            return Dictionary(channels.compactMap { $0.name != nil ? ($0.name!, $0) : nil }, uniquingKeysWith: { (first, _) in first })
        }()

        let existingVariantURLs: Set<String> = try {
            let fetchRequest: NSFetchRequest<ChannelVariant> = ChannelVariant.fetchRequest()
            let variants = try context.fetch(fetchRequest)
            return Set(variants.compactMap { $0.streamURL })
        }()

        for item in items {
            let channel: Channel
            if let existingChannel = existingChannels[item.title] {
                channel = existingChannel
            } else {
                channel = Channel(context: context)
                channel.name = item.title
                channel.logoURL = item.logoURL
            }

            if !existingVariantURLs.contains(item.url) {
                let variant = ChannelVariant(context: context)
                variant.name = item.title
                variant.streamURL = item.url
                variant.channel = channel
            }
        }
    }
}
