import SwiftUI

struct AddPlaylistView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.presentationMode) var presentationMode

    @State private var playlistURL: String = ""
    @State private var isLoading: Bool = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Playlist URL")) {
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
                            Text("Add Playlist")
                        }
                        Spacer()
                    }
                }
                .disabled(isLoading)
            }
            .navigationTitle("Add Playlist")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
            }
        }
    }

    private func addPlaylist() {
        guard let url = URL(string: playlistURL) else {
            self.errorMessage = "Invalid URL format."
            return
        }

        isLoading = true
        errorMessage = nil

        PlaylistParser.parse(url: url, context: viewContext) { error in
            DispatchQueue.main.async {
                self.isLoading = false
                if let error = error {
                    self.errorMessage = "Failed to parse playlist: \\(error.localizedDescription)"
                } else {
                    self.presentationMode.wrappedValue.dismiss()
                }
            }
        }
    }
}
