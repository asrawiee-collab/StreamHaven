import Foundation
import CoreData

/// A utility class for ordering Video on Demand (VOD) content.
public class VODOrderingManager {

    /// An enumeration of the available sort orders for VOD content.
    public enum SortOrder {
        /// Sorts by release date.
        case releaseDate
        /// Sorts chronologically.
        case chronological
        /// Sorts alphabetically.
        case alphabetical
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
            return movies.sorted {
                guard let date1 = $0.releaseDate else { return false }
                guard let date2 = $1.releaseDate else { return true }
                return date1 < date2
            }
        case .chronological:
            return movies.sorted {
                guard let date1 = $0.releaseDate else { return false }
                guard let date2 = $1.releaseDate else { return true }
                return date1 < date2
            }
        case .alphabetical:
            return movies.sorted {
                guard let title1 = $0.title else { return false }
                guard let title2 = $1.title else { return true }
                return title1.localizedCaseInsensitiveCompare(title2) == .orderedAscending
            }
        }
    }
}
