import SwiftUI
import CoreData

#if os(iOS)

/// View for managing playlist sources for a profile.
struct PlaylistSourcesView: View {
    @Environment(\.managedObjectContext) private var context
    @StateObject private var sourceManager = PlaylistSourceManager()
    @ObservedObject var profile: Profile
    
    @State private var showAddSource = false
    @State private var editingSource: PlaylistSource?
    @State private var errorMessage: String?
    
    var body: some View {
        List {
            if sourceManager.sources.isEmpty {
                Section {
                    VStack(spacing: 16) {
                        Image(systemName: "list.bullet.rectangle")
                            .font(.system(size: 60))
                            .foregroundColor(.secondary)
                        Text("No Sources Added")
                            .font(.title2)
                            .fontWeight(.semibold)
                        Text("Add M3U playlists or Xtream Codes logins to get started")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                        Button(action: { showAddSource = true }) {
                            Label("Add Source", systemImage: "plus.circle.fill")
                                .font(.headline)
                        }
                        .buttonStyle(.borderedProminent)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 40)
                }
            } else {
                Section {
                    ForEach(sourceManager.sources) { source in
                        SourceRowView(source: source, sourceManager: sourceManager, profile: profile)
                            .contextMenu {
                                Button(action: { editingSource = source }) {
                                    Label("Edit", systemImage: "pencil")
                                }
                                Button(role: .destructive, action: { deleteSource(source) }) {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                    }
                    .onMove { from, to in
                        moveSource(from: from, to: to)
                    }
                } header: {
                    Text("Sources (\(sourceManager.sources.count))")
                } footer: {
                    Text("Drag to reorder sources. Active sources will be used for content browsing.")
                }
                
                Section {
                    Picker("Source Mode", selection: Binding(
                        get: { profile.mode },
                        set: { newMode in
                            try? sourceManager.setSourceMode(newMode, for: profile)
                        }
                    )) {
                        Text("Combined").tag(Profile.SourceMode.combined)
                        Text("Single").tag(Profile.SourceMode.single)
                    }
                    .pickerStyle(.segmented)
                } header: {
                    Text("Viewing Mode")
                } footer: {
                    if profile.mode == .combined {
                        Text("Combined mode merges content from all active sources into a unified view.")
                    } else {
                        Text("Single mode allows you to view one source at a time.")
                    }
                }
            }
        }
        .navigationTitle("Manage Sources")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button(action: { showAddSource = true }) {
                    Label("Add Source", systemImage: "plus")
                }
            }
            if !sourceManager.sources.isEmpty {
                ToolbarItem(placement: .secondaryAction) {
                    EditButton()
                }
            }
        }
        .sheet(isPresented: $showAddSource) {
            AddSourceView(profile: profile, sourceManager: sourceManager)
        }
        .sheet(item: $editingSource) { source in
            EditSourceView(source: source, sourceManager: sourceManager)
        }
        .alert("Error", isPresented: Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button("OK") { errorMessage = nil }
        } message: {
            Text(errorMessage ?? "")
        }
        .onAppear {
            sourceManager.loadSources(for: profile)
        }
    }
    
    private func deleteSource(_ source: PlaylistSource) {
        do {
            try sourceManager.removeSource(source, from: profile)
        } catch {
            errorMessage = "Failed to delete source: \(error.localizedDescription)"
        }
    }
    
    private func moveSource(from source: IndexSet, to destination: Int) {
        guard let fromIndex = source.first else { return }
        do {
            try sourceManager.moveSource(from: fromIndex, to: destination, in: profile)
        } catch {
            errorMessage = "Failed to reorder sources: \(error.localizedDescription)"
        }
    }
}

/// Row view for displaying a single source.
struct SourceRowView: View {
    @ObservedObject var source: PlaylistSource
    let sourceManager: PlaylistSourceManager
    let profile: Profile
    
    var body: some View {
        HStack(spacing: 12) {
            // Source type icon
            Image(systemName: source.isM3U ? "doc.text" : "server.rack")
                .font(.title2)
                .foregroundColor(source.isActive ? .blue : .gray)
                .frame(width: 40, height: 40)
                .background(Color.secondary.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 8))
            
            VStack(alignment: .leading, spacing: 4) {
                Text(source.name ?? "Unnamed Source")
                    .font(.headline)
                    .foregroundColor(source.isActive ? .primary : .secondary)
                
                HStack(spacing: 8) {
                    Text(source.type == .m3u ? "M3U Playlist" : "Xtream Codes")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    if let lastRefreshed = source.lastRefreshed {
                        Text("•")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text("Updated \(lastRefreshed, style: .relative)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                if let error = source.lastError {
                    Text("Error: \(error)")
                        .font(.caption)
                        .foregroundColor(.red)
                        .lineLimit(1)
                }
            }
            
            Spacer()
            
            Toggle("", isOn: Binding(
                get: { source.isActive },
                set: { isActive in
                    do {
                        if isActive {
                            try sourceManager.activateSource(source)
                        } else {
                            try sourceManager.deactivateSource(source)
                        }
                    } catch {
                        print("Failed to toggle source: \(error)")
                    }
                }
            ))
            .labelsHidden()
        }
        .padding(.vertical, 8)
    }
}

// Extension to make PlaylistSource identifiable for sheets
extension PlaylistSource: Identifiable {
    public var id: UUID {
        sourceID ?? UUID()
    }
}

#Preview {
    NavigationStack {
        PlaylistSourcesView(profile: Profile())
            .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
    }
}

#endif
