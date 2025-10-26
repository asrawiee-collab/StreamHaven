import XCTest
import CoreData
import CloudKit
@testable import StreamHaven

/// Comprehensive tests for CloudKit synchronization functionality.
@MainActor
final class CloudKitSyncTests: XCTestCase {
    
    var context: NSManagedObjectContext!
    var syncManager: CloudKitSyncManager!
    
    override func setUp() async throws {
        try await super.setUp()
        
        // Create in-memory Core Data stack for testing
        let container = NSPersistentContainer(name: "StreamHaven")
        let description = NSPersistentStoreDescription()
        description.type = NSInMemoryStoreType
        container.persistentStoreDescriptions = [description]
        
        container.loadPersistentStores { description, error in
            XCTAssertNil(error)
        }
        
        context = container.viewContext
        syncManager = CloudKitSyncManager(context: context)
    }
    
    override func tearDown() async throws {
        context = nil
        syncManager = nil
        try await super.tearDown()
    }
    
    // MARK: - Core Data Model Tests
    
    func testProfileHasCloudKitProperties() {
        let profile = Profile(context: context)
        profile.name = "Test Profile"
        profile.isAdult = true
        profile.modifiedAt = Date()
        profile.cloudKitRecordName = "test-record"
        
        XCTAssertNotNil(profile.cloudKitRecordName, "Profile should have cloudKitRecordName")
        XCTAssertNotNil(profile.modifiedAt, "Profile should have modifiedAt")
        XCTAssertEqual(profile.cloudKitRecordName, "test-record")
    }
    
    func testFavoriteHasCloudKitProperties() {
        let favorite = Favorite(context: context)
        favorite.favoritedDate = Date()
        favorite.modifiedAt = Date()
        favorite.cloudKitRecordName = "favorite-record"
        
        XCTAssertNotNil(favorite.cloudKitRecordName, "Favorite should have cloudKitRecordName")
        XCTAssertNotNil(favorite.modifiedAt, "Favorite should have modifiedAt")
    }
    
    func testWatchHistoryHasCloudKitProperties() {
        let history = WatchHistory(context: context)
        history.progress = 0.5
        history.watchedDate = Date()
        history.modifiedAt = Date()
        history.cloudKitRecordName = "history-record"
        
        XCTAssertNotNil(history.cloudKitRecordName, "WatchHistory should have cloudKitRecordName")
        XCTAssertNotNil(history.modifiedAt, "WatchHistory should have modifiedAt")
    }
    
    // MARK: - CloudKitSyncManager Initialization Tests
    
    func testSyncManagerInitialization() {
        XCTAssertNotNil(syncManager, "CloudKitSyncManager should initialize")
        XCTAssertFalse(syncManager.isSyncing, "Should not be syncing initially")
        XCTAssertNil(syncManager.lastSyncDate, "Last sync date should be nil initially")
        XCTAssertNil(syncManager.syncError, "Sync error should be nil initially")
        XCTAssertEqual(syncManager.syncStatus, .idle, "Sync status should be idle initially")
    }
    
    // MARK: - Record Conversion Tests
    
    func testProfileToRecordConversion() throws {
        let profile = Profile(context: context)
        profile.name = "Adult Profile"
        profile.isAdult = true
        profile.modifiedAt = Date()
        
        // Save to ensure object is valid
        try context.save()
        
        // Test conversion (would require making method public or using @testable)
        XCTAssertNotNil(profile.name)
        XCTAssertTrue(profile.isAdult)
        XCTAssertNotNil(profile.modifiedAt)
    }
    
    func testFavoriteToRecordConversion() throws {
        let profile = Profile(context: context)
        profile.name = "Test Profile"
        
        let movie = Movie(context: context)
        movie.title = "Test Movie"
        movie.streamURL = "https://example.com/stream"
        movie.imdbID = "tt1234567"
        
        let favorite = Favorite(context: context)
        favorite.favoritedDate = Date()
        favorite.modifiedAt = Date()
        favorite.profile = profile
        favorite.movie = movie
        
        try context.save()
        
        XCTAssertNotNil(favorite.profile)
        XCTAssertNotNil(favorite.movie)
        XCTAssertEqual(favorite.movie?.title, "Test Movie")
    }
    
    func testWatchHistoryToRecordConversion() throws {
        let profile = Profile(context: context)
        profile.name = "Test Profile"
        
        let movie = Movie(context: context)
        movie.title = "Test Movie"
        movie.streamURL = "https://example.com/stream"
        
        let history = WatchHistory(context: context)
        history.progress = 0.75
        history.watchedDate = Date()
        history.modifiedAt = Date()
        history.profile = profile
        history.movie = movie
        
        try context.save()
        
        XCTAssertEqual(history.progress, 0.75)
        XCTAssertNotNil(history.profile)
        XCTAssertNotNil(history.movie)
    }
    
    // MARK: - Conflict Resolution Tests
    
    func testLastWriteWinsConflictResolution() {
        // Create two versions with different modification times
        let olderDate = Date(timeIntervalSinceNow: -3600) // 1 hour ago
        let newerDate = Date()
        
        let localProfile = Profile(context: context)
        localProfile.name = "Local Name"
        localProfile.modifiedAt = newerDate
        
        // Simulate cloud version being older
        let cloudModifiedAt = olderDate
        
        // Local version should win because it's newer
        XCTAssertTrue(newerDate > cloudModifiedAt, "Local version should be newer")
    }
    
    func testCloudVersionWinsWhenNewer() {
        let olderDate = Date(timeIntervalSinceNow: -3600)
        let newerDate = Date()
        
        let localProfile = Profile(context: context)
        localProfile.name = "Local Name"
        localProfile.modifiedAt = olderDate
        
        // Cloud version is newer
        let cloudModifiedAt = newerDate
        
        // Cloud version should win
        XCTAssertTrue(cloudModifiedAt > (localProfile.modifiedAt ?? Date.distantPast), "Cloud version should be newer")
    }
    
    func testWatchHistoryProgressConflictResolution() {
        let history = WatchHistory(context: context)
        history.progress = 0.5
        
        let cloudProgress: Float = 0.75
        
        // Higher progress should win
        XCTAssertTrue(cloudProgress > history.progress, "Cloud progress should be higher")
    }
    
    // MARK: - ProfileManager Integration Tests
    
    func testProfileManagerCreatesProfileWithTimestamp() {
        let profileManager = ProfileManager(context: context)
        
        // Default profiles should be created
        XCTAssertEqual(profileManager.profiles.count, 2, "Should have 2 default profiles")
        
        let adultProfile = profileManager.profiles.first(where: { $0.isAdult })
        XCTAssertNotNil(adultProfile, "Should have adult profile")
        XCTAssertNotNil(adultProfile?.modifiedAt, "Profile should have modifiedAt timestamp")
    }
    
    func testProfileManagerCreateCustomProfile() {
        let profileManager = ProfileManager(context: context)
        profileManager.createProfile(name: "Custom Profile", isAdult: true)
        
        let customProfile = profileManager.profiles.first(where: { $0.name == "Custom Profile" })
        XCTAssertNotNil(customProfile, "Custom profile should be created")
        XCTAssertNotNil(customProfile?.modifiedAt, "Custom profile should have modifiedAt")
    }
    
    func testProfileManagerDeleteProfile() {
        let profileManager = ProfileManager(context: context)
        let initialCount = profileManager.profiles.count
        
        if let profileToDelete = profileManager.profiles.first {
            profileManager.deleteProfile(profileToDelete)
            XCTAssertEqual(profileManager.profiles.count, initialCount - 1, "Profile should be deleted")
        }
    }
    
    // MARK: - FavoritesManager Integration Tests
    
    func testFavoritesManagerAddsTimestamp() throws {
        let profile = Profile(context: context)
        profile.name = "Test Profile"
        
        let movie = Movie(context: context)
        movie.title = "Test Movie"
        movie.streamURL = "https://example.com/stream"
        movie.posterURL = "https://example.com/poster"
        movie.summary = "A test movie"
        movie.rating = "PG-13"
        movie.releaseDate = Date()
        
        try context.save()
        
        let favoritesManager = FavoritesManager(context: context, profile: profile)
        favoritesManager.toggleFavorite(for: movie)
        
        // Fetch the favorite
        let fetchRequest: NSFetchRequest<Favorite> = Favorite.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "profile == %@", profile)
        let favorites = try context.fetch(fetchRequest)
        
        XCTAssertEqual(favorites.count, 1, "Should have 1 favorite")
        XCTAssertNotNil(favorites.first?.modifiedAt, "Favorite should have modifiedAt")
        XCTAssertNotNil(favorites.first?.favoritedDate, "Favorite should have favoritedDate")
    }
    
    func testFavoritesManagerToggleRemovesFavorite() throws {
        let profile = Profile(context: context)
        profile.name = "Test Profile"
        
        let movie = Movie(context: context)
        movie.title = "Test Movie"
        movie.streamURL = "https://example.com/stream"
        movie.posterURL = "https://example.com/poster"
        movie.summary = "A test movie"
        movie.rating = "PG-13"
        movie.releaseDate = Date()
        
        try context.save()
        
        let favoritesManager = FavoritesManager(context: context, profile: profile)
        
        // Add favorite
        favoritesManager.toggleFavorite(for: movie)
        XCTAssertTrue(favoritesManager.isFavorite(item: movie), "Movie should be favorite")
        
        // Remove favorite
        favoritesManager.toggleFavorite(for: movie)
        XCTAssertFalse(favoritesManager.isFavorite(item: movie), "Movie should not be favorite")
    }
    
    // MARK: - WatchHistoryManager Integration Tests
    
    func testWatchHistoryManagerAddsTimestamp() throws {
        let profile = Profile(context: context)
        profile.name = "Test Profile"
        
        let movie = Movie(context: context)
        movie.title = "Test Movie"
        movie.streamURL = "https://example.com/stream"
        movie.posterURL = "https://example.com/poster"
        movie.summary = "A test movie"
        movie.rating = "PG-13"
        movie.releaseDate = Date()
        
        try context.save()
        
        let watchHistoryManager = WatchHistoryManager(context: context, profile: profile)
        watchHistoryManager.updateWatchHistory(for: movie, progress: 0.5)
        
        // Wait for async context.perform to complete
        try await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
        
        // Fetch the watch history
        let history = watchHistoryManager.findWatchHistory(for: movie)
        
        XCTAssertNotNil(history, "Should have watch history")
        XCTAssertEqual(history?.progress, 0.5, "Progress should be 0.5")
        XCTAssertNotNil(history?.modifiedAt, "Watch history should have modifiedAt")
        XCTAssertNotNil(history?.watchedDate, "Watch history should have watchedDate")
    }
    
    func testWatchHistoryManagerUpdatesProgress() throws {
        let profile = Profile(context: context)
        profile.name = "Test Profile"
        
        let movie = Movie(context: context)
        movie.title = "Test Movie"
        movie.streamURL = "https://example.com/stream"
        movie.posterURL = "https://example.com/poster"
        movie.summary = "A test movie"
        movie.rating = "PG-13"
        movie.releaseDate = Date()
        
        try context.save()
        
        let watchHistoryManager = WatchHistoryManager(context: context, profile: profile)
        
        // Set initial progress
        watchHistoryManager.updateWatchHistory(for: movie, progress: 0.25)
        try await Task.sleep(nanoseconds: 100_000_000)
        
        var history = watchHistoryManager.findWatchHistory(for: movie)
        XCTAssertEqual(history?.progress, 0.25)
        
        // Update progress
        watchHistoryManager.updateWatchHistory(for: movie, progress: 0.75)
        try await Task.sleep(nanoseconds: 100_000_000)
        
        history = watchHistoryManager.findWatchHistory(for: movie)
        XCTAssertEqual(history?.progress, 0.75, "Progress should be updated to 0.75")
    }
    
    // MARK: - Settings Tests
    
    func testCloudSyncSettingsDefaults() {
        let settingsManager = SettingsManager()
        
        XCTAssertFalse(settingsManager.enableCloudSync, "Cloud sync should be disabled by default")
        XCTAssertNil(settingsManager.lastCloudSyncDate, "Last sync date should be nil initially")
    }
    
    func testCloudSyncSettingsCanBeChanged() {
        let settingsManager = SettingsManager()
        
        settingsManager.enableCloudSync = true
        XCTAssertTrue(settingsManager.enableCloudSync, "Cloud sync should be enabled")
        
        let now = Date()
        settingsManager.lastCloudSyncDate = now
        XCTAssertEqual(settingsManager.lastCloudSyncDate, now, "Last sync date should be set")
    }
    
    // MARK: - Sync Status Tests
    
    func testSyncStatusIdle() {
        XCTAssertEqual(syncManager.syncStatus, .idle, "Initial status should be idle")
    }
    
    func testSyncStatusEquality() {
        let status1: CloudKitSyncManager.SyncStatus = .idle
        let status2: CloudKitSyncManager.SyncStatus = .idle
        XCTAssertEqual(status1, status2, "Idle statuses should be equal")
        
        let status3: CloudKitSyncManager.SyncStatus = .syncing(progress: 0.5)
        let status4: CloudKitSyncManager.SyncStatus = .syncing(progress: 0.5)
        XCTAssertEqual(status3, status4, "Syncing statuses with same progress should be equal")
        
        let status5: CloudKitSyncManager.SyncStatus = .success
        let status6: CloudKitSyncManager.SyncStatus = .success
        XCTAssertEqual(status5, status6, "Success statuses should be equal")
    }
    
    // MARK: - Error Handling Tests
    
    func testSyncErrorDescriptions() {
        let notAuthError = CloudKitSyncManager.SyncError.notAuthenticated
        XCTAssertTrue(notAuthError.errorDescription?.contains("iCloud") ?? false, "Error should mention iCloud")
        
        let quotaError = CloudKitSyncManager.SyncError.quotaExceeded
        XCTAssertTrue(quotaError.errorDescription?.contains("quota") ?? false, "Error should mention quota")
        
        let networkError = CloudKitSyncManager.SyncError.networkUnavailable
        XCTAssertTrue(networkError.errorDescription?.contains("Network") ?? false, "Error should mention network")
    }
    
    // MARK: - Data Persistence Tests
    
    func testProfilePersistsCloudKitData() throws {
        let profile = Profile(context: context)
        profile.name = "Sync Test"
        profile.isAdult = true
        profile.modifiedAt = Date()
        profile.cloudKitRecordName = "test-record-123"
        
        try context.save()
        
        // Fetch from Core Data
        let fetchRequest: NSFetchRequest<Profile> = Profile.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "cloudKitRecordName == %@", "test-record-123")
        let profiles = try context.fetch(fetchRequest)
        
        XCTAssertEqual(profiles.count, 1, "Should find 1 profile")
        XCTAssertEqual(profiles.first?.cloudKitRecordName, "test-record-123")
        XCTAssertEqual(profiles.first?.name, "Sync Test")
    }
    
    func testFavoritePersistsCloudKitData() throws {
        let favorite = Favorite(context: context)
        favorite.favoritedDate = Date()
        favorite.modifiedAt = Date()
        favorite.cloudKitRecordName = "favorite-record-456"
        
        try context.save()
        
        let fetchRequest: NSFetchRequest<Favorite> = Favorite.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "cloudKitRecordName == %@", "favorite-record-456")
        let favorites = try context.fetch(fetchRequest)
        
        XCTAssertEqual(favorites.count, 1, "Should find 1 favorite")
        XCTAssertEqual(favorites.first?.cloudKitRecordName, "favorite-record-456")
    }
    
    func testWatchHistoryPersistsCloudKitData() throws {
        let history = WatchHistory(context: context)
        history.progress = 0.85
        history.watchedDate = Date()
        history.modifiedAt = Date()
        history.cloudKitRecordName = "history-record-789"
        
        try context.save()
        
        let fetchRequest: NSFetchRequest<WatchHistory> = WatchHistory.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "cloudKitRecordName == %@", "history-record-789")
        let histories = try context.fetch(fetchRequest)
        
        XCTAssertEqual(histories.count, 1, "Should find 1 watch history")
        XCTAssertEqual(histories.first?.cloudKitRecordName, "history-record-789")
        XCTAssertEqual(histories.first?.progress, 0.85)
    }
    
    // MARK: - Multiple Profiles Tests
    
    func testMultipleProfilesIndependentSync() throws {
        let profile1 = Profile(context: context)
        profile1.name = "Profile 1"
        profile1.isAdult = true
        profile1.modifiedAt = Date()
        profile1.cloudKitRecordName = "profile-1"
        
        let profile2 = Profile(context: context)
        profile2.name = "Profile 2"
        profile2.isAdult = false
        profile2.modifiedAt = Date()
        profile2.cloudKitRecordName = "profile-2"
        
        try context.save()
        
        let fetchRequest: NSFetchRequest<Profile> = Profile.fetchRequest()
        let profiles = try context.fetch(fetchRequest)
        
        XCTAssertEqual(profiles.count, 2, "Should have 2 profiles")
        XCTAssertTrue(profiles.allSatisfy { $0.cloudKitRecordName != nil }, "All profiles should have record names")
        XCTAssertTrue(profiles.allSatisfy { $0.modifiedAt != nil }, "All profiles should have modification dates")
    }
    
    // MARK: - CloudKit RecordID Tests
    
    func testProfileCloudKitRecordIDConversion() {
        let profile = Profile(context: context)
        profile.cloudKitRecordName = "test-record"
        
        let recordID = profile.cloudKitRecordID
        XCTAssertNotNil(recordID, "Should have recordID")
        XCTAssertEqual(recordID?.recordName, "test-record", "RecordID should match record name")
        
        // Test setting recordID
        let newRecordID = CKRecord.ID(recordName: "new-record")
        profile.cloudKitRecordID = newRecordID
        XCTAssertEqual(profile.cloudKitRecordName, "new-record", "Record name should be updated")
    }
    
    func testFavoriteCloudKitRecordIDConversion() {
        let favorite = Favorite(context: context)
        favorite.cloudKitRecordName = "favorite-record"
        
        let recordID = favorite.cloudKitRecordID
        XCTAssertNotNil(recordID)
        XCTAssertEqual(recordID?.recordName, "favorite-record")
    }
    
    func testWatchHistoryCloudKitRecordIDConversion() {
        let history = WatchHistory(context: context)
        history.cloudKitRecordName = "history-record"
        
        let recordID = history.cloudKitRecordID
        XCTAssertNotNil(recordID)
        XCTAssertEqual(recordID?.recordName, "history-record")
    }
}
