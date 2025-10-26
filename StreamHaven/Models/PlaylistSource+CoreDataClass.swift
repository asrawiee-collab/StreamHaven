import Foundation
import CoreData

/// Represents a playlist source (M3U or Xtream Codes) for a user profile.
/// This class is a Core Data managed object.
@objc(PlaylistSource)
public class PlaylistSource: NSManagedObject {

}

extension PlaylistSource {

    /// Creates a fetch request for the `PlaylistSource` entity.
    /// - Returns: A `NSFetchRequest<PlaylistSource>` to fetch `PlaylistSource` objects.
    @nonobjc public class func fetchRequest() -> NSFetchRequest<PlaylistSource> {
        return NSFetchRequest<PlaylistSource>(entityName: "PlaylistSource")
    }

    /// Unique identifier for the source.
    @NSManaged public var sourceID: UUID?
    /// User-defined name for the source.
    @NSManaged public var name: String?
    /// Type of source: "m3u" or "xtream".
    @NSManaged public var sourceType: String?
    /// URL for M3U playlists or Xtream Codes server.
    @NSManaged public var url: String?
    /// Username for Xtream Codes authentication.
    @NSManaged public var username: String?
    /// Password for Xtream Codes authentication (stored securely in Keychain via manager).
    @NSManaged public var password: String?
    /// Whether this source is currently active.
    @NSManaged public var isActive: Bool
    /// Display order for sorting sources.
    @NSManaged public var displayOrder: Int32
    /// Date when the source was created.
    @NSManaged public var createdAt: Date?
    /// Date when the source was last refreshed.
    @NSManaged public var lastRefreshed: Date?
    /// Last error message from loading this source (if any).
    @NSManaged public var lastError: String?
    /// JSON metadata for additional source configuration.
    @NSManaged public var metadata: String?
    /// The profile that owns this source.
    @NSManaged public var profile: Profile?

}

// MARK: - Convenience Methods
extension PlaylistSource {
    
    /// Source type constants.
    enum SourceType: String {
        case m3u = "m3u"
        case xtream = "xtream"
    }
    
    /// Returns the source type as an enum.
    var type: SourceType? {
        guard let sourceType = sourceType else { return nil }
        return SourceType(rawValue: sourceType)
    }
    
    /// Returns true if this is an M3U source.
    var isM3U: Bool {
        return type == .m3u
    }
    
    /// Returns true if this is an Xtream Codes source.
    var isXtream: Bool {
        return type == .xtream
    }
    
    /// Returns a display-friendly description of the source.
    var displayDescription: String {
        let typeName = type == .m3u ? "M3U Playlist" : "Xtream Codes"
        let statusText = isActive ? "Active" : "Inactive"
        return "\(name ?? "Unnamed") (\(typeName)) - \(statusText)"
    }
    
}
