import Foundation
import CoreData

@objc(Movie)
public class Movie: NSManagedObject {

}

extension Movie {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<Movie> {
        return NSFetchRequest<Movie>(entityName: "Movie")
    }

    @NSManaged public var posterURL: String?
    @NSManaged public var rating: String?
    @NSManaged public var releaseDate: Date?
    @NSManaged public var summary: String?
    @NSManaged public var title: String?
    @NSManaged public var watchHistory: WatchHistory?
    @NSManaged public var favorite: Favorite?

}
