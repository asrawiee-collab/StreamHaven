import Foundation
import CoreData
import Combine

/// Manages playlist sources for user profiles.
/// Handles adding, removing, activating, and ordering sources.
@MainActor
class PlaylistSourceManager: ObservableObject {
    
    // MARK: - Published Properties
    
    @Published var sources: [PlaylistSource] = []
    @Published var activeSources: [PlaylistSource] = []
    @Published var isLoading = false
    @Published var error: Error?
    
    // MARK: - Private Properties
    
    private let persistenceController: PersistenceController
    private let context: NSManagedObjectContext
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Initialization
    
    init(persistenceController: PersistenceController = .shared) {
        self.persistenceController = persistenceController
        self.context = persistenceController.container.viewContext
    }
    
    // MARK: - Source Management
    
    /// Loads all sources for the given profile.
    func loadSources(for profile: Profile) {
        sources = profile.allSources
        activeSources = profile.activeSources
    }
    
    /// Adds a new M3U playlist source.
    /// - Parameters:
    ///   - name: User-defined name for the source
    ///   - url: URL of the M3U playlist
    ///   - profile: Profile to add the source to
    /// - Returns: The newly created source
    @discardableResult
    func addM3USource(name: String, url: String, to profile: Profile) throws -> PlaylistSource {
        let source = PlaylistSource(context: context)
        source.sourceID = UUID()
        source.name = name
        source.sourceType = PlaylistSource.SourceType.m3u.rawValue
        source.url = url
        source.isActive = true
        source.displayOrder = Int32(profile.allSources.count)
        source.createdAt = Date()
        source.profile = profile
        
        try context.save()
        loadSources(for: profile)
        
        return source
    }
    
    /// Adds a new Xtream Codes source.
    /// - Parameters:
    ///   - name: User-defined name for the source
    ///   - url: Base URL of the Xtream Codes server
    ///   - username: Username for authentication
    ///   - password: Password for authentication
    ///   - profile: Profile to add the source to
    /// - Returns: The newly created source
    @discardableResult
    func addXtreamSource(name: String, url: String, username: String, password: String, to profile: Profile) throws -> PlaylistSource {
        let source = PlaylistSource(context: context)
        source.sourceID = UUID()
        source.name = name
        source.sourceType = PlaylistSource.SourceType.xtream.rawValue
        source.url = url
        source.username = username
        source.password = password // Note: Should be stored in Keychain in production
        source.isActive = true
        source.displayOrder = Int32(profile.allSources.count)
        source.createdAt = Date()
        source.profile = profile
        
        try context.save()
        loadSources(for: profile)
        
        return source
    }
    
    /// Removes a source from the profile.
    func removeSource(_ source: PlaylistSource, from profile: Profile) throws {
        context.delete(source)
        try context.save()
        loadSources(for: profile)
    }
    
    /// Updates a source's details.
    func updateSource(_ source: PlaylistSource, name: String?, url: String?, username: String?, password: String?) throws {
        if let name = name {
            source.name = name
        }
        if let url = url {
            source.url = url
        }
        if let username = username {
            source.username = username
        }
        if let password = password {
            source.password = password
        }
        
        try context.save()
        
        if let profile = source.profile {
            loadSources(for: profile)
        }
    }
    
    /// Activates a source.
    func activateSource(_ source: PlaylistSource) throws {
        source.isActive = true
        try context.save()
        
        if let profile = source.profile {
            loadSources(for: profile)
        }
    }
    
    /// Deactivates a source.
    func deactivateSource(_ source: PlaylistSource) throws {
        source.isActive = false
        try context.save()
        
        if let profile = source.profile {
            loadSources(for: profile)
        }
    }
    
    /// Reorders sources for a profile.
    /// - Parameters:
    ///   - sources: Array of sources in the desired order
    ///   - profile: Profile to reorder sources for
    func reorderSources(_ sources: [PlaylistSource], for profile: Profile) throws {
        for (index, source) in sources.enumerated() {
            source.displayOrder = Int32(index)
        }
        
        try context.save()
        loadSources(for: profile)
    }
    
    /// Moves a source from one position to another.
    func moveSource(from fromIndex: Int, to toIndex: Int, in profile: Profile) throws {
        var mutableSources = profile.allSources
        let source = mutableSources.remove(at: fromIndex)
        mutableSources.insert(source, at: toIndex)
        
        try reorderSources(mutableSources, for: profile)
    }
    
    // MARK: - Source Mode Management
    
    /// Sets the source viewing mode for a profile.
    /// - Parameters:
    ///   - mode: The mode to set (combined or single)
    ///   - profile: Profile to update
    func setSourceMode(_ mode: Profile.SourceMode, for profile: Profile) throws {
        profile.sourceMode = mode.rawValue
        try context.save()
    }
    
    /// Gets the current source mode for a profile.
    func getSourceMode(for profile: Profile) -> Profile.SourceMode {
        return profile.mode
    }
    
    // MARK: - Source Status
    
    /// Updates the last refresh time and error status for a source.
    func updateSourceStatus(_ source: PlaylistSource, lastRefreshed: Date?, error: String?) throws {
        source.lastRefreshed = lastRefreshed
        source.lastError = error
        try context.save()
        
        if let profile = source.profile {
            loadSources(for: profile)
        }
    }
    
    /// Checks if a profile has any active sources.
    func hasActiveSources(for profile: Profile) -> Bool {
        return !profile.activeSources.isEmpty
    }
    
    /// Gets the count of active sources for a profile.
    func activeSourceCount(for profile: Profile) -> Int {
        return profile.activeSources.count
    }
    
}
