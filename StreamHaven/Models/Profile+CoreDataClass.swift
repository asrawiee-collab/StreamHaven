import Foundation
import CoreData

/// Represents a user profile in the application.
/// This class is a Core Data managed object.
@objc(Profile)
public class Profile: NSManagedObject {

}

extension Profile {

    /// Creates a fetch request for the `Profile` entity.
    /// - Returns: A `NSFetchRequest<Profile>` to fetch `Profile` objects.
    @nonobjc public class func fetchRequest() -> NSFetchRequest<Profile> {
        return NSFetchRequest<Profile>(entityName: "Profile")
    }

    /// A boolean indicating whether the profile is for an adult.
    @NSManaged public var isAdult: Bool
    /// The name of the profile.
    @NSManaged public var name: String?
    /// A set of `Favorite` objects associated with the profile.
    @NSManaged public var favorites: NSSet?
    /// A set of `WatchHistory` objects associated with the profile.
    @NSManaged public var watchHistory: NSSet?

}

// MARK: Generated accessors for favorites
extension Profile {

    /// Adds a single `Favorite` object to the `favorites` set.
    /// - Parameter value: The `Favorite` to add.
    @objc(addFavoritesObject:)
    @NSManaged public func addToFavorites(_ value: Favorite)

    /// Removes a single `Favorite` object from the `favorites` set.
    /// - Parameter value: The `Favorite` to remove.
    @objc(removeFavoritesObject:)
    @NSManaged public func removeFromFavorites(_ value: Favorite)

    /// Adds multiple `Favorite` objects to the `favorites` set.
    /// - Parameter values: An `NSSet` of `Favorite` objects to add.
    @objc(addFavorites:)
    @NSManaged public func addToFavorites(_ values: NSSet)

    /// Removes multiple `Favorite` objects from the `favorites` set.
    /// - Parameter values: An `NSSet` of `Favorite` objects to remove.
    @objc(removeFavorites:)
    @NSManaged public func removeFromFavorites(_ values: NSSet)

}

// MARK: Generated accessors for watchHistory
extension Profile {

    /// Adds a single `WatchHistory` object to the `watchHistory` set.
    /// - Parameter value: The `WatchHistory` to add.
    @objc(addWatchHistoryObject:)
    @NSManaged public func addToWatchHistory(_ value: WatchHistory)

    /// Removes a single `WatchHistory` object from the `watchHistory` set.
    /// - Parameter value: The `WatchHistory` to remove.
    @objc(removeWatchHistoryObject:)
    @NSManaged public func removeFromWatchHistory(_ value: WatchHistory)

    /// Adds multiple `WatchHistory` objects to the `watchHistory` set.
    /// - Parameter values: An `NSSet` of `WatchHistory` objects to add.
    @objc(addWatchHistory:)
    @NSManaged public func addToWatchHistory(_ values: NSSet)

    /// Removes multiple `WatchHistory` objects from the `watchHistory` set.
    /// - Parameter values: An `NSSet` of `WatchHistory` objects to remove.
    @objc(removeWatchHistory:)
    @NSManaged public func removeFromWatchHistory(_ values: NSSet)

}
