import SwiftUI
import CoreData
import Combine

/// A view for searching for movies, series, and channels.
public struct SearchView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @State private var searchQuery: String = ""
    @State private var searchResults: [NSManagedObject] = []
    @State private var selectedGenres: Set<String> = []
    @State private var selectedYearRange: YearRange = .all
    @State private var selectedRatings: Set<String> = []
    @State private var showingFilters: Bool = false
    @EnvironmentObject private var navigationCoordinator: NavigationCoordinator
    @EnvironmentObject var settingsManager: SettingsManager
    @EnvironmentObject var profileManager: ProfileManager
    
    private let persistenceProvider: PersistenceProviding

    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    /// A closure that is called when an item is selected.
    public var onItemSelected: ((Destination) -> Void)? = nil

    private let searchPublisher = PassthroughSubject<String, Never>()

    /// Initializes a new `SearchView`.
    /// - Parameters:
    ///   - persistenceProvider: The persistence provider for Core Data operations.
    ///   - onItemSelected: A closure that is called when an item is selected.
    public init(persistenceProvider: PersistenceProviding, onItemSelected: ((Destination) -> Void)? = nil) {
        self.persistenceProvider = persistenceProvider
        self.onItemSelected = onItemSelected
    }

    /// The body of the view.
    public var body: some View {
        VStack {
            SearchBar(text: $searchQuery, onSearchChanged: { query in
                self.searchPublisher.send(query)
            })
            
            // Filter Chips
            if !selectedGenres.isEmpty || selectedYearRange != .all || !selectedRatings.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(Array(selectedGenres), id: \.self) { genre in
                            FilterChip(label: genre) {
                                selectedGenres.remove(genre)
                                applyFilters()
                            }
                        }
                        
                        if selectedYearRange != .all {
                            FilterChip(label: selectedYearRange.displayName) {
                                selectedYearRange = .all
                                applyFilters()
                            }
                        }
                        
                        ForEach(Array(selectedRatings), id: \.self) { rating in
                            FilterChip(label: rating) {
                                selectedRatings.remove(rating)
                                applyFilters()
                            }
                        }
                    }
                    .padding(.horizontal)
                }
                .frame(height: 40)
            }
            
            // Filter Button
            Button(action: { showingFilters.toggle() }) {
                HStack {
                    Image(systemName: "line.3.horizontal.decrease.circle")
                    Text("Filters")
                }
                .padding(.horizontal)
            }

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
        .sheet(isPresented: $showingFilters) {
            FilterSheet(selectedGenres: $selectedGenres, selectedYearRange: $selectedYearRange, selectedRatings: $selectedRatings, onApply: {
                showingFilters = false
                applyFilters()
            })
        }
        .onReceive(searchPublisher.debounce(for: .milliseconds(500), scheduler: DispatchQueue.main)) { query in
            performSearch(query: query)
        }
    }
    
    /// Year range options for filtering
    enum YearRange: String, CaseIterable {
        case all = "All"
        case recent = "2020-2024"
        case tens = "2010-2019"
        case noughties = "2000-2009"
        case nineties = "1990-1999"
        case classic = "Before 1990"
        
        var displayName: String { self.rawValue }
        
        func matches(year: Int?) -> Bool {
            guard let year = year else { return self == .all }
            switch self {
            case .all: return true
            case .recent: return year >= 2020 && year <= 2024
            case .tens: return year >= 2010 && year <= 2019
            case .noughties: return year >= 2000 && year <= 2009
            case .nineties: return year >= 1990 && year <= 1999
            case .classic: return year < 1990
            }
        }
    }

    /// Applies filters to current search results
    private func applyFilters() {
        performSearch(query: searchQuery)
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
            SearchIndexSync.search(query: query, persistence: persistenceProvider) { results in
                let filtered = self.filterAdultContent(results: results)
                self.searchResults = self.applyAdvancedFilters(to: filtered)
            }
        }
    }
    
    /// Applies advanced filters (genre, year, rating) to search results
    private func applyAdvancedFilters(to results: [NSManagedObject]) -> [NSManagedObject] {
        return results.filter { item in
            // Genre filter
            if !selectedGenres.isEmpty {
                var itemGenres: [String] = []
                if let movie = item as? Movie {
                    itemGenres = movie.genres?.components(separatedBy: ",").map { $0.trimmingCharacters(in: .whitespaces) } ?? []
                } else if let series = item as? Series {
                    itemGenres = series.genres?.components(separatedBy: ",").map { $0.trimmingCharacters(in: .whitespaces) } ?? []
                } else {
                    return true // Channels not filtered by genre
                }
                
                if !itemGenres.contains(where: { selectedGenres.contains($0) }) {
                    return false
                }
            }
            
            // Year filter
            if selectedYearRange != .all {
                var itemYear: Int?
                if let movie = item as? Movie {
                    itemYear = movie.releaseYear
                } else if let series = item as? Series {
                    itemYear = series.releaseYear
                } else {
                    return true // Channels not filtered by year
                }
                
                if !selectedYearRange.matches(year: itemYear) {
                    return false
                }
            }
            
            // Rating filter
            if !selectedRatings.isEmpty {
                var itemRating: String?
                if let movie = item as? Movie {
                    itemRating = movie.rating
                } else if let series = item as? Series {
                    itemRating = series.rating
                } else {
                    return true // Channels not filtered by rating
                }
                
                if !selectedRatings.contains(itemRating ?? Rating.unrated.rawValue) {
                    return false
                }
            }
            
            return true
        }
    }
    
    /// Filters adult content from search results based on profile and settings.
    /// - Parameter results: The unfiltered search results.
    /// - Returns: The filtered search results.
    private func filterAdultContent(results: [NSManagedObject]) -> [NSManagedObject] {
        guard let profile = profileManager.currentProfile else { return results }
        
        // Kids profiles: Filter to G, PG, PG-13, Unrated only
        if !profile.isAdult {
            let allowedRatings = [Rating.g.rawValue, Rating.pg.rawValue, Rating.pg13.rawValue, Rating.unrated.rawValue]
            return results.filter { item in
                if let movie = item as? Movie {
                    return allowedRatings.contains(movie.rating ?? Rating.unrated.rawValue)
                } else if let series = item as? Series {
                    return allowedRatings.contains(series.rating ?? Rating.unrated.rawValue)
                }
                return true // Channels not filtered
            }
        }
        // Adult profiles: Optionally filter NC-17 if hideAdultContent is enabled
        else if settingsManager.hideAdultContent {
            let safeRatings = [Rating.g.rawValue, Rating.pg.rawValue, Rating.pg13.rawValue, Rating.r.rawValue, Rating.unrated.rawValue]
            return results.filter { item in
                if let movie = item as? Movie {
                    return safeRatings.contains(movie.rating ?? Rating.unrated.rawValue)
                } else if let series = item as? Series {
                    return safeRatings.contains(series.rating ?? Rating.unrated.rawValue)
                }
                return true // Channels not filtered
            }
        }
        
        return results // No filtering for adult profiles without hideAdultContent
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

/// A filter chip that displays a selected filter and allows removal
struct FilterChip: View {
    let label: String
    let onRemove: () -> Void
    
    var body: some View {
        HStack(spacing: 4) {
            Text(label)
                .font(.caption)
            Button(action: onRemove) {
                Image(systemName: "xmark.circle.fill")
                    .font(.caption)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color.blue.opacity(0.2))
        .foregroundColor(.blue)
        .cornerRadius(8)
    }
}

/// A sheet view for selecting filters
struct FilterSheet: View {
    @Binding var selectedGenres: Set<String>
    @Binding var selectedYearRange: SearchView.YearRange
    @Binding var selectedRatings: Set<String>
    let onApply: () -> Void
    
    @Environment(\.dismiss) private var dismiss
    
    // Common genres
    private let availableGenres = ["Action", "Adventure", "Animation", "Comedy", "Crime", "Documentary", "Drama", "Family", "Fantasy", "Horror", "Mystery", "Romance", "Sci-Fi", "Thriller", "Western"]
    
    // Available ratings
    private let availableRatings = [Rating.g.rawValue, Rating.pg.rawValue, Rating.pg13.rawValue, Rating.r.rawValue, Rating.nc17.rawValue, Rating.unrated.rawValue]
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Genres")) {
                    ForEach(availableGenres, id: \.self) { genre in
                        Button(action: {
                            if selectedGenres.contains(genre) {
                                selectedGenres.remove(genre)
                            } else {
                                selectedGenres.insert(genre)
                            }
                        }) {
                            HStack {
                                Text(genre)
                                Spacer()
                                if selectedGenres.contains(genre) {
                                    Image(systemName: "checkmark")
                                        .foregroundColor(.blue)
                                }
                            }
                        }
                        .foregroundColor(.primary)
                    }
                }
                
                Section(header: Text("Year")) {
                    Picker("Year Range", selection: $selectedYearRange) {
                        ForEach(SearchView.YearRange.allCases, id: \.self) { range in
                            Text(range.displayName).tag(range)
                        }
                    }
                    .pickerStyle(.inline)
                }
                
                Section(header: Text("Rating")) {
                    ForEach(availableRatings, id: \.self) { rating in
                        Button(action: {
                            if selectedRatings.contains(rating) {
                                selectedRatings.remove(rating)
                            } else {
                                selectedRatings.insert(rating)
                            }
                        }) {
                            HStack {
                                Text(rating)
                                Spacer()
                                if selectedRatings.contains(rating) {
                                    Image(systemName: "checkmark")
                                        .foregroundColor(.blue)
                                }
                            }
                        }
                        .foregroundColor(.primary)
                    }
                }
            }
            .navigationTitle("Filter Results")
            .navigationBarItems(
                leading: Button("Clear All") {
                    selectedGenres.removeAll()
                    selectedYearRange = .all
                    selectedRatings.removeAll()
                },
                trailing: Button("Apply") {
                    onApply()
                }
            )
        }
    }
}
