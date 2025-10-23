import Foundation
import CoreData

class VODOrderingManager {

    enum SortOrder {
        case releaseDate, chronological, alphabetical
    }

    static func orderMovies(movies: [Movie], by order: SortOrder = .releaseDate) -> [Movie] {
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
