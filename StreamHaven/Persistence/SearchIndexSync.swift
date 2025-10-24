import Foundation
import CoreData

/// A class for performing searches across the Core Data store.
public class SearchIndexSync {

    // Note: FTS5 is not directly supported by Core Data.
    // The search functionality is implemented using standard Core Data queries.
    // For optimal performance, the 'title' and 'name' attributes of the Movie, Series,
    // and Channel entities should be indexed in the Xcode Data Model Editor.

    /// Searches for movies, series, and channels that match a given query.
    ///
    /// - Parameters:
    ///   - query: The search query.
    ///   - persistence: The `PersistenceController` to use for the search.
    ///   - completion: A closure that is called with the search results.
    ///   - results: An array of `NSManagedObject`s that match the search query.
    public static func search(query: String, persistence: PersistenceController, completion: @escaping (_ results: [NSManagedObject]) -> Void) {
        let backgroundContext = persistence.container.newBackgroundContext()

        backgroundContext.perform {
            var objectIDs: [NSManagedObjectID] = []

            do {
                let movieFetchRequest: NSFetchRequest<Movie> = Movie.fetchRequest()
                movieFetchRequest.predicate = NSPredicate(format: "title CONTAINS[cd] %@", query)
                let movies = try backgroundContext.fetch(movieFetchRequest)
                objectIDs.append(contentsOf: movies.map { $0.objectID })

                let seriesFetchRequest: NSFetchRequest<Series> = Series.fetchRequest()
                seriesFetchRequest.predicate = NSPredicate(format: "title CONTAINS[cd] %@", query)
                let series = try backgroundContext.fetch(seriesFetchRequest)
                objectIDs.append(contentsOf: series.map { $0.objectID })

                let channelFetchRequest: NSFetchRequest<Channel> = Channel.fetchRequest()
                channelFetchRequest.predicate = NSPredicate(format: "name CONTAINS[cd] %@", query)
                let channels = try backgroundContext.fetch(channelFetchRequest)
                objectIDs.append(contentsOf: channels.map { $0.objectID })

            } catch {
                print("Failed to perform search for query: \(query). Error: \(error)")
            }

            DispatchQueue.main.async {
                let mainContext = persistence.container.viewContext
                let finalResults = objectIDs.compactMap { mainContext.object(with: $0) }
                completion(finalResults)
            }
        }
    }
}
