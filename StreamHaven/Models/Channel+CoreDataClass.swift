import Foundation
import CoreData

@objc(Channel)
public class Channel: NSManagedObject {

}

extension Channel {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<Channel> {
        return NSFetchRequest<Channel>(entityName: "Channel")
    }

    @NSManaged public var logoURL: String?
    @NSManaged public var name: String?
    @NSManaged public var variants: NSSet?
    @NSManaged public var favorite: Favorite?

}

// MARK: Generated accessors for variants
extension Channel {

    @objc(addVariantsObject:)
    @NSManaged public func addToVariants(_ value: ChannelVariant)

    @objc(removeVariantsObject:)
    @NSManaged public func removeFromVariants(_ value: ChannelVariant)

    @objc(addVariants:)
    @NSManaged public func addToVariants(_ values: NSSet)

    @objc(removeVariants:)
    @NSManaged public func removeFromVariants(_ values: NSSet)

}
