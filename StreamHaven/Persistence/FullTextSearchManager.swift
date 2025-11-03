import CoreData
import Foundation
import SQLite3

/// Advanced full-text search manager using SQLite FTS5 for fuzzy and fast search.
public final class FullTextSearchManager {
    
    private let persistenceProvider: PersistenceProviding
    private var ftsInitialized = false
    
    /// Initializes the full-text search manager.
    public init(persistenceProvider: PersistenceProviding) {
        self.persistenceProvider = persistenceProvider
    }
    
    /// Initializes FTS5 virtual tables for movies, series, and channels.
    ///
    /// This should be called once after the app launches or when Core Data is set up.
    /// Creates virtual tables that mirror the searchable content from Core Data.
    public func initializeFullTextSearch() throws {
        guard !ftsInitialized else { return }
        
        let context = persistenceProvider.container.newBackgroundContext()
        
        try context.performAndWait {
            guard let storeURL = persistenceProvider.container.persistentStoreDescriptions.first?.url, let storeURLPath = storeURL.path as String? else {
                throw NSError(domain: "FullTextSearchManager", code: 1, userInfo: [NSLocalizedDescriptionKey: "Could not find Core Data store URL"])
            }
            
            var db: OpaquePointer?
            guard sqlite3_open(storeURLPath, &db) == SQLITE_OK, let database = db else {
                throw NSError(domain: "FullTextSearchManager", code: 2, userInfo: [NSLocalizedDescriptionKey: "Failed to open SQLite database"])
            }
            defer { sqlite3_close(database) }
            
            // Create FTS5 virtual table for movies (use stableID for lookups)
            let createMovieFTS = """
            CREATE VIRTUAL TABLE IF NOT EXISTS movie_fts USING fts5(
                stableID UNINDEXED, title, tokenize='porter unicode61'
            );
            """
            
            // Create FTS5 virtual table for series
            let createSeriesFTS = """
            CREATE VIRTUAL TABLE IF NOT EXISTS series_fts USING fts5(
                stableID UNINDEXED, title, tokenize='porter unicode61'
            );
            """
            
            // Create FTS5 virtual table for channels
            let createChannelFTS = """
            CREATE VIRTUAL TABLE IF NOT EXISTS channel_fts USING fts5(
                stableID UNINDEXED, name, tokenize='porter unicode61'
            );
            """
            
            // Execute FTS table creation
            try [createMovieFTS, createSeriesFTS, createChannelFTS].forEach { sql in
                var errMsg: UnsafeMutablePointer<CChar>?
                if sqlite3_exec(database, sql, nil, nil, &errMsg) != SQLITE_OK {
                    let error = errMsg.map { String(cString: $0) } ?? "Unknown error"
                    if let e = errMsg { sqlite3_free(e) }
                    throw NSError(domain: "FullTextSearchManager", code: 3, userInfo: [NSLocalizedDescriptionKey: "FTS5 creation failed: \(error)"])
                }
            }
            
            // Create triggers to keep FTS in sync
            try createFTSTriggers(db: database)
            
            // Initial population of FTS tables
            try populateFTSTables(context: context, db: database)
            
            ftsInitialized = true
        }
    }
    
    /// Creates triggers to automatically update FTS tables when Core Data entities change.
    private func createFTSTriggers(db: OpaquePointer) throws {
        let triggers = [
            // Movie triggers
            """
            CREATE TRIGGER IF NOT EXISTS movie_fts_insert AFTER INSERT ON ZMOVIE BEGIN
                INSERT INTO movie_fts(stableID, title) VALUES (new.ZSTABLEID, new.ZTITLE);
            END;
            """, """
            CREATE TRIGGER IF NOT EXISTS movie_fts_update AFTER UPDATE ON ZMOVIE BEGIN
                UPDATE movie_fts SET title = new.ZTITLE WHERE stableID = old.ZSTABLEID;
            END;
            """, """
            CREATE TRIGGER IF NOT EXISTS movie_fts_delete AFTER DELETE ON ZMOVIE BEGIN
                DELETE FROM movie_fts WHERE stableID = old.ZSTABLEID;
            END;
            """, // Series triggers
            """
            CREATE TRIGGER IF NOT EXISTS series_fts_insert AFTER INSERT ON ZSERIES BEGIN
                INSERT INTO series_fts(stableID, title) VALUES (new.ZSTABLEID, new.ZTITLE);
            END;
            """, """
            CREATE TRIGGER IF NOT EXISTS series_fts_update AFTER UPDATE ON ZSERIES BEGIN
                UPDATE series_fts SET title = new.ZTITLE WHERE stableID = old.ZSTABLEID;
            END;
            """, """
            CREATE TRIGGER IF NOT EXISTS series_fts_delete AFTER DELETE ON ZSERIES BEGIN
                DELETE FROM series_fts WHERE stableID = old.ZSTABLEID;
            END;
            """, // Channel triggers
            """
            CREATE TRIGGER IF NOT EXISTS channel_fts_insert AFTER INSERT ON ZCHANNEL BEGIN
                INSERT INTO channel_fts(stableID, name) VALUES (new.ZSTABLEID, new.ZNAME);
            END;
            """, """
            CREATE TRIGGER IF NOT EXISTS channel_fts_update AFTER UPDATE ON ZCHANNEL BEGIN
                UPDATE channel_fts SET name = new.ZNAME WHERE stableID = old.ZSTABLEID;
            END;
            """, """
            CREATE TRIGGER IF NOT EXISTS channel_fts_delete AFTER DELETE ON ZCHANNEL BEGIN
                DELETE FROM channel_fts WHERE stableID = old.ZSTABLEID;
            END;
            """
        ]
        
        for trigger in triggers {
            var errMsg: UnsafeMutablePointer<CChar>?
            if sqlite3_exec(db, trigger, nil, nil, &errMsg) != SQLITE_OK {
                let error = errMsg.map { String(cString: $0) } ?? "Unknown error"
                if let e = errMsg { sqlite3_free(e) }
                throw NSError(domain: "FullTextSearchManager", code: 4, userInfo: [NSLocalizedDescriptionKey: "Trigger creation failed: \(error)"])
            }
        }
    }
    
    /// Populates FTS tables with existing data from Core Data.
    private func populateFTSTables(context: NSManagedObjectContext, db: OpaquePointer) throws {
        // Populate movies
        let movieFetch: NSFetchRequest<Movie> = Movie.fetchRequest()
        let movies = try context.fetch(movieFetch)
        
        for movie in movies {
            // Ensure stableID exists
            if movie.stableID == nil { movie.stableID = UUID().uuidString }
            guard let title = movie.title, let stableID = movie.stableID else { continue }
            let sql = "INSERT OR REPLACE INTO movie_fts(stableID, title) VALUES (?, ?);"
            var stmt: OpaquePointer?
            
            if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK {
                sqlite3_bind_text(stmt, 1, (stableID as NSString).utf8String, -1, nil)
                sqlite3_bind_text(stmt, 2, (title as NSString).utf8String, -1, nil)
                sqlite3_step(stmt)
            }
            sqlite3_finalize(stmt)
        }
        
        // Populate series
        let seriesFetch: NSFetchRequest<Series> = Series.fetchRequest()
        let series = try context.fetch(seriesFetch)
        
        for show in series {
            if show.stableID == nil { show.stableID = UUID().uuidString }
            guard let title = show.title, let stableID = show.stableID else { continue }
            let sql = "INSERT OR REPLACE INTO series_fts(stableID, title) VALUES (?, ?);"
            var stmt: OpaquePointer?
            
            if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK {
                sqlite3_bind_text(stmt, 1, (stableID as NSString).utf8String, -1, nil)
                sqlite3_bind_text(stmt, 2, (title as NSString).utf8String, -1, nil)
                sqlite3_step(stmt)
            }
            sqlite3_finalize(stmt)
        }
        
        // Populate channels
        let channelFetch: NSFetchRequest<Channel> = Channel.fetchRequest()
        let channels = try context.fetch(channelFetch)
        
        for channel in channels {
            if channel.stableID == nil { channel.stableID = UUID().uuidString }
            guard let name = channel.name, let stableID = channel.stableID else { continue }
            let sql = "INSERT OR REPLACE INTO channel_fts(stableID, name) VALUES (?, ?);"
            var stmt: OpaquePointer?
            
            if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK {
                sqlite3_bind_text(stmt, 1, (stableID as NSString).utf8String, -1, nil)
                sqlite3_bind_text(stmt, 2, (name as NSString).utf8String, -1, nil)
                sqlite3_step(stmt)
            }
            sqlite3_finalize(stmt)
        }
    }
    
    /// Performs a fuzzy full-text search across movies, series, and channels.
    ///
    /// - Parameters:
    ///   - query: The search query string.
    ///   - maxResults: Maximum number of results to return per category.
    ///   - completion: Callback with search results.
    public func fuzzySearch(
        query: String, maxResults: Int = 50, completion: @escaping ([NSManagedObject]) -> Void
    ) {
        let context = persistenceProvider.container.newBackgroundContext()
        
        context.perform {
            guard let storeURL = self.persistenceProvider.container.persistentStoreDescriptions.first?.url, let storeURLPath = storeURL.path as String? else {
                completion([])
                return
            }
            
            var db: OpaquePointer?
            guard sqlite3_open(storeURLPath, &db) == SQLITE_OK, let database = db else {
                completion([])
                return
            }
            defer { sqlite3_close(database) }
            
            // Fuzzy search pattern: prefix* for partial matching
            let fuzzyQuery = query.split(separator: " ").map { "\($0)*" }.joined(separator: " ")
            
            var results: [NSManagedObject] = []
            
            // Search movies
            let movieSQL = """
            SELECT stableID, rank FROM movie_fts
            WHERE movie_fts MATCH ?
            ORDER BY rank
            LIMIT ?;
            """
            
            if let movieIDs = self.executeFTSQueryStrings(db: database, sql: movieSQL, query: fuzzyQuery, limit: maxResults) {
                results.append(contentsOf: self.fetchMovies(context: context, stableIDs: movieIDs))
            }
            
            // Search series
            let seriesSQL = """
            SELECT stableID, rank FROM series_fts
            WHERE series_fts MATCH ?
            ORDER BY rank
            LIMIT ?;
            """
            
            if let seriesIDs = self.executeFTSQueryStrings(db: database, sql: seriesSQL, query: fuzzyQuery, limit: maxResults) {
                results.append(contentsOf: self.fetchSeries(context: context, stableIDs: seriesIDs))
            }
            
            // Search channels
            let channelSQL = """
            SELECT stableID, rank FROM channel_fts
            WHERE channel_fts MATCH ?
            ORDER BY rank
            LIMIT ?;
            """
            
            if let channelIDs = self.executeFTSQueryStrings(db: database, sql: channelSQL, query: fuzzyQuery, limit: maxResults) {
                results.append(contentsOf: self.fetchChannels(context: context, stableIDs: channelIDs))
            }
            
            DispatchQueue.main.async {
                completion(results)
            }
        }
    }
    
    /// Executes FTS query and returns matching row IDs.
    private func executeFTSQueryStrings(db: OpaquePointer, sql: String, query: String, limit: Int) -> [String]? {
        var stmt: OpaquePointer?
        var ids: [String] = []
        
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
            return nil
        }
        defer { sqlite3_finalize(stmt) }
        
        sqlite3_bind_text(stmt, 1, (query as NSString).utf8String, -1, nil)
        sqlite3_bind_int(stmt, 2, Int32(limit))
        
        while sqlite3_step(stmt) == SQLITE_ROW {
            if let cString = sqlite3_column_text(stmt, 0) {
                let idStr = String(cString: cString)
                ids.append(idStr)
            }
        }
        
        return ids
    }
    
    /// Fetches Movie entities by hash-based IDs.
    private func fetchMovies(context: NSManagedObjectContext, stableIDs: [String]) -> [Movie] {
        let fetchRequest: NSFetchRequest<Movie> = Movie.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "stableID IN %@", stableIDs)
        return (try? context.fetch(fetchRequest)) ?? []
    }
    
    /// Fetches Series entities by hash-based IDs.
    private func fetchSeries(context: NSManagedObjectContext, stableIDs: [String]) -> [Series] {
        let fetchRequest: NSFetchRequest<Series> = Series.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "stableID IN %@", stableIDs)
        return (try? context.fetch(fetchRequest)) ?? []
    }
    
    /// Fetches Channel entities by hash-based IDs.
    private func fetchChannels(context: NSManagedObjectContext, stableIDs: [String]) -> [Channel] {
        let fetchRequest: NSFetchRequest<Channel> = Channel.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "stableID IN %@", stableIDs)
        return (try? context.fetch(fetchRequest)) ?? []
    }
}
