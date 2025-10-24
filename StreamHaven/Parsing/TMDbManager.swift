import Foundation
import CoreData

struct TMDbMovieSearchResult: Decodable {
    let id: Int
}

struct TMDbMovieSearchResponse: Decodable {
    let results: [TMDbMovieSearchResult]
}

struct TMDbExternalIDs: Decodable {
    let imdbId: String?
}

@MainActor
class TMDbManager: ObservableObject {

    private var apiKey: String?
    private let apiBaseURL = "https://api.themoviedb.org/3"

    init() {
        if let key = Bundle.main.object(forInfoDictionaryKey: "TMDbAPIKey") as? String {
            self.apiKey = key
        } else {
            print("WARNING: TMDb API Key not found in Info.plist. IMDb ID fetching will not work.")
        }
    }

    func fetchIMDbID(for movie: Movie, context: NSManagedObjectContext) async {
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
                print("Could not find movie '\(title)' on TMDb.")
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
                    print("Successfully fetched and saved IMDb ID (\(imdbID)) for '\(title)'.")
                }
            }
        } catch {
            print("Failed to fetch IMDb ID for movie '\(title)': \(error)")
        }
    }
}
