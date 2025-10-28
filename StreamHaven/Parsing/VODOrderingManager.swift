import Foundation
import CoreData

/// A utility class for ordering Video on Demand (VOD) content.
public final class VODOrderingManager {

    /// An enumeration of the available sort orders for VOD content.
    public enum SortOrder {
        /// Sorts by release date.
        case releaseDate
        /// Sorts chronologically.
        case chronological
        /// Sorts alphabetically.
        case alphabetical
        /// Sorts by popularity.
        case popularity
        /// Sorts by rating.
        case rating
    }

    /// Orders an array of movies based on the specified sort order.
    ///
    /// - Parameters:
    ///   - movies: An array of `Movie` objects to order.
    ///   - order: The `SortOrder` to use for ordering. Defaults to `.releaseDate`.
    /// - Returns: A new array of `Movie` objects sorted according to the specified order.
    public static func orderMovies(movies: [Movie], by order: SortOrder = .releaseDate) -> [Movie] {
        switch order {
        case .releaseDate:
            return movies.sorted { ($0.releaseDate ?? .distantPast) > ($1.releaseDate ?? .distantPast) }
        case .chronological:
            return movies.sorted { ($0.releaseDate ?? .distantFuture) < ($1.releaseDate ?? .distantFuture) }
        case .alphabetical:
            return movies.sorted { ($0.title ?? "") < ($1.title ?? "") }
        case .popularity:
            // Assuming popularity is based on rating, descending
            return movies.sorted { (Rating(rawValue: $0.rating ?? "") ?? .unrated) > (Rating(rawValue: $1.rating ?? "") ?? .unrated) }
        case .rating:
            // Sort by rating, ascending
            return movies.sorted { (Rating(rawValue: $0.rating ?? "") ?? .unrated) < (Rating(rawValue: $1.rating ?? "") ?? .unrated) }
        }
    }
}