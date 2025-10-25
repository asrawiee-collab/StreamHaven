import SwiftUI

/// View for adding a new playlist source.
struct AddSourceView: View {
    @Environment(\.dismiss) private var dismiss
    let profile: Profile
    let sourceManager: PlaylistSourceManager
    
    @State private var sourceType: PlaylistSource.SourceType = .m3u
    @State private var name = ""
    @State private var url = ""
    @State private var username = ""
    @State private var password = ""
    @State private var isLoading = false
    @State private var errorMessage: String?
    
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("Source Type", selection: $sourceType) {
                        Text("M3U Playlist").tag(PlaylistSource.SourceType.m3u)
                        Text("Xtream Codes").tag(PlaylistSource.SourceType.xtream)
                    }
                    .pickerStyle(.segmented)
                } header: {
                    Text("Type")
                } footer: {
                    if sourceType == .m3u {
                        Text("M3U playlists are standard IPTV playlist files.")
                    } else {
                        Text("Xtream Codes is a popular IPTV server API.")
                    }
                }
                
                Section("Details") {
                    TextField("Source Name", text: $name)
                        .textContentType(.name)
                    
                    TextField(sourceType == .m3u ? "Playlist URL" : "Server URL", text: $url)
                        .textContentType(.URL)
                        .keyboardType(.URL)
                        .autocapitalization(.none)
                        .autocorrectionDisabled()
                    
                    if sourceType == .xtream {
                        TextField("Username", text: $username)
                            .textContentType(.username)
                            .autocapitalization(.none)
                            .autocorrectionDisabled()
                        
                        SecureField("Password", text: $password)
                            .textContentType(.password)
                    }
                }
                
                Section {
                    Button(action: addSource) {
                        if isLoading {
                            HStack {
                                Spacer()
                                ProgressView()
                                Text("Adding Source...")
                                    .padding(.leading, 8)
                                Spacer()
                            }
                        } else {
                            Text("Add Source")
                                .frame(maxWidth: .infinity)
                                .fontWeight(.semibold)
                        }
                    }
                    .disabled(!isValid || isLoading)
                }
            }
            .navigationTitle("Add Source")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .alert("Error", isPresented: Binding(
                get: { errorMessage != nil },
                set: { if !$0 { errorMessage = nil } }
            )) {
                Button("OK") { errorMessage = nil }
            } message: {
                Text(errorMessage ?? "")
            }
        }
    }
    
    private var isValid: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty &&
        !url.trimmingCharacters(in: .whitespaces).isEmpty &&
        (sourceType == .m3u || (!username.isEmpty && !password.isEmpty))
    }
    
    private func addSource() {
        isLoading = true
        errorMessage = nil
        
        Task { @MainActor in
            do {
                let trimmedName = name.trimmingCharacters(in: .whitespaces)
                let trimmedURL = url.trimmingCharacters(in: .whitespaces)
                
                if sourceType == .m3u {
                    try sourceManager.addM3USource(
                        name: trimmedName,
                        url: trimmedURL,
                        to: profile
                    )
                } else {
                    try sourceManager.addXtreamSource(
                        name: trimmedName,
                        url: trimmedURL,
                        username: username,
                        password: password,
                        to: profile
                    )
                }
                
                dismiss()
            } catch {
                errorMessage = "Failed to add source: \(error.localizedDescription)"
                isLoading = false
            }
        }
    }
}

#Preview {
    AddSourceView(
        profile: Profile(),
        sourceManager: PlaylistSourceManager()
    )
}
