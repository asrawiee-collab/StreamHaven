import Foundation
import CoreData

enum M3UParserError: Error, LocalizedError {
    case invalidDataEncoding
    case coreDataSaveFailed(Error)

    var errorDescription: String? {
        switch self {
        case .invalidDataEncoding:
            return NSLocalizedString("The playlist file could not be read. Please ensure it's a valid UTF-8 encoded file.", comment: "M3U parser error for invalid encoding")
        case .coreDataSaveFailed(let underlyingError):
            return NSLocalizedString("Failed to save playlist data: \(underlyingError.localizedDescription)", comment: "M3U parser error for Core Data save failure")
        }
    }
}

class M3UPlaylistParser {

    struct M3UChannel {
        let title: String
        let logoURL: String?
        let group: String?
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

    static func parse(data: Data, context: NSManagedObjectContext) throws {
        guard let content = String(data: data, encoding: .utf8) else {
            throw M3UParserError.invalidDataEncoding
        }

        let lines = content.components(separatedBy: .newlines)
        var channels: [M3UChannel] = []
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
                        title = currentChannelInfo["tvg-name"] ?? "Unknown Channel"
                    }
                    let logo = currentChannelInfo["tvg-logo"]
                    let group = currentChannelInfo["group-title"]
                    let url = line

                    let channel = M3UChannel(title: title, logoURL: logo, group: group, url: url)
                    channels.append(channel)

                    if let groupTitle = channel.group, groupTitle.localizedCaseInsensitiveContains("Movie") {
                        try saveMovie(from: channel, context: context)
                    } else {
                        try saveChannel(from: channel, context: context)
                    }
                }
            }
        }

        do {
            try context.save()
            print("Successfully saved \(channels.count) channels from M3U playlist.")
        } catch {
            throw M3UParserError.coreDataSaveFailed(error)
        }
    }

    private static func saveChannel(from m3uChannel: M3UChannel, context: NSManagedObjectContext) throws {
        let fetchRequest: NSFetchRequest<Channel> = Channel.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "name == %@", m3uChannel.title)

        let existingChannels = try context.fetch(fetchRequest)
        let channel: Channel

        if let existingChannel = existingChannels.first {
            channel = existingChannel
        } else {
            channel = Channel(context: context)
            channel.name = m3uChannel.title
            channel.logoURL = m3uChannel.logoURL
        }

        let variantFetchRequest: NSFetchRequest<ChannelVariant> = ChannelVariant.fetchRequest()
        variantFetchRequest.predicate = NSPredicate(format: "streamURL == %@", m3uChannel.url)

        let existingVariants = try context.fetch(variantFetchRequest)
        if existingVariants.isEmpty {
            let variant = ChannelVariant(context: context)
            variant.name = m3uChannel.title
            variant.streamURL = m3uChannel.url
            variant.channel = channel
        }
    }

    private static func saveMovie(from m3uChannel: M3UChannel, context: NSManagedObjectContext) throws {
        let fetchRequest: NSFetchRequest<Movie> = Movie.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "title == %@", m3uChannel.title)

        if try context.fetch(fetchRequest).isEmpty {
            let movie = Movie(context: context)
            movie.title = m3uChannel.title
            movie.posterURL = m3uChannel.logoURL
            movie.streamURL = m3uChannel.url
            // M3U provides limited metadata, so other fields are left nil
        }
    }
}
