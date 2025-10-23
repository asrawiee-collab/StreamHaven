import Foundation
import CoreData

@objc(WatchHistory)
public class WatchHistory: NSManagedObject {

}

extension WatchHistory {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<WatchHistory> {
        return NSFetchRequest<WatchHistory>(entityName: "WatchHistory")
    }

    @NSManaged public var progress: Float
    @NSManaged public var watchedDate: Date?
    @NSManaged public var profile: Profile?
    @NSManaged public var movie: Movie?
    @NSManaged public var episode: Episode?

}
