import Foundation
import CoreData

class ProfileManager: ObservableObject {

    @Published var currentProfile: Profile?
    @Published var profiles: [Profile] = []

    private var context: NSManagedObjectContext

    init(context: NSManagedObjectContext) {
        self.context = context
        fetchProfiles()

        if profiles.isEmpty {
            createDefaultProfiles()
            fetchProfiles()
        }
    }

    func selectProfile(_ profile: Profile) {
        self.currentProfile = profile
    }

    func deselectProfile() {
        self.currentProfile = nil
    }

    private func fetchProfiles() {
        let request: NSFetchRequest<Profile> = Profile.fetchRequest()
        do {
            profiles = try context.fetch(request)
        } catch {
            print("Failed to fetch profiles: \\(error)")
        }
    }

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
            print("Failed to create default profiles: \\(error)")
        }
    }
}
