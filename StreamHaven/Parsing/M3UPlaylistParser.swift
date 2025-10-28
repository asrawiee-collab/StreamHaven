import CoreData
import Foundation

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
    private static let attributeRegex: NSRegularExpression? = {
        let pattern = "([\\w-]+)=(\"[^\"]*\"|'[^']*'|[^,\\s]+)"
        do {
            return try NSRegularExpression(pattern: pattern, options: .caseInsensitive)
        } catch {
            // Avoid crashing in production; fall back to a regex that matches nothing and log the issue.
            PerformanceLogger.logNetwork("M3UPlaylistParser: Failed to compile attribute regex: \(error)", level: .error)
            return nil
        }
    }()

    private static let headerRegex: NSRegularExpression? = {
        let pattern = #"url-tvg=(\"[^\"]*\"|'[^']*'|[^\s]+)"#
        do {
            return try NSRegularExpression(pattern: pattern, options: .caseInsensitive)
        } catch {
            PerformanceLogger.logNetwork("M3UPlaylistParser: Failed to compile header regex: \(error)", level: .error)
            return nil
        }
    }()

    /// Parses the content of an M3U playlist and saves the channels and movies to Core Data.
    ///
    /// - Parameters:
    ///   - data: The raw `Data` of the M3U playlist file.
    ///   - sourceID: Optional source ID to associate with imported content.
    ///   - context: The `NSManagedObjectContext` to perform the import on.
    /// - Throws: An error if the data cannot be decoded or if there is a problem saving to Core Data.
    @available(iOS 13.0, tvOS 13.0, macOS 10.15, *)
    public static func parse(data: Data, sourceID: UUID? = nil, context: NSManagedObjectContext) throws {
        guard let content = String(data: data, encoding: .utf8) else {
            throw PlaylistImportError.parsingFailed(NSError(domain: "M3UParser", code: 1, userInfo: [NSLocalizedDescriptionKey: "Invalid data encoding"]))
        }

        var movieItems: [M3UChannel] = []
        var channelItems: [M3UChannel] = []
        var currentChannelInfo: [String: String] = [:]
        var epgURL: String?

        content.enumerateLines { rawLine, _ in
            let line = rawLine.trimmingCharacters(in: .whitespaces)

            if epgURL == nil, let headerURL = extractEPGURL(from: line) {
                epgURL = headerURL
            }

            if parseInfoLineIfNeeded(line, into: &currentChannelInfo) {
                return
            }

            guard let channel = makeChannelIfNeeded(from: line, info: currentChannelInfo) else { return }

            if let groupTitle = channel.group, groupTitle.localizedCaseInsensitiveContains("Movie") {
                movieItems.append(channel)
            } else {
                channelItems.append(channel)
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
    @available(iOS 13.0, tvOS 13.0, macOS 10.15, *)
    public static func parse(fileURL: URL, sourceID: UUID? = nil, context: NSManagedObjectContext) throws {
        guard let stream = InputStream(url: fileURL) else {
            throw PlaylistImportError.invalidURL
        }
        stream.open()
        defer { stream.close() }

        let bufferSize = 64 * 1024
        var buffer = [UInt8](repeating: 0, count: bufferSize)
        var remainder = Data()
        var movieItems: [M3UChannel] = []
        var channelItems: [M3UChannel] = []
        var currentChannelInfo: [String: String] = [:]
        var epgURL: String?
        var isFirstChunk = true

        func processLine(_ line: String) {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if isFirstChunk {
                isFirstChunk = false
                if let headerURL = extractEPGURL(from: trimmed) {
                    epgURL = headerURL
                }
            }

            if parseInfoLineIfNeeded(trimmed, into: &currentChannelInfo) {
                return
            }

            guard let channel = makeChannelIfNeeded(from: trimmed, info: currentChannelInfo) else { return }

            if let groupTitle = channel.group, groupTitle.localizedCaseInsensitiveContains("Movie") {
                movieItems.append(channel)
            } else {
                channelItems.append(channel)
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

    private static func extractEPGURL(from line: String) -> String? {
        guard line.uppercased().hasPrefix("#EXTM3U"), let headerRegex = headerRegex else {
            return nil
        }

        let range = NSRange(line.startIndex..., in: line)
        guard let match = headerRegex.firstMatch(in: line, range: range),
              let valueRange = Range(match.range(at: 1), in: line) else {
            return nil
        }

        return stripQuotes(String(line[valueRange]))
    }

    private static func parseInfoLineIfNeeded(_ line: String, into info: inout [String: String]) -> Bool {
        guard line.uppercased().hasPrefix("#EXTINF:") else { return false }

        info.removeAll(keepingCapacity: true)

        let infoString = String(line.dropFirst("#EXTINF:".count))
        let attributePortion: String

        if let commaIndex = infoString.firstIndex(of: ",") {
            attributePortion = String(infoString[..<commaIndex])
            let title = infoString[infoString.index(after: commaIndex)...].trimmingCharacters(in: .whitespaces)
            if !title.isEmpty {
                info["title"] = title
            }
        } else {
            attributePortion = infoString
        }

        guard let attributeRegex = attributeRegex else { return true }
        let matches = attributeRegex.matches(in: attributePortion, range: NSRange(attributePortion.startIndex..., in: attributePortion))

        for match in matches {
            guard let keyRange = Range(match.range(at: 1), in: attributePortion),
                  let valueRange = Range(match.range(at: 2), in: attributePortion) else { continue }

            let key = String(attributePortion[keyRange])
            let value = stripQuotes(String(attributePortion[valueRange]))
            info[key] = value
        }

        if info["title"].map({ $0.isEmpty }) ?? true, let fallback = info["tvg-name"], !fallback.isEmpty {
            info["title"] = fallback
        }

        return true
    }

    private static func makeChannelIfNeeded(from line: String, info: [String: String]) -> M3UChannel? {
        guard !line.isEmpty, !line.hasPrefix("#") else { return nil }

        var title = info["title"]?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if title.isEmpty {
            title = info["tvg-name"]?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        }
        if title.isEmpty {
            title = "Unknown"
        }

        return M3UChannel(
            title: title,
            logoURL: info["tvg-logo"],
            group: info["group-title"],
            url: line,
            tvgID: info["tvg-id"]
        )
    }

    private static func stripQuotes(_ value: String) -> String {
        guard !value.isEmpty else { return value }
        if (value.hasPrefix("\"") && value.hasSuffix("\"")) || (value.hasPrefix("'") && value.hasSuffix("'")) {
            return String(value.dropFirst().dropLast())
        }
        return value
    }

    @available(iOS 13.0, tvOS 13.0, macOS 10.15, *)
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

    @available(iOS 13.0, tvOS 13.0, macOS 10.15, *)
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
