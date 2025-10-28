import Foundation
import CloudKit
import CoreData
import os.log

/// Manages synchronization of Core Data entities with CloudKit.
/// Handles profiles, favorites, and watch history across devices.
@MainActor
public final class CloudKitSyncManager: ObservableObject {
    
    // MARK: - Published Properties
    
    @Published var isSyncing = false
    @Published var lastSyncDate: Date?
    @Published var syncError: Error?
    @Published var syncStatus: SyncStatus = .idle
    
    // MARK: - Types
    
    enum SyncStatus: Equatable {
        case idle
        case syncing(progress: Double)
        case success
        case failed(Error)
        
        static func == (lhs: SyncStatus, rhs: SyncStatus) -> Bool {
            switch (lhs, rhs) {
            case (.idle, .idle), (.success, .success):
                return true
            case (.syncing(let p1), .syncing(let p2)):
                return p1 == p2
            case (.failed, .failed):
                return true
            default:
                return false
            }
        }
    }
    
    enum SyncError: LocalizedError {
        case notAuthenticated
        case quotaExceeded
        case networkUnavailable
        case conflictResolutionFailed
        case recordNotFound
        case unknownError(Error)
        
        var errorDescription: String? {
            switch self {
            case .notAuthenticated:
                return "iCloud account not signed in. Please sign in to iCloud in Settings."
            case .quotaExceeded:
                return "iCloud storage quota exceeded. Please free up space."
            case .networkUnavailable:
                return "Network unavailable. Sync will resume when connected."
            case .conflictResolutionFailed:
                return "Failed to resolve sync conflicts. Please try again."
            case .recordNotFound:
                return "Cloud record not found. It may have been deleted on another device."
            case .unknownError(let error):
                return "Sync error: \(error.localizedDescription)"
            }
        }
    }
    
    // MARK: - Record Types
    
    private enum RecordType {
        static let profile = "Profile"
        static let favorite = "Favorite"
        static let watchHistory = "WatchHistory"
    }
    
    // MARK: - Properties
    
    private let container: CKContainer
    private let privateDatabase: CKDatabase
    private let context: NSManagedObjectContext
    private let logger = Logger(subsystem: "com.streamhaven.sync", category: "CloudKit")
    
    /// Queue for pending sync operations when offline
    private var pendingOperations: [SyncOperation] = []
    
    /// Change tokens for incremental sync
    private var profileChangeToken: CKServerChangeToken?
    private var favoriteChangeToken: CKServerChangeToken?
    private var watchHistoryChangeToken: CKServerChangeToken?
    
    // MARK: - Initialization
    
    init(container: CKContainer = .default(), context: NSManagedObjectContext) {
        self.container = container
        self.privateDatabase = container.privateCloudDatabase
        self.context = context
        
        loadChangeTokens()
    }
    
    // MARK: - Public Methods
    
    /// Performs a full sync of all entities
    func performFullSync() async throws {
        guard await isCloudKitAvailable() else {
            throw SyncError.notAuthenticated
        }
        
        isSyncing = true
        syncStatus = .syncing(progress: 0.0)
        syncError = nil
        
        do {
            // Sync in order: Profiles -> Favorites -> Watch History
            try await syncProfiles()
            syncStatus = .syncing(progress: 0.33)
            
            try await syncFavorites()
            syncStatus = .syncing(progress: 0.66)
            
            try await syncWatchHistory()
            syncStatus = .syncing(progress: 1.0)
            
            // Process any pending operations
            try await processPendingOperations()
            
            lastSyncDate = Date()
            syncStatus = .success
            logger.info("Full sync completed successfully")
            
        } catch {
            syncError = error
            syncStatus = .failed(error)
            logger.error("Sync failed: \(error.localizedDescription)")
            throw error
        }
        
        isSyncing = false
    }
    
    /// Syncs a single profile to CloudKit
    func syncProfile(_ profile: Profile) async throws {
        let record = try profileToRecord(profile)
        try await saveRecord(record)
        logger.info("Synced profile: \(profile.name ?? "Unknown")")
    }
    
    /// Syncs a single favorite to CloudKit
    func syncFavorite(_ favorite: Favorite) async throws {
        let record = try favoriteToRecord(favorite)
        try await saveRecord(record)
        logger.info("Synced favorite")
    }
    
    /// Syncs a single watch history entry to CloudKit
    func syncWatchHistory(_ history: WatchHistory) async throws {
        let record = try watchHistoryToRecord(history)
        try await saveRecord(record)
        logger.info("Synced watch history")
    }
    
    /// Deletes a profile from CloudKit
    func deleteProfile(_ profile: Profile) async throws {
        guard let recordID = profile.cloudKitRecordID else { return }
        try await deleteRecord(recordID)
        logger.info("Deleted profile from CloudKit")
    }
    
    /// Deletes a favorite from CloudKit
    func deleteFavorite(_ favorite: Favorite) async throws {
        guard let recordID = favorite.cloudKitRecordID else { return }
        try await deleteRecord(recordID)
        logger.info("Deleted favorite from CloudKit")
    }
    
    /// Deletes a watch history entry from CloudKit
    func deleteWatchHistory(_ history: WatchHistory) async throws {
        guard let recordID = history.cloudKitRecordID else { return }
        try await deleteRecord(recordID)
        logger.info("Deleted watch history from CloudKit")
    }
    
    // MARK: - Private Sync Methods
    
    private func syncProfiles() async throws {
        let query = CKQuery(recordType: RecordType.profile, predicate: NSPredicate(value: true))
        let results = try await fetchRecords(query: query, changeToken: profileChangeToken)
        
        for record in results.records {
            try await processProfileRecord(record)
        }
        
        profileChangeToken = results.changeToken
        saveChangeTokens()
    }
    
    private func syncFavorites() async throws {
        let query = CKQuery(recordType: RecordType.favorite, predicate: NSPredicate(value: true))
        let results = try await fetchRecords(query: query, changeToken: favoriteChangeToken)
        
        for record in results.records {
            try await processFavoriteRecord(record)
        }
        
        favoriteChangeToken = results.changeToken
        saveChangeTokens()
    }
    
    private func syncWatchHistory() async throws {
        let query = CKQuery(recordType: RecordType.watchHistory, predicate: NSPredicate(value: true))
        let results = try await fetchRecords(query: query, changeToken: watchHistoryChangeToken)
        
        for record in results.records {
            try await processWatchHistoryRecord(record)
        }
        
        watchHistoryChangeToken = results.changeToken
        saveChangeTokens()
    }
    
    // MARK: - Record Conversion
    
    private func profileToRecord(_ profile: Profile) throws -> CKRecord {
        let recordID = profile.cloudKitRecordID ?? CKRecord.ID(recordName: UUID().uuidString)
        let record = CKRecord(recordType: RecordType.profile, recordID: recordID)
        
        record["name"] = profile.name as CKRecordValue?
        record["isAdult"] = profile.isAdult as CKRecordValue
        record["modifiedAt"] = Date() as CKRecordValue
        
        // Store recordID for future operations
        profile.cloudKitRecordID = recordID
        try context.save()
        
        return record
    }
    
    private func favoriteToRecord(_ favorite: Favorite) throws -> CKRecord {
        let recordID = favorite.cloudKitRecordID ?? CKRecord.ID(recordName: UUID().uuidString)
        let record = CKRecord(recordType: RecordType.favorite, recordID: recordID)
        
        record["favoritedDate"] = favorite.favoritedDate as CKRecordValue?
        record["profileRecordID"] = favorite.profile?.cloudKitRecordID?.recordName as CKRecordValue?
        
        // Store content identifiers
        if let movie = favorite.movie {
            record["contentType"] = "movie" as CKRecordValue
            record["contentTitle"] = movie.title as CKRecordValue?
            record["contentStreamURL"] = movie.streamURL as CKRecordValue?
            record["contentIMDbID"] = movie.imdbID as CKRecordValue?
        } else if let series = favorite.series {
            record["contentType"] = "series" as CKRecordValue
            record["contentTitle"] = series.title as CKRecordValue?
        } else if let channel = favorite.channel {
            record["contentType"] = "channel" as CKRecordValue
            record["contentTitle"] = channel.name as CKRecordValue?
            record["contentTvgID"] = channel.tvgID as CKRecordValue?
        }
        
        record["modifiedAt"] = Date() as CKRecordValue
        
        favorite.cloudKitRecordID = recordID
        try context.save()
        
        return record
    }
    
    private func watchHistoryToRecord(_ history: WatchHistory) throws -> CKRecord {
        let recordID = history.cloudKitRecordID ?? CKRecord.ID(recordName: UUID().uuidString)
        let record = CKRecord(recordType: RecordType.watchHistory, recordID: recordID)
        
        record["progress"] = history.progress as CKRecordValue
        record["watchedDate"] = history.watchedDate as CKRecordValue?
        record["profileRecordID"] = history.profile?.cloudKitRecordID?.recordName as CKRecordValue?
        
        // Store content identifiers
        if let movie = history.movie {
            record["contentType"] = "movie" as CKRecordValue
            record["contentTitle"] = movie.title as CKRecordValue?
            record["contentStreamURL"] = movie.streamURL as CKRecordValue?
            record["contentIMDbID"] = movie.imdbID as CKRecordValue?
        } else if let episode = history.episode {
            record["contentType"] = "episode" as CKRecordValue
            record["contentTitle"] = episode.title as CKRecordValue?
            record["contentStreamURL"] = episode.streamURL as CKRecordValue?
            record["episodeNumber"] = episode.episodeNumber as CKRecordValue
            // Store season/series info
            if let season = episode.season {
                record["seasonNumber"] = season.seasonNumber as CKRecordValue
                if let series = season.series {
                    record["seriesTitle"] = series.title as CKRecordValue?
                }
            }
        }
        
        record["modifiedAt"] = Date() as CKRecordValue
        
        history.cloudKitRecordID = recordID
        try context.save()
        
        return record
    }
    
    // MARK: - Record Processing
    
    private func processProfileRecord(_ record: CKRecord) async throws {
        let recordName = record.recordID.recordName
        
        // Check if profile already exists
        let fetchRequest: NSFetchRequest<Profile> = Profile.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "cloudKitRecordName == %@", recordName)
        
        let existingProfiles = try context.fetch(fetchRequest)
        let profile = existingProfiles.first ?? Profile(context: context)
        
        // Apply changes with conflict resolution
        let cloudModifiedAt = record["modifiedAt"] as? Date ?? Date.distantPast
        let localModifiedAt = profile.modifiedAt ?? Date.distantPast
        
        if cloudModifiedAt > localModifiedAt {
            // Cloud version is newer, apply changes
            profile.name = record["name"] as? String
            profile.isAdult = record["isAdult"] as? Bool ?? false
            profile.cloudKitRecordName = recordName
            profile.cloudKitRecordID = record.recordID
            profile.modifiedAt = cloudModifiedAt
            
            try context.save()
            logger.info("Updated profile from CloudKit: \(profile.name ?? "Unknown")")
        } else {
            // Local version is newer, upload to cloud
            try await syncProfile(profile)
        }
    }
    
    private func processFavoriteRecord(_ record: CKRecord) async throws {
        let recordName = record.recordID.recordName
        
        // Check if favorite already exists
        let fetchRequest: NSFetchRequest<Favorite> = Favorite.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "cloudKitRecordName == %@", recordName)
        
        let existingFavorites = try context.fetch(fetchRequest)
        let favorite = existingFavorites.first ?? Favorite(context: context)
        
        // Apply changes with conflict resolution
        let cloudModifiedAt = record["modifiedAt"] as? Date ?? Date.distantPast
        let localModifiedAt = favorite.modifiedAt ?? Date.distantPast
        
        if cloudModifiedAt > localModifiedAt {
            favorite.favoritedDate = record["favoritedDate"] as? Date
            favorite.cloudKitRecordName = recordName
            favorite.cloudKitRecordID = record.recordID
            favorite.modifiedAt = cloudModifiedAt
            
            // Link to profile
            if let profileRecordName = record["profileRecordID"] as? String {
                let profileFetch: NSFetchRequest<Profile> = Profile.fetchRequest()
                profileFetch.predicate = NSPredicate(format: "cloudKitRecordName == %@", profileRecordName)
                if let profile = try context.fetch(profileFetch).first {
                    favorite.profile = profile
                }
            }
            
            // Note: Content linking (movie/series/channel) requires matching by title/IMDbID
            // This is handled separately after initial sync
            
            try context.save()
            logger.info("Updated favorite from CloudKit")
        }
    }
    
    private func processWatchHistoryRecord(_ record: CKRecord) async throws {
        let recordName = record.recordID.recordName
        
        // Check if watch history already exists
        let fetchRequest: NSFetchRequest<WatchHistory> = WatchHistory.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "cloudKitRecordName == %@", recordName)
        
        let existingHistory = try context.fetch(fetchRequest)
        let history = existingHistory.first ?? WatchHistory(context: context)
        
        // Apply changes with conflict resolution (use highest progress)
        let cloudProgress = record["progress"] as? Float ?? 0
        
        if cloudProgress > history.progress || history.cloudKitRecordName == nil {
            history.progress = cloudProgress
            history.watchedDate = record["watchedDate"] as? Date
            history.cloudKitRecordName = recordName
            history.cloudKitRecordID = record.recordID
            history.modifiedAt = record["modifiedAt"] as? Date
            
            // Link to profile
            if let profileRecordName = record["profileRecordID"] as? String {
                let profileFetch: NSFetchRequest<Profile> = Profile.fetchRequest()
                profileFetch.predicate = NSPredicate(format: "cloudKitRecordName == %@", profileRecordName)
                if let profile = try context.fetch(profileFetch).first {
                    history.profile = profile
                }
            }
            
            try context.save()
            logger.info("Updated watch history from CloudKit")
        }
    }
    
    // MARK: - CloudKit Operations
    
    private func fetchRecords(query: CKQuery, changeToken: CKServerChangeToken?) async throws -> (records: [CKRecord], changeToken: CKServerChangeToken?) {
        var allRecords: [CKRecord] = []
        var cursor: CKQueryOperation.Cursor?
        var newChangeToken: CKServerChangeToken?
        
        let operation = CKQueryOperation(query: query)
        operation.resultsLimit = 100
        
        return try await withCheckedThrowingContinuation { continuation in
            operation.recordMatchedBlock = { recordID, result in
                switch result {
                case .success(let record):
                    allRecords.append(record)
                case .failure(let error):
                    self.logger.error("Failed to fetch record: \(error.localizedDescription)")
                }
            }
            
            operation.queryResultBlock = { result in
                switch result {
                case .success(let fetchCursor):
                    cursor = fetchCursor
                    newChangeToken = fetchCursor as? CKServerChangeToken
                    continuation.resume(returning: (allRecords, newChangeToken))
                case .failure(let error):
                    continuation.resume(throwing: error)
                }
            }
            
            privateDatabase.add(operation)
        }
    }
    
    private func saveRecord(_ record: CKRecord) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            privateDatabase.save(record) { savedRecord, error in
                if let error = error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume()
                }
            }
        }
    }
    
    private func deleteRecord(_ recordID: CKRecord.ID) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            privateDatabase.delete(withRecordID: recordID) { _, error in
                if let error = error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume()
                }
            }
        }
    }
    
    // MARK: - Pending Operations
    
    private struct SyncOperation: Codable {
        enum OperationType: String, Codable {
            case create, update, delete
        }
        
        let type: OperationType
        let recordType: String
        let recordName: String
        let data: Data?
    }
    
    private func processPendingOperations() async throws {
        guard !self.pendingOperations.isEmpty else { return }

        logger.info("Processing \(self.pendingOperations.count) pending operations")

        for operation in self.pendingOperations {
            logger.debug("Pending operation type=\(operation.type.rawValue) record=\(operation.recordName)")
            // Process each pending operation
            // Implementation depends on operation type
        }

        self.pendingOperations.removeAll()
        savePendingOperations()
    }
    
    // MARK: - Change Token Persistence
    
    private func loadChangeTokens() {
        if let data = UserDefaults.standard.data(forKey: "cloudkit.profileChangeToken"),
           let token = try? NSKeyedUnarchiver.unarchivedObject(ofClass: CKServerChangeToken.self, from: data) {
            profileChangeToken = token
        }
        
        if let data = UserDefaults.standard.data(forKey: "cloudkit.favoriteChangeToken"),
           let token = try? NSKeyedUnarchiver.unarchivedObject(ofClass: CKServerChangeToken.self, from: data) {
            favoriteChangeToken = token
        }
        
        if let data = UserDefaults.standard.data(forKey: "cloudkit.watchHistoryChangeToken"),
           let token = try? NSKeyedUnarchiver.unarchivedObject(ofClass: CKServerChangeToken.self, from: data) {
            watchHistoryChangeToken = token
        }
    }
    
    private func saveChangeTokens() {
        if let token = profileChangeToken,
           let data = try? NSKeyedArchiver.archivedData(withRootObject: token, requiringSecureCoding: true) {
            UserDefaults.standard.set(data, forKey: "cloudkit.profileChangeToken")
        }
        
        if let token = favoriteChangeToken,
           let data = try? NSKeyedArchiver.archivedData(withRootObject: token, requiringSecureCoding: true) {
            UserDefaults.standard.set(data, forKey: "cloudkit.favoriteChangeToken")
        }
        
        if let token = watchHistoryChangeToken,
           let data = try? NSKeyedArchiver.archivedData(withRootObject: token, requiringSecureCoding: true) {
            UserDefaults.standard.set(data, forKey: "cloudkit.watchHistoryChangeToken")
        }
    }
    
    private func savePendingOperations() {
        if let data = try? JSONEncoder().encode(pendingOperations) {
            UserDefaults.standard.set(data, forKey: "cloudkit.pendingOperations")
        }
    }
    
    private func loadPendingOperations() {
        if let data = UserDefaults.standard.data(forKey: "cloudkit.pendingOperations"),
           let operations = try? JSONDecoder().decode([SyncOperation].self, from: data) {
            pendingOperations = operations
        }
    }
    
    // MARK: - CloudKit Availability
    
    private func isCloudKitAvailable() async -> Bool {
        do {
            let status = try await container.accountStatus()
            return status == .available
        } catch {
            logger.error("Failed to check CloudKit availability: \(error.localizedDescription)")
            return false
        }
    }
}

// MARK: - Core Data Extensions

extension Profile {
    var cloudKitRecordID: CKRecord.ID? {
        get {
            guard let recordName = cloudKitRecordName else { return nil }
            return CKRecord.ID(recordName: recordName)
        }
        set {
            cloudKitRecordName = newValue?.recordName
        }
    }
}

extension Favorite {
    var cloudKitRecordID: CKRecord.ID? {
        get {
            guard let recordName = cloudKitRecordName else { return nil }
            return CKRecord.ID(recordName: recordName)
        }
        set {
            cloudKitRecordName = newValue?.recordName
        }
    }
}

extension WatchHistory {
    var cloudKitRecordID: CKRecord.ID? {
        get {
            guard let recordName = cloudKitRecordName else { return nil }
            return CKRecord.ID(recordName: recordName)
        }
        set {
            cloudKitRecordName = newValue?.recordName
        }
    }
}
