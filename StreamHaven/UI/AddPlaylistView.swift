import SwiftUI

struct AddPlaylistView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.presentationMode) var presentationMode
    @EnvironmentObject var dataManager: StreamHavenData

    @State private var playlistURL: String = ""
    @State private var isLoading: Bool = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text(NSLocalizedString("Playlist URL", comment: "Add playlist view section header"))) {
                    TextField("https://example.com/playlist.m3u", text: $playlistURL)
                        .keyboardType(.URL)
                        .autocapitalization(.none)
                }

                if let errorMessage = errorMessage {
                    Section {
                        Text(errorMessage)
                            .foregroundColor(.red)
                    }
                }

                Button(action: addPlaylist) {
                    HStack {
                        Spacer()
                        if isLoading {
                            ProgressView()
                        } else {
                            Text(NSLocalizedString("Add Playlist", comment: "Button title to add a playlist"))
                        }
                        Spacer()
                    }
                }
                .disabled(isLoading)
            }
            .navigationTitle(NSLocalizedString("Add Playlist", comment: "Add playlist view navigation title"))
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(NSLocalizedString("Cancel", comment: "Button title to cancel adding a playlist")) {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
            }
        }
    }

    private func addPlaylist() {
        guard let url = URL(string: playlistURL) else {
            self.errorMessage = NSLocalizedString("Invalid URL format.", comment: "Error message for invalid URL in Add Playlist view")
            return
        }

        isLoading = true
        errorMessage = nil

        Task {
            do {
                try await dataManager.importPlaylist(from: url)
                await MainActor.run {
                    self.isLoading = false
                    self.presentationMode.wrappedValue.dismiss()
                }
            } catch {
                await MainActor.run {
                    self.isLoading = false
                    self.errorMessage = error.localizedDescription
                }
            }
        }
    }
}
