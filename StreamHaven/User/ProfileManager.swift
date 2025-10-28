import CoreData
import Foundation

/// Manages user profiles, including persistence and optional CloudKit sync.
public final class ProfileManager: ObservableObject {

    // MARK: - Published Properties

    @Published public private(set) var profiles: [Profile] = []
    @Published public var currentProfile: Profile?

    // MARK: - Dependencies

    private let context: NSManagedObjectContext
    private let cloudKitSyncManager: CloudKitSyncManager?

    // MARK: - Initialization

    public init(context: NSManagedObjectContext, cloudKitSyncManager: CloudKitSyncManager? = nil) {
        self.context = context
        self.cloudKitSyncManager = cloudKitSyncManager
        refreshProfiles()

        if profiles.isEmpty {
            createDefaultProfiles()
            refreshProfiles()
        }
    }

    // MARK: - Public API

    public func selectProfile(_ profile: Profile) {
        currentProfile = profile
    }

    public func deselectProfile() {
        currentProfile = nil
    }

    public func refreshProfiles() {
        let request: NSFetchRequest<Profile> = Profile.fetchRequest()
        do {
            profiles = try context.fetch(request)
        } catch {
            ErrorReporter.log(error, context: "ProfileManager.refreshProfiles.fetch")
        }
    }

    public func createProfile(name: String, isAdult: Bool) {
        let profile = Profile(context: context)
        profile.name = name
        profile.isAdult = isAdult
        profile.modifiedAt = Date()

        saveContext(contextMessage: "ProfileManager.createProfile.save")
        refreshProfiles()

        Task { @MainActor in
            try? await cloudKitSyncManager?.syncProfile(profile)
        }
    }

    public func deleteProfile(_ profile: Profile) {
        Task { @MainActor in
            try? await cloudKitSyncManager?.deleteProfile(profile)
        }

        context.delete(profile)
        saveContext(contextMessage: "ProfileManager.deleteProfile.save")
        refreshProfiles()
    }

    // MARK: - Private Helpers

    private func createDefaultProfiles() {
        let adultProfile = Profile(context: context)
        adultProfile.name = "Adult"
        adultProfile.isAdult = true
        adultProfile.modifiedAt = Date()

        let kidsProfile = Profile(context: context)
        kidsProfile.name = "Kids"
        kidsProfile.isAdult = false
        kidsProfile.modifiedAt = Date()

        saveContext(contextMessage: "ProfileManager.createDefaultProfiles.save")

        Task { @MainActor in
            try? await cloudKitSyncManager?.syncProfile(adultProfile)
            try? await cloudKitSyncManager?.syncProfile(kidsProfile)
        }
    }

    private func saveContext(contextMessage: String) {
        guard context.hasChanges else { return }

        do {
            try context.save()
        } catch {
            ErrorReporter.log(error, context: contextMessage)
        }
    }
}
