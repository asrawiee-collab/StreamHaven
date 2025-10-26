//
//  WatchlistManager.swift
//  StreamHaven
//
//  Created on October 25, 2025.
//

import Foundation
import CoreData
import Combine

@MainActor
class WatchlistManager: ObservableObject {
    
    // MARK: - Published Properties
    
    @Published var watchlists: [Watchlist] = []
    @Published var selectedWatchlist: Watchlist?
    
    // MARK: - Properties
    
    private let context: NSManagedObjectContext
    private let maxWatchlists: Int = 20 // Per profile
    
    // MARK: - Errors
    
    enum WatchlistError: LocalizedError {
        case watchlistLimitReached
        case watchlistNotFound
        case itemAlreadyExists
        case itemNotFound
        case invalidContent
        case profileNotFound
        
        var errorDescription: String? {
            switch self {
            case .watchlistLimitReached:
                return "You've reached the maximum number of watchlists (20)."
            case .watchlistNotFound:
                return "Watchlist not found."
            case .itemAlreadyExists:
                return "This item is already in the watchlist."
            case .itemNotFound:
                return "Item not found in watchlist."
            case .invalidContent:
                return "Invalid content type. Only movies, series, and episodes are supported."
            case .profileNotFound:
                return "Profile not found."
            }
        }
    }
    
    // MARK: - Initialization
    
    init(context: NSManagedObjectContext) {
        self.context = context
    }
    
    // MARK: - Watchlist Management
    
    /// Load all watchlists for a profile
    func loadWatchlists(for profile: Profile) {
        let request: NSFetchRequest<Watchlist> = Watchlist.fetchRequest()
        request.predicate = NSPredicate(format: "profile == %@", profile)
        request.sortDescriptors = [NSSortDescriptor(key: "createdAt", ascending: true)]
        
        do {
            watchlists = try context.fetch(request)
        } catch {
            print("Failed to load watchlists: \(error)")
            watchlists = []
        }
    }
    
    /// Create a new watchlist
    func createWatchlist(
        name: String,
        icon: String = "list.bullet",
        profile: Profile
    ) throws -> Watchlist {
        // Check limit
        let count = getWatchlistCount(for: profile)
        guard count < maxWatchlists else {
            throw WatchlistError.watchlistLimitReached
        }
        
        let watchlist = Watchlist.create(name: name, icon: icon, profile: profile, context: context)
        
        try context.save()
        loadWatchlists(for: profile)
        
        return watchlist
    }
    
    /// Delete a watchlist
    func deleteWatchlist(_ watchlist: Watchlist, profile: Profile) throws {
        context.delete(watchlist)
        try context.save()
        loadWatchlists(for: profile)
    }
    
    /// Rename a watchlist
    func renameWatchlist(_ watchlist: Watchlist, newName: String, profile: Profile) throws {
        watchlist.name = newName
        watchlist.updatedAt = Date()
        try context.save()
        loadWatchlists(for: profile)
    }
    
    /// Update watchlist icon
    func updateIcon(_ watchlist: Watchlist, icon: String, profile: Profile) throws {
        watchlist.icon = icon
        watchlist.updatedAt = Date()
        try context.save()
        loadWatchlists(for: profile)
    }
    
    /// Get watchlist count for a profile
    func getWatchlistCount(for profile: Profile) -> Int {
        let request: NSFetchRequest<Watchlist> = Watchlist.fetchRequest()
        request.predicate = NSPredicate(format: "profile == %@", profile)
        
        do {
            return try context.count(for: request)
        } catch {
            print("Failed to count watchlists: \(error)")
            return 0
        }
    }
    
    // MARK: - Item Management
    
    /// Add content to a watchlist
    func addToWatchlist(
        _ content: NSManagedObject,
        watchlist: Watchlist
    ) throws {
        // Validate content type
        guard content is Movie || content is Episode || content is Series else {
            throw WatchlistError.invalidContent
        }
        
        let contentID = content.objectID.uriRepresentation().absoluteString
        
        // Check if already exists
        if watchlist.contains(contentID: contentID) {
            throw WatchlistError.itemAlreadyExists
        }
        
        // Get next position
        let position = Int32(watchlist.itemCount)
        
        // Create item
        guard let _ = WatchlistItem.create(
            for: content,
            watchlist: watchlist,
            position: position,
            context: context
        ) else {
            throw WatchlistError.invalidContent
        }
        
        watchlist.updatedAt = Date()
        try context.save()
    }
    
    /// Remove item from watchlist
    func removeFromWatchlist(_ item: WatchlistItem, watchlist: Watchlist) throws {
        context.delete(item)
        watchlist.updatedAt = Date()
        try context.save()
        
        // Reorder remaining items
        reorderItems(in: watchlist)
    }
    
    /// Move item to new position (for drag-to-reorder)
    func moveItem(
        _ item: WatchlistItem,
        to newPosition: Int32,
        in watchlist: Watchlist
    ) throws {
        let oldPosition = item.position
        
        guard oldPosition != newPosition else { return }
        
        let items = watchlist.sortedItems
        
        if oldPosition < newPosition {
            // Moving down
            for otherItem in items where otherItem.position > oldPosition && otherItem.position <= newPosition {
                otherItem.position -= 1
            }
        } else {
            // Moving up
            for otherItem in items where otherItem.position >= newPosition && otherItem.position < oldPosition {
                otherItem.position += 1
            }
        }
        
        item.position = newPosition
        watchlist.updatedAt = Date()
        try context.save()
    }
    
    /// Reorder items to fix gaps in positions
    private func reorderItems(in watchlist: Watchlist) {
        let items = watchlist.sortedItems
        for (index, item) in items.enumerated() {
            item.position = Int32(index)
        }
        
        do {
            try context.save()
        } catch {
            print("Failed to reorder items: \(error)")
        }
    }
    
    /// Check if content is in any watchlist
    func isInAnyWatchlist(_ content: NSManagedObject, profile: Profile) -> Bool {
        let contentID = content.objectID.uriRepresentation().absoluteString
        
        let request: NSFetchRequest<WatchlistItem> = WatchlistItem.fetchRequest()
        request.predicate = NSPredicate(
            format: "contentID == %@ AND watchlist.profile == %@",
            contentID,
            profile
        )
        
        do {
            let count = try context.count(for: request)
            return count > 0
        } catch {
            print("Failed to check watchlist membership: \(error)")
            return false
        }
    }
    
    /// Get all watchlists containing this content
    func getWatchlistsContaining(_ content: NSManagedObject, profile: Profile) -> [Watchlist] {
        let contentID = content.objectID.uriRepresentation().absoluteString
        
        let request: NSFetchRequest<Watchlist> = Watchlist.fetchRequest()
        request.predicate = NSPredicate(
            format: "profile == %@ AND ANY items.contentID == %@",
            profile,
            contentID
        )
        request.sortDescriptors = [NSSortDescriptor(key: "name", ascending: true)]
        
        do {
            return try context.fetch(request)
        } catch {
            print("Failed to fetch watchlists: \(error)")
            return []
        }
    }
    
    /// Get items in a watchlist
    func getItems(for watchlist: Watchlist) -> [WatchlistItem] {
        return watchlist.sortedItems
    }
    
    /// Clear all items from a watchlist
    func clearWatchlist(_ watchlist: Watchlist) throws {
        guard let items = watchlist.items as? Set<WatchlistItem> else { return }
        
        for item in items {
            context.delete(item)
        }
        
        watchlist.updatedAt = Date()
        try context.save()
    }
    
    // MARK: - Utility Methods
    
    /// Get total item count across all watchlists for a profile
    func getTotalItemCount(for profile: Profile) -> Int {
        let request: NSFetchRequest<WatchlistItem> = WatchlistItem.fetchRequest()
        request.predicate = NSPredicate(format: "watchlist.profile == %@", profile)
        
        do {
            return try context.count(for: request)
        } catch {
            print("Failed to count items: \(error)")
            return 0
        }
    }
    
    /// Search watchlists by name
    func searchWatchlists(query: String, profile: Profile) -> [Watchlist] {
        let request: NSFetchRequest<Watchlist> = Watchlist.fetchRequest()
        request.predicate = NSPredicate(
            format: "profile == %@ AND name CONTAINS[cd] %@",
            profile,
            query
        )
        request.sortDescriptors = [NSSortDescriptor(key: "name", ascending: true)]
        
        do {
            return try context.fetch(request)
        } catch {
            print("Failed to search watchlists: \(error)")
            return []
        }
    }
}
