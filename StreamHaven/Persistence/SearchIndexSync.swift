import Foundation
import CoreData

class SearchIndexSync {

    static func search(query: String, context: NSManagedObjectContext) -> [NSManagedObject] {
        var results: [NSManagedObject] = []

        let movieFetchRequest: NSFetchRequest<Movie> = Movie.fetchRequest()
        movieFetchRequest.predicate = NSPredicate(format: "title CONTAINS[cd] %@", query)

        let seriesFetchRequest: NSFetchRequest<Series> = Series.fetchRequest()
        seriesFetchRequest.predicate = NSPredicate(format: "title CONTAINS[cd] %@", query)

        let channelFetchRequest: NSFetchRequest<Channel> = Channel.fetchRequest()
        channelFetchRequest.predicate = NSPredicate(format: "name CONTAINS[cd] %@", query)

        do {
            let movies = try context.fetch(movieFetchRequest)
            results.append(contentsOf: movies)

            let series = try context.fetch(seriesFetchRequest)
            results.append(contentsOf: series)

            let channels = try context.fetch(channelFetchRequest)
            results.append(contentsOf: channels)
        } catch {
            print("Failed to perform search for query: \\(query). Error: \\(error)")
        }

        return results
    }
}
