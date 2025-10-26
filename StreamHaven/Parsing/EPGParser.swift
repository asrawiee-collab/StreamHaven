import Foundation
import CoreData

/// A parser for processing XMLTV format EPG data and importing it into Core Data.
public class EPGParser: NSObject, XMLParserDelegate {
    
    private var context: NSManagedObjectContext
    private var currentElement = ""
    private var currentProgramme: [String: String] = [:]
    private var currentTextContent = ""
    private var parsedEntries: [EPGProgramme] = []
    
    /// A struct representing a single programme parsed from XMLTV data.
    private struct EPGProgramme {
        let channelID: String
        let title: String
        let description: String?
        let category: String?
        let startTime: Date
        let endTime: Date
    }
    
    /// Initializes a new `EPGParser`.
    /// - Parameter context: The `NSManagedObjectContext` to perform the import on.
    public init(context: NSManagedObjectContext) {
        self.context = context
        super.init()
    }
    
    /// Parses XMLTV format EPG data and saves it to Core Data.
    ///
    /// - Parameters:
    ///   - data: The raw `Data` of the XMLTV file.
    ///   - context: The `NSManagedObjectContext` to perform the import on.
    /// - Throws: An error if the data cannot be parsed or if there is a problem saving to Core Data.
    public static func parse(data: Data, context: NSManagedObjectContext) throws {
        let parser = EPGParser(context: context)
        let xmlParser = XMLParser(data: data)
        xmlParser.delegate = parser
        
        guard xmlParser.parse() else {
            if let error = xmlParser.parserError {
                throw PlaylistImportError.parsingFailed(error)
            }
            throw PlaylistImportError.parsingFailed(NSError(domain: "EPGParser", code: 1, userInfo: [NSLocalizedDescriptionKey: "Unknown parsing error"]))
        }
        
        try parser.saveToCoreData()
    }
    
    /// Parses an XMLTV date-time string and converts it to a Date.
    /// XMLTV format: YYYYMMDDHHmmss +HHMM
    /// Example: 20231024180000 +0000
    private func parseXMLTVDate(_ dateString: String) -> Date? {
        // Split on space to separate date/time from timezone
        let components = dateString.components(separatedBy: " ")
        guard components.count >= 1 else { return nil }
        
        let dateTimeString = components[0]
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyyMMddHHmmss"
        dateFormatter.timeZone = TimeZone(secondsFromGMT: 0)
        
        // Parse timezone offset if present
        if components.count > 1 {
            let timezone = components[1]
            if timezone.hasPrefix("+") || timezone.hasPrefix("-") {
                let sign = timezone.hasPrefix("+") ? 1 : -1
                let offset = String(timezone.dropFirst())
                if offset.count == 4,
                   let hours = Int(offset.prefix(2)),
                   let minutes = Int(offset.suffix(2)) {
                    let secondsOffset = sign * (hours * 3600 + minutes * 60)
                    dateFormatter.timeZone = TimeZone(secondsFromGMT: secondsOffset)
                }
            }
        }
        
        return dateFormatter.date(from: dateTimeString)
    }
    
    // MARK: - XMLParserDelegate
    
    public func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName qName: String?, attributes attributeDict: [String : String] = [:]) {
        currentElement = elementName
        currentTextContent = ""
        
        if elementName == "programme" {
            currentProgramme = [:]
            if let channel = attributeDict["channel"] {
                currentProgramme["channel"] = channel
            }
            if let start = attributeDict["start"] {
                currentProgramme["start"] = start
            }
            if let stop = attributeDict["stop"] {
                currentProgramme["stop"] = stop
            }
        }
    }
    
    public func parser(_ parser: XMLParser, foundCharacters string: String) {
        currentTextContent += string.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    public func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName qName: String?) {
        switch elementName {
        case "title":
            currentProgramme["title"] = currentTextContent
        case "desc":
            currentProgramme["desc"] = currentTextContent
        case "category":
            currentProgramme["category"] = currentTextContent
        case "programme":
            // Finished parsing a programme element
            if let channelID = currentProgramme["channel"],
               let title = currentProgramme["title"],
               let startString = currentProgramme["start"],
               let stopString = currentProgramme["stop"],
               let startTime = parseXMLTVDate(startString),
               let endTime = parseXMLTVDate(stopString) {
                
                let programme = EPGProgramme(
                    channelID: channelID,
                    title: title,
                    description: currentProgramme["desc"],
                    category: currentProgramme["category"],
                    startTime: startTime,
                    endTime: endTime
                )
                parsedEntries.append(programme)
            }
            currentProgramme = [:]
        default:
            break
        }
        
        currentElement = ""
        currentTextContent = ""
    }
    
    /// Saves the parsed EPG entries to Core Data.
    private func saveToCoreData() throws {
        guard !parsedEntries.isEmpty else { return }
        
        // Fetch all channels and create a lookup dictionary by tvgID
        let channelFetch: NSFetchRequest<Channel> = Channel.fetchRequest()
        let channels = try context.fetch(channelFetch)
        var channelsByTvgID: [String: Channel] = [:]
        
        for channel in channels {
            if let tvgID = channel.tvgID {
                channelsByTvgID[tvgID] = channel
            }
        }
        
        // Get current time for cleaning old entries
        let now = Date()
        let oneDayAgo = Calendar.current.date(byAdding: .day, value: -1, to: now) ?? now
        
        // Delete old EPG entries (older than 1 day)
        let deleteFetch: NSFetchRequest<NSFetchRequestResult> = EPGEntry.fetchRequest()
        deleteFetch.predicate = NSPredicate(format: "endTime < %@", oneDayAgo as CVarArg)
        let deleteRequest = NSBatchDeleteRequest(fetchRequest: deleteFetch)
        try context.execute(deleteRequest)
        
        // Insert new EPG entries
        var insertedCount = 0
        for programme in parsedEntries {
            guard let channel = channelsByTvgID[programme.channelID] else {
                // Skip entries for channels we don't have
                continue
            }
            
            // Check if this entry already exists
            let existingFetch: NSFetchRequest<EPGEntry> = EPGEntry.fetchRequest()
            existingFetch.predicate = NSPredicate(
                format: "channel == %@ AND startTime == %@ AND title == %@",
                channel, programme.startTime as CVarArg, programme.title
            )
            existingFetch.fetchLimit = 1
            
            let existing = try context.fetch(existingFetch)
            if !existing.isEmpty {
                continue // Skip duplicates
            }
            
            let entry = EPGEntry(context: context)
            entry.channel = channel
            entry.title = programme.title
            entry.descriptionText = programme.description
            entry.category = programme.category
            entry.startTime = programme.startTime
            entry.endTime = programme.endTime
            
            insertedCount += 1
        }
        
        if context.hasChanges {
            try context.save()
            print("Successfully imported \(insertedCount) EPG entries from XMLTV.")
        }
    }
}
