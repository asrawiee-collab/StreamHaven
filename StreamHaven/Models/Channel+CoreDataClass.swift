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
    /// The TVG ID used for linking to EPG data (from tvg-id attribute in M3U).
    @NSManaged public var tvgID: String?
    /// The unique identifier of the source this channel came from.
    @NSManaged public var sourceID: UUID?
    /// A set of `ChannelVariant` objects representing different streams or versions of the channel.
    @NSManaged public var variants: NSSet?
    /// The `Favorite` object if the channel is marked as a favorite.
    @NSManaged public var favorite: Favorite?
    /// A set of `EPGEntry` objects representing the electronic program guide for this channel.
    @NSManaged public var epgEntries: NSSet?

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

// MARK: Generated accessors for epgEntries
extension Channel {

    /// Adds a single `EPGEntry` to the `epgEntries` set.
    /// - Parameter value: The `EPGEntry` to add.
    @objc(addEpgEntriesObject:)
    @NSManaged public func addToEpgEntries(_ value: EPGEntry)

    /// Removes a single `EPGEntry` from the `epgEntries` set.
    /// - Parameter value: The `EPGEntry` to remove.
    @objc(removeEpgEntriesObject:)
    @NSManaged public func removeFromEpgEntries(_ value: EPGEntry)

    /// Adds multiple `EPGEntry` objects to the `epgEntries` set.
    /// - Parameter values: An `NSSet` of `EPGEntry` objects to add.
    @objc(addEpgEntries:)
    @NSManaged public func addToEpgEntries(_ values: NSSet)

    /// Removes multiple `EPGEntry` objects from the `epgEntries` set.
    /// - Parameter values: An `NSSet` of `EPGEntry` objects to remove.
    @objc(removeEpgEntries:)
    @NSManaged public func removeFromEpgEntries(_ values: NSSet)

}
