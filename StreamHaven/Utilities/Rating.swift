import Foundation

/// An enumeration of the possible content ratings.
public enum Rating: String, Comparable, CaseIterable {
    /// G - General Audiences.
    case g = "G"
    /// PG - Parental Guidance Suggested.
    case pg = "PG"
    /// PG-13 - Parents Strongly Cautioned.
    case pg13 = "PG-13"
    /// R - Restricted.
    case r = "R"
    /// NC-17 - Adults Only.
    case nc17 = "NC-17"
    /// Unrated.
    case unrated = "Unrated"

    private var order: Int {
        switch self {
        case .g: return 1
        case .pg: return 2
        case .pg13: return 3
        case .r: return 4
        case .nc17: return 5
        case .unrated: return 0
        }
    }

    public static func < (lhs: Rating, rhs: Rating) -> Bool {
        return lhs.order < rhs.order
    }
}
