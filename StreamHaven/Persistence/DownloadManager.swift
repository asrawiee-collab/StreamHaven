import AVFoundation
import CoreData
import Foundation
import os.log

#if !os(tvOS)
/// Manages persistent downloads of HLS content for offline playback.
/// Uses AVAssetDownloadURLSession for HLS streaming downloads.
@MainActor
public class DownloadManager: NSObject, ObservableObject {
    
    // MARK: - Published Properties
    
    @Published public var activeDownloads: [Download] = []
    @Published public var completedDownloads: [Download] = []
    @Published public var totalStorageUsed: Int64 = 0
    @Published public var downloadError: Error?
    
    // MARK: - Properties
    
    private let context: NSManagedObjectContext
    private let logger = Logger(subsystem: "com.streamhaven.downloads", category: "DownloadManager")
    
    private var downloadSession: AVAssetDownloadURLSession!
    private var activeDownloadTasks: [String: AVAssetDownloadTask] = [:]
    private var contextObserver: NSObjectProtocol?
    
    /// Maximum storage in bytes (default: 10GB)
    public var maxStorageBytes: Int64
    
    /// Auto-delete watched downloads
    public var autoDeleteWatched: Bool = false
    
    /// Download quality preference
    public enum DownloadQuality: String {
        case low       // ~720p
        case medium // ~1080p
        case high     // ~4K
        case auto     // Best available
    }
    public var preferredQuality: DownloadQuality = .medium
    
    // MARK: - Initialization
    
    public init(context: NSManagedObjectContext, maxStorageGB: Int = 10) {
        self.context = context
        self.maxStorageBytes = Int64(maxStorageGB) * 1_073_741_824 // Convert GB to bytes
        super.init()
        
        setupDownloadSession()
        loadDownloads()
        calculateStorageUsed()

        contextObserver = NotificationCenter.default.addObserver(
            forName: .NSManagedObjectContextObjectsDidChange, object: context, queue: nil
        ) { [weak self] notification in
            guard let self else { return }
            if Thread.isMainThread {
                MainActor.assumeIsolated {
                    self.handleContextChange(notification: notification)
                }
            } else {
                Task { @MainActor [weak self] in
                    self?.handleContextChange(notification: notification)
                }
            }
        }
    }
    
    deinit {
        if let observer = contextObserver {
            NotificationCenter.default.removeObserver(observer)
        }
    }
    
    private func setupDownloadSession() {
        let config = URLSessionConfiguration.background(withIdentifier: "com.streamhaven.downloads")
        config.isDiscretionary = false
        config.sessionSendsLaunchEvents = true
        
        downloadSession = AVAssetDownloadURLSession(
            configuration: config, assetDownloadDelegate: self, delegateQueue: .main
        )
    }
    
    // MARK: - Public Methods
    
    /// Starts downloading content.
    /// - Parameters:
    ///   - item: The content item to download (Movie or Episode)
    ///   - title: The title of the content
    ///   - thumbnailURL: Optional thumbnail URL
    public func startDownload(for item: NSManagedObject, title: String, thumbnailURL: String? = nil) throws {
        guard let streamURL = getStreamURL(for: item) else {
            throw DownloadError.invalidURL
        }
        
        // Check if already downloaded or downloading
        if let existing = findDownload(for: item) {
            if existing.downloadStatus == .completed {
                throw DownloadError.alreadyDownloaded
            } else if existing.downloadStatus == .downloading {
                throw DownloadError.alreadyDownloading
            }
        }
        
        // Check storage quota
        guard hasAvailableStorage() else {
            throw DownloadError.storageQuotaExceeded
        }
        
        guard let url = URL(string: streamURL) else {
            throw DownloadError.invalidURL
        }
        
        let asset = AVURLAsset(url: url)
        
        // Create download entity
        let download = Download(context: context)
        download.streamURL = streamURL
        download.contentTitle = title
        download.thumbnailURL = thumbnailURL
        download.progress = 0.0
        download.downloadStatus = .queued
        
        if let movie = item as? Movie {
            download.contentType = "movie"
            download.imdbID = movie.imdbID
            download.movie = movie
        } else if let episode = item as? Episode {
            download.contentType = "episode"
            download.episode = episode
        }
        
        try context.save()
        
        // Start download task
        let options = createDownloadOptions()
        guard let task = downloadSession.makeAssetDownloadTask(
            asset: asset, assetTitle: title, assetArtworkData: nil, options: options
        ) else {
            download.downloadStatus = .failed
            try context.save()
            throw DownloadError.notSupported
        }

        task.taskDescription = streamURL
        activeDownloadTasks[streamURL] = task
        download.downloadStatus = .downloading
        try context.save()

        task.resume()
        
        loadDownloads()
        logger.info("Started download: \(title)")
    }
    
    /// Pauses a download.
    public func pauseDownload(_ download: Download) {
        guard let streamURL = download.streamURL else {
            download.downloadStatus = .paused
            try? context.save()
            loadDownloads()
            logger.info("Paused download without active task: \(download.contentTitle ?? "Unknown")")
            return
        }
        
        if let task = activeDownloadTasks[streamURL] {
            task.suspend()
        }
        download.downloadStatus = .paused
        try? context.save()
        
        loadDownloads()
        logger.info("Paused download: \(download.contentTitle ?? "Unknown")")
    }
    
    /// Resumes a paused download.
    public func resumeDownload(_ download: Download) {
        guard let streamURL = download.streamURL else {
            download.downloadStatus = .downloading
            try? context.save()
            loadDownloads()
            logger.info("Resumed download without active task: \(download.contentTitle ?? "Unknown")")
            return
        }
        
        if let task = activeDownloadTasks[streamURL] {
            task.resume()
        }
        download.downloadStatus = .downloading
        try? context.save()
        
        loadDownloads()
        logger.info("Resumed download: \(download.contentTitle ?? "Unknown")")
    }
    
    /// Cancels and deletes a download.
    public func cancelDownload(_ download: Download) {
        if let streamURL = download.streamURL, let task = activeDownloadTasks[streamURL] {
            task.cancel()
            activeDownloadTasks.removeValue(forKey: streamURL)
        }
        
        // Delete file if it exists
        if let filePath = download.filePath {
            try? FileManager.default.removeItem(atPath: filePath)
        }
        
        context.delete(download)
        try? context.save()
        
        loadDownloads()
        calculateStorageUsed()
        logger.info("Cancelled download: \(download.contentTitle ?? "Unknown")")
    }
    
    /// Deletes a completed download.
    public func deleteDownload(_ download: Download) {
        if let filePath = download.filePath {
            try? FileManager.default.removeItem(atPath: filePath)
        }
        
        context.delete(download)
        try? context.save()
        
        loadDownloads()
        calculateStorageUsed()
        logger.info("Deleted download: \(download.contentTitle ?? "Unknown")")
    }
    
    /// Gets the local file path for downloaded content.
    public func getLocalFilePath(for item: NSManagedObject) -> String? {
        guard let download = findDownload(for: item), download.isAvailableOffline else {
            return nil
        }
        return download.filePath
    }
    
    /// Checks if content is downloaded and available offline.
    public func isDownloaded(_ item: NSManagedObject) -> Bool {
        guard let download = findDownload(for: item) else {
            return false
        }
        return download.isAvailableOffline
    }
    
    /// Cleans up expired downloads.
    public func cleanupExpiredDownloads() {
        let fetchRequest: NSFetchRequest<Download> = Download.fetchRequest()
        
        do {
            let downloads = try context.fetch(fetchRequest)
            var deletedCount = 0
            
            for download in downloads where download.isExpired {
                deleteDownload(download)
                deletedCount += 1
            }
            
            if deletedCount > 0 {
                logger.info("Cleaned up \(deletedCount) expired downloads")
            }
        } catch {
            logger.error("Failed to cleanup expired downloads: \(error.localizedDescription)")
        }
    }
    
    /// Cleans up watched downloads if auto-delete is enabled.
    public func cleanupWatchedDownloads() {
        guard autoDeleteWatched else { return }
        
        let fetchRequest: NSFetchRequest<Download> = Download.fetchRequest()
        
        do {
            let downloads = try context.fetch(fetchRequest)
            var deletedCount = 0
            
            for download in downloads where download.downloadStatus == .completed {
                // Check if fully watched
                if let movie = download.movie, movie.hasBeenWatched {
                    deleteDownload(download)
                    deletedCount += 1
                } else if let episode = download.episode, let history = episode.watchHistory, history.progress >= 0.9 { // 90% watched
                    deleteDownload(download)
                    deletedCount += 1
                }
            }
            
            if deletedCount > 0 {
                logger.info("Cleaned up \(deletedCount) watched downloads")
            }
        } catch {
            logger.error("Failed to cleanup watched downloads: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Private Methods
    
    private func loadDownloads() {
        let fetchRequest: NSFetchRequest<Download> = Download.fetchRequest()
        
        do {
            let downloads = try context.fetch(fetchRequest)
            
            activeDownloads = downloads.filter {
                $0.downloadStatus == .downloading || $0.downloadStatus == .paused || $0.downloadStatus == .queued
            }
            
            completedDownloads = downloads.filter {
                $0.downloadStatus == .completed
            }
        } catch {
            logger.error("Failed to load downloads: \(error.localizedDescription)")
        }
    }
    
    private func findDownload(for item: NSManagedObject) -> Download? {
        let fetchRequest: NSFetchRequest<Download> = Download.fetchRequest()
        
        if let movie = item as? Movie {
            fetchRequest.predicate = NSPredicate(format: "movie == %@", movie)
        } else if let episode = item as? Episode {
            fetchRequest.predicate = NSPredicate(format: "episode == %@", episode)
        } else {
            return nil
        }
        
        return try? context.fetch(fetchRequest).first
    }
    
    private func getStreamURL(for item: NSManagedObject?) -> String? {
        if let movie = item as? Movie {
            return movie.streamURL
        } else if let episode = item as? Episode {
            return episode.streamURL
        }
        return nil
    }

    // MARK: - Delegate Helpers

    @MainActor
    private func handleDownloadCompletion(streamURL: String, location: URL) {
        let fetchRequest: NSFetchRequest<Download> = Download.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "streamURL == %@", streamURL)

        guard let download = try? context.fetch(fetchRequest).first else {
            return
        }

        download.filePath = location.path
        download.downloadStatus = .completed
        download.progress = 1.0
        download.downloadedAt = Date()

        download.expiresAt = Calendar.current.date(byAdding: .day, value: 30, to: Date())

        if let attributes = try? FileManager.default.attributesOfItem(atPath: location.path), let size = attributes[.size] as? Int64 {
            download.fileSize = size
        }

        try? context.save()

        activeDownloadTasks.removeValue(forKey: streamURL)
        loadDownloads()
        calculateStorageUsed()

        let title = download.contentTitle ?? "Unknown"
        logger.info("Download completed: \(title, privacy: .public)")
    }

    @MainActor
    private func handleDownloadProgress(streamURL: String, percentComplete: Double) {
        let fetchRequest: NSFetchRequest<Download> = Download.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "streamURL == %@", streamURL)

        guard let download = try? context.fetch(fetchRequest).first else {
            return
        }

        download.progress = Float(percentComplete)
        try? context.save()
    }

    @MainActor
    private func handleDownloadFailure(streamURL: String, error: NSError) {
        let fetchRequest: NSFetchRequest<Download> = Download.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "streamURL == %@", streamURL)

        guard let download = try? context.fetch(fetchRequest).first else {
            return
        }

        download.downloadStatus = .failed
        try? context.save()

        activeDownloadTasks.removeValue(forKey: streamURL)
        loadDownloads()

        downloadError = error
        let title = download.contentTitle ?? "Unknown"
        logger.error("Download failed: \(title, privacy: .public) - \(error.localizedDescription, privacy: .public)")
    }
    
    private func calculateStorageUsed() {
        let fetchRequest: NSFetchRequest<Download> = Download.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "status == %@", Download.Status.completed.rawValue)
        
        do {
            let downloads = try context.fetch(fetchRequest)
            totalStorageUsed = downloads.reduce(0) { $0 + $1.fileSize }
        } catch {
            logger.error("Failed to calculate storage: \(error.localizedDescription)")
        }
    }
    
    private func hasAvailableStorage() -> Bool {
        return totalStorageUsed < maxStorageBytes
    }
    
    private func createDownloadOptions() -> [String: Any] {
        var options: [String: Any] = [:]
        
        // Set preferred quality
        switch preferredQuality {
        case .low:
            options[AVAssetDownloadTaskMinimumRequiredMediaBitrateKey] = 2_000_000 // 2 Mbps
        case .medium:
            options[AVAssetDownloadTaskMinimumRequiredMediaBitrateKey] = 5_000_000 // 5 Mbps
        case .high:
            options[AVAssetDownloadTaskMinimumRequiredMediaBitrateKey] = 10_000_000 // 10 Mbps
        case .auto:
            break // Use default
        }
        
        return options
    }

    private func handleContextChange(notification: Notification) {
        guard let userInfo = notification.userInfo else { return }
        let relevantKeys = [NSInsertedObjectsKey, NSUpdatedObjectsKey, NSDeletedObjectsKey]
        let hasDownloadChange = relevantKeys.contains { key in
            guard let objects = userInfo[key] as? Set<NSManagedObject> else { return false }
            return objects.contains { $0 is Download }
        }

        if hasDownloadChange {
            loadDownloads()
            calculateStorageUsed()
        }
    }
}

// MARK: - AVAssetDownloadDelegate

@available(iOS 15.0, macOS 11.0, *)
extension DownloadManager: AVAssetDownloadDelegate, URLSessionTaskDelegate {
    
    nonisolated public func urlSession(_ session: URLSession, assetDownloadTask: AVAssetDownloadTask, didFinishDownloadingTo location: URL) {
        let streamURL = assetDownloadTask.taskDescription ?? assetDownloadTask.urlAsset.url.absoluteString
        guard !streamURL.isEmpty else { return }

        Task { @MainActor [weak self] in
            self?.handleDownloadCompletion(streamURL: streamURL, location: location)
        }
    }
    
    nonisolated public func urlSession(_ session: URLSession, assetDownloadTask: AVAssetDownloadTask, didLoad timeRange: CMTimeRange, totalTimeRangesLoaded loadedTimeRanges: [NSValue], timeRangeExpectedToLoad expectedTimeRange: CMTimeRange) {
        let streamURL = assetDownloadTask.taskDescription ?? assetDownloadTask.urlAsset.url.absoluteString
        guard !streamURL.isEmpty else { return }

        var percentComplete: Double = 0.0
        for value in loadedTimeRanges {
            let loadedRange = value.timeRangeValue
            percentComplete += CMTimeGetSeconds(loadedRange.duration) / CMTimeGetSeconds(expectedTimeRange.duration)
        }

        Task { @MainActor [weak self] in
            self?.handleDownloadProgress(streamURL: streamURL, percentComplete: percentComplete)
        }
    }
    
    nonisolated public func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        guard let error else { return }
        let streamURL = task.taskDescription ?? task.originalRequest?.url?.absoluteString ?? ""
        guard !streamURL.isEmpty else { return }

        let nsError = error as NSError
        Task { @MainActor [weak self] in
            self?.handleDownloadFailure(streamURL: streamURL, error: nsError)
        }
    }
}

// MARK: - Error Types

public enum DownloadError: LocalizedError {
    case invalidURL
    case alreadyDownloaded
    case alreadyDownloading
    case storageQuotaExceeded
    case notSupported
    
    public var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid stream URL."
        case .alreadyDownloaded:
            return "This content is already downloaded."
        case .alreadyDownloading:
            return "This content is currently downloading."
        case .storageQuotaExceeded:
            return "Storage quota exceeded. Please delete some downloads."
        case .notSupported:
            return "Downloads are not supported on this platform."
        }
    }
}

#else
// tvOS fallback - downloads not supported
@MainActor
public class DownloadManager: NSObject, ObservableObject {
    @Published public var activeDownloads: [Download] = []
    @Published public var completedDownloads: [Download] = []
    @Published public var totalStorageUsed: Int64 = 0
    @Published public var downloadError: Error?
    
    public var maxStorageBytes: Int64 = 0
    public var autoDeleteWatched: Bool = false
    public enum DownloadQuality: String {
        case low, medium, high, auto
    }
    public var preferredQuality: DownloadQuality = .medium
    
    public init(context: NSManagedObjectContext, maxStorageGB: Int = 10) {
        super.init()
    }
    
    public func startDownload(for item: NSManagedObject, title: String, thumbnailURL: String? = nil) throws {
        throw DownloadError.notSupported
    }
    
    public func pauseDownload(_ download: Download) {}
    public func resumeDownload(_ download: Download) {}
    public func cancelDownload(_ download: Download) {}
    public func deleteDownload(_ download: Download) {}
    public func getLocalFilePath(for item: NSManagedObject) -> String? { nil }
    public func isDownloaded(_ item: NSManagedObject) -> Bool { false }
    public func cleanupExpiredDownloads() {}
    public func cleanupWatchedDownloads() {}
}
#endif
