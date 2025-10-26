import Foundation
import CoreData

extension StreamCache {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<StreamCache> {
        return NSFetchRequest<StreamCache>(entityName: "StreamCache")
    }

    @NSManaged public var streamURL: String
    @NSManaged public var cachedAt: Date
    @NSManaged public var lastAccessed: Date
    @NSManaged public var expiresAt: Date
    @NSManaged public var cacheIdentifier: String

}

extension StreamCache : Identifiable {

}
