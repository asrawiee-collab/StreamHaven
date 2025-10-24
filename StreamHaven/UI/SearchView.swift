import SwiftUI
import CoreData
import Combine

/// A view for searching for movies, series, and channels.
public struct SearchView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @State private var searchQuery: String = ""
    @State private var searchResults: [NSManagedObject] = []
    @EnvironmentObject private var navigationCoordinator: NavigationCoordinator

    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    /// A closure that is called when an item is selected.
    public var onItemSelected: ((Destination) -> Void)? = nil

    private let searchPublisher = PassthroughSubject<String, Never>()

    /// Initializes a new `SearchView`.
    /// - Parameter onItemSelected: A closure that is called when an item is selected.
    public init(onItemSelected: ((Destination) -> Void)? = nil) {
        self.onItemSelected = onItemSelected
    }

    /// The body of the view.
    public var body: some View {
        VStack {
            SearchBar(text: $searchQuery, onSearchChanged: { query in
                self.searchPublisher.send(query)
            })

            ScrollView {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 150))]) {
                    ForEach(searchResults, id: \.self) { result in
                        if let movie = result as? Movie {
                            Button(action: { handleSelection(.movieDetail(movie)) }) {
                                CardView(url: URL(string: movie.posterURL ?? ""), title: movie.title ?? "No Title")
                            }
                            .buttonStyle(PlainButtonStyle())
                        } else if let series = result as? Series {
                            Button(action: { handleSelection(.seriesDetail(series)) }) {
                                CardView(url: URL(string: series.posterURL ?? ""), title: series.title ?? "No Title")
                            }
                            .buttonStyle(PlainButtonStyle())
                        } else if let channel = result as? Channel {
                            CardView(url: URL(string: channel.logoURL ?? ""), title: channel.name ?? "No Name")
                        }
                    }
                }
                .padding()
            }
        }
        .navigationTitle(NSLocalizedString("Search", comment: "Search view navigation title"))
        .onReceive(searchPublisher.debounce(for: .milliseconds(500), scheduler: DispatchQueue.main)) { query in
            performSearch(query: query)
        }
    }

    /// Handles the selection of an item.
    /// - Parameter destination: The `Destination` to navigate to.
    private func handleSelection(_ destination: Destination) {
        if horizontalSizeClass == .regular {
            onItemSelected?(destination)
        } else {
            navigationCoordinator.goTo(destination)
        }
    }

    /// Performs a search with the given query.
    /// - Parameter query: The search query.
    private func performSearch(query: String) {
        if query.isEmpty {
            searchResults = []
        } else {
            SearchIndexSync.search(query: query, persistence: PersistenceController.shared) { results in
                self.searchResults = results
            }
        }
    }
}

/// A view that displays a search bar.
public struct SearchBar: View {
    /// The text in the search bar.
    @Binding public var text: String
    /// A closure that is called when the search text changes.
    public var onSearchChanged: (String) -> Void

    /// The body of the view.
    public var body: some View {
        HStack {
            TextField(NSLocalizedString("Search for movies, series, or channels", comment: "Search bar placeholder"), text: $text)
                .padding(8)
                .padding(.horizontal, 25)
                .background(Color(.systemGray6))
                .cornerRadius(8)
                .overlay(
                    HStack {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(.gray)
                            .frame(minWidth: 0, maxWidth: .infinity, alignment: .leading)
                            .padding(.leading, 8)
                    }
                )
                .onChange(of: text, perform: onSearchChanged)
        }
        .padding()
    }
}
