import SwiftUI

/// A view that displays a card with an image and a title.
public struct CardView: View {
    /// The URL of the image to display.
    let url: URL?
    /// The title to display.
    let title: String
    /// Optional: EPG entries for Now/Next overlay (for channel cards)
    var nowProgram: String? = nil
    var nextProgram: String? = nil

    @EnvironmentObject var settingsManager: SettingsManager

#if os(tvOS)
    @Environment(\.isFocused) var isFocused: Bool
#endif

    /// The body of the view.
    public var body: some View {
        VStack {
            ZStack(alignment: .bottomLeading) {
                AsyncImage(url: url) { image in
                    image
                        .accessibilityLabel(Text(title))
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    ZStack {
                        Color.gray
                        Text(title)
                            .foregroundColor(.white)
                            .multilineTextAlignment(.center)
                            .padding()
                .frame(width: 180, height: 270)
                .cornerRadius(10)
#if os(tvOS)
                // Enhanced focus border for accessibility mode
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(isFocused && settingsManager.accessibilityModeEnabled ? Color.yellow : Color.clear, lineWidth: 4)
                )
#endif
                .frame(width: 180, height: 270)
                .cornerRadius(10)

                // Now/Next overlay (if available)
                if let now = nowProgram {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Now: \(now)")
                            .font(.caption2)
                            .foregroundColor(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.black.opacity(0.7))
                            .cornerRadius(4)
                        if let next = nextProgram {
                            Text("Next: \(next)")
                                .font(.caption2)
                                .foregroundColor(.white)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.black.opacity(0.5))
                                .cornerRadius(4)
                        }
                    }
        }
#if os(tvOS)
        .scaleEffect(isFocused ? (settingsManager.accessibilityModeEnabled ? 1.15 : 1.1) : 1.0)
        .shadow(color: .black.opacity(0.7), radius: isFocused ? 20 : 0, x: 0, y: 10)
        .animation(.easeInOut(duration: 0.2), value: isFocused)
#endif
    }
}
#if os(tvOS)
        .scaleEffect(isFocused ? 1.1 : 1.0)
        .shadow(color: .black.opacity(0.7), radius: isFocused ? 20 : 0, x: 0, y: 10)
        .animation(.easeInOut(duration: 0.2), value: isFocused)
#endif
    }
}
