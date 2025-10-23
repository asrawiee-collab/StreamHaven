import SwiftUI
import CoreData
import Combine

struct SearchView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @State private var searchQuery: String = ""
    @State private var searchResults: [NSManagedObject] = []

    private let searchPublisher = PassthroughSubject<String, Never>()

    var body: some View {
        NavigationView {
            VStack {
                SearchBar(text: $searchQuery, onSearchChanged: { query in
                    self.searchPublisher.send(query)
                })

                ScrollView {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 150))]) {
                        ForEach(searchResults, id: \.self) { result in
                            if let movie = result as? Movie {
                                NavigationLink(destination: MovieDetailView(movie: movie)) {
                                    CardView(url: URL(string: movie.posterURL ?? ""), title: movie.title ?? "No Title")
                                }
                                .buttonStyle(PlainButtonStyle())
                            } else if let series = result as? Series {
                                NavigationLink(destination: SeriesDetailView(series: series)) {
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
    }

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

struct SearchBar: View {
    @Binding var text: String
    var onSearchChanged: (String) -> Void

    var body: some View {
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
