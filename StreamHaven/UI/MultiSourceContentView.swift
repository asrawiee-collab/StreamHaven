import CoreData
import SwiftUI

/// View for displaying content with multiple source options.
struct MultiSourceContentView<T: NSManagedObject>: View {
    let group: MultiSourceContentManager.ContentGroup<T>
    let profile: Profile
    let contentManager: MultiSourceContentManager
    let onSelect: (T) -> Void
    
    @State private var showSourcePicker = false
    @State private var selectedItem: T
    
    init(
        group: MultiSourceContentManager.ContentGroup<T>,
        profile: Profile,
        contentManager: MultiSourceContentManager,
        onSelect: @escaping (T) -> Void
    ) {
        self.group = group
        self.profile = profile
        self.contentManager = contentManager
        self.onSelect = onSelect
        _selectedItem = State(initialValue: contentManager.selectBestItem(from: group))
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button(action: { onSelect(selectedItem) }) {
                contentRowView
            }
            .buttonStyle(.plain)
            
            if group.itemCount > 1 {
                Divider()
                    .padding(.leading, 16)
                
                Button(action: { showSourcePicker = true }) {
                    HStack {
                        Image(systemName: "arrow.triangle.2.circlepath")
                            .font(.caption)
                            .foregroundColor(.blue)
                        
                        Text("\(group.itemCount) sources available")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Spacer()
                        
                        Image(systemName: "chevron.right")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                }
                .buttonStyle(.plain)
            }
        }
        .sheet(isPresented: $showSourcePicker) {
            SourcePickerSheet(
                group: group,
                profile: profile,
                contentManager: contentManager,
                selectedItem: $selectedItem
            )
        }
    }
    
    @ViewBuilder
    private var contentRowView: some View {
        if let movie = selectedItem as? Movie {
            MovieRowView(movie: movie)
        } else if let series = selectedItem as? Series {
            SeriesRowView(series: series)
        } else if let channel = selectedItem as? Channel {
            ChannelRowView(channel: channel)
        } else {
            Text("Unknown content type")
        }
    }
}

/// Sheet for picking a source from multiple options.
struct SourcePickerSheet<T: NSManagedObject>: View {
    @Environment(\.dismiss) private var dismiss
    let group: MultiSourceContentManager.ContentGroup<T>
    let profile: Profile
    let contentManager: MultiSourceContentManager
    @Binding var selectedItem: T
    
    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(Array(group.allItems.enumerated()), id: \.offset) { index, item in
                        SourceItemRow(
                            item: item,
                            profile: profile,
                            contentManager: contentManager,
                            isSelected: isSelected(item)
                        ) {
                            selectedItem = item
                            dismiss()
                        }
                    }
                } header: {
                    Text("Available Sources")
                } footer: {
                    Text("Select the source you'd like to use for this content.")
                }
            }
            .navigationTitle("Choose Source")
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
        }
    }
    
    private func isSelected(_ item: T) -> Bool {
        return item.objectID == selectedItem.objectID
    }
}

/// Row view for a source option.
struct SourceItemRow<T: NSManagedObject>: View {
    let item: T
    let profile: Profile
    let contentManager: MultiSourceContentManager
    let isSelected: Bool
    let onSelect: () -> Void
    
    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    if let sourceID = getSourceID() {
                        if let metadata = contentManager.getSourceMetadata(for: sourceID, in: profile) {
                            Text(metadata.sourceName)
                                .font(.headline)
                                .foregroundColor(.primary)
                            
                            HStack(spacing: 8) {
                                qualityBadge
                                
                                if let lastRefreshed = metadata.lastRefreshed {
                                    Text("•")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                    Text("Updated \(lastRefreshed, style: .relative)")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                        } else {
                            Text("Unknown Source")
                                .font(.headline)
                                .foregroundColor(.secondary)
                        }
                    } else {
                        Text("No Source")
                            .font(.headline)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.blue)
                        .font(.title3)
                }
            }
            .padding(.vertical, 4)
        }
        .buttonStyle(.plain)
    }
    
    @ViewBuilder
    private var qualityBadge: some View {
        let quality = contentManager.assessQuality(streamURL: getStreamURL(), name: getName())
        let (label, color) = qualityInfo(for: quality)
        
        Text(label)
            .font(.caption2)
            .fontWeight(.semibold)
            .foregroundColor(.white)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(color)
            .clipShape(Capsule())
    }
    
    private func qualityInfo(for quality: Int) -> (String, Color) {
        switch quality {
        case 5: return ("4K", .purple)
        case 4: return ("FHD", .blue)
        case 3: return ("HD", .green)
        case 2: return ("SD", .orange)
        default: return ("?", .gray)
        }
    }
    
    private func getSourceID() -> UUID? {
        if let movie = item as? Movie {
            return movie.sourceID
        } else if let series = item as? Series {
            return series.sourceID
        } else if let channel = item as? Channel {
            return channel.sourceID
        }
        return nil
    }
    
    private func getStreamURL() -> String? {
        if let movie = item as? Movie {
            return movie.streamURL
        } else if let channel = item as? Channel {
            let variants = channel.variants?.allObjects as? [ChannelVariant]
            return variants?.first?.streamURL
        }
        return nil
    }
    
    private func getName() -> String? {
        if let movie = item as? Movie {
            return movie.title
        } else if let series = item as? Series {
            return series.title
        } else if let channel = item as? Channel {
            return channel.name
        }
        return nil
    }
}

// MARK: - Placeholder Row Views

struct MovieRowView: View {
    let movie: Movie
    
    var body: some View {
        HStack(spacing: 12) {
            AsyncImage(url: URL(string: movie.posterURL ?? "")) { image in
                image.resizable().aspectRatio(contentMode: .fill)
            } placeholder: {
                Color.gray.opacity(0.3)
            }
            .frame(width: 60, height: 90)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            
            VStack(alignment: .leading, spacing: 4) {
                Text(movie.title ?? "Unknown")
                    .font(.headline)
                    .lineLimit(2)
                
                if let releaseDate = movie.releaseDate {
                    Text(releaseDate, style: .date)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 16)
    }
}

struct SeriesRowView: View {
    let series: Series
    
    var body: some View {
        HStack(spacing: 12) {
            AsyncImage(url: URL(string: series.posterURL ?? "")) { image in
                image.resizable().aspectRatio(contentMode: .fill)
            } placeholder: {
                Color.gray.opacity(0.3)
            }
            .frame(width: 60, height: 90)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            
            VStack(alignment: .leading, spacing: 4) {
                Text(series.title ?? "Unknown")
                    .font(.headline)
                    .lineLimit(2)
                
                if let releaseDate = series.releaseDate {
                    Text(releaseDate, style: .date)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 16)
    }
}

struct ChannelRowView: View {
    let channel: Channel
    
    var body: some View {
        HStack(spacing: 12) {
            AsyncImage(url: URL(string: channel.logoURL ?? "")) { image in
                image.resizable().aspectRatio(contentMode: .fit)
            } placeholder: {
                Color.gray.opacity(0.3)
            }
            .frame(width: 60, height: 60)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            
            VStack(alignment: .leading, spacing: 4) {
                Text(channel.name ?? "Unknown")
                    .font(.headline)
                    .lineLimit(2)
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 16)
    }
}

