import CoreData
import Foundation

/// Represents a season of a television series.
/// This class is a Core Data managed object.
@objc(Season)
public class Season: NSManagedObject {

}

extension Season {

    /// Creates a fetch request for the `Season` entity.
    /// - Returns: A `NSFetchRequest<Season>` to fetch `Season` objects.
    @nonobjc public class func fetchRequest() -> NSFetchRequest<Season> {
        return NSFetchRequest<Season>(entityName: "Season")
    }

    /// The number of the season.
    @NSManaged public var seasonNumber: Int16
    /// A short summary or description of the season.
    @NSManaged public var summary: String?
    /// A set of `Episode` objects belonging to this season.
    @NSManaged public var episodes: NSSet?
    /// The parent `Series` object to which this season belongs.
    @NSManaged public var series: Series?

}

// MARK: Generated accessors for episodes
extension Season {

    /// Adds a single `Episode` object to the `episodes` set.
    /// - Parameter value: The `Episode` to add.
    @objc(addEpisodesObject:)
    @NSManaged public func addToEpisodes(_ value: Episode)

    /// Removes a single `Episode` object from the `episodes` set.
    /// - Parameter value: The `Episode` to remove.
    @objc(removeEpisodesObject:)
    @NSManaged public func removeFromEpisodes(_ value: Episode)

    /// Adds multiple `Episode` objects to the `episodes` set.
    /// - Parameter values: An `NSSet` of `Episode` objects to add.
    @objc(addEpisodes:)
    @NSManaged public func addToEpisodes(_ values: NSSet)

    /// Removes multiple `Episode` objects from the `episodes` set.
    /// - Parameter values: An `NSSet` of `Episode` objects to remove.
    @objc(removeEpisodes:)
    @NSManaged public func removeFromEpisodes(_ values: NSSet)

}
