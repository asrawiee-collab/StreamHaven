import Foundation
import CoreData

/// Represents the cached data of a playlist.
/// This class is a Core Data managed object.
@objc(PlaylistCache)
public class PlaylistCache: NSManagedObject {

}

extension PlaylistCache {

    /// Creates a fetch request for the `PlaylistCache` entity.
    /// - Returns: A `NSFetchRequest<PlaylistCache>` to fetch `PlaylistCache` objects.
    @nonobjc public class func fetchRequest() -> NSFetchRequest<PlaylistCache> {
        return NSFetchRequest<PlaylistCache>(entityName: "PlaylistCache")
    }

    /// The local file path where the playlist content is cached.
    @NSManaged public var filePath: String?
    /// The date when the playlist was last refreshed.
    @NSManaged public var lastRefreshed: Date?
    /// The URL of the playlist.
    @NSManaged public var url: String?
    /// The URL of the EPG (Electronic Program Guide) source for this playlist.
    @NSManaged public var epgURL: String?

}
