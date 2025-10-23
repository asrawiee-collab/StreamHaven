import Foundation
import CoreData

class SearchIndexSync {

    // Note: FTS5 is not directly supported by Core Data.
    // The search functionality is implemented using standard Core Data queries.
    // For optimal performance, the 'title' and 'name' attributes of the Movie, Series,
    // and Channel entities should be indexed in the Xcode Data Model Editor.

    static func search(query: String, persistence: PersistenceController, completion: @escaping ([NSManagedObject]) -> Void) {
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
