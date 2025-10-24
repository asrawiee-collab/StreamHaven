import Foundation
import CoreData

/// A class for managing user profiles.
public class ProfileManager: ObservableObject {

    /// The currently selected profile.
    @Published public var currentProfile: Profile?
    /// An array of all available profiles.
    @Published public var profiles: [Profile] = []

    private var context: NSManagedObjectContext

    /// Initializes a new `ProfileManager`.
    ///
    /// - Parameter context: The `NSManagedObjectContext` to use for Core Data operations.
    public init(context: NSManagedObjectContext) {
        self.context = context
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
            print("Failed to fetch profiles: \(error)")
        }
    }

    /// Creates the default "Adult" and "Kids" profiles.
    private func createDefaultProfiles() {
        let adultProfile = Profile(context: context)
        adultProfile.name = "Adult"
        adultProfile.isAdult = true

        let kidsProfile = Profile(context: context)
        kidsProfile.name = "Kids"
        kidsProfile.isAdult = false

        do {
            try context.save()
        } catch {
            print("Failed to create default profiles: \(error)")
        }
    }
}
