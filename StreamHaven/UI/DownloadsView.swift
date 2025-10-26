import SwiftUI

/// View for managing all downloads.
public struct DownloadsView: View {
    @EnvironmentObject var downloadManager: DownloadManager
    @EnvironmentObject var playbackManager: PlaybackManager
    @EnvironmentObject var profileManager: ProfileManager
    
    @State private var showingPlayer = false
    @State private var selectedItem: NSManagedObject?
    
    public init() {}
    
    public var body: some View {
        NavigationView {
            List {
#if !os(tvOS)
                // Storage Info Section
                Section(header: Text("Storage")) {
                    HStack {
                        Text("Used")
                        Spacer()
                        Text(formatBytes(downloadManager.totalStorageUsed))
                            .foregroundColor(.secondary)
                    }
                    
                    HStack {
                        Text("Available")
                        Spacer()
                        Text(formatBytes(downloadManager.maxStorageBytes - downloadManager.totalStorageUsed))
                            .foregroundColor(.secondary)
                    }
                    
                    ProgressView(value: Double(downloadManager.totalStorageUsed), total: Double(downloadManager.maxStorageBytes))
                        .progressViewStyle(LinearProgressViewStyle())
                }
                
                // Active Downloads Section
                if !downloadManager.activeDownloads.isEmpty {
                    Section(header: Text("Downloading")) {
                        ForEach(downloadManager.activeDownloads, id: \.self) { download in
                            ActiveDownloadRow(download: download)
                        }
                    }
                }
                
                // Completed Downloads Section
                if !downloadManager.completedDownloads.isEmpty {
                    Section(header: Text("Downloaded")) {
                        ForEach(downloadManager.completedDownloads, id: \.self) { download in
                            CompletedDownloadRow(download: download, onPlay: {
                                playDownload(download)
                            })
                        }
                        .onDelete(perform: deleteDownloads)
                    }
                }
                
                // Empty State
                if downloadManager.activeDownloads.isEmpty && downloadManager.completedDownloads.isEmpty {
                    Section {
                        VStack(spacing: 16) {
                            Image(systemName: "arrow.down.circle")
                                .font(.system(size: 60))
                                .foregroundColor(.secondary)
                            Text("No Downloads")
                                .font(.title2)
                            Text("Movies and episodes you download will appear here for offline viewing.")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 40)
                    }
                }
#else
                // tvOS not supported
                Section {
                    VStack(spacing: 16) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.system(size: 60))
                            .foregroundColor(.secondary)
                        Text("Not Available")
                            .font(.title2)
                        Text("Downloads are not available on tvOS.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 40)
                }
#endif
            }
            .navigationTitle("Downloads")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Menu {
                        Button(action: {
                            downloadManager.cleanupExpiredDownloads()
                        }) {
                            Label("Clean Up Expired", systemImage: "trash")
                        }
                        
                        Button(action: {
                            downloadManager.cleanupWatchedDownloads()
                        }) {
                            Label("Clean Up Watched", systemImage: "checkmark.circle")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
        }
        .sheet(isPresented: $showingPlayer) {
            if let player = playbackManager.player,
               let item = selectedItem {
                if let movie = item as? Movie {
                    PlaybackViewController(player: player, imdbID: movie.imdbID)
                } else if let episode = item as? Episode {
                    PlaybackViewController(player: player, imdbID: episode.series?.imdbID)
                }
            }
        }
    }
    
    // MARK: - Helper Methods
    
    private func formatBytes(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useGB, .useMB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }
    
    private func deleteDownloads(at offsets: IndexSet) {
        for index in offsets {
            let download = downloadManager.completedDownloads[index]
            downloadManager.deleteDownload(download)
        }
    }
    
    private func playDownload(_ download: Download) {
        guard let profile = profileManager.currentProfile else { return }
        
        if let movie = download.movie {
            selectedItem = movie
            playbackManager.loadMedia(for: movie, profile: profile, isOffline: true)
            showingPlayer = true
        } else if let episode = download.episode {
            selectedItem = episode
            playbackManager.loadMedia(for: episode, profile: profile, isOffline: true)
            showingPlayer = true
        }
    }
}

// MARK: - Active Download Row

struct ActiveDownloadRow: View {
    @ObservedObject var download: Download
    @EnvironmentObject var downloadManager: DownloadManager
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                if let thumbnailURL = download.thumbnailURL {
                    AsyncImage(url: URL(string: thumbnailURL)) { image in
                        image.resizable()
                    } placeholder: {
                        Color.gray
                    }
                    .frame(width: 60, height: 90)
                    .cornerRadius(8)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(download.contentTitle ?? "Unknown")
                        .font(.headline)
                    
                    Text("\(download.contentType?.capitalized ?? "") • \(Int(download.progress * 100))%")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    ProgressView(value: download.progress)
                        .progressViewStyle(LinearProgressViewStyle())
                }
                
                Spacer()
                
                HStack(spacing: 12) {
                    Button(action: {
                        if download.downloadStatus == .downloading {
                            downloadManager.pauseDownload(download)
                        } else {
                            downloadManager.resumeDownload(download)
                        }
                    }) {
                        Image(systemName: download.downloadStatus == .downloading ? "pause.circle.fill" : "play.circle.fill")
                            .font(.title2)
                    }
                    
                    Button(action: {
                        downloadManager.cancelDownload(download)
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title2)
                            .foregroundColor(.red)
                    }
                }
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Completed Download Row

struct CompletedDownloadRow: View {
    @ObservedObject var download: Download
    let onPlay: () -> Void
    
    var body: some View {
        HStack {
            if let thumbnailURL = download.thumbnailURL {
                AsyncImage(url: URL(string: thumbnailURL)) { image in
                    image.resizable()
                } placeholder: {
                    Color.gray
                }
                .frame(width: 60, height: 90)
                .cornerRadius(8)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(download.contentTitle ?? "Unknown")
                    .font(.headline)
                
                HStack {
                    Text(download.contentType?.capitalized ?? "")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    if let fileSize = download.fileSize as? Int64 {
                        Text("• \(formatBytes(fileSize))")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    if download.isExpired {
                        Text("• Expired")
                            .font(.caption)
                            .foregroundColor(.red)
                    }
                }
            }
            
            Spacer()
            
            Button(action: onPlay) {
                Image(systemName: "play.circle.fill")
                    .font(.title2)
                    .foregroundColor(.blue)
            }
        }
        .padding(.vertical, 4)
        .opacity(download.isExpired ? 0.5 : 1.0)
    }
    
    private func formatBytes(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useGB, .useMB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }
}
