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

/// A struct representing the external IDs of a movie from the TMDb API.
public struct TMDbExternalIDs: Decodable {
    /// The IMDb ID of the movie.
    let imdbId: String?
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
}
