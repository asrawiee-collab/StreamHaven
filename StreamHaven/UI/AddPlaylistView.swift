import SwiftUI

#if os(iOS)

/// A view for adding a new playlist from a URL.
public struct AddPlaylistView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.presentationMode) var presentationMode
    @EnvironmentObject var dataManager: StreamHavenData

    @State private var playlistURL: String = ""
    @State private var epgURL: String = ""
    @State private var isLoading: Bool = false
    @State private var loadingStatus: String = ""
    @State private var errorAlert: ErrorAlert?

    /// The body of the view.
    public var body: some View {
        NavigationView {
            Form {
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Image(systemName: "info.circle.fill")
                                .foregroundColor(.blue)
                            Text(NSLocalizedString("New: Multi-Source Support", comment: "Info banner title"))
                                .font(.subheadline)
                                .fontWeight(.semibold)
                        }
                        Text(NSLocalizedString("Add multiple playlists and Xtream Codes logins in Settings > Manage Sources for a better experience.", comment: "Info banner message"))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(.vertical, 4)
                }
                
                Section(header: Text(NSLocalizedString("Playlist URL", comment: "Add playlist view section header"))) {
                    TextField("https://example.com/playlist.m3u", text: $playlistURL)
                        .keyboardType(.URL)
                        .autocapitalization(.none)
                        .disabled(isLoading)
                }
                Section(header: Text(NSLocalizedString("EPG URL (optional)", comment: "Add playlist view section header for EPG"))) {
                    TextField("https://example.com/epg.xml", text: $epgURL)
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

    /// Adds the playlist from the URL.
    private func addPlaylist() {
        guard let url = URL(string: playlistURL) else {
            self.errorAlert = ErrorAlert(message: PlaylistImportError.invalidURL.localizedDescription)
            return
        }

        let epgURLValue = epgURL.isEmpty ? nil : URL(string: epgURL)

        isLoading = true
        loadingStatus = NSLocalizedString("Downloading...", comment: "Playlist import status")

        Task {
            do {
                try await dataManager.importPlaylist(from: url, epgURL: epgURLValue, progress: { status in
                    Task { @MainActor in
                        self.loadingStatus = status
                    }
                })
                await MainActor.run {
                    self.isLoading = false
                    self.presentationMode.wrappedValue.dismiss()
                }
            } catch let error as PlaylistImportError {
                ErrorReporter.log(error, context: "AddPlaylistView.importPlaylist")
                await MainActor.run {
                    self.isLoading = false
                    self.errorAlert = ErrorAlert(
                        message: ErrorReporter.userMessage(for: error),
                        retryAction: {
                            self.addPlaylist()
                        }
                    )
                }
            } catch {
                ErrorReporter.log(error, context: "AddPlaylistView.importPlaylist")
                await MainActor.run {
                    self.isLoading = false
                    self.errorAlert = ErrorAlert(message: ErrorReporter.userMessage(for: error))
                }
            }
        }
    }
}

/// A struct representing an error alert.
public struct ErrorAlert: Identifiable {
    /// The unique identifier for the alert.
    public var id = UUID()
    /// The title of the alert.
    public var title: String = NSLocalizedString("Error", comment: "Default alert title for errors")
    /// The message of the alert.
    public var message: String
    /// An optional action to perform when the user taps the retry button.
    public var retryAction: (() -> Void)? = nil
}

#endif
