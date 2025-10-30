import SwiftUI

/// An enumeration of the possible navigation destinations.
@available(iOS 16, macOS 13, tvOS 16, *)
public enum Destination: Hashable {
    /// The movie detail view.
    case movieDetail(Movie)
    /// The series detail view.
    case seriesDetail(Series)
    /// The actor detail view.
    case actorDetail(Actor)

    // Conformance to Hashable for NavigationPath
    public func hash(into hasher: inout Hasher) {
        switch self {
        case .movieDetail(let movie):
            hasher.combine("movie")
            hasher.combine(movie.objectID)
        case .seriesDetail(let series):
            hasher.combine("series")
            hasher.combine(series.objectID)
        case .actorDetail(let actor):
            hasher.combine("actor")
            hasher.combine(actor.objectID)
        }
    }

    public static func == (lhs: Destination, rhs: Destination) -> Bool {
        switch (lhs, rhs) {
        case (.movieDetail(let lhsMovie), .movieDetail(let rhsMovie)):
            return lhsMovie.objectID == rhsMovie.objectID
        case (.seriesDetail(let lhsSeries), .seriesDetail(let rhsSeries)):
            return lhsSeries.objectID == rhsSeries.objectID
        case (.actorDetail(let lhsActor), .actorDetail(let rhsActor)):
            return lhsActor.objectID == rhsActor.objectID
        default:
            return false
        }
    }
}

/// A class for coordinating navigation.
@MainActor
@available(iOS 16, macOS 13, tvOS 16, *)
public final class NavigationCoordinator: ObservableObject {
    /// The navigation path.
    @Published public var path = NavigationPath()

    /// Navigates to a destination.
    ///
    /// - Parameter destination: The `Destination` to navigate to.
    public func goTo(_ destination: Destination) {
        path.append(destination)
    }

    /// Pushes a destination onto the navigation stack (alias for goTo).
    ///
    /// - Parameter destination: The `Destination` to navigate to.
    public func push(_ destination: Destination) {
        goTo(destination)
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
