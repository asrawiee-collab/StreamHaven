import XCTest
import CoreData
@testable import StreamHaven

/// Tests for ProfileManager.
@MainActor
final class ProfileManagerTests: XCTestCase {
    var profileManager: ProfileManager!
    var context: NSManagedObjectContext!
    var persistenceProvider: PersistenceProviding!
    
    override func setUp() async throws {
        try await super.setUp()
        
        // Create in-memory Core Data stack
        let container = NSPersistentContainer(
            name: "StreamHavenTest",
            managedObjectModel: TestCoreDataModelBuilder.sharedModel
        )
        
        let description = NSPersistentStoreDescription()
        description.type = NSInMemoryStoreType
        container.persistentStoreDescriptions = [description]
        
        var loadError: Error?
        container.loadPersistentStores { _, error in
            loadError = error
        }
        
        if let error = loadError {
            throw XCTSkip("Failed to load in-memory store: \(error)")
        }
        
        context = container.viewContext
        
        struct TestProvider: PersistenceProviding {
            let container: NSPersistentContainer
        }
        persistenceProvider = TestProvider(container: container)
        
        // Initialize ProfileManager (will create default profiles)
        profileManager = ProfileManager(context: context)
    }
    
    override func tearDown() async throws {
        profileManager = nil
        context = nil
        persistenceProvider = nil
        try await super.tearDown()
    }
    
    // MARK: - Initialization Tests
    
    func testProfileManagerInitialization() {
        XCTAssertNotNil(profileManager, "ProfileManager should initialize")
        XCTAssertFalse(profileManager.profiles.isEmpty, "Should have profiles after initialization")
    }
    
    func testDefaultProfilesCreation() {
        // ProfileManager automatically creates Adult and Kids profiles on first launch
        XCTAssertEqual(profileManager.profiles.count, 2, "Should have 2 default profiles")
        
        let profileNames = Set(profileManager.profiles.compactMap { $0.name })
        XCTAssertTrue(profileNames.contains("Adult"), "Should have Adult profile")
        XCTAssertTrue(profileNames.contains("Kids"), "Should have Kids profile")
    }
    
    func testDefaultProfilesConfiguration() {
        let adultProfile = profileManager.profiles.first { $0.name == "Adult" }
        let kidsProfile = profileManager.profiles.first { $0.name == "Kids" }
        
        XCTAssertNotNil(adultProfile, "Adult profile should exist")
        XCTAssertNotNil(kidsProfile, "Kids profile should exist")
        
        XCTAssertTrue(adultProfile?.isAdult == true, "Adult profile should be marked as adult")
        XCTAssertFalse(kidsProfile?.isAdult == true, "Kids profile should not be marked as adult")
    }
    
    // MARK: - Profile Selection Tests
    
    func testSelectProfile() {
        guard let profile = profileManager.profiles.first else {
            XCTFail("Should have at least one profile")
            return
        }
        
        profileManager.selectProfile(profile)
        
        XCTAssertNotNil(profileManager.currentProfile, "Current profile should be set")
        XCTAssertEqual(profileManager.currentProfile?.objectID, profile.objectID, "Should select the correct profile")
    }
    
    func testDeselectProfile() {
        guard let profile = profileManager.profiles.first else {
            XCTFail("Should have at least one profile")
            return
        }
        
        profileManager.selectProfile(profile)
        XCTAssertNotNil(profileManager.currentProfile, "Profile should be selected")
        
        profileManager.deselectProfile()
        XCTAssertNil(profileManager.currentProfile, "Current profile should be nil after deselect")
    }
    
    func testSelectDifferentProfiles() {
        guard profileManager.profiles.count >= 2 else {
            XCTFail("Should have at least 2 profiles")
            return
        }
        
        let profile1 = profileManager.profiles[0]
        let profile2 = profileManager.profiles[1]
        
        profileManager.selectProfile(profile1)
        XCTAssertEqual(profileManager.currentProfile?.objectID, profile1.objectID)
        
        profileManager.selectProfile(profile2)
        XCTAssertEqual(profileManager.currentProfile?.objectID, profile2.objectID, "Should switch to new profile")
    }
    
    // MARK: - Profile Creation Tests
    
    func testCreateAdultProfile() {
        let initialCount = profileManager.profiles.count
        
        profileManager.createProfile(name: "New Adult", isAdult: true)
        
        XCTAssertEqual(profileManager.profiles.count, initialCount + 1, "Should have one more profile")
        
        let newProfile = profileManager.profiles.first { $0.name == "New Adult" }
        XCTAssertNotNil(newProfile, "New profile should exist")
        XCTAssertTrue(newProfile?.isAdult == true, "New profile should be adult")
    }
    
    func testCreateKidsProfile() {
        let initialCount = profileManager.profiles.count
        
        profileManager.createProfile(name: "New Kid", isAdult: false)
        
        XCTAssertEqual(profileManager.profiles.count, initialCount + 1, "Should have one more profile")
        
        let newProfile = profileManager.profiles.first { $0.name == "New Kid" }
        XCTAssertNotNil(newProfile, "New profile should exist")
        XCTAssertFalse(newProfile?.isAdult == true, "New profile should not be adult")
    }
    
    func testCreateMultipleProfiles() {
        let initialCount = profileManager.profiles.count
        
        profileManager.createProfile(name: "Profile 1", isAdult: true)
        profileManager.createProfile(name: "Profile 2", isAdult: false)
        profileManager.createProfile(name: "Profile 3", isAdult: true)
        
        XCTAssertEqual(profileManager.profiles.count, initialCount + 3, "Should have 3 new profiles")
    }
    
    func testCreateProfileWithSpecialCharacters() {
        profileManager.createProfile(name: "José's Profile 🎬", isAdult: true)
        
        let profile = profileManager.profiles.first { $0.name == "José's Profile 🎬" }
        XCTAssertNotNil(profile, "Should handle special characters in profile name")
    }
    
    func testCreateProfileSetsModifiedDate() {
        let beforeDate = Date()
        
        profileManager.createProfile(name: "Test Profile", isAdult: true)
        
        let afterDate = Date()
        
        let profile = profileManager.profiles.first { $0.name == "Test Profile" }
        XCTAssertNotNil(profile?.modifiedAt, "Modified date should be set")
        
        if let modifiedAt = profile?.modifiedAt {
            XCTAssertTrue(modifiedAt >= beforeDate && modifiedAt <= afterDate, "Modified date should be current")
        }
    }
    
    // MARK: - Profile Deletion Tests
    
    func testDeleteProfile() {
        profileManager.createProfile(name: "To Delete", isAdult: true)
        
        guard let profileToDelete = profileManager.profiles.first(where: { $0.name == "To Delete" }) else {
            XCTFail("Profile should have been created")
            return
        }
        
        let initialCount = profileManager.profiles.count
        
        profileManager.deleteProfile(profileToDelete)
        
        XCTAssertEqual(profileManager.profiles.count, initialCount - 1, "Should have one less profile")
        XCTAssertNil(profileManager.profiles.first { $0.name == "To Delete" }, "Deleted profile should not exist")
    }
    
    func testDeleteSelectedProfile() {
        profileManager.createProfile(name: "To Delete", isAdult: true)
        
        guard let profileToDelete = profileManager.profiles.first(where: { $0.name == "To Delete" }) else {
            XCTFail("Profile should have been created")
            return
        }
        
        profileManager.selectProfile(profileToDelete)
        XCTAssertNotNil(profileManager.currentProfile, "Profile should be selected")
        
        profileManager.deleteProfile(profileToDelete)
        
        // Note: currentProfile is not automatically cleared, this is by design
        // The UI should handle profile selection after deletion
        XCTAssertNil(profileManager.profiles.first { $0.name == "To Delete" }, "Profile should be deleted")
    }
    
    func testDeleteLastRemainingProfile() {
        // Delete all but one profile
        while profileManager.profiles.count > 1 {
            profileManager.deleteProfile(profileManager.profiles[0])
        }
        
        XCTAssertEqual(profileManager.profiles.count, 1, "Should have one profile remaining")
        
        // Delete the last profile
        profileManager.deleteProfile(profileManager.profiles[0])
        
        XCTAssertEqual(profileManager.profiles.count, 0, "Should be able to delete last profile")
    }
    
    // MARK: - Profile Refresh Tests
    
    func testRefreshProfiles() {
        let initialCount = profileManager.profiles.count
        
        // Create a profile directly in Core Data without going through ProfileManager
        let directProfile = Profile(context: context)
        directProfile.name = "Direct Profile"
        directProfile.isAdult = true
        try? context.save()
        
        // Profiles list should be stale
        XCTAssertEqual(profileManager.profiles.count, initialCount, "Profiles list should be stale")
        
        // Refresh should pick up the new profile
        profileManager.refreshProfiles()
        
        XCTAssertEqual(profileManager.profiles.count, initialCount + 1, "Refresh should update profiles list")
        XCTAssertTrue(profileManager.profiles.contains { $0.name == "Direct Profile" }, "Should find directly created profile")
    }
    
    // MARK: - Edge Cases
    
    func testCreateProfileWithEmptyName() {
        profileManager.createProfile(name: "", isAdult: true)
        
        let profile = profileManager.profiles.first { $0.name == "" }
        XCTAssertNotNil(profile, "Should allow empty profile name")
    }
    
    func testCreateProfileWithLongName() {
        let longName = String(repeating: "a", count: 500)
        profileManager.createProfile(name: longName, isAdult: true)
        
        let profile = profileManager.profiles.first { $0.name == longName }
        XCTAssertNotNil(profile, "Should handle long profile names")
    }
    
    func testCreateProfilesWithDuplicateNames() {
        profileManager.createProfile(name: "Duplicate", isAdult: true)
        profileManager.createProfile(name: "Duplicate", isAdult: false)
        
        let duplicates = profileManager.profiles.filter { $0.name == "Duplicate" }
        XCTAssertEqual(duplicates.count, 2, "Should allow duplicate profile names")
        XCTAssertNotEqual(duplicates[0].isAdult, duplicates[1].isAdult, "Duplicate named profiles should have different settings")
    }
    
    // MARK: - Profile Persistence Tests
    
    func testProfilesPersistAcrossManagerInstances() {
        profileManager.createProfile(name: "Persistent Profile", isAdult: true)
        
        let profileCount = profileManager.profiles.count
        
        // Create new manager instance with same context
        let newManager = ProfileManager(context: context)
        
        XCTAssertEqual(newManager.profiles.count, profileCount, "New manager should load existing profiles")
        XCTAssertTrue(newManager.profiles.contains { $0.name == "Persistent Profile" }, "Should find previously created profile")
    }
}
