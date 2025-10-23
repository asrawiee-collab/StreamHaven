import SwiftUI

enum Destination: Hashable {
    case movieDetail(Movie)
    case seriesDetail(Series)

    // Conformance to Hashable for NavigationPath
    func hash(into hasher: inout Hasher) {
        switch self {
        case .movieDetail(let movie):
            hasher.combine("movie")
            hasher.combine(movie.objectID)
        case .seriesDetail(let series):
            hasher.combine("series")
            hasher.combine(series.objectID)
        }
    }

    static func == (lhs: Destination, rhs: Destination) -> Bool {
        switch (lhs, rhs) {
        case (.movieDetail(let lhsMovie), .movieDetail(let rhsMovie)):
            return lhsMovie.objectID == rhsMovie.objectID
        case (.seriesDetail(let lhsSeries), .seriesDetail(let rhsSeries)):
            return lhsSeries.objectID == rhsSeries.objectID
        default:
            return false
        }
    }
}

@MainActor
class NavigationCoordinator: ObservableObject {
    @Published var path = NavigationPath()

    func goTo(_ destination: Destination) {
        path.append(destination)
    }

    func pop() {
        path.removeLast()
    }

    func popToRoot() {
        path.removeLast(path.count)
    }
}
