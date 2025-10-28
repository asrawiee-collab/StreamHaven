import Foundation
import CoreData

/// Manages content grouping and source selection for multi-source playlists.
@MainActor
final class MultiSourceContentManager: ObservableObject {
    
    // MARK: - Types
    
    /// Represents a group of content items from multiple sources.
    struct ContentGroup<T> {
        let primaryItem: T
        let alternativeItems: [T]
        let sourceIDs: [UUID]
        
        var allItems: [T] {
            [primaryItem] + alternativeItems
        }
        
        var itemCount: Int {
            allItems.count
        }
    }
    
    /// Metadata about a stream source.
    struct SourceMetadata {
        let sourceID: UUID
        let sourceName: String
        let isActive: Bool
        let lastRefreshed: Date?
    }
    
    // MARK: - Properties
    
    private let context: NSManagedObjectContext
    private let similarityThreshold: Double = 0.85
    
    // MARK: - Initialization
    
    init(context: NSManagedObjectContext) {
        self.context = context
    }
    
    // MARK: - Content Grouping
    
    /// Groups movies by similar titles and metadata.
    func groupMovies(for profile: Profile) throws -> [ContentGroup<Movie>] {
        let activeSources = profile.activeSources
        guard profile.mode == .combined else {
            // In single mode, return ungrouped movies
            return try fetchMovies(for: profile).map { ContentGroup(primaryItem: $0, alternativeItems: [], sourceIDs: [$0.sourceID].compactMap { $0 }) }
        }
        
        let movies = try fetchMovies(for: profile)
        return groupItems(movies, by: { $0.title ?? "" }, sourceIDs: activeSources.map { $0.sourceID }.compactMap { $0 })
    }
    
    /// Groups series by similar titles and metadata.
    func groupSeries(for profile: Profile) throws -> [ContentGroup<Series>] {
        let activeSources = profile.activeSources
        guard profile.mode == .combined else {
            return try fetchSeries(for: profile).map { ContentGroup(primaryItem: $0, alternativeItems: [], sourceIDs: [$0.sourceID].compactMap { $0 }) }
        }
        
        let series = try fetchSeries(for: profile)
        return groupItems(series, by: { $0.title ?? "" }, sourceIDs: activeSources.map { $0.sourceID }.compactMap { $0 })
    }
    
    /// Groups channels by similar names and metadata.
    func groupChannels(for profile: Profile) throws -> [ContentGroup<Channel>] {
        let activeSources = profile.activeSources
        guard profile.mode == .combined else {
            return try fetchChannels(for: profile).map { ContentGroup(primaryItem: $0, alternativeItems: [], sourceIDs: [$0.sourceID].compactMap { $0 }) }
        }
        
        let channels = try fetchChannels(for: profile)
        return groupItems(channels, by: { $0.name ?? "" }, sourceIDs: activeSources.map { $0.sourceID }.compactMap { $0 })
    }
    
    // MARK: - Fetching
    
    private func fetchMovies(for profile: Profile) throws -> [Movie] {
        let fetchRequest: NSFetchRequest<Movie> = Movie.fetchRequest()
        let sourceIDs = profile.activeSources.compactMap { $0.sourceID }
        
        if !sourceIDs.isEmpty {
            fetchRequest.predicate = NSPredicate(format: "sourceID IN %@", sourceIDs)
        }
        
        return try context.fetch(fetchRequest)
    }
    
    private func fetchSeries(for profile: Profile) throws -> [Series] {
        let fetchRequest: NSFetchRequest<Series> = Series.fetchRequest()
        let sourceIDs = profile.activeSources.compactMap { $0.sourceID }
        
        if !sourceIDs.isEmpty {
            fetchRequest.predicate = NSPredicate(format: "sourceID IN %@", sourceIDs)
        }
        
        return try context.fetch(fetchRequest)
    }
    
    private func fetchChannels(for profile: Profile) throws -> [Channel] {
        let fetchRequest: NSFetchRequest<Channel> = Channel.fetchRequest()
        let sourceIDs = profile.activeSources.compactMap { $0.sourceID }
        
        if !sourceIDs.isEmpty {
            fetchRequest.predicate = NSPredicate(format: "sourceID IN %@", sourceIDs)
        }
        
        return try context.fetch(fetchRequest)
    }
    
    // MARK: - Grouping Logic
    
    private func groupItems<T>(_ items: [T], by keyPath: (T) -> String, sourceIDs: [UUID]) -> [ContentGroup<T>] {
        var groups: [String: [T]] = [:]
        
        // Group items by normalized title
        for item in items {
            let title = keyPath(item)
            let normalizedTitle = normalizeTitle(title)
            
            if groups[normalizedTitle] == nil {
                groups[normalizedTitle] = []
            }
            groups[normalizedTitle]?.append(item)
        }
        
        // Convert groups to ContentGroup objects
        return groups.values.compactMap { groupItems in
            guard let primary = groupItems.first else { return nil }
            let alternatives = Array(groupItems.dropFirst())
            let itemSourceIDs = groupItems.compactMap { item -> UUID? in
                if let movie = item as? Movie {
                    return movie.sourceID
                } else if let series = item as? Series {
                    return series.sourceID
                } else if let channel = item as? Channel {
                    return channel.sourceID
                }
                return nil
            }
            return ContentGroup(primaryItem: primary, alternativeItems: alternatives, sourceIDs: itemSourceIDs)
        }
        .sorted { lhs, rhs in
            // Sort by title
            let lhsTitle = keyPath(lhs.primaryItem)
            let rhsTitle = keyPath(rhs.primaryItem)
            return lhsTitle < rhsTitle
        }
    }
    
    /// Normalizes a title for comparison (removes special characters, converts to lowercase, etc.)
    private func normalizeTitle(_ title: String) -> String {
        // Remove common prefixes
        var normalized = title
            .lowercased()
            .trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Remove "the", "a", "an" prefixes
        let prefixes = ["the ", "a ", "an "]
        for prefix in prefixes {
            if normalized.hasPrefix(prefix) {
                normalized = String(normalized.dropFirst(prefix.count))
                break
            }
        }
        
        // Remove special characters and extra spaces
        normalized = normalized
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .joined(separator: " ")
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespaces)
        
        return normalized
    }
    
    // MARK: - Source Metadata
    
    /// Gets metadata for a source by ID.
    func getSourceMetadata(for sourceID: UUID, in profile: Profile) -> SourceMetadata? {
        guard let source = profile.allSources.first(where: { $0.sourceID == sourceID }) else {
            return nil
        }
        
        return SourceMetadata(
            sourceID: sourceID,
            sourceName: source.name ?? "Unknown Source",
            isActive: source.isActive,
            lastRefreshed: source.lastRefreshed
        )
    }
    
    /// Gets all source metadata for items in a group.
    func getSourceMetadata(for group: ContentGroup<some Any>, in profile: Profile) -> [SourceMetadata] {
        return group.sourceIDs.compactMap { getSourceMetadata(for: $0, in: profile) }
    }
    
    // MARK: - Quality Assessment
    
    /// Assesses the quality of a stream URL based on resolution hints in the URL or name.
    func assessQuality(streamURL: String?, name: String?) -> Int {
        let text = "\(streamURL ?? "") \(name ?? "")".lowercased()
        
        if text.contains("4k") || text.contains("2160p") {
            return 5
        } else if text.contains("1080p") || text.contains("fhd") {
            return 4
        } else if text.contains("720p") || text.contains("hd") {
            return 3
        } else if text.contains("480p") || text.contains("sd") {
            return 2
        } else {
            return 1 // Unknown/low quality
        }
    }
    
    /// Selects the best item from a group based on quality and source reliability.
    func selectBestItem<T>(from group: ContentGroup<T>) -> T {
        // For now, return the primary item (first one found)
        // In a more advanced implementation, this could consider:
        // - Stream quality (resolution, bitrate)
        // - Source reliability (error rate, response time)
        // - User preferences (preferred sources)
        return group.primaryItem
    }
    
}
