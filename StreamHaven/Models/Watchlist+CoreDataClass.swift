//
//  Watchlist+CoreDataClass.swift
//  StreamHaven
//
//  Created on October 25, 2025.
//

import Foundation
import CoreData

@objc(Watchlist)
public class Watchlist: NSManagedObject {
    
    // MARK: - Computed Properties
    
    /// Number of items in this watchlist
    var itemCount: Int {
        return items?.count ?? 0
    }
    
    /// Sorted items by position
    var sortedItems: [WatchlistItem] {
        guard let items = items as? Set<WatchlistItem> else { return [] }
        return items.sorted { $0.position < $1.position }
    }
    
    // MARK: - Factory Methods
    
    /// Create a new watchlist
    static func create(
        name: String,
        icon: String = "list.bullet",
        profile: Profile,
        context: NSManagedObjectContext
    ) -> Watchlist {
        let watchlist = Watchlist(context: context)
        watchlist.name = name
        watchlist.icon = icon
        watchlist.createdAt = Date()
        watchlist.updatedAt = Date()
        watchlist.profile = profile
        return watchlist
    }
    
    // MARK: - Helper Methods
    
    /// Add an item to this watchlist
    func addItem(_ item: WatchlistItem) {
        item.watchlist = self
        updatedAt = Date()
    }
    
    /// Remove an item from this watchlist
    func removeItem(_ item: WatchlistItem) {
        if let context = managedObjectContext {
            context.delete(item)
            updatedAt = Date()
        }
    }
    
    /// Check if content is already in this watchlist
    func contains(contentID: String) -> Bool {
        guard let items = items as? Set<WatchlistItem> else { return false }
        return items.contains { $0.contentID == contentID }
    }
    
    /// Get all movies in this watchlist
    func getMovies(context: NSManagedObjectContext) -> [Movie] {
        return sortedItems
            .filter { $0.contentType == WatchlistItem.ContentType.movie.rawValue }
            .compactMap { $0.fetchContent(context: context) as? Movie }
    }
    
    /// Get all series in this watchlist
    func getSeries(context: NSManagedObjectContext) -> [Series] {
        return sortedItems
            .filter { $0.contentType == WatchlistItem.ContentType.series.rawValue }
            .compactMap { $0.fetchContent(context: context) as? Series }
    }
    
    /// Get all episodes in this watchlist
    func getEpisodes(context: NSManagedObjectContext) -> [Episode] {
        return sortedItems
            .filter { $0.contentType == WatchlistItem.ContentType.episode.rawValue }
            .compactMap { $0.fetchContent(context: context) as? Episode }
    }
}

// MARK: - Core Data Properties

extension Watchlist {
    
    @NSManaged public var name: String
    @NSManaged public var createdAt: Date
    @NSManaged public var updatedAt: Date
    @NSManaged public var icon: String
    @NSManaged public var profile: Profile
    @NSManaged public var items: NSSet?
    
}

// MARK: - Generated accessors for items

extension Watchlist {
    
    @objc(addItemsObject:)
    @NSManaged public func addToItems(_ value: WatchlistItem)
    
    @objc(removeItemsObject:)
    @NSManaged public func removeFromItems(_ value: WatchlistItem)
    
    @objc(addItems:)
    @NSManaged public func addToItems(_ values: NSSet)
    
    @objc(removeItems:)
    @NSManaged public func removeFromItems(_ values: NSSet)
    
}
