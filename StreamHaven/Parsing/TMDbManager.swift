import Foundation
import CoreData

/// A struct representing a movie search result from the TMDb API.
public struct TMDbMovieSearchResult: Decodable {
    /// The TMDb ID of the movie.
    let id: Int
}

/// A struct representing the response from a movie search request to the TMDb API.
public struct TMDbMovieSearchResponse: Decodable {
    /// An array of `TMDbMovieSearchResult` objects.
    let results: [TMDbMovieSearchResult]
}

/// A struct representing a series search result from the TMDb API.
public struct TMDbSeriesSearchResult: Decodable {
    /// The TMDb ID of the series.
    let id: Int
}

/// A struct representing the response from a series search request to the TMDb API.
public struct TMDbSeriesSearchResponse: Decodable {
    /// An array of `TMDbSeriesSearchResult` objects.
    let results: [TMDbSeriesSearchResult]
}

/// A struct representing the external IDs of a movie from the TMDb API.
public struct TMDbExternalIDs: Decodable {
    /// The IMDb ID of the movie.
    let imdbId: String?
}

/// A struct representing a movie from TMDb API (for recommendations/trending).
public struct TMDbMovie: Decodable {
    let id: Int
    let title: String
    let overview: String?
    let posterPath: String?
    let releaseDate: String?
    let voteAverage: Double?
    
    enum CodingKeys: String, CodingKey {
        case id, title, overview
        case posterPath = "poster_path"
        case releaseDate = "release_date"
        case voteAverage = "vote_average"
    }
}

/// A struct representing a series from TMDb API (for recommendations/trending).
public struct TMDbSeries: Decodable {
    let id: Int
    let name: String
    let overview: String?
    let posterPath: String?
    let firstAirDate: String?
    let voteAverage: Double?
    
    enum CodingKeys: String, CodingKey {
        case id, name, overview
        case posterPath = "poster_path"
        case firstAirDate = "first_air_date"
        case voteAverage = "vote_average"
    }
}

/// A struct representing the response from recommendations/trending API.
public struct TMDbMovieListResponse: Decodable {
    let results: [TMDbMovie]
}

/// A struct representing the response from series recommendations/trending API.
public struct TMDbSeriesListResponse: Decodable {
    let results: [TMDbSeries]
}

/// A struct representing a video from TMDb API (trailer/preview).
public struct TMDbVideo: Decodable {
    let id: String
    let key: String
    let site: String
    let type: String
    let name: String
    let official: Bool?
    
    enum CodingKeys: String, CodingKey {
        case id, key, site, type, name, official
    }
    
    /// Returns the YouTube URL for this video if it's a YouTube video.
    var youtubeURL: URL? {
        guard site == "YouTube" else { return nil }
        return URL(string: "https://www.youtube.com/watch?v=\(key)")
    }
}

/// A struct representing the response from videos API.
public struct TMDbVideosResponse: Decodable {
    let results: [TMDbVideo]
}

/// A class for interacting with The Movie Database (TMDb) API.
@MainActor
public final class TMDbManager: TMDbManaging {

    /// The TMDb API key.
    private var apiKey: String?
    /// The base URL for the TMDb API.
    private let apiBaseURL = "https://api.themoviedb.org/3"

    /// Initializes a new `TMDbManager`.
    /// Tries to load API key from Keychain. You can also inject a key for testing.
    public init(apiKey: String? = nil) {
        if let apiKey = apiKey {
            self.apiKey = apiKey
        } else {
            // Look up securely stored key
            self.apiKey = KeychainHelper.getPassword(for: "TMDbAPIKey", service: "StreamHaven.API")
        }
        if self.apiKey == nil {
            PerformanceLogger.logNetwork("TMDb API Key not found in Keychain. IMDb ID fetching disabled.")
        }
    }

    /// Fetches the IMDb ID for a movie from the TMDb API and saves it to the Core Data object.
    ///
    /// - Parameters:
    ///   - movie: The `Movie` object to fetch the IMDb ID for.
    ///   - context: The `NSManagedObjectContext` to perform the save on.
    public func fetchIMDbID(for movie: Movie, context: NSManagedObjectContext) async {
        guard let apiKey = apiKey, let title = movie.title else { return }

        // Don't re-fetch if we already have it
        if movie.imdbID != nil {
            return
        }

        do {
            // 1. Search for the movie by title to get the TMDb ID
            let searchQuery = title.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
            let searchURLString = "\(apiBaseURL)/search/movie?api_key=\(apiKey)&query=\(searchQuery)"
            guard let searchURL = URL(string: searchURLString) else { return }

            let (searchData, _) = try await URLSession.shared.data(from: searchURL)
            let searchResponse = try JSONDecoder().decode(TMDbMovieSearchResponse.self, from: searchData)

            guard let tmdbID = searchResponse.results.first?.id else {
                PerformanceLogger.logNetwork("TMDb: Could not find movie \(title)")
                return
            }

            // 2. Fetch the external IDs (including IMDb ID) using the TMDb ID
            let externalIDsURLString = "\(apiBaseURL)/movie/\(tmdbID)/external_ids?api_key=\(apiKey)"
            guard let externalIDsURL = URL(string: externalIDsURLString) else { return }

            let (externalIDsData, _) = try await URLSession.shared.data(from: externalIDsURL)
            let externalIDsResponse = try JSONDecoder().decode(TMDbExternalIDs.self, from: externalIDsData)

            // 3. Save the IMDb ID to the Core Data object
            if let imdbID = externalIDsResponse.imdbId {
                context.performAndWait {
                    movie.imdbID = imdbID
                    try? context.save()
                    PerformanceLogger.logNetwork("TMDb: Saved IMDb ID \(imdbID) for \(title)")
                }
            }
        } catch {
            PerformanceLogger.logNetwork("TMDb error: Failed to fetch IMDb ID for \(title): \(error)")
        }
    }
    
    /// Fetches similar movies from TMDb based on a movie's TMDb ID.
    /// - Parameter tmdbID: The TMDb ID of the movie.
    /// - Returns: An array of similar TMDb movies.
    public func getSimilarMovies(tmdbID: Int) async throws -> [TMDbMovie] {
        guard let apiKey = apiKey else {
            throw TMDbError.missingAPIKey
        }
        
        let urlString = "\(apiBaseURL)/movie/\(tmdbID)/similar?api_key=\(apiKey)"
        guard let url = URL(string: urlString) else {
            throw TMDbError.invalidURL
        }
        
        let (data, _) = try await URLSession.shared.data(from: url)
        let response = try JSONDecoder().decode(TMDbMovieListResponse.self, from: data)
        PerformanceLogger.logNetwork("TMDb: Fetched \(response.results.count) similar movies for TMDb ID \(tmdbID)")
        return response.results
    }
    
    /// Fetches trending movies from TMDb (this week).
    /// - Returns: An array of trending TMDb movies.
    public func getTrendingMovies() async throws -> [TMDbMovie] {
        guard let apiKey = apiKey else {
            throw TMDbError.missingAPIKey
        }
        
        let urlString = "\(apiBaseURL)/trending/movie/week?api_key=\(apiKey)"
        guard let url = URL(string: urlString) else {
            throw TMDbError.invalidURL
        }
        
        let (data, _) = try await URLSession.shared.data(from: url)
        let response = try JSONDecoder().decode(TMDbMovieListResponse.self, from: data)
        PerformanceLogger.logNetwork("TMDb: Fetched \(response.results.count) trending movies")
        return response.results
    }
    
    /// Fetches trending series from TMDb (this week).
    /// - Returns: An array of trending TMDb series.
    public func getTrendingSeries() async throws -> [TMDbSeries] {
        guard let apiKey = apiKey else {
            throw TMDbError.missingAPIKey
        }
        
        let urlString = "\(apiBaseURL)/trending/tv/week?api_key=\(apiKey)"
        guard let url = URL(string: urlString) else {
            throw TMDbError.invalidURL
        }
        
        let (data, _) = try await URLSession.shared.data(from: url)
        let response = try JSONDecoder().decode(TMDbSeriesListResponse.self, from: data)
        PerformanceLogger.logNetwork("TMDb: Fetched \(response.results.count) trending series")
        return response.results
    }
    
    /// Searches for a movie by title in the local Core Data store.
    /// - Parameters:
    ///   - title: The movie title to search for.
    ///   - context: The managed object context.
    /// - Returns: The matching Movie object if found.
    public func findLocalMovie(title: String, context: NSManagedObjectContext) -> Movie? {
        let request: NSFetchRequest<Movie> = Movie.fetchRequest()
        request.predicate = NSPredicate(format: "title CONTAINS[cd] %@", title)
        request.fetchLimit = 1
        
        return try? context.fetch(request).first
    }
    
    /// Searches for a series by title in the local Core Data store.
    /// - Parameters:
    ///   - name: The series name to search for.
    ///   - context: The managed object context.
    /// - Returns: The matching Series object if found.
    public func findLocalSeries(name: String, context: NSManagedObjectContext) -> Series? {
        let request: NSFetchRequest<Series> = Series.fetchRequest()
        request.predicate = NSPredicate(format: "title CONTAINS[cd] %@", name)
        request.fetchLimit = 1
        
        return try? context.fetch(request).first
    }
    
    /// Fetches videos (trailers/previews) for a movie from TMDb.
    /// - Parameters:
    ///   - movie: The Movie object to fetch videos for.
    ///   - context: The managed object context.
    /// - Returns: The preview URL (YouTube) if found.
    public func fetchMovieVideos(for movie: Movie, context: NSManagedObjectContext) async -> URL? {
        guard let apiKey = apiKey, let title = movie.title else { return nil }
        
        do {
            // 1. Search for the movie by title to get the TMDb ID
            let searchQuery = title.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
            let searchURLString = "\(apiBaseURL)/search/movie?api_key=\(apiKey)&query=\(searchQuery)"
            guard let searchURL = URL(string: searchURLString) else { return nil }
            
            let (searchData, _) = try await URLSession.shared.data(from: searchURL)
            let searchResponse = try JSONDecoder().decode(TMDbMovieSearchResponse.self, from: searchData)
            
            guard let tmdbID = searchResponse.results.first?.id else {
                PerformanceLogger.logNetwork("TMDb: Could not find movie \(title)")
                return nil
            }
            
            // 2. Fetch videos for the movie
            let videosURLString = "\(apiBaseURL)/movie/\(tmdbID)/videos?api_key=\(apiKey)"
            guard let videosURL = URL(string: videosURLString) else { return nil }
            
            let (videosData, _) = try await URLSession.shared.data(from: videosURL)
            let videosResponse = try JSONDecoder().decode(TMDbVideosResponse.self, from: videosData)
            
            // 3. Find the first official trailer or teaser
            let preview = videosResponse.results.first { video in
                video.site == "YouTube" && (video.type == "Trailer" || video.type == "Teaser") && (video.official == true || video.official == nil)
            }
            
            if let previewURL = preview?.youtubeURL {
                // Save the preview URL to Core Data
                context.performAndWait {
                    movie.previewURL = previewURL.absoluteString
                    try? context.save()
                    PerformanceLogger.logNetwork("TMDb: Saved preview URL for \(title)")
                }
                return previewURL
            }
        } catch {
            PerformanceLogger.logNetwork("TMDb error: Failed to fetch videos for \(title): \(error)")
        }
        
        return nil
    }
    
    /// Fetches videos (trailers/previews) for a series from TMDb.
    /// - Parameters:
    ///   - series: The Series object to fetch videos for.
    ///   - context: The managed object context.
    /// - Returns: The preview URL (YouTube) if found.
    public func fetchSeriesVideos(for series: Series, context: NSManagedObjectContext) async -> URL? {
        guard let apiKey = apiKey, let title = series.title else { return nil }
        
        do {
            // 1. Search for the series by title to get the TMDb ID
            let searchQuery = title.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
            let searchURLString = "\(apiBaseURL)/search/tv?api_key=\(apiKey)&query=\(searchQuery)"
            guard let searchURL = URL(string: searchURLString) else { return nil }
            
            let (searchData, _) = try await URLSession.shared.data(from: searchURL)
            let searchResponse = try JSONDecoder().decode(TMDbSeriesSearchResponse.self, from: searchData)
            
            guard let tmdbID = searchResponse.results.first?.id else {
                PerformanceLogger.logNetwork("TMDb: Could not find series \(title)")
                return nil
            }
            
            // 2. Fetch videos for the series
            let videosURLString = "\(apiBaseURL)/tv/\(tmdbID)/videos?api_key=\(apiKey)"
            guard let videosURL = URL(string: videosURLString) else { return nil }
            
            let (videosData, _) = try await URLSession.shared.data(from: videosURL)
            let videosResponse = try JSONDecoder().decode(TMDbVideosResponse.self, from: videosData)
            
            // 3. Find the first official trailer or teaser
            let preview = videosResponse.results.first { video in
                video.site == "YouTube" && (video.type == "Trailer" || video.type == "Teaser") && (video.official == true || video.official == nil)
            }
            
            if let previewURL = preview?.youtubeURL {
                // Save the preview URL to Core Data
                context.performAndWait {
                    series.previewURL = previewURL.absoluteString
                    try? context.save()
                    PerformanceLogger.logNetwork("TMDb: Saved preview URL for \(title)")
                }
                return previewURL
            }
        } catch {
            PerformanceLogger.logNetwork("TMDb error: Failed to fetch videos for \(title): \(error)")
        }
        
        return nil
    }
}

/// Errors that can occur when using TMDbManager.
public enum TMDbError: Error {
    case missingAPIKey
    case invalidURL
    case networkError(Error)
    case decodingError(Error)
}
