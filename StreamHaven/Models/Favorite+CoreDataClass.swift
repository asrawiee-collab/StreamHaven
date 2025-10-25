import Foundation
import CoreData

/// Represents a favorite item (movie, series, or channel) for a user profile.
/// This class is a Core Data managed object.
@objc(Favorite)
public class Favorite: NSManagedObject {

}

extension Favorite {

    /// Creates a fetch request for the `Favorite` entity.
    /// - Returns: A `NSFetchRequest<Favorite>` to fetch `Favorite` objects.
    @nonobjc public class func fetchRequest() -> NSFetchRequest<Favorite> {
        return NSFetchRequest<Favorite>(entityName: "Favorite")
    }

    /// The date when the item was marked as a favorite.
    @NSManaged public var favoritedDate: Date?
    /// CloudKit record name for sync tracking.
    @NSManaged public var cloudKitRecordName: String?
    /// Last modification timestamp for conflict resolution.
    @NSManaged public var modifiedAt: Date?
    /// The `Profile` to which this favorite belongs.
    @NSManaged public var profile: Profile?
    /// The `Movie` object if the favorite is a movie.
    @NSManaged public var movie: Movie?
    /// The `Series` object if the favorite is a series.
    @NSManaged public var series: Series?
    /// The `Channel` object if the favorite is a channel.
    @NSManaged public var channel: Channel?

}
