# Actor Filtering Feature - Implementation Evaluation

## Feature Overview

Add cast/crew information to movie and series detail pages with clickable actor cards that filter content by actor - similar to Apple TV+ and Prime Video.

## Difficulty Assessment

**Overall Difficulty: Medium (3-5 days for experienced developer)**

Gemini's assessment is accurate. This feature aligns well with your existing architecture and TMDb integration.

---

## Current Architecture Analysis

### ✅ What You Already Have

1. **TMDb Integration (`TMDbManager.swift`)**
   - ✅ API key management via Keychain
   - ✅ Rate limiting (4 req/sec, burst 8)
   - ✅ Movie/Series search endpoints
   - ✅ External IDs fetching (IMDb)
   - ✅ Trending/recommendations endpoints
   - ✅ Video/trailer fetching
   - **Missing**: Credits/cast endpoints

2. **Core Data Model**
   - ✅ Movie entity with TMDb integration
   - ✅ Series entity with TMDb integration
   - ✅ Junction table pattern (e.g., WatchHistory, Favorite)
   - **Missing**: Actor entity, Credit junction table

3. **UI Components**
   - ✅ `MovieDetailView` and `SeriesDetailView` with scrollable layouts
   - ✅ `CardView` for grid displays
   - ✅ AsyncImage for remote images
   - ✅ Navigation patterns with `NavigationCoordinator`
   - ✅ Horizontal ScrollView sections (used in HomeView)
   - **Missing**: ActorCardView, ActorDetailView

4. **Search & Filtering**
   - ✅ Full-text search infrastructure (FullTextSearchManager)
   - ✅ Core Data fetch requests with predicates
   - ✅ Local content matching (`findLocalMovie`, `findLocalSeries`)
   - **Missing**: Actor-based filtering logic

---

## Implementation Plan

### Phase 1: Data Model Extension (Low Difficulty - 2-3 hours)

#### 1.1 Create Actor Entity

**Location**: Create `/Users/asrawiee/Desktop/StreamHaven/StreamHaven/Models/Actor+CoreDataClass.swift`

```swift
@objc(Actor)
public class Actor: NSManagedObject {
    @NSManaged public var tmdbID: Int64
    @NSManaged public var name: String?
    @NSManaged public var photoURL: String?
    @NSManaged public var biography: String?
    @NSManaged public var popularity: Double
    @NSManaged public var credits: NSSet?
}
```

#### 1.2 Create Credit Junction Entity

**Location**: Create `/Users/asrawiee/Desktop/StreamHaven/StreamHaven/Models/Credit+CoreDataClass.swift`

```swift
@objc(Credit)
public class Credit: NSManagedObject {
    @NSManaged public var character: String?
    @NSManaged public var order: Int16  // Cast order (0 = main star)
    @NSManaged public var creditType: String?  // "cast" or "crew"
    @NSManaged public var job: String?  // For crew: "Director", "Writer", etc.
    
    // Relationships
    @NSManaged public var actor: Actor?
    @NSManaged public var movie: Movie?
    @NSManaged public var series: Series?
}
```

#### 1.3 Update Existing Entities

**File**: `Movie+CoreDataClass.swift` and `Series+CoreDataClass.swift`

Add relationship:

```swift
@NSManaged public var credits: NSSet?
```

#### 1.4 Update LightweightCoreDataModelBuilder

**File**: `/Users/asrawiee/Desktop/StreamHaven/StreamHaven/Persistence/LightweightCoreDataModelBuilder.swift`

Add Actor and Credit entities to the model builder (follow pattern of existing entities).

**Estimated Time**: 2-3 hours
**Risk**: Low - you have 17 existing entities with this pattern
**Testing**: Update TestCoreDataModelBuilder to include new entities

---

### Phase 2: TMDb API Integration (Medium Difficulty - 3-4 hours)

#### 2.1 Create Data Structures

**File**: `/Users/asrawiee/Desktop/StreamHaven/StreamHaven/Parsing/TMDbManager.swift`

Add after line 72 (after TMDbSeriesListResponse):

```swift
/// A struct representing a cast member from TMDb credits API.
public struct TMDbCastMember: Decodable {
    let id: Int
    let name: String
    let character: String?
    let profilePath: String?
    let order: Int
    
    enum CodingKeys: String, CodingKey {
        case id, name, character, order
        case profilePath = "profile_path"
    }
    
    /// Returns the full photo URL for this actor.
    var photoURL: String? {
        guard let path = profilePath else { return nil }
        return "https://image.tmdb.org/t/p/w185\(path)"
    }
}

/// A struct representing a crew member from TMDb credits API.
public struct TMDbCrewMember: Decodable {
    let id: Int
    let name: String
    let job: String
    let profilePath: String?
    
    enum CodingKeys: String, CodingKey {
        case id, name, job
        case profilePath = "profile_path"
    }
}

/// A struct representing the response from credits API.
public struct TMDbCreditsResponse: Decodable {
    let cast: [TMDbCastMember]
    let crew: [TMDbCrewMember]
}
```

#### 2.2 Add Credits Fetching Methods

**File**: `/Users/asrawiee/Desktop/StreamHaven/StreamHaven/Parsing/TMDbManager.swift`

Add after `fetchSeriesVideos` method (around line 372):

```swift
/// Fetches cast and crew for a movie from TMDb.
/// - Parameters:
///   - movie: The Movie object to fetch credits for.
///   - context: The managed object context.
public func fetchMovieCredits(for movie: Movie, context: NSManagedObjectContext) async {
    guard let apiKey = apiKey, let title = movie.title else { return }
    
    do {
        // 1. Search for the movie to get TMDb ID
        let searchQuery = title.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        let searchURLString = "\(apiBaseURL)/search/movie?api_key=\(apiKey)&query=\(searchQuery)"
        guard let searchURL = URL(string: searchURLString) else { return }
        
        await rateLimiter.acquire()
        let (searchData, _) = try await URLSession.shared.data(from: searchURL)
        let searchResponse = try JSONDecoder().decode(TMDbMovieSearchResponse.self, from: searchData)
        
        guard let tmdbID = searchResponse.results.first?.id else {
            PerformanceLogger.logNetwork("TMDb: Could not find movie \(title)")
            return
        }
        
        // 2. Fetch credits for the movie
        let creditsURLString = "\(apiBaseURL)/movie/\(tmdbID)/credits?api_key=\(apiKey)"
        guard let creditsURL = URL(string: creditsURLString) else { return }
        
        await rateLimiter.acquire()
        let (creditsData, _) = try await URLSession.shared.data(from: creditsURL)
        let creditsResponse = try JSONDecoder().decode(TMDbCreditsResponse.self, from: creditsData)
        
        // 3. Save credits to Core Data
        await saveCredits(creditsResponse, for: movie, context: context)
        
        PerformanceLogger.logNetwork("TMDb: Fetched \(creditsResponse.cast.count) cast members for \(title)")
    } catch {
        PerformanceLogger.logNetwork("TMDb error: Failed to fetch credits for \(title): \(error)")
    }
}

/// Fetches cast and crew for a series from TMDb.
/// - Parameters:
///   - series: The Series object to fetch credits for.
///   - context: The managed object context.
public func fetchSeriesCredits(for series: Series, context: NSManagedObjectContext) async {
    guard let apiKey = apiKey, let title = series.title else { return }
    
    do {
        // 1. Search for the series to get TMDb ID
        let searchQuery = title.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        let searchURLString = "\(apiBaseURL)/search/tv?api_key=\(apiKey)&query=\(searchQuery)"
        guard let searchURL = URL(string: searchURLString) else { return }
        
        await rateLimiter.acquire()
        let (searchData, _) = try await URLSession.shared.data(from: searchURL)
        let searchResponse = try JSONDecoder().decode(TMDbSeriesSearchResponse.self, from: searchData)
        
        guard let tmdbID = searchResponse.results.first?.id else {
            PerformanceLogger.logNetwork("TMDb: Could not find series \(title)")
            return
        }
        
        // 2. Fetch credits for the series
        let creditsURLString = "\(apiBaseURL)/tv/\(tmdbID)/credits?api_key=\(apiKey)"
        guard let creditsURL = URL(string: creditsURLString) else { return }
        
        await rateLimiter.acquire()
        let (creditsData, _) = try await URLSession.shared.data(from: creditsURL)
        let creditsResponse = try JSONDecoder().decode(TMDbCreditsResponse.self, from: creditsData)
        
        // 3. Save credits to Core Data
        await saveCredits(creditsResponse, for: series, context: context)
        
        PerformanceLogger.logNetwork("TMDb: Fetched \(creditsResponse.cast.count) cast members for \(title)")
    } catch {
        PerformanceLogger.logNetwork("TMDb error: Failed to fetch credits for \(title): \(error)")
    }
}

/// Saves credits to Core Data, creating or updating Actor and Credit entities.
private func saveCredits(_ creditsResponse: TMDbCreditsResponse, for content: Any, context: NSManagedObjectContext) async {
    context.perform {
        // Limit to top 10 cast members to avoid cluttering UI
        let topCast = Array(creditsResponse.cast.prefix(10))
        
        for castMember in topCast {
            // Find or create Actor
            let actorFetch: NSFetchRequest<Actor> = Actor.fetchRequest()
            actorFetch.predicate = NSPredicate(format: "tmdbID == %d", castMember.id)
            
            let actor: Actor
            if let existingActor = try? context.fetch(actorFetch).first {
                actor = existingActor
            } else {
                actor = Actor(context: context)
                actor.tmdbID = Int64(castMember.id)
            }
            
            // Update actor info
            actor.name = castMember.name
            actor.photoURL = castMember.photoURL
            
            // Create Credit junction
            let credit = Credit(context: context)
            credit.actor = actor
            credit.character = castMember.character
            credit.order = Int16(castMember.order)
            credit.creditType = "cast"
            
            // Link to content
            if let movie = content as? Movie {
                credit.movie = movie
            } else if let series = content as? Series {
                credit.series = series
            }
        }
        
        try? context.save()
    }
}
```

**Estimated Time**: 3-4 hours
**Risk**: Low - follows existing patterns in TMDbManager
**Testing**: Add tests in `TMDbManagerTests.swift` for credits fetching

---

### Phase 3: UI Implementation (Medium Difficulty - 4-5 hours)

#### 3.1 Create ActorCardView

**Location**: Create `/Users/asrawiee/Desktop/StreamHaven/StreamHaven/UI/ActorCardView.swift`

```swift
import SwiftUI

/// A card view displaying an actor's photo and name.
struct ActorCardView: View {
    let actor: Actor
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 8) {
                AsyncImage(url: URL(string: actor.photoURL ?? "")) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    ZStack {
                        Color.gray.opacity(0.3)
                        Image(systemName: "person.fill")
                            .foregroundColor(.gray)
                            .font(.largeTitle)
                    }
                }
                .frame(width: 100, height: 150)
                .clipShape(RoundedRectangle(cornerRadius: 10))
                
                Text(actor.name ?? "Unknown")
                    .font(.caption)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
                    .frame(width: 100)
            }
        }
        .buttonStyle(.plain)
    }
}
```

#### 3.2 Update MovieDetailView

**File**: `/Users/asrawiee/Desktop/StreamHaven/StreamHaven/UI/MovieDetailView.swift`

Add after line 23 (after @State declarations):

```swift
@State private var cast: [Actor] = []
```

Add in `iosDetailView` after the smart summary section (around line 90):

```swift
// Cast Section
if !cast.isEmpty {
    VStack(alignment: .leading, spacing: 12) {
        Text("Cast")
            .font(.title2)
            .fontWeight(.bold)
            .padding(.horizontal)
        
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 16) {
                ForEach(cast, id: \.tmdbID) { actor in
                    ActorCardView(actor: actor) {
                        navigationCoordinator.push(.actorDetail(actor))
                    }
                }
            }
            .padding(.horizontal)
        }
    }
    .padding(.vertical)
}
```

Add to `onAppear`:

```swift
.onAppear(perform: {
    setup()
    fetchIMDbID()
    generateSmartSummary()
    loadCast()  // Add this line
})
```

Add helper method after `generateSmartSummary()`:

```swift
/// Loads cast members for this movie.
private func loadCast() {
    // Fetch credits if not already loaded
    if let credits = movie.credits as? Set<Credit>, !credits.isEmpty {
        let sortedCredits = credits
            .filter { $0.creditType == "cast" }
            .sorted { $0.order < $1.order }
        cast = sortedCredits.compactMap { $0.actor }
    } else {
        // Fetch from TMDb in background
        Task {
            await tmdbManager.fetchMovieCredits(for: movie, context: viewContext)
            
            // Reload cast after fetch
            if let credits = movie.credits as? Set<Credit> {
                let sortedCredits = credits
                    .filter { $0.creditType == "cast" }
                    .sorted { $0.order < $1.order }
                await MainActor.run {
                    cast = sortedCredits.compactMap { $0.actor }
                }
            }
        }
    }
}
```

#### 3.3 Update SeriesDetailView

**File**: `/Users/asrawiee/Desktop/StreamHaven/StreamHaven/UI/SeriesDetailView.swift`

Apply similar changes as MovieDetailView:

- Add `@State private var cast: [Actor] = []`
- Add cast section in UI
- Add `loadCast()` method
- Call in `onAppear`

#### 3.4 Update NavigationCoordinator

**File**: `/Users/asrawiee/Desktop/StreamHaven/StreamHaven/UI/NavigationCoordinator.swift`

Add new destination (around line 10):

```swift
/// The actor detail view.
case actorDetail(Actor)
```

Update `hash(into:)` method:

```swift
case .actorDetail(let actor):
    hasher.combine("actor")
    hasher.combine(actor.objectID)
```

Update `==` method:

```swift
case (.actorDetail(let lhsActor), .actorDetail(let rhsActor)):
    return lhsActor.objectID == rhsActor.objectID
```

**Estimated Time**: 4-5 hours
**Risk**: Medium - requires careful navigation handling
**Testing**: Manual UI testing on iPhone/iPad/tvOS simulators

---

### Phase 4: Actor Filtering View (Medium Difficulty - 3-4 hours)

#### 4.1 Create ActorDetailView

**Location**: Create `/Users/asrawiee/Desktop/StreamHaven/StreamHaven/UI/ActorDetailView.swift`

```swift
import SwiftUI
import CoreData

/// A view displaying an actor's filmography filtered from local library.
struct ActorDetailView: View {
    let actor: Actor
    
    @Environment(\.managedObjectContext) private var viewContext
    @EnvironmentObject var navigationCoordinator: NavigationCoordinator
    @EnvironmentObject var settingsManager: SettingsManager
    
    @State private var movies: [Movie] = []
    @State private var series: [Series] = []
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Actor Header
                HStack(spacing: 20) {
                    AsyncImage(url: URL(string: actor.photoURL ?? "")) { image in
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    } placeholder: {
                        ZStack {
                            Color.gray.opacity(0.3)
                            Image(systemName: "person.fill")
                                .foregroundColor(.gray)
                                .font(.system(size: 60))
                        }
                    }
                    .frame(width: 150, height: 225)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text(actor.name ?? "Unknown Actor")
                            .font(.largeTitle)
                            .fontWeight(.bold)
                        
                        if let biography = actor.biography, !biography.isEmpty {
                            Text(biography)
                                .font(.body)
                                .lineLimit(5)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .padding()
                
                // Movies Section
                if !movies.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Movies in Your Library")
                            .font(.title2)
                            .fontWeight(.bold)
                            .padding(.horizontal)
                        
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 150))], spacing: 20) {
                            ForEach(movies) { movie in
                                Button(action: {
                                    navigationCoordinator.push(.movieDetail(movie))
                                }) {
                                    CardView(
                                        url: URL(string: movie.posterURL ?? ""),
                                        title: movie.title ?? "No Title"
                                    )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.horizontal)
                    }
                }
                
                // Series Section
                if !series.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Series in Your Library")
                            .font(.title2)
                            .fontWeight(.bold)
                            .padding(.horizontal)
                        
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 150))], spacing: 20) {
                            ForEach(series) { seriesItem in
                                Button(action: {
                                    navigationCoordinator.push(.seriesDetail(seriesItem))
                                }) {
                                    CardView(
                                        url: URL(string: seriesItem.posterURL ?? ""),
                                        title: seriesItem.title ?? "No Title"
                                    )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.horizontal)
                    }
                }
                
                // Empty State
                if movies.isEmpty && series.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "film.stack")
                            .font(.system(size: 60))
                            .foregroundColor(.gray)
                        Text("No content found in your library")
                            .font(.title3)
                            .foregroundColor(.secondary)
                        Text("This actor appears in other titles not currently in your playlists")
                            .font(.body)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 40)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.top, 100)
                }
            }
        }
        .navigationTitle(actor.name ?? "Actor")
        .onAppear {
            loadFilmography()
        }
    }
    
    /// Loads movies and series featuring this actor from local library.
    private func loadFilmography() {
        guard let credits = actor.credits as? Set<Credit> else { return }
        
        // Extract movies
        let movieCredits = credits.compactMap { $0.movie }
        movies = movieCredits.sorted { ($0.title ?? "") < ($1.title ?? "") }
        
        // Extract series
        let seriesCredits = credits.compactMap { $0.series }
        series = seriesCredits.sorted { ($0.title ?? "") < ($1.title ?? "") }
    }
}
```

#### 4.2 Update MainView Navigation

**File**: `/Users/asrawiee/Desktop/StreamHaven/StreamHaven/UI/MainView.swift`

Add to `.navigationDestination` handler (around line 120):

```swift
case .actorDetail(let actor):
    ActorDetailView(actor: actor)
```

**Estimated Time**: 3-4 hours
**Risk**: Low - uses existing patterns
**Testing**: Manual testing with multiple actors

---

### Phase 5: Batch Operations & Performance (Medium Difficulty - 2-3 hours)

#### 5.1 Batch Credits Fetching

**File**: `/Users/asrawiee/Desktop/StreamHaven/StreamHaven/Parsing/TMDbManager.swift`

Add method to batch fetch credits during playlist import:

```swift
/// Batch fetches credits for multiple movies.
/// - Parameters:
///   - movies: Array of movies to fetch credits for.
///   - context: The managed object context.
public func batchFetchMovieCredits(for movies: [Movie], context: NSManagedObjectContext) async {
    // Process in chunks of 10 to respect rate limits
    let chunks = movies.chunked(into: 10)
    
    for chunk in chunks {
        await withTaskGroup(of: Void.self) { group in
            for movie in chunk {
                group.addTask {
                    await self.fetchMovieCredits(for: movie, context: context)
                }
            }
        }
        
        // Pause between chunks to respect rate limits
        try? await Task.sleep(nanoseconds: 3_000_000_000) // 3 seconds
    }
}

/// Batch fetches credits for multiple series.
/// - Parameters:
///   - series: Array of series to fetch credits for.
///   - context: The managed object context.
public func batchFetchSeriesCredits(for series: [Series], context: NSManagedObjectContext) async {
    let chunks = series.chunked(into: 10)
    
    for chunk in chunks {
        await withTaskGroup(of: Void.self) { group in
            for seriesItem in chunk {
                group.addTask {
                    await self.fetchSeriesCredits(for: seriesItem, context: context)
                }
            }
        }
        
        try? await Task.sleep(nanoseconds: 3_000_000_000) // 3 seconds
    }
}
```

Add array extension:

```swift
extension Array {
    func chunked(into size: Int) -> [[Element]] {
        stride(from: 0, to: count, by: size).map {
            Array(self[$0 ..< Swift.min($0 + size, count)])
        }
    }
}
```

#### 5.2 Add Settings Toggle

**File**: `/Users/asrawiee/Desktop/StreamHaven/StreamHaven/User/SettingsManager.swift`

Add:

```swift
@AppStorage("fetchActorInfo") public var fetchActorInfo: Bool = true
```

**File**: `/Users/asrawiee/Desktop/StreamHaven/StreamHaven/UI/SettingsView.swift`

Add in settings list:

```swift
Toggle("Fetch Actor Information", isOn: $settingsManager.fetchActorInfo)
    .help("Automatically fetch cast information from TMDb for movies and series")
```

**Estimated Time**: 2-3 hours
**Risk**: Low - optimization
**Testing**: Performance testing with large libraries

---

## Implementation Timeline

| Phase | Task | Time | Priority | Dependencies |
|-------|------|------|----------|--------------|
| 1 | Data Model Extension | 2-3h | Critical | None |
| 2 | TMDb API Integration | 3-4h | Critical | Phase 1 |
| 3 | UI Implementation | 4-5h | High | Phase 2 |
| 4 | Actor Detail View | 3-4h | High | Phase 3 |
| 5 | Batch Operations | 2-3h | Medium | Phase 2-4 |
| - | Testing & Polish | 2-3h | High | All phases |

**Total Time**: 16-22 hours (2-3 days for experienced developer)

---

## Risks & Mitigations

### Risk 1: Rate Limiting

**Impact**: High
**Mitigation**:

- Already have RateLimiter in place (4 req/sec)
- Batch operations with delays
- Cache credits data (don't re-fetch on every view)

### Risk 2: Large Data Volume

**Impact**: Medium
**Mitigation**:

- Limit to top 10 cast members per content
- Only fetch on-demand (when user opens detail view)
- Add settings toggle to disable feature

### Risk 3: Navigation Complexity

**Impact**: Low
**Mitigation**:

- Use existing NavigationCoordinator pattern
- Test thoroughly on all platforms (iOS/tvOS/macOS)

### Risk 4: Missing Actor Photos

**Impact**: Low
**Mitigation**:

- Use placeholder image (person.fill SF Symbol)
- Handle nil photoURL gracefully

---

## Testing Strategy

### Unit Tests

**File**: Create `/Users/asrawiee/Desktop/StreamHaven/StreamHaven/Tests/ActorFilteringTests.swift`

```swift
import XCTest
import CoreData
@testable import StreamHaven

@MainActor
final class ActorFilteringTests: XCTestCase {
    var container: NSPersistentContainer!
    var context: NSManagedObjectContext!
    var tmdbManager: TMDbManager!
    
    override func setUp() async throws {
        // Use TestCoreDataModelBuilder with Actor/Credit entities
        container = NSPersistentContainer(name: "Test", managedObjectModel: TestCoreDataModelBuilder.sharedModel)
        let description = NSPersistentStoreDescription()
        description.type = NSInMemoryStoreType
        container.persistentStoreDescriptions = [description]
        
        container.loadPersistentStores { _, _ in }
        context = container.viewContext
        tmdbManager = TMDbManager(apiKey: "test_key")
    }
    
    func testActorEntityCreation() {
        let actor = Actor(context: context)
        actor.tmdbID = 123
        actor.name = "Test Actor"
        actor.photoURL = "https://example.com/photo.jpg"
        
        XCTAssertEqual(actor.tmdbID, 123)
        XCTAssertEqual(actor.name, "Test Actor")
    }
    
    func testCreditRelationships() {
        let movie = Movie(context: context)
        movie.title = "Test Movie"
        
        let actor = Actor(context: context)
        actor.name = "Test Actor"
        
        let credit = Credit(context: context)
        credit.actor = actor
        credit.movie = movie
        credit.character = "Hero"
        credit.order = 0
        
        try? context.save()
        
        XCTAssertEqual(movie.credits?.count, 1)
        XCTAssertEqual(actor.credits?.count, 1)
    }
    
    func testActorFilmographyFiltering() {
        let actor = Actor(context: context)
        actor.name = "Test Actor"
        
        // Create 3 movies
        for i in 1...3 {
            let movie = Movie(context: context)
            movie.title = "Movie \(i)"
            
            let credit = Credit(context: context)
            credit.actor = actor
            credit.movie = movie
        }
        
        try? context.save()
        
        let credits = actor.credits as? Set<Credit>
        let movies = credits?.compactMap { $0.movie }
        
        XCTAssertEqual(movies?.count, 3)
    }
}
```

### Integration Tests

- Test TMDb credits API calls with real API key (skip if no key)
- Test navigation flow: Movie Detail → Actor Card → Actor Detail → Back
- Test with multiple actors per movie
- Test empty state (actor not in library)

### UI Tests

**File**: Add to existing UI test files

```swift
func testActorCardNavigation() throws {
    // 1. Open movie detail
    // 2. Scroll to cast section
    // 3. Tap actor card
    // 4. Verify ActorDetailView appears
    // 5. Verify actor name displays
    // 6. Tap movie in filmography
    // 7. Verify returns to correct movie
}
```

---

## Performance Considerations

### Memory

- **Impact**: +10-20MB for typical library
- Actor photos: ~30KB each × 10 actors × 100 movies = ~30MB
- Mitigated by AsyncImage caching

### Database Size

- **Impact**: +5-10% increase
- Actor entity: ~200 bytes × 500 actors = ~100KB
- Credit entity: ~100 bytes × 5000 credits = ~500KB
- Negligible compared to movie/series data

### API Calls

- **Current usage**: ~4 calls per movie/series (search, external_ids, videos, similar)
- **Additional**: +1 call per movie/series for credits
- **Total**: ~5 calls per content item
- Within rate limits with existing RateLimiter

### UI Performance

- Horizontal ScrollView with 10 actors: No performance issues
- Tested pattern already used in HomeView for trending content
- LazyVGrid in ActorDetailView: Efficient for large lists

---

## Future Enhancements

### Phase 2 (Nice to Have)

1. **Actor Biography**
   - Fetch full actor details from TMDb `/person/{id}` endpoint
   - Display in ActorDetailView header

2. **Crew Information**
   - Show directors, writers, producers
   - Separate section in detail view

3. **Actor Search**
   - Add actor name to FTS index
   - Search by actor name in SearchView

4. **Popular Actors**
   - Show "Top Actors in Your Library" section on HomeView
   - Sort by number of titles in library

5. **Actor Recommendations**
   - "Because you watched movies with [Actor]..."
   - Use TMDb's similar content API

### Phase 3 (Advanced)

1. **Collaborative Filtering**
   - "People who liked [Actor] also liked..."
   - Requires user interaction tracking

2. **Actor Trending**
   - TMDb trending persons API
   - Highlight actors with new releases

3. **tvOS Enhancements**
   - Hover previews on actor cards
   - Focus engine optimization

---

## Comparison with Existing Features

### Similar Complexity to

1. **Trending/Recommendations** (Already Implemented)
   - TMDb API integration: ✓
   - New data structures: ✓
   - UI components: ✓
   - Difficulty: Medium ✓

2. **Franchise Grouping** (Already Implemented)
   - Core Data relationships: ✓
   - UI filtering: ✓
   - Performance optimization: ✓

### Easier Than

1. **Full-Text Search** (Already Implemented)
   - Requires SQLite FTS5 virtual tables
   - Complex database migrations
   - Advanced query parsing

2. **Multi-Source Management** (Already Implemented)
   - Complex data deduplication
   - Source metadata tracking
   - Conflict resolution

---

## Conclusion

### Feasibility: ✅ HIGH

This feature is highly feasible because:

1. ✅ **Architecture Support**: Your app already has all the foundational pieces
2. ✅ **Pattern Consistency**: Follows existing patterns (TMDb integration, Core Data relationships, navigation)
3. ✅ **Low Risk**: No major refactoring required
4. ✅ **Incremental**: Can be implemented in phases
5. ✅ **Well-Defined API**: TMDb credits endpoint is stable and well-documented

### Recommended Approach

1. **Start Small**: Implement phases 1-3 first (data model + basic UI)
2. **Test Early**: Validate Core Data model changes before proceeding
3. **User Feedback**: Ship basic version, gather feedback before advanced features
4. **Performance Monitor**: Track API usage and database size growth

### Estimated Effort

- **Minimum Viable Feature**: 12-16 hours (Phases 1-3)
- **Full Implementation**: 20-25 hours (All phases + testing)
- **With Polish**: 25-30 hours (Include Phase 2 enhancements)

### Success Criteria

- ✅ Cast displayed on 100% of detail views
- ✅ Actor navigation works on all platforms
- ✅ No performance degradation
- ✅ 95%+ test coverage for new code
- ✅ API rate limits respected
- ✅ Graceful handling of missing data

---

## Next Steps

1. **Review this evaluation** with your team
2. **Prioritize phases** based on user needs
3. **Update Core Data model** (Phase 1)
4. **Create feature branch**: `feature/actor-filtering`
5. **Implement incrementally** with frequent commits
6. **Test on all platforms** (iOS, tvOS, macOS if applicable)
7. **Update TEST_COVERAGE_IMPROVEMENT_PLAN.md** with actor filtering tests

**Questions? Issues? Refer back to this document for guidance.**
