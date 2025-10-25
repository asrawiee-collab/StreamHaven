//
//  WatchlistItem+CoreDataClass.swift
//  StreamHaven
//
//  Created on October 25, 2025.
//

import Foundation
import CoreData

@objc(WatchlistItem)
public class WatchlistItem: NSManagedObject {
    
    // MARK: - Content Type Enum
    
    enum ContentType: String, CaseIterable {
        case movie
        case episode
        case series
    }
    
    // MARK: - Computed Properties
    
    /// Type-safe content type
    var itemContentType: ContentType? {
        get {
            return ContentType(rawValue: contentType)
        }
        set {
            contentType = newValue?.rawValue ?? ContentType.movie.rawValue
        }
    }
    
    // MARK: - Factory Methods
    
    /// Create a new watchlist item
    static func create(
        for content: NSManagedObject,
        watchlist: Watchlist,
        position: Int32,
        context: NSManagedObjectContext
    ) -> WatchlistItem? {
        let item = WatchlistItem(context: context)
        
        // Store content ID and type
        item.contentID = content.objectID.uriRepresentation().absoluteString
        
        if content is Movie {
            item.contentType = ContentType.movie.rawValue
        } else if content is Episode {
            item.contentType = ContentType.episode.rawValue
        } else if content is Series {
            item.contentType = ContentType.series.rawValue
        } else {
            context.delete(item)
            return nil
        }
        
        item.addedAt = Date()
        item.position = position
        item.watchlist = watchlist
        
        return item
    }
    
    // MARK: - Helper Methods
    
    /// Fetch the actual content object (Movie, Episode, or Series)
    func fetchContent(context: NSManagedObjectContext) -> NSManagedObject? {
        guard let url = URL(string: contentID),
              let objectID = context.persistentStoreCoordinator?.managedObjectID(forURIRepresentation: url) else {
            return nil
        }
        
        do {
            return try context.existingObject(with: objectID)
        } catch {
            print("Failed to fetch content for watchlist item: \(error)")
            return nil
        }
    }
    
    /// Get display title for this item
    func getTitle(context: NSManagedObjectContext) -> String {
        guard let content = fetchContent(context: context) else {
            return "Unknown"
        }
        
        if let movie = content as? Movie {
            return movie.title
        } else if let episode = content as? Episode {
            return episode.title
        } else if let series = content as? Series {
            return series.title
        }
        
        return "Unknown"
    }
    
    /// Get poster/thumbnail URL for this item
    func getPosterURL(context: NSManagedObjectContext) -> String? {
        guard let content = fetchContent(context: context) else {
            return nil
        }
        
        if let movie = content as? Movie {
            return movie.posterURL
        } else if let series = content as? Series {
            return series.posterURL
        }
        
        return nil
    }
}

// MARK: - Core Data Properties

extension WatchlistItem {
    
    @NSManaged public var contentID: String
    @NSManaged public var contentType: String
    @NSManaged public var addedAt: Date
    @NSManaged public var position: Int32
    @NSManaged public var watchlist: Watchlist
    
}
