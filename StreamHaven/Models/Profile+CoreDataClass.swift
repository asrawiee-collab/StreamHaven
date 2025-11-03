import CoreData
import Foundation

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
    /// CloudKit record name for sync tracking.
    @NSManaged public var cloudKitRecordName: String?
    /// Last modification timestamp for conflict resolution.
    @NSManaged public var modifiedAt: Date?
    /// Source viewing mode: "combined" (merge all sources) or "single" (view one source at a time).
    @NSManaged public var sourceMode: String?
    /// A set of `Favorite` objects associated with the profile.
    @NSManaged public var favorites: NSSet?
    /// A set of `WatchHistory` objects associated with the profile.
    @NSManaged public var watchHistory: NSSet?
    /// A set of `PlaylistSource` objects associated with the profile.
    @NSManaged public var playlistSources: NSSet?

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

// MARK: Generated accessors for playlistSources
extension Profile {

    /// Adds a single `PlaylistSource` object to the `playlistSources` set.
    /// - Parameter value: The `PlaylistSource` to add.
    @objc(addPlaylistSourcesObject:)
    @NSManaged public func addToPlaylistSources(_ value: PlaylistSource)

    /// Removes a single `PlaylistSource` object from the `playlistSources` set.
    /// - Parameter value: The `PlaylistSource` to remove.
    @objc(removePlaylistSourcesObject:)
    @NSManaged public func removeFromPlaylistSources(_ value: PlaylistSource)

    /// Adds multiple `PlaylistSource` objects to the `playlistSources` set.
    /// - Parameter values: An `NSSet` of `PlaylistSource` objects to add.
    @objc(addPlaylistSources:)
    @NSManaged public func addToPlaylistSources(_ values: NSSet)

    /// Removes multiple `PlaylistSource` objects from the `playlistSources` set.
    /// - Parameter values: An `NSSet` of `PlaylistSource` objects to remove.
    @objc(removePlaylistSources:)
    @NSManaged public func removeFromPlaylistSources(_ values: NSSet)

}

// MARK: - Convenience Methods
extension Profile {
    
    /// Source viewing mode constants.
    enum SourceMode: String {
        case combined
        case single
    }
    
    /// Returns the source mode as an enum.
    var mode: SourceMode {
        guard let sourceMode = sourceMode else { return .combined }
        return SourceMode(rawValue: sourceMode) ?? .combined
    }
    
    /// Returns all active playlist sources for this profile, sorted by display order.
    var activeSources: [PlaylistSource] {
        guard let sources = playlistSources as? Set<PlaylistSource> else { return [] }
        return sources
            .filter { $0.isActive }
            .sorted { $0.displayOrder < $1.displayOrder }
    }
    
    /// Returns all playlist sources for this profile, sorted by display order.
    var allSources: [PlaylistSource] {
        guard let sources = playlistSources as? Set<PlaylistSource> else { return [] }
        return sources.sorted { $0.displayOrder < $1.displayOrder }
    }

}
