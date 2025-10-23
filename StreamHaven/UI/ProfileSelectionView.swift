import SwiftUI

struct ProfileSelectionView: View {
    @ObservedObject var profileManager: ProfileManager

    var body: some View {
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
