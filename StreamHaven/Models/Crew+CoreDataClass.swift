
import Foundation
import CoreData

/// Represents a crew member from TMDb.
/// This class is a Core Data managed object.
@objc(Crew)
public class Crew: NSManagedObject {
    public override func awakeFromInsert() {
        super.awakeFromInsert()
    }
}

extension Crew {
    
    /// Creates a fetch request for the `Crew` entity.
    /// - Returns: A `NSFetchRequest<Crew>` to fetch `Crew` objects.
    @nonobjc public class func fetchRequest() -> NSFetchRequest<Crew> {
        return NSFetchRequest<Crew>(entityName: "Crew")
    }
    
    /// The TMDb ID for this crew member.
    @NSManaged public var tmdbID: Int64
    /// The crew member's name.
    @NSManaged public var name: String?
    /// The job of the crew member (e.g., "Director", "Writer").
    @NSManaged public var job: String?
    /// The URL of the crew member's profile photo.
    @NSManaged public var profilePath: String?
    
    /// The movie this crew member worked on.
    @NSManaged public var movie: Movie?
    /// The series this crew member worked on.
    @NSManaged public var series: Series?
}

extension Crew: Identifiable {
    public var id: Int64 { tmdbID }
}
