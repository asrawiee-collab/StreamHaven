import Foundation
import CoreData

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
            fatalError("Failed to compile attribute regex: \\(error)")
        }
    }()

    static func parse(data: Data, context: NSManagedObjectContext) {
        guard let content = String(data: data, encoding: .utf8) else {
            print("Failed to decode M3U data.")
            return
        }

        let lines = content.components(separatedBy: .newlines)
        var channels: [M3UChannel] = []
        var currentChannelInfo: [String: String] = [:]

        for i in 0..<lines.count {
            let line = lines[i].trimmingCharacters(in: .whitespaces)

            if line.uppercased().hasPrefix("#EXTINF:") {
                currentChannelInfo = [:]

                let infoString = String(line.dropFirst("#EXTINF:".count))

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

                    saveChannel(from: channel, context: context)
                }
            }
        }

        do {
            try context.save()
            print("Successfully saved \\(channels.count) channels from M3U playlist.")
        } catch {
            print("Failed to save Core Data context: \\(error)")
        }
    }

    private static func saveChannel(from m3uChannel: M3UChannel, context: NSManagedObjectContext) {
        let fetchRequest: NSFetchRequest<Channel> = Channel.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "name == %@", m3uChannel.title)

        do {
            let existingChannels = try context.fetch(fetchRequest)
            let channel: Channel

            if let existingChannel = existingChannels.first {
                channel = existingChannel
            } else {
                channel = Channel(context: context)
                channel.name = m3uChannel.title
                channel.logoURL = m3uChannel.logoURL
            }

            let variant = ChannelVariant(context: context)
            variant.name = m3uChannel.title
            variant.streamURL = m3uChannel.url
            variant.channel = channel

        } catch {
            print("Failed to fetch or create channel: \\(m3uChannel.title). Error: \\(error)")
        }
    }
}
