import Foundation
import CoreData

/// Represents a television channel in the application.
/// This class is a Core Data managed object.
@objc(Channel)
public class Channel: NSManagedObject {

}

extension Channel {

    /// Creates a fetch request for the `Channel` entity.
    /// - Returns: A `NSFetchRequest<Channel>` to fetch `Channel` objects.
    @nonobjc public class func fetchRequest() -> NSFetchRequest<Channel> {
        return NSFetchRequest<Channel>(entityName: "Channel")
    }

    /// The URL of the channel's logo.
    @NSManaged public var logoURL: String?
    /// The name of the channel.
    @NSManaged public var name: String?
    /// A set of `ChannelVariant` objects representing different streams or versions of the channel.
    @NSManaged public var variants: NSSet?
    /// The `Favorite` object if the channel is marked as a favorite.
    @NSManaged public var favorite: Favorite?

}

// MARK: Generated accessors for variants
extension Channel {

    /// Adds a single `ChannelVariant` to the `variants` set.
    /// - Parameter value: The `ChannelVariant` to add.
    @objc(addVariantsObject:)
    @NSManaged public func addToVariants(_ value: ChannelVariant)

    /// Removes a single `ChannelVariant` from the `variants` set.
    /// - Parameter value: The `ChannelVariant` to remove.
    @objc(removeVariantsObject:)
    @NSManaged public func removeFromVariants(_ value: ChannelVariant)

    /// Adds multiple `ChannelVariant` objects to the `variants` set.
    /// - Parameter values: An `NSSet` of `ChannelVariant` objects to add.
    @objc(addVariants:)
    @NSManaged public func addToVariants(_ values: NSSet)

    /// Removes multiple `ChannelVariant` objects from the `variants` set.
    /// - Parameter values: An `NSSet` of `ChannelVariant` objects to remove.
    @objc(removeVariants:)
    @NSManaged public func removeFromVariants(_ values: NSSet)

}
