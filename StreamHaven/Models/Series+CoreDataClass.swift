import Foundation
import CoreData

/// Represents a television series in the application.
/// This class is a Core Data managed object.
@objc(Series)
public class Series: NSManagedObject {

}

extension Series {

    /// Creates a fetch request for the `Series` entity.
    /// - Returns: A `NSFetchRequest<Series>` to fetch `Series` objects.
    @nonobjc public class func fetchRequest() -> NSFetchRequest<Series> {
        return NSFetchRequest<Series>(entityName: "Series")
    }

    /// The URL of the series' poster image.
    @NSManaged public var posterURL: String?
    /// The content rating of the series (e.g., "PG-13", "R").
    @NSManaged public var rating: String?
    /// The release date of the series.
    @NSManaged public var releaseDate: Date?
    /// A short summary or description of the series.
    @NSManaged public var summary: String?
    /// The title of the series.
    @NSManaged public var title: String?
    /// A set of `Season` objects belonging to this series.
    @NSManaged public var seasons: NSSet?
    /// The `Favorite` object if the series is marked as a favorite.
    @NSManaged public var favorite: Favorite?

}

// MARK: Generated accessors for seasons
extension Series {

    /// Adds a single `Season` object to the `seasons` set.
    /// - Parameter value: The `Season` to add.
    @objc(addSeasonsObject:)
    @NSManaged public func addToSeasons(_ value: Season)

    /// Removes a single `Season` object from the `seasons` set.
    /// - Parameter value: The `Season` to remove.
    @objc(removeSeasonsObject:)
    @NSManaged public func removeFromSeasons(_ value: Season)

    /// Adds multiple `Season` objects to the `seasons` set.
    /// - Parameter values: An `NSSet` of `Season` objects to add.
    @objc(addSeasons:)
    @NSManaged public func addToSeasons(_ values: NSSet)

    /// Removes multiple `Season` objects from the `seasons` set.
    /// - Parameter values: An `NSSet` of `Season` objects to remove.
    @objc(removeSeasons:)
    @NSManaged public func removeFromSeasons(_ values: NSSet)

}
