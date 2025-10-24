import SwiftUI

/// A view that displays an empty state with a title, message, and optional action button.
public struct EmptyStateView: View {
    /// The title of the empty state.
    let title: String
    /// The message of the empty state.
    let message: String
    /// The title of the action button.
    let actionTitle: String?
    /// The action to perform when the action button is tapped.
    let action: (() -> Void)?

    /// Initializes a new `EmptyStateView`.
    ///
    /// - Parameters:
    ///   - title: The title of the empty state.
    ///   - message: The message of the empty state.
    ///   - actionTitle: The title of the action button.
    ///   - action: The action to perform when the action button is tapped.
    public init(title: String, message: String, actionTitle: String? = nil, action: (() -> Void)? = nil) {
        self.title = title
        self.message = message
        self.actionTitle = actionTitle
        self.action = action
    }

    /// The body of the view.
    public var body: some View {
        VStack(spacing: 20) {
            Text(title)
                .font(.title)
                .fontWeight(.bold)
            Text(message)
                .font(.body)
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
            if let actionTitle = actionTitle, let action = action {
                Button(action: action) {
                    Text(actionTitle)
                        .padding(.horizontal)
                        .padding(.vertical, 10)
                        .background(Color.accentColor)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                }
            }
        }
        .padding()
    }
}
