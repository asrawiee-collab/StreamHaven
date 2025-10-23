import Foundation

enum StreamHavenError: Error, LocalizedError {
    case invalidURL
    case noDataReceived
    case unknownPlaylistType
    case m3uParsingError(String)
    case xtreamCodesParsingError(String)
    case cachingFailed

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return NSLocalizedString("The provided URL is not valid.", comment: "Error message")
        case .noDataReceived:
            return NSLocalizedString("No data was received from the server.", comment: "Error message")
        case .unknownPlaylistType:
            return NSLocalizedString("The playlist type could not be determined.", comment: "Error message")
        case .m3uParsingError(let detail):
            return String(format: NSLocalizedString("M3U parsing failed: %@", comment: "Error message"), detail)
        case .xtreamCodesParsingError(let detail):
            return String(format: NSLocalizedString("Xtream Codes parsing failed: %@", comment: "Error message"), detail)
        case .cachingFailed:
            return NSLocalizedString("Failed to save the playlist to the local cache.", comment: "Error message")
        }
    }
}
