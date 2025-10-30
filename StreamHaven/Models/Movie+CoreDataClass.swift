import Foundation
import CoreData

/// Represents a movie in the application.
/// This class is a Core Data managed object.
@objc(Movie)
public class Movie: NSManagedObject {
    public override func awakeFromInsert() {
        super.awakeFromInsert()
        if self.stableID == nil {
            self.stableID = UUID().uuidString
        }
    }

    public override func willSave() {
        super.willSave()
        syncReleaseYearWithReleaseDate()
    }

    private func syncReleaseYearWithReleaseDate() {
        guard let releaseDate else { return }
        let year = Calendar.current.component(.year, from: releaseDate)
        if releaseYear != year {
            releaseYear = year
        }
    }
}

extension Movie {

    /// Creates a fetch request for the `Movie` entity.
    /// - Returns: A `NSFetchRequest<Movie>` to fetch `Movie` objects.
    @nonobjc public class func fetchRequest() -> NSFetchRequest<Movie> {
        return NSFetchRequest<Movie>(entityName: "Movie")
    }

    /// The URL of the movie's poster image.
    @NSManaged public var posterURL: String?
    /// The content rating of the movie (e.g., "PG-13", "R").
    @NSManaged public var rating: String?
    /// The release date of the movie.
    @NSManaged public var releaseDate: Date?
    /// A short summary or description of the movie.
    @NSManaged public var summary: String?
    /// Comma-separated genre list for the movie.
    @NSManaged public var genres: String?
    /// The URL of the video stream for this movie.
    @NSManaged public var streamURL: String?
    /// The URL of a preview or trailer clip for hover playback.
    @NSManaged public var previewURL: String?
    /// The title of the movie.
    @NSManaged public var title: String?
    /// The IMDb ID of the movie (e.g., "tt1234567").
    @NSManaged public var imdbID: String?
    /// A stable UUID string for cross-table references and FTS mapping.
    @NSManaged public var stableID: String?
    /// The unique identifier of the source this movie came from.
    @NSManaged public var sourceID: UUID?
    /// The `WatchHistory` object if the movie has been watched.
    @NSManaged public var watchHistory: WatchHistory?
    /// The `Favorite` object if the movie is marked as a favorite.
    @NSManaged public var favorite: Favorite?
    /// The set of credits (cast/crew) for this movie.
    @NSManaged public var credits: NSSet?
    /// Stored release year backing value (NSNumber to allow nil).
    @NSManaged private var releaseYearValue: NSNumber?

    /// The release year extracted or provided independently of full release date.
    public var releaseYear: Int? {
        get { releaseYearValue?.intValue }
        set { releaseYearValue = newValue.map { NSNumber(value: $0) } }
    }

}
