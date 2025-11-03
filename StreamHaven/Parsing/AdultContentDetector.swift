import Foundation

/// A utility class for detecting adult content in titles and categories.
public final class AdultContentDetector {

    /// Keywords that should flag a title as adult content.
    private static let adultTitleKeywords: Set<String> = [
        "adult", "18+", "xxx", "porn", "erotic", "explicit", "material"
    ]

    /// Category keywords that should flag a classification as adult content.
    private static let adultCategoryKeywords: Set<String> = [
        "adult", "xxx", "18+", "mature", "nsfw"
    ]

    /// Checks whether the provided metadata represents adult content.
    /// - Parameters:
    ///   - title: The content title to evaluate.
    ///   - categoryName: An optional category or genre label associated with the content.
    /// - Returns: `true` when the title or category explicitly references adult content; otherwise `false`.
    public static func isAdultContent(title: String, categoryName: String? = nil) -> Bool {
        let normalizedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedCategory = categoryName?.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !(normalizedTitle.isEmpty && (normalizedCategory?.isEmpty ?? true)) else {
            return false
        }

        if containsAdultKeyword(in: normalizedTitle, keywords: adultTitleKeywords) {
            return true
        }

        if let category = normalizedCategory, containsAdultKeyword(in: category, keywords: adultCategoryKeywords) {
            return true
        }

        return false
    }

    private static func containsAdultKeyword(in text: String, keywords: Set<String>) -> Bool {
        guard !text.isEmpty else { return false }

        for keyword in keywords where matches(keyword: keyword, in: text) {
            return true
        }

        return false
    }

    private static func matches(keyword: String, in text: String) -> Bool {
        let escapedKeyword = NSRegularExpression.escapedPattern(for: keyword)
        let requiresWordBoundary = keyword.rangeOfCharacter(from: CharacterSet.alphanumerics.inverted) == nil
        let pattern = requiresWordBoundary ? "\\b\(escapedKeyword)\\b" : escapedKeyword

        return text.range(of: pattern, options: [.regularExpression, .caseInsensitive]) != nil
    }
}
