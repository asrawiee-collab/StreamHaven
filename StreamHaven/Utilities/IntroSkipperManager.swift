//
//  IntroSkipperManager.swift
//  StreamHaven
//
//  Service for detecting and managing intro/outro timing data
//

import CoreData
import Foundation

/// Manager for fetching and storing intro/outro timing data from multiple sources.
public final class IntroSkipperManager {
    
    /// TheTVDB API configuration
    private let tvdbAPIKey: String?
    private let tvdbBaseURL = "https://api4.thetvdb.com/v4"
    private var tvdbToken: String?
    private var tokenExpiresAt: Date?
    
    /// TMDb API configuration (for series/episode metadata)
    private let tmdbAPIKey: String?
    private let tmdbBaseURL = "https://api.themoviedb.org/3"
    
    /// Heuristic defaults (in seconds)
    private let defaultIntroStart: Double = 0
    private let defaultIntroEnd: Double = 90
    
    /// Cache to avoid redundant API calls
    private var introCache: [String: IntroTiming] = [:]
    
    /// Timing data structure
    public struct IntroTiming {
        let introStart: Double
        let introEnd: Double
        let creditStart: Double?
        let source: IntroSource
    }
    
    /// Source of intro timing data
    public enum IntroSource {
        case tvdb           // TheTVDB API
        case m3uMetadata    // Parsed from M3U playlist
        case heuristic      // Default 90-second assumption
        case cached         // Previously fetched data
    }
    
    /// Initializes the IntroSkipperManager.
    /// - Parameters:
    ///   - tvdbAPIKey: Optional TheTVDB API key for fetching intro data.
    ///   - tmdbAPIKey: Optional TMDb API key for series lookup.
    public init(tvdbAPIKey: String? = nil, tmdbAPIKey: String? = nil) {
        self.tvdbAPIKey = tvdbAPIKey
        self.tmdbAPIKey = tmdbAPIKey
    }
    
    // MARK: - Public Methods
    
    /// Fetches intro timing for an episode from available sources.
    /// - Parameters:
    ///   - episode: The episode to fetch intro timing for.
    ///   - context: Core Data context for updating episode.
    /// - Returns: IntroTiming data or nil if unavailable.
    public func getIntroTiming(for episode: Episode, context: NSManagedObjectContext) async -> IntroTiming? {
        // Check if we already have intro data stored
        if episode.hasIntroData {
            return IntroTiming(
                introStart: episode.introStartTime, introEnd: episode.introEndTime, creditStart: episode.creditStartTime > 0 ? episode.creditStartTime: nil, source: .cached
            )
        }
        
        // Try TheTVDB API if configured
        if let tvdbAPIKey = tvdbAPIKey, let timing = await fetchFromTheTVDB(episode: episode) {
            await storeIntroTiming(timing, for: episode, context: context)
            return timing
        }
        
        // Fallback to heuristic (90-second intro)
        let heuristicTiming = IntroTiming(
            introStart: defaultIntroStart, introEnd: defaultIntroEnd, creditStart: nil, source: .heuristic
        )
        
        // Store heuristic so we don't keep retrying API
        await storeIntroTiming(heuristicTiming, for: episode, context: context)
        return heuristicTiming
    }
    
    /// Manually sets intro timing for an episode (e.g., from M3U metadata).
    /// - Parameters:
    ///   - introStart: Start time of intro in seconds.
    ///   - introEnd: End time of intro in seconds.
    ///   - creditStart: Optional start time of credits in seconds.
    ///   - episode: The episode to update.
    ///   - context: Core Data context.
    public func setIntroTiming(
        introStart: Double, introEnd: Double, creditStart: Double?, for episode: Episode, context: NSManagedObjectContext
    ) async {
        let timing = IntroTiming(
            introStart: introStart, introEnd: introEnd, creditStart: creditStart, source: .m3uMetadata
        )
        await storeIntroTiming(timing, for: episode, context: context)
    }
    
    // MARK: - TheTVDB API Integration
    
    /// Authenticates with TheTVDB API and retrieves access token.
    private func authenticateTheTVDB() async -> String? {
        // Check if we have a valid token
        if let token = tvdbToken, let expiresAt = tokenExpiresAt, Date() < expiresAt {
            return token
        }
        
        guard let apiKey = tvdbAPIKey else { return nil }
        
        let authURL = URL(string: "\(tvdbBaseURL)/login")!
        var request = URLRequest(url: authURL)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body = ["apikey": apiKey]
        request.httpBody = try? JSONEncoder().encode(body)
        
        do {
            let (data, _) = try await URLSession.shared.data(for: request)
            if let response = try? JSONDecoder().decode(TheTVDBAuthResponse.self, from: data) {
                self.tvdbToken = response.data.token
                // TheTVDB tokens expire after 30 days, but we'll refresh after 7 days to be safe
                self.tokenExpiresAt = Date().addingTimeInterval(7 * 24 * 60 * 60)
                PerformanceLogger.logNetwork("TheTVDB authentication successful")
                return response.data.token
            }
        } catch {
            PerformanceLogger.logNetwork("TheTVDB authentication failed: \(error.localizedDescription)")
        }
        
        return nil
    }
    
    /// Fetches intro timing from TheTVDB API.
    private func fetchFromTheTVDB(episode: Episode) async -> IntroTiming? {
        guard let token = await authenticateTheTVDB(), let series = episode.season?.series, let seriesTitle = series.title else {
            return nil
        }
        
        // First, search for the series to get TheTVDB series ID
        guard let tvdbSeriesID = await searchTheTVDBSeries(title: seriesTitle, token: token) else {
            PerformanceLogger.logNetwork("TheTVDB series not found: \(seriesTitle)")
            return nil
        }
        
        // Then fetch episode details with intro timing
        guard let timing = await fetchTheTVDBEpisode(
            seriesID: tvdbSeriesID, seasonNumber: Int(episode.season?.seasonNumber ?? 0), episodeNumber: Int(episode.episodeNumber), token: token
        ) else {
            PerformanceLogger.logNetwork("TheTVDB episode intro data not found")
            return nil
        }
        
        PerformanceLogger.logNetwork("TheTVDB intro data fetched successfully")
        return timing
    }
    
    /// Searches TheTVDB for a series by title.
    private func searchTheTVDBSeries(title: String, token: String) async -> Int? {
        let encodedTitle = title.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? title
        let searchURL = URL(string: "\(tvdbBaseURL)/search?query=\(encodedTitle)&type=series")!
        
        var request = URLRequest(url: searchURL)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        do {
            let (data, _) = try await URLSession.shared.data(for: request)
            if let response = try? JSONDecoder().decode(TheTVDBSearchResponse.self, from: data), let firstResult = response.data.first {
                return firstResult.tvdb_id
            }
        } catch {
            PerformanceLogger.logNetwork("TheTVDB search error: \(error.localizedDescription)")
        }
        
        return nil
    }
    
    /// Fetches episode details from TheTVDB including intro timing.
    private func fetchTheTVDBEpisode(
        seriesID: Int, seasonNumber: Int, episodeNumber: Int, token: String
    ) async -> IntroTiming? {
        // TheTVDB uses extended episode endpoint for detailed data
        let episodeURL = URL(string: "\(tvdbBaseURL)/series/\(seriesID)/episodes/default?season=\(seasonNumber)&episodeNumber=\(episodeNumber)")!
        
        var request = URLRequest(url: episodeURL)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        do {
            let (data, _) = try await URLSession.shared.data(for: request)
            if let response = try? JSONDecoder().decode(TheTVDBEpisodeResponse.self, from: data), let episode = response.data.episodes.first {
                
                // TheTVDB may have intro timing in extended metadata
                // If not available, return nil to fallback to heuristic
                if let introStart = episode.introStart, let introEnd = episode.introEnd {
                    return IntroTiming(
                        introStart: introStart, introEnd: introEnd, creditStart: episode.creditStart, source: .tvdb
                    )
                }
            }
        } catch {
            PerformanceLogger.logNetwork("TheTVDB episode fetch error: \(error.localizedDescription)")
        }
        
        return nil
    }
    
    // MARK: - Data Storage
    
    /// Stores intro timing data in Core Data.
    private func storeIntroTiming(_ timing: IntroTiming, for episode: Episode, context: NSManagedObjectContext) async {
        await MainActor.run {
            episode.introStartTime = timing.introStart
            episode.introEndTime = timing.introEnd
            episode.creditStartTime = timing.creditStart ?? 0
            episode.hasIntroData = true
            
            do {
                try context.save()
                PerformanceLogger.logNetwork("Intro timing saved for episode: \\(episode.title ?? \"Unknown\")")
            } catch {
                PerformanceLogger.logNetwork("Failed to save intro timing: \\(error.localizedDescription)")
            }
        }
    }
}

// MARK: - TheTVDB API Models

private struct TheTVDBAuthResponse: Codable {
    let data: TheTVDBAuthData
}

private struct TheTVDBAuthData: Codable {
    let token: String
}

private struct TheTVDBSearchResponse: Codable {
    let data: [TheTVDBSearchResult]
}

private struct TheTVDBSearchResult: Codable {
    let tvdb_id: Int
    let name: String
}

private struct TheTVDBEpisodeResponse: Codable {
    let data: TheTVDBEpisodeData
}

private struct TheTVDBEpisodeData: Codable {
    let episodes: [TheTVDBEpisode]
}

private struct TheTVDBEpisode: Codable {
    let id: Int
    let seasonNumber: Int
    let number: Int
    let name: String
    let introStart: Double?
    let introEnd: Double?
    let creditStart: Double?
}
