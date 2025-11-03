import CoreData
import Foundation

/// Represents a credit linking an actor to a movie or series.
/// This is a junction table for the many-to-many relationship.
@objc(Credit)
public class Credit: NSManagedObject {
    public override func awakeFromInsert() {
        super.awakeFromInsert()
    }
}

extension Credit {
    
    /// Creates a fetch request for the `Credit` entity.
    /// - Returns: A `NSFetchRequest<Credit>` to fetch `Credit` objects.
    @nonobjc public class func fetchRequest() -> NSFetchRequest<Credit> {
        return NSFetchRequest<Credit>(entityName: "Credit")
    }
    
    /// The character name the actor played.
    @NSManaged public var character: String?
    /// The order of appearance (0 = main star).
    @NSManaged public var order: Int16
    /// The type of credit: "cast" or "crew".
    @NSManaged public var creditType: String?
    /// For crew: the job title (e.g., "Director", "Writer").
    @NSManaged public var job: String?
    
    // MARK: - Relationships
    
    /// The actor for this credit.
    @NSManaged public var actor: Actor?
    /// The movie this credit is for (if applicable).
    @NSManaged public var movie: Movie?
    /// The series this credit is for (if applicable).
    @NSManaged public var series: Series?
}

extension Credit: Identifiable {
    public var id: NSManagedObjectID { objectID }
}
