import Foundation
import CoreData

@objc(Season)
public class Season: NSManagedObject {

}

extension Season {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<Season> {
        return NSFetchRequest<Season>(entityName: "Season")
    }

    @NSManaged public var seasonNumber: Int16
    @NSManaged public var summary: String?
    @NSManaged public var episodes: NSSet?
    @NSManaged public var series: Series?

}

// MARK: Generated accessors for episodes
extension Season {

    @objc(addEpisodesObject:)
    @NSManaged public func addToEpisodes(_ value: Episode)

    @objc(removeEpisodesObject:)
    @NSManaged public func removeFromEpisodes(_ value: Episode)

    @objc(addEpisodes:)
    @NSManaged public func addToEpisodes(_ values: NSSet)

    @objc(removeEpisodes:)
    @NSManaged public func removeFromEpisodes(_ values: NSSet)

}
