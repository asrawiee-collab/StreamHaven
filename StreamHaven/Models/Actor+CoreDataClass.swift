import CoreData
import Foundation

/// Represents an actor or crew member from TMDb.
/// This class is a Core Data managed object.
@objc(Actor)
public class Actor: NSManagedObject {
    public override func awakeFromInsert() {
        super.awakeFromInsert()
    }
}

extension Actor {
    
    /// Creates a fetch request for the `Actor` entity.
    /// - Returns: A `NSFetchRequest<Actor>` to fetch `Actor` objects.
    @nonobjc public class func fetchRequest() -> NSFetchRequest<Actor> {
        return NSFetchRequest<Actor>(entityName: "Actor")
    }
    
    /// The TMDb ID for this actor.
    @NSManaged public var tmdbID: Int64
    /// The actor's name.
    @NSManaged public var name: String?
    /// The URL of the actor's profile photo.
    @NSManaged public var photoURL: String?
    /// The actor's biography text.
    @NSManaged public var biography: String?
    /// The popularity score from TMDb.
    @NSManaged public var popularity: Double
    /// The set of credits (movies/series) this actor appears in.
    @NSManaged public var credits: NSSet?
}

// MARK: Generated accessors for credits
extension Actor {
    
    @objc(addCreditsObject:)
    @NSManaged public func addToCredits(_ value: Credit)
    
    @objc(removeCreditsObject:)
    @NSManaged public func removeFromCredits(_ value: Credit)
    
    @objc(addCredits:)
    @NSManaged public func addToCredits(_ values: NSSet)
    
    @objc(removeCredits:)
    @NSManaged public func removeFromCredits(_ values: NSSet)
}

extension Actor: Identifiable {
    public var id: Int64 { tmdbID }
}
