import SwiftUI

/// An enumeration of the possible navigation destinations.
public enum Destination: Hashable {
    /// The movie detail view.
    case movieDetail(Movie)
    /// The series detail view.
    case seriesDetail(Series)

    // Conformance to Hashable for NavigationPath
    public func hash(into hasher: inout Hasher) {
        switch self {
        case .movieDetail(let movie):
            hasher.combine("movie")
            hasher.combine(movie.objectID)
        case .seriesDetail(let series):
            hasher.combine("series")
            hasher.combine(series.objectID)
        }
    }

    public static func == (lhs: Destination, rhs: Destination) -> Bool {
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

/// A class for coordinating navigation.
@MainActor
public class NavigationCoordinator: ObservableObject {
    /// The navigation path.
    @Published public var path = NavigationPath()

    /// Navigates to a destination.
    ///
    /// - Parameter destination: The `Destination` to navigate to.
    public func goTo(_ destination: Destination) {
        path.append(destination)
    }

    /// Pops the top view controller from the navigation stack.
    public func pop() {
        path.removeLast()
    }

    /// Pops to the root view controller.
    public func popToRoot() {
        path.removeLast(path.count)
    }
}
