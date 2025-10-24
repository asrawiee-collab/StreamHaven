import SwiftUI

#if os(iOS)
/// A view that displays the main UI for iPad, using a `NavigationSplitView`.
public struct iPadContainerView: View {

    /// An enumeration of the possible tabs in the sidebar.
    public enum SidebarTab: String, Hashable {
        /// The home tab.
        case home = "Home"
        /// The favorites tab.
        case favorites = "Favorites"
        /// The search tab.
        case search = "Search"
        /// The settings tab.
        case settings = "Settings"
    }

    @State private var selectedTab: SidebarTab? = .home
    @State private var selectedDetail: Destination?

    /// The `ProfileManager` for managing user profiles.
    @ObservedObject public var profileManager: ProfileManager

    /// The body of the view.
    public var body: some View {
        NavigationSplitView {
            List(selection: $selectedTab) {
                Label(SidebarTab.home.rawValue, systemImage: "house").tag(SidebarTab.home)
                Label(SidebarTab.favorites.rawValue, systemImage: "heart").tag(SidebarTab.favorites)
                Label(SidebarTab.search.rawValue, systemImage: "magnifyingglass").tag(SidebarTab.search)
                Label(SidebarTab.settings.rawValue, systemImage: "gear").tag(SidebarTab.settings)
            }
            .navigationTitle("StreamHaven")
        } content: {
            switch selectedTab {
            case .home:
                HomeView(profileManager: profileManager, onItemSelected: { selectedDetail = $0 })
            case .favorites:
                FavoritesView(profileManager: profileManager, onItemSelected: { selectedDetail = $0 })
            case .search:
                SearchView(onItemSelected: { selectedDetail = $0 })
            case .settings:
                SettingsView()
            case nil:
                Text("Select a category")
            }
        } detail: {
            if let selectedDetail = selectedDetail {
                switch selectedDetail {
                case .movieDetail(let movie):
                    MovieDetailView(movie: movie)
                case .seriesDetail(let series):
                    SeriesDetailView(series: series)
                }
            } else {
                Text("Select an item to view details")
            }
        }
    }
}
#endif
