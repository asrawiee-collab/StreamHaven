import SwiftUI

/// View for editing an existing playlist source.
struct EditSourceView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var source: PlaylistSource
    let sourceManager: PlaylistSourceManager
    
    @State private var name: String
    @State private var url: String
    @State private var username: String
    @State private var password: String
    @State private var isLoading = false
    @State private var errorMessage: String?
    
    init(source: PlaylistSource, sourceManager: PlaylistSourceManager) {
        self.source = source
        self.sourceManager = sourceManager
        _name = State(initialValue: source.name ?? "")
        _url = State(initialValue: source.url ?? "")
        _username = State(initialValue: source.username ?? "")
        _password = State(initialValue: source.password ?? "")
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack {
                        Text("Type")
                            .foregroundColor(.secondary)
                        Spacer()
                        Text(source.isM3U ? "M3U Playlist" : "Xtream Codes")
                    }
                } footer: {
                    Text("Source type cannot be changed after creation.")
                }
                
                Section("Details") {
                    TextField("Source Name", text: $name)
#if os(iOS)
                        .textContentType(.name)
#endif
                    
                    TextField(source.isM3U ? "Playlist URL" : "Server URL", text: $url)
#if os(iOS)
                        .textContentType(.URL)
                        .keyboardType(.URL)
                        .autocapitalization(.none)
                        .autocorrectionDisabled()
#endif
                    
                    if source.isXtream {
                        TextField("Username", text: $username)
#if os(iOS)
                            .textContentType(.username)
                            .autocapitalization(.none)
                            .autocorrectionDisabled()
#endif
                        
                        SecureField("Password", text: $password)
#if os(iOS)
                            .textContentType(.password)
#endif
                    }
                }
                
                Section {
                    HStack {
                        Text("Status")
                            .foregroundColor(.secondary)
                        Spacer()
                        Text(source.isActive ? "Active" : "Inactive")
                            .foregroundColor(source.isActive ? .green : .orange)
                    }
                    
                    if let lastRefreshed = source.lastRefreshed {
                        HStack {
                            Text("Last Updated")
                                .foregroundColor(.secondary)
                            Spacer()
                            Text(lastRefreshed, style: .relative)
                        }
                    }
                    
                    if let error = source.lastError {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Last Error")
                                .foregroundColor(.secondary)
                            Text(error)
                                .font(.caption)
                                .foregroundColor(.red)
                        }
                    }
                } header: {
                    Text("Status")
                }
                
                Section {
                    Button(action: saveChanges) {
                        if isLoading {
                            HStack {
                                Spacer()
                                ProgressView()
                                Text("Saving...")
                                    .padding(.leading, 8)
                                Spacer()
                            }
                        } else {
                            Text("Save Changes")
                                .frame(maxWidth: .infinity)
                                .fontWeight(.semibold)
                        }
                    }
                    .disabled(!isValid || !hasChanges || isLoading)
                }
            }
            .navigationTitle("Edit Source")
#if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
#endif
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
        (source.isM3U || (!username.isEmpty && !password.isEmpty))
    }
    
    private var hasChanges: Bool {
        name != (source.name ?? "") ||
        url != (source.url ?? "") ||
        username != (source.username ?? "") ||
        password != (source.password ?? "")
    }
    
    private func saveChanges() {
        isLoading = true
        errorMessage = nil
        
        Task { @MainActor in
            do {
                try sourceManager.updateSource(
                    source,
                    name: name.trimmingCharacters(in: .whitespaces),
                    url: url.trimmingCharacters(in: .whitespaces),
                    username: source.isXtream ? username : nil,
                    password: source.isXtream ? password : nil
                )
                
                dismiss()
            } catch {
                errorMessage = "Failed to update source: \(error.localizedDescription)"
                isLoading = false
            }
        }
    }
}

#Preview {
    let source = PlaylistSource()
    source.sourceID = UUID()
    source.name = "Test Source"
    source.sourceType = "m3u"
    source.url = "https://example.com/playlist.m3u"
    source.isActive = true
    
    return EditSourceView(
        source: source,
        sourceManager: PlaylistSourceManager()
    )
}
