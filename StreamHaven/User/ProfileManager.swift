import Foundation
import CoreData

/// A class for managing user profiles.
public class ProfileManager: ObservableObject {

    /// The currently selected profile.
    @Published public var currentProfile: Profile?
    /// An array of all available profiles.
    @Published public var profiles: [Profile] = []

    private var context: NSManagedObjectContext
    private var cloudKitSyncManager: CloudKitSyncManager?

    /// Initializes a new `ProfileManager`.
    ///
    /// - Parameters:
    ///   - context: The `NSManagedObjectContext` to use for Core Data operations.
    ///   - cloudKitSyncManager: Optional CloudKit sync manager for cross-device sync.
    public init(context: NSManagedObjectContext, cloudKitSyncManager: CloudKitSyncManager? = nil) {
        self.context = context
        self.cloudKitSyncManager = cloudKitSyncManager
        fetchProfiles()

        if profiles.isEmpty {
            createDefaultProfiles()
            fetchProfiles()
        }
    }

    /// Selects a profile as the current profile.
    ///
    /// - Parameter profile: The `Profile` to select.
    public func selectProfile(_ profile: Profile) {
        self.currentProfile = profile
    }

    /// Deselects the current profile.
    public func deselectProfile() {
        self.currentProfile = nil
    }

    /// Fetches all profiles from Core Data.
    private func fetchProfiles() {
        let request: NSFetchRequest<Profile> = Profile.fetchRequest()
        do {
            profiles = try context.fetch(request)
        } catch {
    /// Creates the default "Adult" and "Kids" profiles.
    private func createDefaultProfiles() {
        let adultProfile = Profile(context: context)
        adultProfile.name = "Adult"
        adultProfile.isAdult = true
        adultProfile.modifiedAt = Date()

        let kidsProfile = Profile(context: context)
        kidsProfile.name = "Kids"
        kidsProfile.isAdult = false
        kidsProfile.modifiedAt = Date()

        do {
            try context.save()
            
            // Sync to CloudKit if enabled
            Task { @MainActor in
                try? await cloudKitSyncManager?.syncProfile(adultProfile)
                try? await cloudKitSyncManager?.syncProfile(kidsProfile)
            }
        } catch {
            ErrorReporter.log(error, context: "ProfileManager.createDefaultProfiles.save")
        }
    }
    
    /// Creates a new profile.
    ///
    /// - Parameters:
    ///   - name: The name of the profile.
    ///   - isAdult: Whether the profile is for an adult.
    public func createProfile(name: String, isAdult: Bool) {
        let profile = Profile(context: context)
        profile.name = name
        profile.isAdult = isAdult
        profile.modifiedAt = Date()
        
        do {
            try context.save()
            fetchProfiles()
            
            // Sync to CloudKit if enabled
            Task { @MainActor in
                try? await cloudKitSyncManager?.syncProfile(profile)
            }
        } catch {
            ErrorReporter.log(error, context: "ProfileManager.createProfile.save")
        }
    }
    
    /// Deletes a profile.
    ///
    /// - Parameter profile: The profile to delete.
    public func deleteProfile(_ profile: Profile) {
        // Delete from CloudKit first
        Task { @MainActor in
            try? await cloudKitSyncManager?.deleteProfile(profile)
        }
        
        context.delete(profile)
        
        do {
            try context.save()
            fetchProfiles()
        } catch {
            ErrorReporter.log(error, context: "ProfileManager.deleteProfile.save")
        }
    }
}       } catch {
            ErrorReporter.log(error, context: "ProfileManager.createDefaultProfiles.save")
        }
    }
}
