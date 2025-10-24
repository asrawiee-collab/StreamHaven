import Foundation
import CoreData

@objc(Series)
public class Series: NSManagedObject {

}

extension Series {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<Series> {
        return NSFetchRequest<Series>(entityName: "Series")
    }

    @NSManaged public var posterURL: String?
    @NSManaged public var rating: String?
    @NSManaged public var releaseDate: Date?
    @NSManaged public var summary: String?
    @NSManaged public var title: String?
    @NSManaged public var seasons: NSSet?
    @NSManaged public var favorite: Favorite?

}

// MARK: Generated accessors for seasons
extension Series {

    @objc(addSeasonsObject:)
    @NSManaged public func addToSeasons(_ value: Season)

    @objc(removeSeasonsObject:)
    @NSManaged public func removeFromSeasons(_ value: Season)

    @objc(addSeasons:)
    @NSManaged public func addToSeasons(_ values: NSSet)

    @objc(removeSeasons:)
    @NSManaged public func removeFromSeasons(_ values: NSSet)

}
