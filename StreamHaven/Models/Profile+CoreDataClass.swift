import Foundation
import CoreData

@objc(Profile)
public class Profile: NSManagedObject {

}

extension Profile {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<Profile> {
        return NSFetchRequest<Profile>(entityName: "Profile")
    }

    @NSManaged public var isAdult: Bool
    @NSManaged public var name: String?
    @NSManaged public var favorites: NSSet?
    @NSManaged public var watchHistory: NSSet?

}

// MARK: Generated accessors for favorites
extension Profile {

    @objc(addFavoritesObject:)
    @NSManaged public func addToFavorites(_ value: Favorite)

    @objc(removeFavoritesObject:)
    @NSManaged public func removeFromFavorites(_ value: Favorite)

    @objc(addFavorites:)
    @NSManaged public func addToFavorites(_ values: NSSet)

    @objc(removeFavorites:)
    @NSManaged public func removeFromFavorites(_ values: NSSet)

}

// MARK: Generated accessors for watchHistory
extension Profile {

    @objc(addWatchHistoryObject:)
    @NSManaged public func addToWatchHistory(_ value: WatchHistory)

    @objc(removeWatchHistoryObject:)
    @NSManaged public func removeFromWatchHistory(_ value: WatchHistory)

    @objc(addWatchHistory:)
    @NSManaged public func addToWatchHistory(_ values: NSSet)

    @objc(removeWatchHistory:)
    @NSManaged public func removeFromWatchHistory(_ values: NSSet)

}
