import SwiftUI

struct AddPlaylistView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.presentationMode) var presentationMode
    @EnvironmentObject var dataManager: StreamHavenData

    @State private var playlistURL: String = ""
    @State private var isLoading: Bool = false
    @State private var loadingStatus: String = ""
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
                            VStack {
                                ProgressView()
                                Text(loadingStatus)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
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
                if let retryAction = alert.retryAction {
                    return Alert(
                        title: Text(alert.title),
                        message: Text(alert.message),
                        primaryButton: .default(Text(NSLocalizedString("Retry", comment: "Retry button title")), action: retryAction),
                        secondaryButton: .cancel(Text(NSLocalizedString("OK", comment: "Default button for alert")))
                    )
                } else {
                    return Alert(
                        title: Text(alert.title),
                        message: Text(alert.message),
                        dismissButton: .default(Text(NSLocalizedString("OK", comment: "Default button for alert")))
                    )
                }
            }
        }
    }

    private func addPlaylist() {
        guard let url = URL(string: playlistURL) else {
            self.errorAlert = ErrorAlert(message: PlaylistImportError.invalidURL.localizedDescription)
            return
        }

        isLoading = true
        loadingStatus = NSLocalizedString("Downloading...", comment: "Playlist import status")

        Task {
            do {
                try await dataManager.importPlaylist(from: url, progress: { status in
                    Task { @MainActor in
                        self.loadingStatus = status
                    }
                })
                await MainActor.run {
                    self.isLoading = false
                    self.presentationMode.wrappedValue.dismiss()
                }
            } catch let error as PlaylistImportError {
                await MainActor.run {
                    self.isLoading = false
                    self.errorAlert = ErrorAlert(
                        message: error.localizedDescription,
                        retryAction: {
                            self.addPlaylist()
                        }
                    )
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
    var retryAction: (() -> Void)? = nil
}
