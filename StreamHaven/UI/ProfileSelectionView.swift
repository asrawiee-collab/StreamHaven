import SwiftUI

/// A view for selecting a user profile.
public struct ProfileSelectionView: View {
    /// The `ProfileManager` for managing user profiles.
    @ObservedObject public var profileManager: ProfileManager

    /// The body of the view.
    public var body: some View {
        VStack {
            Text(NSLocalizedString("Who's Watching?", comment: "Profile selection title"))
                .font(.largeTitle)
                .padding()

            HStack(spacing: 40) {
                ForEach(profileManager.profiles, id: \.self) { profile in
                    Button(action: {
                        profileManager.selectProfile(profile)
                    }) {
                        VStack {
                            Circle()
                                .frame(width: 150, height: 150)
                                .foregroundColor(.gray)

                            Text(profile.name ?? "Unknown")
                                .font(.headline)
                        }
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
        }
    }
}
