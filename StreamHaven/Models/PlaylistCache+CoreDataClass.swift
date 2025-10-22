import Foundation
import CoreData

@objc(PlaylistCache)
public class PlaylistCache: NSManagedObject {

}

extension PlaylistCache {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<PlaylistCache> {
        return NSFetchRequest<PlaylistCache>(entityName: "PlaylistCache")
    }

    @NSManaged public var data: Data?
    @NSManaged public var lastRefreshed: Date?
    @NSManaged public var url: String?

}
