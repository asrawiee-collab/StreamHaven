import SwiftUI
import CoreData

struct FavoritesView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @ObservedObject var profileManager: ProfileManager
    @EnvironmentObject private var navigationCoordinator: NavigationCoordinator

    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    var onItemSelected: ((Destination) -> Void)? = nil

    @FetchRequest var favorites: FetchedResults<Favorite>

    init(profileManager: ProfileManager, onItemSelected: ((Destination) -> Void)? = nil) {
        self.profileManager = profileManager
        self.onItemSelected = onItemSelected

        var predicate = NSPredicate(value: false)
        if let profile = profileManager.currentProfile {
            predicate = NSPredicate(format: "profile == %@", profile)
        }

        _favorites = FetchRequest<Favorite>(
            sortDescriptors: [NSSortDescriptor(keyPath: \Favorite.favoritedDate, ascending: false)],
            predicate: predicate,
            animation: .default)
    }

    var body: some View {
        Group {
            if favorites.isEmpty {
                EmptyStateView(
                    title: NSLocalizedString("No Favorites Yet", comment: "Empty state title for favorites"),
                    message: NSLocalizedString("Tap the heart icon on any movie or series to add it to your favorites.", comment: "Empty state message for favorites")
                )
            } else {
                ScrollView {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 150))]) {
                        ForEach(favorites) { favorite in
                            if let movie = favorite.movie {
                                Button(action: { handleSelection(.movieDetail(movie)) }) {
                                    CardView(url: URL(string: movie.posterURL ?? ""), title: movie.title ?? "No Title")
                        }
                        .buttonStyle(PlainButtonStyle())
                    } else if let series = favorite.series {
                        Button(action: { handleSelection(.seriesDetail(series)) }) {
                            CardView(url: URL(string: series.posterURL ?? ""), title: series.title ?? "No Title")
                        }
                        .buttonStyle(PlainButtonStyle())
                    } else if let channel = favorite.channel {
                        CardView(url: URL(string: channel.logoURL ?? ""), title: channel.name ?? "No Name")
                    }
                }
            }
            .padding()
        }
    }
}
        .navigationTitle(NSLocalizedString("Favorites", comment: "Favorites view navigation title"))
    }

    private func handleSelection(_ destination: Destination) {
        if horizontalSizeClass == .regular {
            onItemSelected?(destination)
        } else {
            navigationCoordinator.goTo(destination)
        }
    }
}
