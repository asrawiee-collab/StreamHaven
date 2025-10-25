import Foundation
import CoreData

/// Represents a downloaded or downloading content item.
/// This class is a Core Data managed object.
@objc(Download)
public class Download: NSManagedObject {

}

extension Download {

    /// Creates a fetch request for the `Download` entity.
    /// - Returns: A `NSFetchRequest<Download>` to fetch `Download` objects.
    @nonobjc public class func fetchRequest() -> NSFetchRequest<Download> {
        return NSFetchRequest<Download>(entityName: "Download")
    }

    /// The stream URL of the content.
    @NSManaged public var streamURL: String?
    /// The title of the content.
    @NSManaged public var contentTitle: String?
    /// The type of content (movie, episode).
    @NSManaged public var contentType: String?
    /// The download status (queued, downloading, completed, failed, paused).
    @NSManaged public var status: String?
    /// The download progress (0.0 to 1.0).
    @NSManaged public var progress: Float
    /// The local file path once downloaded.
    @NSManaged public var filePath: String?
    /// The file size in bytes.
    @NSManaged public var fileSize: Int64
    /// The date when the download completed.
    @NSManaged public var downloadedAt: Date?
    /// The expiration date for the download.
    @NSManaged public var expiresAt: Date?
    /// The thumbnail URL.
    @NSManaged public var thumbnailURL: String?
    /// The IMDb ID for matching.
    @NSManaged public var imdbID: String?
    /// The `Movie` object if the download is for a movie.
    @NSManaged public var movie: Movie?
    /// The `Episode` object if the download is for an episode.
    @NSManaged public var episode: Episode?
}

// MARK: - Download Status

extension Download {
    /// Enumeration of possible download statuses.
    public enum Status: String {
        case queued = "queued"
        case downloading = "downloading"
        case completed = "completed"
        case failed = "failed"
        case paused = "paused"
    }
    
    /// Gets the status as an enum value.
    public var downloadStatus: Status {
        get {
            Status(rawValue: status ?? "queued") ?? .queued
        }
        set {
            status = newValue.rawValue
        }
    }
    
    /// Checks if the download is completed and file exists.
    public var isAvailableOffline: Bool {
        guard downloadStatus == .completed,
              let filePath = filePath else {
            return false
        }
        return FileManager.default.fileExists(atPath: filePath)
    }
    
    /// Checks if the download has expired.
    public var isExpired: Bool {
        guard let expiresAt = expiresAt else {
            return false
        }
        return Date() > expiresAt
    }
}
