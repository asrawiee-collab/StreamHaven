import Foundation

struct SubtitleFile: Decodable {
    let fileId: Int
    let fileName: String
}

struct Subtitle: Decodable {
    let attributes: SubtitleAttributes
}

struct SubtitleAttributes: Decodable {
    let language: String
    let files: [SubtitleFile]
}

struct SubtitleSearchResponse: Decodable {
    let data: [Subtitle]
}

struct SubtitleDownloadResponse: Decodable {
    let link: String
}

@MainActor
class SubtitleManager: ObservableObject {

    private var apiKey: String? // Will be loaded from Info.plist
    private let apiBaseURL = "https://api.opensubtitles.com/api/v1"

    init() {
        // In a real app, you would load this from a secure place.
        // For this project, we'll expect it to be in the Info.plist.
        // I will add instructions for this in the README.
        if let key = Bundle.main.object(forInfoDictionaryKey: "OpenSubtitlesAPIKey") as? String {
            self.apiKey = key
        } else {
            print("WARNING: OpenSubtitles API Key not found in Info.plist. Subtitle search will not work.")
        }
    }

    func searchSubtitles(for imdbID: String) async throws -> [Subtitle] {
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

    func downloadSubtitle(for fileID: Int) async throws -> URL {
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
