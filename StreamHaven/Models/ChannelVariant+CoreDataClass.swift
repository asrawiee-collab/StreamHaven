import Foundation
import CoreData

@objc(ChannelVariant)
public class ChannelVariant: NSManagedObject {

}

extension ChannelVariant {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<ChannelVariant> {
        return NSFetchRequest<ChannelVariant>(entityName: "ChannelVariant")
    }

    @NSManaged public var name: String?
    @NSManaged public var streamURL: String?
    @NSManaged public var channel: Channel?

}
