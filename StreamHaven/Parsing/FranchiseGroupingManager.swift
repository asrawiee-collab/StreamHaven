import Foundation
import CoreData

/// A utility class for grouping movies into franchises.
public final class FranchiseGroupingManager {

    /// Groups an array of movies into franchises based on their titles.
    /// - Parameter movies: An array of `Movie` objects to group.
    /// - Returns: A dictionary where the keys are franchise names and the values are arrays of movies belonging to that franchise.
    public static func groupFranchises(movies: [Movie]) -> [String: [Movie]] {
        var franchiseGroups: [String: [Movie]] = [:]
        var processedMovies: Set<NSManagedObjectID> = []

        for movie in movies {
            if processedMovies.contains(movie.objectID) {
                continue
            }

            guard let title = movie.title else { continue }

            let franchiseName = detectFranchiseName(from: title)
            var currentGroup = [movie]
            processedMovies.insert(movie.objectID)

            for otherMovie in movies {
                if movie.objectID != otherMovie.objectID && !processedMovies.contains(otherMovie.objectID) {
                    guard let otherTitle = otherMovie.title else { continue }
                    if detectFranchiseName(from: otherTitle) == franchiseName {
                        currentGroup.append(otherMovie)
                        processedMovies.insert(otherMovie.objectID)
                    }
                }
            }

            if currentGroup.count > 1 {
                franchiseGroups[franchiseName] = currentGroup.sorted(by: { ($0.title ?? "") < ($1.title ?? "") })
            }
        }

        return franchiseGroups
    }

    /// Detects the franchise name from a movie title.
    /// - Parameter title: The title of the movie.
    /// - Returns: The detected franchise name.
    private static func detectFranchiseName(from title: String) -> String {
        var franchiseName = title
        
        // First, check for common subtitle-based sequel patterns
        let originalTitle = franchiseName
        franchiseName = removeCommonSubtitles(from: franchiseName)
        
        // If subtitle removal didn't change anything, try other patterns
        if franchiseName == originalTitle {
            let patterns = [
                ":\\s.*",              // Removes colon and everything after (e.g., "Movie: Subtitle")
                "\\s\\d+$",            // Removes trailing numbers (e.g., "Movie 2")
                "\\sPart\\s\\w+",      // Removes "Part X" (e.g., "Movie Part II")
                "\\s(I|V|X)+$",        // Removes roman numerals at end (e.g., "Movie III")
            ]

            for pattern in patterns {
                if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) {
                    let range = NSRange(location: 0, length: franchiseName.utf16.count)
                    franchiseName = regex.stringByReplacingMatches(in: franchiseName, options: [], range: range, withTemplate: "")
                    if franchiseName != originalTitle {
                        break // Found a match, stop trying other patterns
                    }
                }
            }
        }

        return franchiseName.trimmingCharacters(in: .whitespaces)
    }
    
    /// Removes common subtitle patterns from movie titles to detect franchises.
    /// - Parameter title: The title to process.
    /// - Returns: The title with common subtitles removed.
    private static func removeCommonSubtitles(from title: String) -> String {
        // Common single-word subtitle patterns for sequels
        let subtitleWords = [
            // Action/continuation words
            "Reloaded", "Revolutions", "Revolution", "Returns", "Resurrection",
            "Rising", "Rises", "Reborn", "Redemption", "Revenge", "Retribution",
            // Directional/temporal
            "Begins", "Origins", "Genesis", "Forever", "Legacy", "Legends",
            "Awakens", "Awakening", "Dawn", "Dusk", "Midnight", "Eclipse",
            // Endings
            "Endgame", "Finale", "Final", "Last", "Ultimate", "Infinity",
            // Action descriptors
            "Strike", "Force", "Attack", "War", "Battle", "Combat",
            "Quest", "Mission", "Journey", "Voyage", "Adventure",
            // Story progression
            "Chapter", "Chronicles", "Saga", "Tales", "Stories",
            // Superlatives/intensifiers
            "Extreme", "Maximum", "Overdrive", "Turbo",
            // Common sequel words
            "Reload", "Recharged", "Reckoning", "Vengeance",
            // Fate/destiny themed
            "Salvation", "Fate", "Destiny", "Judgment", "Apocalypse"
        ]
        
        var result = title
        
        // Simple pattern: match single subtitle words at the end of title
        for word in subtitleWords {
            // Match word at the end with optional punctuation/spacing
            let simplePattern = "\\s+\(word)$"
            if let regex = try? NSRegularExpression(pattern: simplePattern.replacingOccurrences(of: "(word)", with: word), options: .caseInsensitive) {
                let range = NSRange(location: 0, length: result.utf16.count)
                let newResult = regex.stringByReplacingMatches(in: result, options: [], range: range, withTemplate: "")
                if newResult != result {
                    result = newResult
                    break
                }
            }
        }
        
        return result
    }
}
