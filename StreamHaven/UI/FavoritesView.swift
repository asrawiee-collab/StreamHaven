import SwiftUI
import CoreData

struct FavoritesView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @ObservedObject var profileManager: ProfileManager

    @FetchRequest var favorites: FetchedResults<Favorite>

    init(profileManager: ProfileManager) {
        self.profileManager = profileManager

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
        NavigationView {
            ScrollView {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 150))]) {
                    ForEach(favorites) { favorite in
                        if let movie = favorite.movie {
                            NavigationLink(destination: MovieDetailView(movie: movie)) {
                                CardView(url: URL(string: movie.posterURL ?? ""), title: movie.title ?? "No Title")
                            }
                            .buttonStyle(PlainButtonStyle())
                        } else if let series = favorite.series {
                            NavigationLink(destination: SeriesDetailView(series: series)) {
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
            .navigationTitle(NSLocalizedString("Favorites", comment: "Favorites view navigation title"))
        }
    }
}
