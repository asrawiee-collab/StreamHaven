import Foundation

/// A utility class for detecting adult content in titles.
public final class AdultContentDetector {

    /// A set of keywords that are used to identify adult content.
    private static let adultKeywords: Set<String> = [
        "adult", "18+", "xxx", "porn", "erotic"
    ]

    /// Checks if a title contains adult content keywords.
    /// - Parameter title: The title to check.
    /// - Returns: `true` if the title contains adult content keywords, `false` otherwise.
    public static func isAdultContent(title: String) -> Bool {
        let lowercasedTitle = title.lowercased()
        for keyword in adultKeywords {
            if lowercasedTitle.contains(keyword) {
                return true
            }
        }
        return false
    }
}
