import Foundation
import CoreData

@objc(Favorite)
public class Favorite: NSManagedObject {

}

extension Favorite {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<Favorite> {
        return NSFetchRequest<Favorite>(entityName: "Favorite")
    }

    @NSManaged public var favoritedDate: Date?
    @NSManaged public var profile: Profile?
    @NSManaged public var movie: Movie?
    @NSManaged public var series: Series?
    @NSManaged public var channel: Channel?

}
