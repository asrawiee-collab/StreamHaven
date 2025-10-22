import Foundation

class AdultContentDetector {

    private static let adultKeywords: Set<String> = [
        "adult", "18+", "xxx", "porn", "erotic"
    ]

    static func isAdultContent(title: String) -> Bool {
        let lowercasedTitle = title.lowercased()
        for keyword in adultKeywords {
            if lowercasedTitle.contains(keyword) {
                return true
            }
        }
        return false
    }
}
