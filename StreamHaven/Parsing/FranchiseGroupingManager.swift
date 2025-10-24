import Foundation
import CoreData

/// A utility class for grouping movies into franchises.
public class FranchiseGroupingManager {

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
        let patterns = [
            ":\\s.*",
            "\\s\\d+$",
            "\\sPart\\s\\w+",
            "\\s(I|V|X)+$",
        ]

        var franchiseName = title
        for pattern in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) {
                let range = NSRange(location: 0, length: franchiseName.utf16.count)
                franchiseName = regex.stringByReplacingMatches(in: franchiseName, options: [], range: range, withTemplate: "")
            }
        }

        return franchiseName.trimmingCharacters(in: .whitespaces)
    }
}
