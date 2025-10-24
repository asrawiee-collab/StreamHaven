import Foundation

enum PlaylistImportError: Error, LocalizedError {
    case invalidURL
    case networkError(Error)
    case unsupportedPlaylistType
    case parsingFailed(Error)
    case saveDataFailed(Error)

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return NSLocalizedString("The URL you entered appears to be invalid. Please check it and try again.", comment: "Invalid URL format error message")
        case .networkError(let underlyingError):
            return String(format: NSLocalizedString("Could not connect to the server: %@. Please check your network connection and the URL.", comment: "Network error message"), underlyingError.localizedDescription)
        case .unsupportedPlaylistType:
            return NSLocalizedString("The playlist format is not supported. Please use a valid M3U or Xtream Codes playlist.", comment: "Unsupported playlist type error message")
        case .parsingFailed(let underlyingError):
            return String(format: NSLocalizedString("The playlist file could not be read: %@.", comment: "Playlist parsing error message"), underlyingError.localizedDescription)
        case .saveDataFailed(let underlyingError):
            return String(format: NSLocalizedString("Failed to save the playlist data: %@.", comment: "Core Data save failure message"), underlyingError.localizedDescription)
        }
    }

    var recoverySuggestion: String? {
        switch self {
        case .invalidURL, .unsupportedPlaylistType, .parsingFailed:
            return NSLocalizedString("Please check the playlist URL and format, then try again.", comment: "Recovery suggestion for URL/format errors")
        case .networkError:
            return NSLocalizedString("Please check your internet connection and the server address, then try again.", comment: "Recovery suggestion for network errors")
        case .saveDataFailed:
            return NSLocalizedString("Please try again later. If the problem persists, consider restarting the app.", comment: "Recovery suggestion for data saving errors")
        }
    }
}
