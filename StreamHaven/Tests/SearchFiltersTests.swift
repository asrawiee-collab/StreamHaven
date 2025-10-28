//
//  SearchFiltersTests.swift
//  StreamHaven
//
//  Tests for search filter functionality
//

import XCTest
import CoreData
@testable import StreamHaven

#if os(iOS) || os(tvOS)
private typealias SearchYearRange = SearchView.YearRange
#else
private enum SearchYearRange: String, CaseIterable {
    case all = "All"
    case recent = "2020-2024"
    case tens = "2010-2019"
    case noughties = "2000-2009"
    case nineties = "1990-1999"
    case classic = "Before 1990"

    func matches(year: Int?) -> Bool {
        guard let year else { return self == .all }
        switch self {
        case .all:
            return true
        case .recent:
            return year >= 2020 && year <= 2024
        case .tens:
            return year >= 2010 && year <= 2019
        case .noughties:
            return year >= 2000 && year <= 2009
        case .nineties:
            return year >= 1990 && year <= 1999
        case .classic:
            return year < 1990
        }
    }
}
#endif
@MainActor
final class SearchFiltersTests: XCTestCase {
    private var container: NSPersistentContainer!
    var context: NSManagedObjectContext!
    var testMovies: [Movie] = []
    var testSeries: [Series] = []

    override func setUp() async throws {
        try await super.setUp()

        guard let model = Self.loadManagedObjectModel() else {
            XCTFail("Unable to load Core Data model for SearchFiltersTests")
            return
        }

        container = NSPersistentContainer(name: "StreamHaven", managedObjectModel: model)

        let description = NSPersistentStoreDescription()
        description.type = NSInMemoryStoreType
        container.persistentStoreDescriptions = [description]

        var loadError: Error?
        container.loadPersistentStores { _, error in
            loadError = error
        }

        if let loadError {
            XCTFail("Failed to load in-memory store: \(loadError)")
            return
        }

        context = container.viewContext
        seedSampleContent()
    }

    override func tearDown() async throws {
        testMovies.removeAll()
        testSeries.removeAll()
        context = nil
        container = nil
        try await super.tearDown()
    }

    private static func loadManagedObjectModel() -> NSManagedObjectModel? {
#if SWIFT_PACKAGE
        let primaryBundle = Bundle(for: Movie.self)
#else
        let primaryBundle = Bundle(for: Movie.self)
#endif
        let candidateBundles = [primaryBundle] + Bundle.allBundles + Bundle.allFrameworks
        for candidate in candidateBundles {
            if let url = candidate.url(forResource: "StreamHaven", withExtension: "momd") ??
                candidate.url(forResource: "StreamHaven", withExtension: "mom") {
                if let model = NSManagedObjectModel(contentsOf: url) {
                    Self.patchManagedObjectClasses(in: model)
#if DEBUG
                    let entitySummaries = model.entities.map { entity in
                        "\(entity.name ?? "<nil>") -> \(entity.managedObjectClassName ?? "<nil>")"
                    }.joined(separator: ", ")
                    print("SearchFiltersTests loaded entities from \(candidate.bundlePath): \(entitySummaries)")
#endif
                    return model
                }
            }
        }

        if let merged = NSManagedObjectModel.mergedModel(from: candidateBundles) {
            Self.patchManagedObjectClasses(in: merged)
#if DEBUG
            let entitySummaries = merged.entities.map { entity in
                "\(entity.name ?? "<nil>") -> \(entity.managedObjectClassName ?? "<nil>")"
            }.joined(separator: ", ")
            print("SearchFiltersTests loaded merged entities: \(entitySummaries)")
#endif
            return merged
        }

        return nil
    }

    private static func patchManagedObjectClasses(in model: NSManagedObjectModel) {
        for entity in model.entities {
            guard let mappedClass = entityClassMap[entity.name ?? ""] else { continue }
            entity.managedObjectClassName = NSStringFromClass(mappedClass)
        }
    }

    private static let entityClassMap: [String: NSManagedObject.Type] = [
        "Movie": Movie.self,
        "Series": Series.self,
        "Season": Season.self,
        "Episode": Episode.self,
        "Channel": Channel.self,
        "ChannelVariant": ChannelVariant.self,
        "Profile": Profile.self,
        "WatchHistory": WatchHistory.self,
        "Favorite": Favorite.self,
        "StreamCache": StreamCache.self,
        "PlaylistCache": PlaylistCache.self,
        "PlaylistSource": PlaylistSource.self,
        "Download": Download.self,
        "UpNextQueueItem": UpNextQueueItem.self,
        "Watchlist": Watchlist.self,
        "WatchlistItem": WatchlistItem.self,
        "EPGEntry": EPGEntry.self
    ]

    private func seedSampleContent() {
        testMovies = [
            makeMovie(
                title: "Action Movie",
                genres: ["Action", "Adventure"],
                rating: .pg13,
                releaseYear: 2022
            ),
            makeMovie(
                title: "Comedy Movie",
                genres: ["Comedy"],
                rating: .r,
                releaseYear: 2015
            ),
            makeMovie(
                title: "Horror Movie",
                genres: ["Horror"],
                rating: .nc17,
                releaseYear: 2021
            ),
            makeMovie(
                title: "Classic Movie",
                genres: ["Drama"],
                rating: .pg,
                releaseYear: 1985
            ),
            makeMovie(
                title: "Family Movie",
                genres: ["Family"],
                rating: .pg,
                releaseYear: 2004
            )
        ]

        testSeries = [
            makeSeries(
                title: "Sci-Fi Saga",
                genres: ["Sci-Fi", "Adventure"],
                rating: .pg13,
                releaseYear: 2021
            ),
            makeSeries(
                title: "Classic Sitcom",
                genres: ["Comedy"],
                rating: .pg,
                releaseYear: 1994
            )
        ]

        do {
            try context.save()
        } catch {
            XCTFail("Failed to seed sample content: \(error)")
        }
    }

    private func makeMovie(title: String, genres: [String], rating: Rating, releaseYear: Int) -> Movie {
        let movie = Movie(context: context)
        movie.title = title
        movie.genres = genres.joined(separator: ", ")
        movie.rating = rating.rawValue
        movie.releaseYear = releaseYear
        movie.releaseDate = Calendar.current.date(from: DateComponents(year: releaseYear, month: 1, day: 1))
        movie.streamURL = "https://example.com/\(title).m3u8"
        return movie
    }

    private func makeSeries(title: String, genres: [String], rating: Rating, releaseYear: Int) -> Series {
        let series = Series(context: context)
        series.title = title
        series.genres = genres.joined(separator: ", ")
        series.rating = rating.rawValue
        series.releaseYear = releaseYear
        series.releaseDate = Calendar.current.date(from: DateComponents(year: releaseYear, month: 1, day: 1))
        return series
    }

    private func genres(for movie: Movie) -> [String] {
        movie.genres?
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespaces) } ?? []
    }

    private func genres(for series: Series) -> [String] {
        series.genres?
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespaces) } ?? []
    }

    // MARK: - Year Range Tests

    func testYearRangeRecent() {
        let yearRange = SearchYearRange.recent

        XCTAssertTrue(yearRange.matches(year: 2022))
        XCTAssertTrue(yearRange.matches(year: 2020))
        XCTAssertTrue(yearRange.matches(year: 2024))
        XCTAssertFalse(yearRange.matches(year: 2019))
        XCTAssertFalse(yearRange.matches(year: 2025))
    }

    func testYearRangeTens() {
        let yearRange = SearchYearRange.tens

        XCTAssertTrue(yearRange.matches(year: 2015))
        XCTAssertTrue(yearRange.matches(year: 2010))
        XCTAssertTrue(yearRange.matches(year: 2019))
        XCTAssertFalse(yearRange.matches(year: 2009))
        XCTAssertFalse(yearRange.matches(year: 2020))
    }

    func testYearRangeNoughties() {
        let yearRange = SearchYearRange.noughties

        XCTAssertTrue(yearRange.matches(year: 2005))
        XCTAssertTrue(yearRange.matches(year: 2000))
        XCTAssertTrue(yearRange.matches(year: 2009))
        XCTAssertFalse(yearRange.matches(year: 1999))
        XCTAssertFalse(yearRange.matches(year: 2010))
    }

    func testYearRangeNineties() {
        let yearRange = SearchYearRange.nineties

        XCTAssertTrue(yearRange.matches(year: 1995))
        XCTAssertTrue(yearRange.matches(year: 1990))
        XCTAssertTrue(yearRange.matches(year: 1999))
        XCTAssertFalse(yearRange.matches(year: 1989))
        XCTAssertFalse(yearRange.matches(year: 2000))
    }

    func testYearRangeClassic() {
        let yearRange = SearchYearRange.classic

        XCTAssertTrue(yearRange.matches(year: 1985))
        XCTAssertTrue(yearRange.matches(year: 1950))
        XCTAssertTrue(yearRange.matches(year: 1989))
        XCTAssertFalse(yearRange.matches(year: 1990))
        XCTAssertFalse(yearRange.matches(year: 2000))
    }

    func testYearRangeAll() {
        let yearRange = SearchYearRange.all

        XCTAssertTrue(yearRange.matches(year: 1950))
        XCTAssertTrue(yearRange.matches(year: 2024))
        XCTAssertTrue(yearRange.matches(year: nil))
    }

    // MARK: - Genre Filter Tests

    func testGenreFilterSingleGenre() {
        let actionMovies = testMovies.filter { genres(for: $0).contains("Action") }

        XCTAssertEqual(actionMovies.count, 1)
        XCTAssertEqual(actionMovies.first?.title, "Action Movie")
    }

    func testGenreFilterMultipleGenres() {
        let selectedGenres: Set<String> = ["Comedy", "Drama"]
        let filteredMovies = testMovies.filter { movie in
            genres(for: movie).contains { selectedGenres.contains($0) }
        }

        XCTAssertEqual(filteredMovies.count, 2)
        XCTAssertEqual(Set(filteredMovies.map { $0.title ?? "" }), ["Comedy Movie", "Classic Movie"])
    }

    func testGenreFilterNoMatches() {
        let westernMovies = testMovies.filter { genres(for: $0).contains("Western") }

        XCTAssertEqual(westernMovies.count, 0)
    }

    // MARK: - Rating Filter Tests

    func testRatingFilterSingleRating() {
        let pg13Movies = testMovies.filter { $0.rating == Rating.pg13.rawValue }

        XCTAssertEqual(pg13Movies.count, 1)
        XCTAssertEqual(pg13Movies.first?.title, "Action Movie")
    }

    func testRatingFilterMultipleRatings() {
        let selectedRatings: Set<String> = [Rating.r.rawValue, Rating.nc17.rawValue]
        let filteredMovies = testMovies.filter { movie in
            selectedRatings.contains(movie.rating ?? Rating.unrated.rawValue)
        }

        XCTAssertEqual(filteredMovies.count, 2)
        XCTAssertEqual(Set(filteredMovies.compactMap { $0.title }), ["Comedy Movie", "Horror Movie"])
    }

    // MARK: - Combined Filter Tests

    func testCombinedFiltersYearAndGenre() {
        let yearRange = SearchYearRange.tens
        let selectedGenres: Set<String> = ["Comedy"]

        let filteredMovies = testMovies.filter { movie in
            let matchesGenre = genres(for: movie).contains { selectedGenres.contains($0) }
            let matchesYear = yearRange.matches(year: movie.releaseYear)
            return matchesGenre && matchesYear
        }

        XCTAssertEqual(filteredMovies.count, 1)
        XCTAssertEqual(filteredMovies.first?.title, "Comedy Movie")
    }

    func testCombinedFiltersAllThreeTypes() {
        let yearRange = SearchYearRange.recent
        let selectedGenres: Set<String> = ["Action"]
        let selectedRatings: Set<String> = [Rating.pg13.rawValue]

        let filteredMovies = testMovies.filter { movie in
            let matchesGenre = genres(for: movie).contains { selectedGenres.contains($0) }
            let matchesYear = yearRange.matches(year: movie.releaseYear)
            let matchesRating = selectedRatings.contains(movie.rating ?? Rating.unrated.rawValue)
            return matchesGenre && matchesYear && matchesRating
        }

        XCTAssertEqual(filteredMovies.count, 1)
        XCTAssertEqual(filteredMovies.first?.title, "Action Movie")
    }

    func testCombinedFiltersNoMatches() {
        let yearRange = SearchYearRange.nineties
        let selectedGenres: Set<String> = ["Horror"]
        let selectedRatings: Set<String> = [Rating.pg.rawValue]

        let filteredMovies = testMovies.filter { movie in
            let matchesGenre = genres(for: movie).contains { selectedGenres.contains($0) }
            let matchesYear = yearRange.matches(year: movie.releaseYear)
            let matchesRating = selectedRatings.contains(movie.rating ?? Rating.unrated.rawValue)
            return matchesGenre && matchesYear && matchesRating
        }

        XCTAssertEqual(filteredMovies.count, 0)
    }

    // MARK: - Series Filter Tests

    func testSeriesFilteringMatchesGenreAndYear() {
        let yearRange = SearchYearRange.recent
        let selectedGenres: Set<String> = ["Sci-Fi"]

        let filteredSeries = testSeries.filter { series in
            let matchesGenre = genres(for: series).contains { selectedGenres.contains($0) }
            let matchesYear = yearRange.matches(year: series.releaseYear)
            return matchesGenre && matchesYear
        }

        XCTAssertEqual(filteredSeries.count, 1)
        XCTAssertEqual(filteredSeries.first?.title, "Sci-Fi Saga")
    }
}