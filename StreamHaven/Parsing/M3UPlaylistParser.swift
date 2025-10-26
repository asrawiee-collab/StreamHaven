import Foundation
import CoreData

/// A parser for processing M3U playlists and importing their content into Core Data.
public final class M3UPlaylistParser {

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
        /// The tvg-id for EPG linking.
        let tvgID: String?
    }

    // This regex handles attributes with double quotes, single quotes, or no quotes.
    private static let attributeRegex: NSRegularExpression = {
        let pattern = "([\\w-]+)=(\"[^\"]*\"|'[^']*'|[^,\\s]+)"
        do {
            return try NSRegularExpression(pattern: pattern, options: .caseInsensitive)
        } catch {
            // Avoid crashing in production; fall back to a regex that matches nothing and log the issue.
            PerformanceLogger.logNetwork("M3UPlaylistParser: Failed to compile attribute regex: \(error)", level: .error)
            return try! NSRegularExpression(pattern: "(?!)", options: [])
        }
    }()

    /// Parses the content of an M3U playlist and saves the channels and movies to Core Data.
    ///
    /// - Parameters:
    ///   - data: The raw `Data` of the M3U playlist file.
    ///   - sourceID: Optional source ID to associate with imported content.
    ///   - context: The `NSManagedObjectContext` to perform the import on.
    /// - Throws: An error if the data cannot be decoded or if there is a problem saving to Core Data.
    public static func parse(data: Data, sourceID: UUID? = nil, context: NSManagedObjectContext) throws {
        guard let content = String(data: data, encoding: .utf8) else {
            throw PlaylistImportError.parsingFailed(NSError(domain: "M3UParser", code: 1, userInfo: [NSLocalizedDescriptionKey: "Invalid data encoding"]))
        }
        var lines: [String] = []
        content.enumerateLines { line, _ in
            lines.append(line)
        }
        var movieItems: [M3UChannel] = []
        var channelItems: [M3UChannel] = []
        var currentChannelInfo: [String: String] = [:]
        var epgURL: String? = nil

        // Look for #EXTM3U header with url-tvg
        if let firstLine = lines.first, firstLine.uppercased().hasPrefix("#EXTM3U") {
            let header = firstLine
            let headerRegex = try? NSRegularExpression(pattern: "url-tvg=(\"[^\"]*\"|'[^']*'|[^\s]+)", options: .caseInsensitive)
            if let headerRegex = headerRegex {
                let matches = headerRegex.matches(in: header, range: NSRange(header.startIndex..., in: header))
                for match in matches {
                    if let valueRange = Range(match.range(at: 1), in: header) {
                        var value = String(header[valueRange])
                        if value.hasPrefix("\"") && value.hasSuffix("\"") || value.hasPrefix("'") && value.hasSuffix("'") {
                            value = String(value.dropFirst().dropLast())
                        }
                        epgURL = value
                    }
                }
            }
        }

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
                    let tvgID = currentChannelInfo["tvg-id"]

                    let channel = M3UChannel(title: title, logoURL: logo, group: group, url: url, tvgID: tvgID)

                    if let groupTitle = channel.group, groupTitle.localizedCaseInsensitiveContains("Movie") {
                        movieItems.append(channel)
                    } else {
                        channelItems.append(channel)
                    }
                }
            }
        }

        try batchInsertMovies(items: movieItems, sourceID: sourceID, context: context)
        try importChannels(items: channelItems, sourceID: sourceID, context: context)

        // Store EPG URL in PlaylistCache if found
        if let epgURL = epgURL {
            let fetchRequest: NSFetchRequest<PlaylistCache> = PlaylistCache.fetchRequest()
            fetchRequest.fetchLimit = 1
            if let playlistCache = try context.fetch(fetchRequest).first {
                playlistCache.epgURL = epgURL
            }
        }

        if context.hasChanges {
            do {
                try context.save()
            } catch {
                throw PlaylistImportError.saveDataFailed(error)
            }
        }
    }

    /// Streams a playlist file from disk to reduce memory footprint.
    public static func parse(fileURL: URL, sourceID: UUID? = nil, context: NSManagedObjectContext) throws {
        guard let stream = InputStream(url: fileURL) else {
            throw PlaylistImportError.invalidURL
        }
        stream.open()
        defer { stream.close() }

        let bufferSize = 64 * 1024
        var buffer = Array<UInt8>(repeating: 0, count: bufferSize)
        var remainder = Data()
        var movieItems: [M3UChannel] = []
        var channelItems: [M3UChannel] = []
        var currentChannelInfo: [String: String] = [:]
        var epgURL: String? = nil
        var isFirstChunk = true

        func processLine(_ line: String) {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if isFirstChunk {
                isFirstChunk = false
                if trimmed.uppercased().hasPrefix("#EXTM3U") {
                    let header = trimmed
                    let headerRegex = try? NSRegularExpression(pattern: "url-tvg=(\"[^\"]*\"|'[^']*'|[^\s]+)", options: .caseInsensitive)
                    if let headerRegex = headerRegex {
                        let matches = headerRegex.matches(in: header, range: NSRange(header.startIndex..., in: header))
                        for match in matches {
                            if let valueRange = Range(match.range(at: 1), in: header) {
                                var value = String(header[valueRange])
                                if value.hasPrefix("\"") && value.hasSuffix("\"") || value.hasPrefix("'") && value.hasSuffix("'") {
                                    value = String(value.dropFirst().dropLast())
                                }
                                epgURL = value
                            }
                        }
                    }
                }
            }

            if trimmed.uppercased().hasPrefix("#EXTINF:") {
                currentChannelInfo = [:]
                guard let infoString = trimmed.split(separator: ",", maxSplits: 1).last.map(String.init) else { return }
                let matches = attributeRegex.matches(in: infoString, range: NSRange(infoString.startIndex..., in: infoString))
                for match in matches {
                    if let keyRange = Range(match.range(at: 1), in: infoString),
                       let valueRange = Range(match.range(at: 2), in: infoString) {
                        let key = String(infoString[keyRange])
                        var value = String(infoString[valueRange])
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
            } else if !trimmed.isEmpty && !trimmed.hasPrefix("#") {
                if var title = currentChannelInfo["title"] {
                    if title.isEmpty {
                        title = currentChannelInfo["tvg-name"] ?? "Unknown"
                    }
                    let logo = currentChannelInfo["tvg-logo"]
                    let group = currentChannelInfo["group-title"]
                    let url = trimmed
                    let tvgID = currentChannelInfo["tvg-id"]
                    let channel = M3UChannel(title: title, logoURL: logo, group: group, url: url, tvgID: tvgID)
                    if let groupTitle = channel.group, groupTitle.localizedCaseInsensitiveContains("Movie") {
                        movieItems.append(channel)
                    } else {
                        channelItems.append(channel)
                    }
                }
            }
        }

        while stream.hasBytesAvailable {
            let read = stream.read(&buffer, maxLength: bufferSize)
            if read < 0 { break }
            if read == 0 { break }
            let chunk = Data(buffer[0..<read])
            var dataToProcess = remainder
            dataToProcess.append(chunk)
            // Split on \n
            while let range = dataToProcess.firstRange(of: Data([0x0A])) {
                let lineData = dataToProcess.subdata(in: 0..<range.lowerBound)
                // Trim trailing \r
                var trimmedData = lineData
                if trimmedData.last == 0x0D { trimmedData.removeLast() }
                if let line = String(data: trimmedData, encoding: .utf8) {
                    processLine(line)
                }
                dataToProcess.removeSubrange(0..<range.upperBound)
            }
            remainder = dataToProcess
        }
        // Process the last line if any
        if !remainder.isEmpty, let line = String(data: remainder, encoding: .utf8) {
            processLine(line)
        }

        try batchInsertMovies(items: movieItems, sourceID: sourceID, context: context)
        try importChannels(items: channelItems, sourceID: sourceID, context: context)

        if let epgURL = epgURL {
            let fetchRequest: NSFetchRequest<PlaylistCache> = PlaylistCache.fetchRequest()
            fetchRequest.fetchLimit = 1
            if let playlistCache = try context.fetch(fetchRequest).first {
                playlistCache.epgURL = epgURL
            }
        }

        if context.hasChanges {
            do { try context.save() } catch { throw PlaylistImportError.saveDataFailed(error) }
        }
    }

    private static func batchInsertMovies(items: [M3UChannel], sourceID: UUID? = nil, context: NSManagedObjectContext) throws {
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
            var movieDict: [String: Any] = [
                "title": item.title,
                "posterURL": item.logoURL ?? "",
                "streamURL": item.url
            ]
            if let sourceID = sourceID {
                movieDict["sourceID"] = sourceID
            }
            return movieDict
        })

        do {
            try context.execute(batchInsertRequest)
            print("Successfully batch inserted \(uniqueItems.count) movies.")
        } catch {
            throw PlaylistImportError.saveDataFailed(error)
        }
    }

    private static func importChannels(items: [M3UChannel], sourceID: UUID? = nil, context: NSManagedObjectContext) throws {
        guard !items.isEmpty else { return }
        
        // Fetch existing channels to avoid duplicates
        let existingChannelNames: Set<String> = try {
            let fr: NSFetchRequest<Channel> = Channel.fetchRequest()
            fr.propertiesToFetch = ["name"]
            return Set(try context.fetch(fr).compactMap { $0.name })
        }()
        
        // Fetch existing variants to avoid duplicates
        let existingVariantURLs: Set<String> = try {
            let fr: NSFetchRequest<ChannelVariant> = ChannelVariant.fetchRequest()
            fr.propertiesToFetch = ["streamURL"]
            return Set(try context.fetch(fr).compactMap { $0.streamURL })
        }()

        // Batch insert new Channels
        let newChannels = items.filter { !existingChannelNames.contains($0.title) }
        if !newChannels.isEmpty {
            let channelBatchInsert = NSBatchInsertRequest(entityName: "Channel", objects: newChannels.map { item in
                var channelDict: [String: Any] = [
                    "name": item.title,
                    "logoURL": item.logoURL ?? "",
                    "tvgID": item.tvgID ?? ""
                ]
                if let sourceID = sourceID {
                    channelDict["sourceID"] = sourceID
                }
                return channelDict
            })
            try context.execute(channelBatchInsert)
            print("Successfully batch inserted \(newChannels.count) channels.")
        }

        // Refresh channel map after batch insertion
        let channelsByName: [String: Channel] = try {
            let fr: NSFetchRequest<Channel> = Channel.fetchRequest()
            let channels = try context.fetch(fr)
            return Dictionary(channels.compactMap { ch in ch.name.map { ($0, ch) } }, uniquingKeysWith: { a, _ in a })
        }()

        // Batch insert ChannelVariants for any missing stream URLs
        let newVariants = items.filter { !existingVariantURLs.contains($0.url) }
        if !newVariants.isEmpty {
            // Build variant dictionaries with proper relationships
            var variantDicts: [[String: Any]] = []
            for item in newVariants {
                if let channel = channelsByName[item.title] {
                    var variantDict: [String: Any] = [
                        "name": item.title,
                        "streamURL": item.url,
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
                print("Successfully batch inserted \(variantDicts.count) channel variants.")
            }
        }
    }
}
