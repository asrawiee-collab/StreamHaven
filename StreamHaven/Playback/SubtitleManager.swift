import Foundation

/// A struct representing a subtitle file from the OpenSubtitles API.
public struct SubtitleFile: Decodable {
    /// The ID of the file.
    let fileId: Int
    /// The name of the file.
    let fileName: String
}

/// A struct representing a subtitle from the OpenSubtitles API.
public struct Subtitle: Decodable {
    /// The attributes of the subtitle.
    let attributes: SubtitleAttributes
}

/// A struct representing the attributes of a subtitle from the OpenSubtitles API.
public struct SubtitleAttributes: Decodable {
    /// The language of the subtitle.
    let language: String
    /// An array of `SubtitleFile` objects.
    let files: [SubtitleFile]
}

/// A struct representing the response from a subtitle search request to the OpenSubtitles API.
public struct SubtitleSearchResponse: Decodable {
    /// An array of `Subtitle` objects.
    let data: [Subtitle]
}

/// A struct representing the response from a subtitle download request to the OpenSubtitles API.
public struct SubtitleDownloadResponse: Decodable {
    /// The URL to download the subtitle from.
    let link: String
}

/// A class for interacting with the OpenSubtitles API.
@MainActor
public class SubtitleManager: ObservableObject {

    private var apiKey: String? // Will be loaded from Info.plist
    private let apiBaseURL = "https://api.opensubtitles.com/api/v1"

    /// Initializes a new `SubtitleManager` and loads the API key from the `Info.plist`.
    public init() {
        // In a real app, you would load this from a secure place.
        // For this project, we'll expect it to be in the Info.plist.
        // I will add instructions for this in the README.
        if let key = Bundle.main.object(forInfoDictionaryKey: "OpenSubtitlesAPIKey") as? String {
            self.apiKey = key
        } else {
            print("WARNING: OpenSubtitles API Key not found in Info.plist. Subtitle search will not work.")
        }
    }

    /// Searches for subtitles for a given IMDb ID.
    ///
    /// - Parameter imdbID: The IMDb ID of the movie or series to search for.
    /// - Returns: An array of `Subtitle` objects.
    /// - Throws: An error if the search fails.
    public func searchSubtitles(for imdbID: String) async throws -> [Subtitle] {
        guard let apiKey = apiKey else {
            throw NSError(domain: "SubtitleManager", code: 1, userInfo: [NSLocalizedDescriptionKey: "API Key is missing."])
        }

        let urlString = "\(apiBaseURL)/subtitles?imdb_id=\(imdbID)"
        guard let url = URL(string: urlString) else {
            throw NSError(domain: "SubtitleManager", code: 2, userInfo: [NSLocalizedDescriptionKey: "Invalid search URL."])
        }

        var request = URLRequest(url: url)
        request.addValue(apiKey, forHTTPHeaderField: "Api-Key")
        request.addValue("StreamHaven v1.0", forHTTPHeaderField: "User-Agent")

        let (data, _) = try await URLSession.shared.data(for: request)
        let response = try JSONDecoder().decode(SubtitleSearchResponse.self, from: data)
        return response.data
    }

    /// Downloads a subtitle file.
    ///
    /// - Parameter fileID: The ID of the file to download.
    /// - Returns: The local URL of the downloaded subtitle file.
    /// - Throws: An error if the download fails.
    public func downloadSubtitle(for fileID: Int) async throws -> URL {
        guard let apiKey = apiKey else {
            throw NSError(domain: "SubtitleManager", code: 1, userInfo: [NSLocalizedDescriptionKey: "API Key is missing."])
        }

        let urlString = "\(apiBaseURL)/download"
        guard let url = URL(string: urlString) else {
            throw NSError(domain: "SubtitleManager", code: 3, userInfo: [NSLocalizedDescriptionKey: "Invalid download URL."])
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue(apiKey, forHTTPHeaderField: "Api-Key")
        request.addValue("StreamHaven v1.0", forHTTPHeaderField: "User-Agent")
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")

        let body = ["file_id": fileID]
        request.httpBody = try JSONEncoder().encode(body)

        let (data, _) = try await URLSession.shared.data(for: request)
        let response = try JSONDecoder().decode(SubtitleDownloadResponse.self, from: data)

        guard let downloadURL = URL(string: response.link) else {
            throw NSError(domain: "SubtitleManager", code: 4, userInfo: [NSLocalizedDescriptionKey: "Invalid subtitle download link received."])
        }

        let (localURL, _) = try await URLSession.shared.download(from: downloadURL)
        return localURL
    }
}
