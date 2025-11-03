import CoreData
import Foundation

/// Represents a specific stream or version of a television channel.
/// This class is a Core Data managed object.
@objc(ChannelVariant)
public class ChannelVariant: NSManagedObject {

}

extension ChannelVariant {

    /// Creates a fetch request for the `ChannelVariant` entity.
    /// - Returns: A `NSFetchRequest<ChannelVariant>` to fetch `ChannelVariant` objects.
    @nonobjc public class func fetchRequest() -> NSFetchRequest<ChannelVariant> {
        return NSFetchRequest<ChannelVariant>(entityName: "ChannelVariant")
    }

    /// The name of the channel variant (e.g., "HD", "SD").
    @NSManaged public var name: String?
    /// The URL of the video stream for this variant.
    @NSManaged public var streamURL: String?
    /// The unique identifier of the source this variant came from.
    @NSManaged public var sourceID: UUID?
    /// The parent `Channel` object to which this variant belongs.
    @NSManaged public var channel: Channel?

}
