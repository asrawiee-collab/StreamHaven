import SwiftUI

/// View that prompts the user to choose between combined or single source mode when multiple sources are active.
struct SourceModePromptView: View {
    @Environment(\.dismiss) private var dismiss
    let profile: Profile
    let sourceManager: PlaylistSourceManager
    @State private var selectedMode: Profile.SourceMode = .combined
    @State private var isLoading = false
    @State private var errorMessage: String?
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                // Header
                VStack(spacing: 12) {
                    Image(systemName: "list.bullet.rectangle.portrait")
                        .font(.system(size: 60))
                        .foregroundColor(.blue)
                    
                    Text("Multiple Sources Detected")
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    Text("You have \(sourceManager.activeSourceCount(for: profile)) active sources. Choose how you'd like to view your content.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
                .padding(.top, 40)
                
                // Mode selection cards
                VStack(spacing: 16) {
                    SourceModeCard(
                        mode: .combined,
                        isSelected: selectedMode == .combined,
                        icon: "square.stack.3d.up",
                        title: "Combined Mode",
                        description: "Merge content from all active sources into a unified view. All movies, series, and channels appear together.",
                        benefits: [
                            "Browse all content at once",
                            "Automatic fallback between sources",
                            "Best quality selection"
                        ]
                    ) {
                        selectedMode = .combined
                    }
                    
                    SourceModeCard(
                        mode: .single,
                        isSelected: selectedMode == .single,
                        icon: "square.on.square",
                        title: "Single Mode",
                        description: "View one source at a time. Switch between sources manually to browse different catalogs.",
                        benefits: [
                            "Clear source separation",
                            "Easy source comparison",
                            "Simple troubleshooting"
                        ]
                    ) {
                        selectedMode = .single
                    }
                }
                .padding(.horizontal)
                
                Spacer()
                
                // Continue button
                Button(action: saveMode) {
                    if isLoading {
                        HStack {
                            ProgressView()
                                .tint(.white)
                            Text("Saving...")
                                .foregroundColor(.white)
                                .padding(.leading, 8)
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                    } else {
                        Text("Continue with \(selectedMode == .combined ? "Combined" : "Single") Mode")
                            .fontWeight(.semibold)
                            .frame(maxWidth: .infinity)
                            .padding()
                    }
                }
                .background(Color.blue)
                .foregroundColor(.white)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .padding(.horizontal)
                .padding(.bottom, 32)
                .disabled(isLoading)
            }
            .navigationBarTitleDisplayMode(.inline)
            .alert("Error", isPresented: Binding(
                get: { errorMessage != nil },
                set: { if !$0 { errorMessage = nil } }
            )) {
                Button("OK") { errorMessage = nil }
            } message: {
                Text(errorMessage ?? "")
            }
        }
        .interactiveDismissDisabled()
        .onAppear {
            selectedMode = profile.mode
        }
    }
    
    private func saveMode() {
        isLoading = true
        errorMessage = nil
        
        Task { @MainActor in
            do {
                try sourceManager.setSourceMode(selectedMode, for: profile)
                dismiss()
            } catch {
                errorMessage = "Failed to save mode: \(error.localizedDescription)"
                isLoading = false
            }
        }
    }
}

/// Card view for displaying a source mode option.
struct SourceModeCard: View {
    let mode: Profile.SourceMode
    let isSelected: Bool
    let icon: String
    let title: String
    let description: String
    let benefits: [String]
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: icon)
                        .font(.title2)
                        .foregroundColor(isSelected ? .white : .blue)
                    
                    Text(title)
                        .font(.headline)
                        .foregroundColor(isSelected ? .white : .primary)
                    
                    Spacer()
                    
                    if isSelected {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.title3)
                            .foregroundColor(.white)
                    }
                }
                
                Text(description)
                    .font(.subheadline)
                    .foregroundColor(isSelected ? .white.opacity(0.9) : .secondary)
                    .multilineTextAlignment(.leading)
                
                Divider()
                    .background(isSelected ? Color.white.opacity(0.3) : Color.gray.opacity(0.3))
                
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(benefits, id: \.self) { benefit in
                        HStack(spacing: 8) {
                            Image(systemName: "checkmark")
                                .font(.caption)
                                .foregroundColor(isSelected ? .white : .green)
                            Text(benefit)
                                .font(.caption)
                                .foregroundColor(isSelected ? .white.opacity(0.9) : .secondary)
                        }
                    }
                }
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isSelected ? Color.blue : Color.secondary.opacity(0.1))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? Color.blue : Color.gray.opacity(0.3), lineWidth: isSelected ? 2 : 1)
            )
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    let profile = Profile()
    return SourceModePromptView(
        profile: profile,
        sourceManager: PlaylistSourceManager()
    )
}
