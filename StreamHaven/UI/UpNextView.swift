import SwiftUI

/// View displaying the Up Next queue with management controls.
public struct UpNextView: View {
    @EnvironmentObject var queueManager: UpNextQueueManager
    @EnvironmentObject var profileManager: ProfileManager
    @EnvironmentObject var playbackManager: PlaybackManager
    @Environment(\.managedObjectContext) private var context
    
    @State private var showingPlayer = false
    @State private var selectedContent: NSManagedObject?
    
    public init() {}
    
    public var body: some View {
        NavigationView {
            List {
                if queueManager.queueItems.isEmpty {
                    emptyState
                } else {
                    Section(header: Text("Up Next")) {
                        ForEach(queueManager.queueItems, id: \.self) { item in
                            UpNextQueueItemRow(item: item, onPlay: {
                                playQueueItem(item)
                            })
                        }
                        .onDelete(perform: deleteItems)
                        .onMove(perform: moveItems)
                    }
                    
                    // Auto-added items indicator
                    let autoAddedCount = queueManager.queueItems.filter { $0.autoAdded }.count
                    if autoAddedCount > 0 {
                        Section {
                            HStack {
                                Image(systemName: "sparkles")
                                    .foregroundColor(.blue)
                                Text("\(autoAddedCount) auto-suggested items")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Up Next")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Menu {
                        Button(action: clearAutoAdded) {
                            Label("Clear Auto-Added", systemImage: "sparkles.rectangle.stack")
                        }
                        
                        Button(action: clearAll) {
                            Label("Clear All", systemImage: "trash")
                        }
                        .foregroundColor(.red)
                        
                        Button(action: generateSuggestions) {
                            Label("Generate Suggestions", systemImage: "wand.and.stars")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
                
                ToolbarItem(placement: .navigationBarLeading) {
                    EditButton()
                }
            }
        }
        .sheet(isPresented: $showingPlayer) {
            if let player = playbackManager.player,
               let content = selectedContent {
                if let movie = content as? Movie {
                    PlaybackViewController(player: player, imdbID: movie.imdbID)
                } else if let episode = content as? Episode {
                    PlaybackViewController(player: player, imdbID: episode.season?.series?.imdbID)
                }
            }
        }
        .onAppear {
            if let profile = profileManager.currentProfile {
                queueManager.loadQueue(for: profile)
            }
        }
    }
    
    // MARK: - Empty State
    
    private var emptyState: some View {
        Section {
            VStack(spacing: 16) {
                Image(systemName: "list.bullet.below.rectangle")
                    .font(.system(size: 60))
                    .foregroundColor(.secondary)
                Text("No Items in Queue")
                    .font(.title2)
                Text("Content you add to Up Next will appear here. The app will also suggest content based on your watching habits.")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
                
                Button(action: generateSuggestions) {
                    Label("Generate Suggestions", systemImage: "wand.and.stars")
                        .padding(.horizontal, 20)
                        .padding(.vertical, 10)
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 40)
        }
    }
    
    // MARK: - Actions
    
    private func playQueueItem(_ item: UpNextQueueItem) {
        guard let profile = profileManager.currentProfile,
              let content = item.fetchContent(context: context) else {
            return
        }
        
        selectedContent = content
        
        if let movie = content as? Movie {
            playbackManager.loadMedia(for: movie, profile: profile)
            showingPlayer = true
        } else if let episode = content as? Episode {
            playbackManager.loadMedia(for: episode, profile: profile)
            showingPlayer = true
        }
    }
    
    private func deleteItems(at offsets: IndexSet) {
        guard let profile = profileManager.currentProfile else { return }
        
        for index in offsets {
            let item = queueManager.queueItems[index]
            queueManager.removeFromQueue(item, profile: profile)
        }
    }
    
    private func moveItems(from source: IndexSet, to destination: Int) {
        guard let profile = profileManager.currentProfile,
              let sourceIndex = source.first else { return }
        
        let item = queueManager.queueItems[sourceIndex]
        queueManager.moveItem(item, to: destination, profile: profile)
    }
    
    private func clearAutoAdded() {
        guard let profile = profileManager.currentProfile else { return }
        queueManager.clearAutoAddedItems(for: profile)
    }
    
    private func clearAll() {
        guard let profile = profileManager.currentProfile else { return }
        queueManager.clearQueue(for: profile)
    }
    
    private func generateSuggestions() {
        guard let profile = profileManager.currentProfile else { return }
        queueManager.generateSuggestions(for: profile)
    }
}

// MARK: - Queue Item Row

struct UpNextQueueItemRow: View {
    @ObservedObject var item: UpNextQueueItem
    @Environment(\.managedObjectContext) private var context
    let onPlay: () -> Void
    
    @State private var contentTitle: String = "Loading..."
    @State private var contentSubtitle: String = ""
    @State private var thumbnailURL: String?
    
    var body: some View {
        HStack(spacing: 12) {
            // Thumbnail
            if let thumbnailURL = thumbnailURL, let url = URL(string: thumbnailURL) {
                AsyncImage(url: url) { image in
                    image.resizable()
                } placeholder: {
                    Color.gray
                }
                .frame(width: 60, height: 90)
                .cornerRadius(8)
            } else {
                Rectangle()
                    .fill(Color.gray.opacity(0.3))
                    .frame(width: 60, height: 90)
                    .cornerRadius(8)
                    .overlay(
                        Image(systemName: item.queueContentType == .movie ? "film" : "tv")
                            .foregroundColor(.white)
                    )
            }
            
            // Content Info
            VStack(alignment: .leading, spacing: 4) {
                Text(contentTitle)
                    .font(.headline)
                
                if !contentSubtitle.isEmpty {
                    Text(contentSubtitle)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                HStack {
                    if item.autoAdded {
                        HStack(spacing: 4) {
                            Image(systemName: "sparkles")
                                .font(.caption2)
                            Text("Suggested")
                                .font(.caption2)
                        }
                        .foregroundColor(.blue)
                    }
                    
                    Text("Position \(item.position + 1)")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            // Play Button
            Button(action: onPlay) {
                Image(systemName: "play.circle.fill")
                    .font(.title2)
                    .foregroundColor(.blue)
            }
        }
        .padding(.vertical, 4)
        .onAppear {
            loadContentInfo()
        }
    }
    
    private func loadContentInfo() {
        guard let content = item.fetchContent(context: context) else {
            contentTitle = "Content Not Found"
            return
        }
        
        if let movie = content as? Movie {
            contentTitle = movie.title ?? "Unknown Movie"
            contentSubtitle = "Movie • \(movie.rating ?? "Unrated")"
            thumbnailURL = movie.posterURL
        } else if let episode = content as? Episode {
            contentTitle = episode.title ?? "Unknown Episode"
            if let season = episode.season, let series = season.series {
                contentSubtitle = "\(series.title ?? "Unknown Series") • S\(season.seasonNumber)E\(episode.episodeNumber)"
            } else {
                contentSubtitle = "Episode \(episode.episodeNumber)"
            }
            thumbnailURL = episode.season?.series?.posterURL
        } else if let series = content as? Series {
            contentTitle = series.title ?? "Unknown Series"
            contentSubtitle = "Series"
            thumbnailURL = series.posterURL
        }
    }
}

// MARK: - Up Next Preview (for HomeView)

public struct UpNextPreview: View {
    @EnvironmentObject var queueManager: UpNextQueueManager
    @Environment(\.managedObjectContext) private var context
    
    public init() {}
    
    public var body: some View {
        if !queueManager.queueItems.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("Up Next")
                        .font(.title2)
                        .bold()
                    Spacer()
                    NavigationLink(destination: UpNextView()) {
                        Text("See All")
                            .font(.subheadline)
                    }
                }
                .padding(.horizontal)
                
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(Array(queueManager.queueItems.prefix(5)), id: \.self) { item in
                            UpNextPreviewCard(item: item)
                        }
                    }
                    .padding(.horizontal)
                }
            }
        }
    }
}

struct UpNextPreviewCard: View {
    @ObservedObject var item: UpNextQueueItem
    @Environment(\.managedObjectContext) private var context
    @EnvironmentObject var playbackManager: PlaybackManager
    @EnvironmentObject var profileManager: ProfileManager
    
    @State private var contentTitle: String = ""
    @State private var thumbnailURL: String?
    @State private var showingPlayer = false
    @State private var content: NSManagedObject?
    
    var body: some View {
        Button(action: play) {
            VStack(alignment: .leading, spacing: 8) {
                // Thumbnail
                if let thumbnailURL = thumbnailURL, let url = URL(string: thumbnailURL) {
                    AsyncImage(url: url) { image in
                        image.resizable()
                    } placeholder: {
                        Color.gray
                    }
                    .frame(width: 120, height: 180)
                    .cornerRadius(10)
                } else {
                    Rectangle()
                        .fill(Color.gray.opacity(0.3))
                        .frame(width: 120, height: 180)
                        .cornerRadius(10)
                }
                
                Text(contentTitle)
                    .font(.caption)
                    .lineLimit(2)
                    .frame(width: 120, alignment: .leading)
                
                if item.autoAdded {
                    HStack(spacing: 4) {
                        Image(systemName: "sparkles")
                            .font(.caption2)
                        Text("Suggested")
                            .font(.caption2)
                    }
                    .foregroundColor(.blue)
                }
            }
        }
        .onAppear {
            loadContentInfo()
        }
        .sheet(isPresented: $showingPlayer) {
            if let player = playbackManager.player,
               let content = content {
                if let movie = content as? Movie {
                    PlaybackViewController(player: player, imdbID: movie.imdbID)
                } else if let episode = content as? Episode {
                    PlaybackViewController(player: player, imdbID: episode.season?.series?.imdbID)
                }
            }
        }
    }
    
    private func loadContentInfo() {
        guard let fetchedContent = item.fetchContent(context: context) else { return }
        content = fetchedContent
        
        if let movie = fetchedContent as? Movie {
            contentTitle = movie.title ?? "Unknown"
            thumbnailURL = movie.posterURL
        } else if let episode = fetchedContent as? Episode {
            contentTitle = episode.title ?? "Unknown"
            thumbnailURL = episode.season?.series?.posterURL
        }
    }
    
    private func play() {
        guard let profile = profileManager.currentProfile,
              let content = content else { return }
        
        if let movie = content as? Movie {
            playbackManager.loadMedia(for: movie, profile: profile)
            showingPlayer = true
        } else if let episode = content as? Episode {
            playbackManager.loadMedia(for: episode, profile: profile)
            showingPlayer = true
        }
    }
}
