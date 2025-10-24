import SwiftUI

/// A view that displays a card with an image and a title.
public struct CardView: View {
    /// The URL of the image to display.
    let url: URL?
    /// The title to display.
    let title: String

#if os(tvOS)
    @Environment(\.isFocused) var isFocused: Bool
#endif

    /// The body of the view.
    public var body: some View {
        VStack {
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
                }
            }
            .frame(width: 180, height: 270)
            .cornerRadius(10)

            Text(title)
                .font(.caption)
                .lineLimit(1)
        }
#if os(tvOS)
        .scaleEffect(isFocused ? 1.1 : 1.0)
        .shadow(color: .black.opacity(0.7), radius: isFocused ? 20 : 0, x: 0, y: 10)
        .animation(.easeInOut(duration: 0.2), value: isFocused)
#endif
    }
}
