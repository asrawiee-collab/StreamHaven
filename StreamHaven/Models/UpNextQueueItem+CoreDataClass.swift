import Foundation
import CoreData

@objc(UpNextQueueItem)
public class UpNextQueueItem: NSManagedObject {
    
    @NSManaged public var contentID: String
    @NSManaged public var contentType: String
    @NSManaged public var addedAt: Date
    @NSManaged public var position: Int32
    @NSManaged public var autoAdded: Bool
    @NSManaged public var profile: Profile?
    
    /// Returns a fetch request for UpNextQueueItem entities.
    @nonobjc public class func fetchRequest() -> NSFetchRequest<UpNextQueueItem> {
        return NSFetchRequest<UpNextQueueItem>(entityName: "UpNextQueueItem")
    }
    
    /// Content type enum for type-safe content identification.
    public enum ContentType: String {
        case movie = "movie"
        case episode = "episode"
        case series = "series"
    }
    
    /// Typed content type getter/setter.
    public var queueContentType: ContentType {
        get {
            return ContentType(rawValue: contentType) ?? .movie
        }
        set {
            contentType = newValue.rawValue
        }
    }
    
    /// Fetches the actual content object (Movie, Episode, or Series) from Core Data.
    /// - Parameter context: The managed object context to fetch from.
    /// - Returns: The content object if found, nil otherwise.
    public func fetchContent(context: NSManagedObjectContext) -> NSManagedObject? {
        switch queueContentType {
        case .movie:
            let fetchRequest: NSFetchRequest<Movie> = Movie.fetchRequest()
            fetchRequest.predicate = NSPredicate(format: "self == %@", contentID)
            return try? context.fetch(fetchRequest).first
            
        case .episode:
            let fetchRequest: NSFetchRequest<Episode> = Episode.fetchRequest()
            fetchRequest.predicate = NSPredicate(format: "self == %@", contentID)
            return try? context.fetch(fetchRequest).first
            
        case .series:
            let fetchRequest: NSFetchRequest<Series> = Series.fetchRequest()
            fetchRequest.predicate = NSPredicate(format: "self == %@", contentID)
            return try? context.fetch(fetchRequest).first
        }
    }
    
    /// Creates a new UpNextQueueItem for the given content.
    /// - Parameters:
    ///   - content: The content object (Movie, Episode, or Series).
    ///   - profile: The profile this queue item belongs to.
    ///   - position: The position in the queue.
    ///   - autoAdded: Whether this was automatically added by the system.
    ///   - context: The managed object context.
    /// - Returns: The created UpNextQueueItem, or nil if content type is unsupported.
    public static func create(
        for content: NSManagedObject,
        profile: Profile,
        position: Int32,
        autoAdded: Bool,
        context: NSManagedObjectContext
    ) -> UpNextQueueItem? {
        let item = UpNextQueueItem(context: context)
        item.profile = profile
        item.addedAt = Date()
        item.position = position
        item.autoAdded = autoAdded
        
        if let movie = content as? Movie {
            item.contentID = movie.objectID.uriRepresentation().absoluteString
            item.queueContentType = .movie
        } else if let episode = content as? Episode {
            item.contentID = episode.objectID.uriRepresentation().absoluteString
            item.queueContentType = .episode
        } else if let series = content as? Series {
            item.contentID = series.objectID.uriRepresentation().absoluteString
            item.queueContentType = .series
        } else {
            context.delete(item)
            return nil
        }
        
        return item
    }
}
