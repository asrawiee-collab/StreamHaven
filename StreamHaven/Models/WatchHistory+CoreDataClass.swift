import CoreData
import Foundation

/// Represents the watch history for a movie or episode.
/// This class is a Core Data managed object.
@objc(WatchHistory)
public class WatchHistory: NSManagedObject {

}

extension WatchHistory {

    /// Creates a fetch request for the `WatchHistory` entity.
    /// - Returns: A `NSFetchRequest<WatchHistory>` to fetch `WatchHistory` objects.
    @nonobjc public class func fetchRequest() -> NSFetchRequest<WatchHistory> {
        return NSFetchRequest<WatchHistory>(entityName: "WatchHistory")
    }

    /// The watch progress as a percentage (0.0 to 1.0).
    @NSManaged public var progress: Float
    /// The date when the item was last watched.
    @NSManaged public var watchedDate: Date?
    /// CloudKit record name for sync tracking.
    @NSManaged public var cloudKitRecordName: String?
    /// Last modification timestamp for conflict resolution.
    @NSManaged public var modifiedAt: Date?
    /// The `Profile` to which this watch history belongs.
    @NSManaged public var profile: Profile?
    /// The `Movie` object if the watch history is for a movie.
    @NSManaged public var movie: Movie?
    /// The `Episode` object if the watch history is for an episode.
    @NSManaged public var episode: Episode?

}
