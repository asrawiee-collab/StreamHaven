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

/// A struct representing a cast member from TMDb credits API.
public struct TMDbCastMember: Decodable, Sendable {
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
public struct TMDbCrewMember: Decodable, Sendable {
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
public struct TMDbCreditsResponse: Decodable, Sendable {
    let cast: [TMDbCastMember]
    let crew: [TMDbCrewMember]
}

/// A struct for full person details from TMDb API.
public struct TMDbPersonDetail: Decodable, Sendable {
    let id: Int
    let name: String
    let biography: String?
    let profilePath: String?
    
    enum CodingKeys: String, CodingKey {
        case id, name, biography
        case profilePath = "profile_path"
    }

    /// Returns the full photo URL for this person.
    var photoURL: String? {
        guard let path = profilePath else { return nil }
        return "https://image.tmdb.org/t/p/w185\(path)"
    }
}

/// A class for interacting with The Movie Database (TMDb) API.
@MainActor
public final class TMDbManager: ObservableObject, TMDbManaging {

    /// The TMDb API key.
    public var apiKey: String?
    /// The base URL for the TMDb API.
    private let apiBaseURL = "https://api.themoviedb.org/3"
    
    /// Client-side rate limiter (default ~4 req/sec, burst 8)
    private let rateLimiter = RateLimiter(maxTokens: 8, refillPerSecond: 4)

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
    ///   - context: The managed object context.
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

            await rateLimiter.acquire()
            let (searchData, _) = try await URLSession.shared.data(from: searchURL)
            let searchResponse = try JSONDecoder().decode(TMDbMovieSearchResponse.self, from: searchData)

            guard let tmdbID = searchResponse.results.first?.id else {
                PerformanceLogger.logNetwork("TMDb: Could not find movie \(title)")
                return
            }

            // 2. Fetch the external IDs (including IMDb ID) using the TMDb ID
            let externalIDsURLString = "\(apiBaseURL)/movie/\(tmdbID)/external_ids?api_key=\(apiKey)"
            guard let externalIDsURL = URL(string: externalIDsURLString) else { return }

            await rateLimiter.acquire()
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
    
    /// Fetches full details for a person (actor) from TMDb.
    /// - Parameter tmdbID: The TMDb ID of the person.
    /// - Returns: A `TMDbPersonDetail` object if found, otherwise `nil`.
    public func fetchPersonDetails(tmdbID: Int) async throws -> TMDbPersonDetail? {
        guard let actualApiKey = apiKey else {
            throw TMDbError.missingAPIKey
        }

        let urlString = "\(apiBaseURL)/person/\(tmdbID)?api_key=\(actualApiKey)"
        guard let url = URL(string: urlString) else {
            throw TMDbError.invalidURL
        }

        await rateLimiter.acquire()
        let (data, response) = try await URLSession.shared.data(from: url)

        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            PerformanceLogger.logNetwork("TMDb: Failed to fetch person details for TMDb ID \(tmdbID). Status code: \((response as? HTTPURLResponse)?.statusCode ?? 0)")
            return nil
        }

        let personDetail = try JSONDecoder().decode(TMDbPersonDetail.self, from: data)
        PerformanceLogger.logNetwork("TMDb: Fetched details for person \(personDetail.name) (TMDb ID \(tmdbID))")
        return personDetail
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
        
        await rateLimiter.acquire()
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
        
        await rateLimiter.acquire()
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
        
        await rateLimiter.acquire()
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
            
            await rateLimiter.acquire()
            let (searchData, _) = try await URLSession.shared.data(from: searchURL)
            let searchResponse = try JSONDecoder().decode(TMDbMovieSearchResponse.self, from: searchData)
            
            guard let tmdbID = searchResponse.results.first?.id else {
                PerformanceLogger.logNetwork("TMDb: Could not find movie \(title)")
                return nil
            }
            
            // 2. Fetch videos for the movie
            let videosURLString = "\(apiBaseURL)/movie/\(tmdbID)/videos?api_key=\(apiKey)"
            guard let videosURL = URL(string: videosURLString) else { return nil }
            
            await rateLimiter.acquire()
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
            
            await rateLimiter.acquire()
            let (searchData, _) = try await URLSession.shared.data(from: searchURL)
            let searchResponse = try JSONDecoder().decode(TMDbSeriesSearchResponse.self, from: searchData)
            
            guard let tmdbID = searchResponse.results.first?.id else {
                PerformanceLogger.logNetwork("TMDb: Could not find series \(title)")
                return nil
            }
            
            // 2. Fetch videos for the series
            let videosURLString = "\(apiBaseURL)/tv/\(tmdbID)/videos?api_key=\(apiKey)"
            guard let videosURL = URL(string: videosURLString) else { return nil }
            
            await rateLimiter.acquire()
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
        let cast = creditsResponse.cast
        
        await context.perform {
            // Limit to top 10 cast members to avoid cluttering UI
            let topCast = Array(cast.prefix(10))
            
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
            
            // Save Crew members
            let crew = creditsResponse.crew
            for crewMember in crew {
                // Find or create Crew
                let crewFetch: NSFetchRequest<Crew> = Crew.fetchRequest()
                crewFetch.predicate = NSPredicate(format: "tmdbID == %d AND job == %@", crewMember.id, crewMember.job)
                
                let crewEntity: Crew
                if let existingCrew = try? context.fetch(crewFetch).first {
                    crewEntity = existingCrew
                } else {
                    crewEntity = Crew(context: context)
                    crewEntity.tmdbID = Int64(crewMember.id)
                    crewEntity.job = crewMember.job
                }
                
                // Update crew info
                crewEntity.name = crewMember.name
                crewEntity.profilePath = crewMember.profilePath
                
                // Link to content
                if let movie = content as? Movie {
                    crewEntity.movie = movie
                } else if let series = content as? Series {
                    crewEntity.series = series
                }
            }
            
            try? context.save()
        }
    }
    
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
}

extension Array {
    func chunked(into size: Int) -> [[Element]] {
        stride(from: 0, to: count, by: size).map {
            Array(self[$0 ..< Swift.min($0 + size, count)])
        }
    }
}

/// Errors that can occur when using TMDbManager.
public enum TMDbError: Error {
    case missingAPIKey
    case invalidURL
    case networkError(Error)
    case decodingError(Error)
}
