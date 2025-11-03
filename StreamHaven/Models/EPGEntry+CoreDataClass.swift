import CoreData
import Foundation

/// Represents an EPG (Electronic Program Guide) entry in the application.
/// This class is a Core Data managed object.
@objc(EPGEntry)
public class EPGEntry: NSManagedObject {

}

extension EPGEntry {

    /// Creates a fetch request for the `EPGEntry` entity.
    /// - Returns: A `NSFetchRequest<EPGEntry>` to fetch `EPGEntry` objects.
    @nonobjc public class func fetchRequest() -> NSFetchRequest<EPGEntry> {
        return NSFetchRequest<EPGEntry>(entityName: "EPGEntry")
    }

    /// The category or genre of the program (e.g., "Sports", "News", "Drama").
    @NSManaged public var category: String?
    /// A detailed description of the program.
    @NSManaged public var descriptionText: String?
    /// The end time of the program.
    @NSManaged public var endTime: Date?
    /// The start time of the program.
    @NSManaged public var startTime: Date?
    /// The title of the program.
    @NSManaged public var title: String?
    /// The channel this EPG entry belongs to.
    @NSManaged public var channel: Channel?

}

extension EPGEntry: Identifiable {

}
