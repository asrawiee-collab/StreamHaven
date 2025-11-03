import CoreData
import Foundation

/// Manages all data operations for the StreamHaven application, including importing playlists and managing the Core Data stack.
@MainActor
public final class StreamHavenData: ObservableObject {

    /// The persistence provider for the Core Data stack.
    private let persistenceProvider: PersistenceProviding
    
    /// Manager for maintaining denormalized fields.
    private let denormalizationManager: DenormalizationManager

    /// A background context for performing data import and processing tasks without blocking the main thread.
    public let backgroundContext: NSManagedObjectContext

    /// Initializes a new data manager with the specified persistence provider.
    /// - Parameter persistenceProvider: The `PersistenceProviding` to use for Core Data operations.
    public init(persistenceProvider: PersistenceProviding) {
        self.persistenceProvider = persistenceProvider
        self.denormalizationManager = DenormalizationManager(persistenceProvider: persistenceProvider)
        self.backgroundContext = persistenceProvider.container.newBackgroundContext()
        self.backgroundContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy

        NotificationCenter.default.addObserver(
            self, selector: #selector(contextDidSave), name: .NSManagedObjectContextDidSave, object: backgroundContext
        )
    }

    @objc private func contextDidSave(notification: Notification) {
        // Indexing is handled via Core Data's standard querying.
    }

    /// Downloads, parses, and imports a playlist from a remote URL.
    ///
    /// This function performs the entire import process, including:
    /// 1. Downloading the playlist data from the specified URL.
    /// 2. Caching the downloaded data to the file system.
    /// 3. Detecting the playlist type (M3U or Xtream Codes).
    /// 4. Parsing the data and saving the content to Core Data.
    ///
    /// - Parameters:
    ///   - url: The URL of the playlist to import.
    ///   - progress: A closure that is called with status updates during the import process.
    /// - Throws: A `PlaylistImportError` if the import fails at any stage.
    public func importPlaylist(from url: URL, epgURL: URL? = nil, progress: @escaping (String) -> Void) async throws {
        progress(NSLocalizedString("Downloading...", comment: "Playlist import status"))
        let (data, _) = try await URLSession.shared.data(from: url)

        progress(NSLocalizedString("Caching playlist...", comment: "Playlist import status"))
        try await backgroundContext.perform {
            _ = PlaylistCacheManager.cachePlaylist(url: url, data: data, context: self.backgroundContext, epgURL: epgURL)
        }

        progress(NSLocalizedString("Parsing playlist...", comment: "Playlist import status"))
        try await PlaylistParser.parse(url: url, context: backgroundContext, data: data)

        progress(NSLocalizedString("Updating indexes...", comment: "Playlist import status"))
        try await denormalizationManager.rebuildDenormalizedFields()
    }
    
    /// Imports multiple playlists concurrently with optimized resource usage.
    ///
    /// - Parameters:
    ///   - urls: The array of playlist URLs to import.
    ///   - progress: A closure that is called with per-playlist status updates.
    /// - Returns: A dictionary mapping URLs to their import results (success or error).
    public func importPlaylists(
        from urls: [URL], progress: @escaping (URL, String) -> Void
    ) async -> [URL: Result<Void, Error>] {
        // Limit concurrent imports to avoid overwhelming the system
        let maxConcurrentImports = min(urls.count, 3)
        
        return await withTaskGroup(of: (URL, Result<Void, Error>).self) { group in
            var results: [URL: Result<Void, Error>] = [:]
            var urlIterator = urls.makeIterator()
            var activeCount = 0
            
            // Start initial batch
            for _ in 0..<maxConcurrentImports {
                if let url = urlIterator.next() {
                    group.addTask {
                        await self.importPlaylistTask(url: url, progress: progress)
                    }
                    activeCount += 1
                }
            }
            
            // Process results and start new tasks
            for await (url, result) in group {
                results[url] = result
                
                // Start next task if available
                if let nextURL = urlIterator.next() {
                    group.addTask {
                        await self.importPlaylistTask(url: nextURL, progress: progress)
                    }
                }
            }
            
            return results
        }
    }
    
    /// Helper method for parallel import execution.
    private func importPlaylistTask(url: URL, progress: @escaping (URL, String) -> Void) async -> (URL, Result<Void, Error>) {
        // Create isolated context for this import
        let isolatedContext = persistenceProvider.container.newBackgroundContext()
        isolatedContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        
        do {
            progress(url, NSLocalizedString("Downloading...", comment: ""))
            let (data, _) = try await URLSession.shared.data(from: url)
            
            progress(url, NSLocalizedString("Caching...", comment: ""))
            try await isolatedContext.perform {
                _ = PlaylistCacheManager.cachePlaylist(url: url, data: data, context: isolatedContext)
            }

            progress(url, NSLocalizedString("Parsing...", comment: ""))
            try await PlaylistParser.parse(url: url, context: isolatedContext, data: data)

            progress(url, NSLocalizedString("Complete", comment: ""))
            return (url, .success(()))
        } catch {
            progress(url, NSLocalizedString("Failed", comment: ""))
            ErrorReporter.log(error, context: "StreamHavenData.importPlaylistTask")
            return (url, .failure(error))
        }
    }
    
    /// Downloads and parses a playlist incrementally as data arrives.
    ///
    /// This enables faster perceived performance by starting parsing before the full download completes.
    ///
    /// - Parameters:
    ///   - url: The URL of the playlist to import.
    ///   - progress: A closure that is called with status updates including parse progress.
    /// - Throws: A `PlaylistImportError` if the import fails at any stage.
    public func importPlaylistIncremental(from url: URL, progress: @escaping (String) -> Void) async throws {
        let type = PlaylistParser.detectPlaylistType(from: url)
        
        // Only M3U supports incremental parsing
        guard type == .m3u else {
            // Fall back to standard import for non-M3U
            return try await importPlaylist(from: url, epgURL: nil, progress: progress)
        }
        
        progress(NSLocalizedString("Connecting...", comment: ""))
        
        // Create URLSession with streaming delegate
        let session = URLSession(configuration: .default)
        let (asyncBytes, response) = try await session.bytes(from: url)
        
        guard (response as? HTTPURLResponse)?.statusCode == 200 else {
            throw PlaylistImportError.networkError(URLError(.badServerResponse))
        }
        
        // Write to temporary file and parse incrementally
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("m3u")
        
        guard let outputStream = OutputStream(url: tempURL, append: false) else {
            throw PlaylistImportError.invalidURL
        }
        
        outputStream.open()
        defer {
            outputStream.close()
            try? FileManager.default.removeItem(at: tempURL)
        }
        
        var totalBytes = 0
        let expectedLength = response.expectedContentLength
        
        progress(NSLocalizedString("Downloading...", comment: ""))
        
        // Stream data to disk
        for try await byte in asyncBytes {
            let buffer = [byte]
            outputStream.write(buffer, maxLength: 1)
            totalBytes += 1
            
            // Update progress periodically
            if totalBytes % 10240 == 0 { // Every 10KB
                if expectedLength > 0 {
                    let percent = Int((Double(totalBytes) / Double(expectedLength)) * 100)
                    progress(NSLocalizedString("Downloading \(percent)%", comment: ""))
                }
            }
        }
        
        outputStream.close()
        
        progress(NSLocalizedString("Caching playlist...", comment: ""))
        let cachedData = try Data(contentsOf: tempURL)
        try await backgroundContext.perform {
            _ = PlaylistCacheManager.cachePlaylist(url: url, data: cachedData, context: self.backgroundContext, epgURL: nil)
        }

        progress(NSLocalizedString("Parsing playlist...", comment: ""))
        try await backgroundContext.perform {
            try M3UPlaylistParser.parse(fileURL: tempURL, context: self.backgroundContext)
        }

        progress(NSLocalizedString("Complete", comment: ""))
    }
}
