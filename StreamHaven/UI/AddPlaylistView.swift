import SwiftUI

struct AddPlaylistView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.presentationMode) var presentationMode
    @EnvironmentObject var dataManager: StreamHavenData

    @State private var playlistURL: String = ""
    @State private var isLoading: Bool = false
    @State private var errorAlert: ErrorAlert?

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text(NSLocalizedString("Playlist URL", comment: "Add playlist view section header"))) {
                    TextField("https://example.com/playlist.m3u", text: $playlistURL)
                        .keyboardType(.URL)
                        .autocapitalization(.none)
                        .disabled(isLoading)
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
                    .disabled(isLoading)
                }
            }
            .alert(item: $errorAlert) { alert in
                Alert(
                    title: Text(alert.title),
                    message: Text(alert.message),
                    dismissButton: .default(Text(NSLocalizedString("OK", comment: "Default button for alert")))
                )
            }
        }
    }

    private func addPlaylist() {
        guard let url = URL(string: playlistURL) else {
            self.errorAlert = ErrorAlert(message: NSLocalizedString("The URL you entered appears to be invalid. Please check it and try again.", comment: "Invalid URL format error message"))
            return
        }

        isLoading = true

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
                    self.errorAlert = ErrorAlert(message: error.localizedDescription)
                }
            }
        }
    }
}

struct ErrorAlert: Identifiable {
    var id = UUID()
    var title: String = NSLocalizedString("Error", comment: "Default alert title for errors")
    var message: String
}
