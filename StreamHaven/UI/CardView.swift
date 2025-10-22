import SwiftUI

struct CardView: View {
    let url: URL?
    let title: String

    var body: some View {
        VStack {
            AsyncImage(url: url) { image in
                image
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
            .frame(width: 150, height: 225)
            .cornerRadius(10)

            Text(title)
                .font(.caption)
                .lineLimit(1)
        }
    }
}
