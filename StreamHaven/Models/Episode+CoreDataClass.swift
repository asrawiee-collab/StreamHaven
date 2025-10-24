import Foundation
import CoreData

/// Represents a single episode of a television series.
/// This class is a Core Data managed object.
@objc(Episode)
public class Episode: NSManagedObject {

}

extension Episode {

    /// Creates a fetch request for the `Episode` entity.
    /// - Returns: A `NSFetchRequest<Episode>` to fetch `Episode` objects.
    @nonobjc public class func fetchRequest() -> NSFetchRequest<Episode> {
        return NSFetchRequest<Episode>(entityName: "Episode")
    }

    /// The number of the episode within a season.
    @NSManaged public var episodeNumber: Int16
    /// A short summary or description of the episode.
    @NSManaged public var summary: String?
    /// The title of the episode.
    @NSManaged public var title: String?
    /// The URL of the video stream for this episode.
    @NSManaged public var streamURL: String?
    /// The parent `Season` object to which this episode belongs.
    @NSManaged public var season: Season?
    /// The `WatchHistory` object if the episode has been watched.
    @NSManaged public var watchHistory: WatchHistory?

}
