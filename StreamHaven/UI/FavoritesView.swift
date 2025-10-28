import SwiftUI
import CoreData

#if os(iOS) || os(tvOS)

/// A view that displays the user's favorite movies, series, and channels.
public struct FavoritesView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @ObservedObject var profileManager: ProfileManager
    @EnvironmentObject private var navigationCoordinator: NavigationCoordinator
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    public var onItemSelected: ((Destination) -> Void)? = nil

    @FetchRequest private var favorites: FetchedResults<Favorite>

    public init(profileManager: ProfileManager, onItemSelected: ((Destination) -> Void)? = nil) {
        self.profileManager = profileManager
        self.onItemSelected = onItemSelected

        var predicate = NSPredicate(value: false)
        if let profile = profileManager.currentProfile {
            predicate = NSPredicate(format: "profile == %@", profile)
        }

        _favorites = FetchRequest<Favorite>(
            sortDescriptors: [NSSortDescriptor(keyPath: \Favorite.favoritedDate, ascending: false)],
            predicate: predicate,
            animation: .default
        )
    }

    public var body: some View {
        Group {
            if favorites.isEmpty {
                EmptyStateView(
                    title: NSLocalizedString("No Favorites Yet", comment: "Empty favorites title"),
                    message: NSLocalizedString("Tap the heart icon on any movie or series to add it to your favorites.", comment: "Empty favorites message")
                )
            } else {
                ScrollView {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 150))]) {
                        ForEach(favorites, id: \.objectID) { favorite in
                            favoriteContent(for: favorite)
                        }
                    }
                    .padding()
                }
            }
        }
        .navigationTitle(NSLocalizedString("Favorites", comment: "Favorites title"))
    }

    @ViewBuilder
    private func favoriteContent(for favorite: Favorite) -> some View {
        if let movie = favorite.movie {
            Button(action: { handleSelection(.movieDetail(movie)) }) {
                CardView(url: URL(string: movie.posterURL ?? ""), title: movie.title ?? "No Title")
            }
            .buttonStyle(.plain)
        } else if let series = favorite.series {
            Button(action: { handleSelection(.seriesDetail(series)) }) {
                CardView(url: URL(string: series.posterURL ?? ""), title: series.title ?? "No Title")
            }
            .buttonStyle(.plain)
        } else if let channel = favorite.channel {
            CardView(url: URL(string: channel.logoURL ?? ""), title: channel.name ?? "No Name")
        }
    }

    private func handleSelection(_ destination: Destination) {
        if horizontalSizeClass == .regular {
            onItemSelected?(destination)
        } else {
            navigationCoordinator.goTo(destination)
        }
    }
}

#else

public struct FavoritesView: View {
    @ObservedObject var profileManager: ProfileManager
    public init(profileManager: ProfileManager, onItemSelected: ((Destination) -> Void)? = nil) {
        self.profileManager = profileManager
    }

    public var body: some View {
        Text("Favorites are not available on this platform.")
            .padding()
    }
}

#endif
