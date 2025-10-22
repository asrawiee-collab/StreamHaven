import Foundation
import CoreData

@objc(Episode)
public class Episode: NSManagedObject {

}

extension Episode {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<Episode> {
        return NSFetchRequest<Episode>(entityName: "Episode")
    }

    @NSManaged public var episodeNumber: Int16
    @NSManaged public var summary: String?
    @NSManaged public var title: String?
    @NSManaged public var streamURL: String?
    @NSManaged public var season: Season?
    @NSManaged public var watchHistory: WatchHistory?

}
