import Foundation

enum Rating: String, Comparable, CaseIterable {
    case g = "G"
    case pg = "PG"
    case pg13 = "PG-13"
    case r = "R"
    case nc17 = "NC-17"
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

    static func < (lhs: Rating, rhs: Rating) -> Bool {
        return lhs.order < rhs.order
    }
}
