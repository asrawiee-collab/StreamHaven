import Foundation
import CoreData

/// Represents a movie in the application.
/// This class is a Core Data managed object.
@objc(Movie)
public class Movie: NSManagedObject {

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
    /// The URL of the video stream for this movie.
    @NSManaged public var streamURL: String?
    /// The title of the movie.
    @NSManaged public var title: String?
    /// The IMDb ID of the movie (e.g., "tt1234567").
    @NSManaged public var imdbID: String?
    /// The unique identifier of the source this movie came from.
    @NSManaged public var sourceID: UUID?
    /// The `WatchHistory` object if the movie has been watched.
    @NSManaged public var watchHistory: WatchHistory?
    /// The `Favorite` object if the movie is marked as a favorite.
    @NSManaged public var favorite: Favorite?

}
