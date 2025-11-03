import CoreData
import Foundation

/// Represents a television series in the application.
/// This class is a Core Data managed object.
@objc(Series)
public class Series: NSManagedObject {
    public override func awakeFromInsert() {
        super.awakeFromInsert()
        if self.stableID == nil {
            self.stableID = UUID().uuidString
        }
    }

    public override func willSave() {
        super.willSave()
        syncReleaseYearWithReleaseDate()
    }

    private func syncReleaseYearWithReleaseDate() {
        guard let releaseDate else { return }
        let year = Calendar.current.component(.year, from: releaseDate)
        if releaseYear != year {
            releaseYear = year
        }
    }
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
    /// Comma-separated genre list for the series.
    @NSManaged public var genres: String?
    /// The title of the series.
    @NSManaged public var title: String?
    /// The URL of a preview or trailer clip for hover playback.
    @NSManaged public var previewURL: String?
    /// A stable UUID string for cross-table references and FTS mapping.
    @NSManaged public var stableID: String?
    /// The unique identifier of the source this series came from.
    @NSManaged public var sourceID: UUID?
    /// A set of `Season` objects belonging to this series.
    @NSManaged public var seasons: NSSet?
    /// The `Favorite` object if the series is marked as a favorite.
    @NSManaged public var favorite: Favorite?
    /// The set of credits (cast/crew) for this series.
    @NSManaged public var credits: NSSet?
    /// Stored release year backing value (NSNumber to allow nil).
    @NSManaged private var releaseYearValue: NSNumber?

    /// The release year extracted or provided independently of first air date.
    public var releaseYear: Int? {
        get { releaseYearValue?.intValue }
        set { releaseYearValue = newValue.map { NSNumber(value: $0) } }
    }

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
