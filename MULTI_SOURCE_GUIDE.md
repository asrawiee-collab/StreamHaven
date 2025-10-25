# Multi-Source Playlist System

## Overview

StreamHaven now supports multiple playlist sources per profile, allowing users to add and manage multiple M3U playlists and Xtream Codes logins. This feature enables content aggregation from multiple providers, automatic fallback, and intelligent stream selection.

## Key Features

### 1. Multiple Source Support
- Add unlimited M3U playlists and Xtream Codes logins per profile
- Each source can be independently activated/deactivated
- Sources can be reordered to set priority
- Track source status, last refresh time, and errors

### 2. Viewing Modes

#### Combined Mode (Default)
- Merges content from all active sources into a unified view
- Automatically groups duplicate content (same movie/series/channel from different sources)
- Displays all available streams with quality indicators
- Allows manual stream selection or uses automatic "best source" logic

#### Single Mode
- View one source at a time
- Switch between sources manually
- Useful for troubleshooting or comparing catalogs

### 3. Content Grouping
- Intelligently groups content by title normalization
- Handles variations in naming (e.g., "The Matrix" vs "Matrix")
- Shows source information for each stream variant
- Quality indicators: 4K, FHD, HD, SD

### 4. Stream Selection
- Automatic "best source" selection based on:
  - Stream quality (resolution hints in URL/name)
  - Source reliability (error rate)
  - Manual override available for any content

### 5. Source Management UI
- Add/edit/delete sources
- Activate/deactivate sources
- Reorder sources (drag and drop)
- View source status and last update time
- See error messages for problematic sources

## Architecture

### Core Data Schema

#### PlaylistSource Entity
```swift
- sourceID: UUID (unique identifier)
- name: String (user-defined name)
- sourceType: String ("m3u" or "xtream")
- url: String (playlist URL or server URL)
- username: String? (for Xtream Codes)
- password: String? (for Xtream Codes, should use Keychain)
- isActive: Bool (whether source is active)
- displayOrder: Int32 (for ordering)
- createdAt: Date
- lastRefreshed: Date?
- lastError: String?
- metadata: String? (JSON for additional config)
```

#### Profile Updates
```swift
- sourceMode: String ("combined" or "single")
- playlistSources: [PlaylistSource] (relationship)
```

#### Content Updates
All content entities (Movie, Series, Channel, ChannelVariant) now have:
```swift
- sourceID: UUID? (tracks which source the content came from)
```

### Key Classes

#### PlaylistSourceManager
Manages CRUD operations for playlist sources:
- `addM3USource()`: Add M3U playlist
- `addXtreamSource()`: Add Xtream Codes login
- `removeSource()`: Delete a source
- `activateSource()` / `deactivateSource()`: Toggle source
- `reorderSources()`: Change source priority
- `setSourceMode()`: Switch between combined/single mode

#### MultiSourceContentManager
Handles content grouping and selection:
- `groupMovies()` / `groupSeries()` / `groupChannels()`: Group content by similarity
- `selectBestItem()`: Choose best stream from group
- `assessQuality()`: Evaluate stream quality
- `getSourceMetadata()`: Retrieve source information

### UI Components

#### PlaylistSourcesView
Main source management interface:
- List of all sources with status
- Add/edit/delete/reorder actions
- Mode selector (combined vs single)
- Empty state with add button

#### AddSourceView
Form for adding new sources:
- Source type picker (M3U/Xtream)
- Name, URL, credentials fields
- Validation and error handling

#### EditSourceView
Form for editing existing sources:
- Update name, URL, credentials
- View source status and errors
- Non-editable source type

#### SourceModePromptView
Onboarding prompt for choosing viewing mode:
- Displayed when multiple sources are active
- Explains combined vs single mode
- Visual cards with benefits list

#### MultiSourceContentView
Content display with multi-source support:
- Shows primary content item
- Indicates multiple sources available
- Opens source picker sheet
- Quality badges and source names

## Usage

### Adding Sources

#### M3U Playlist
```swift
try sourceManager.addM3USource(
    name: "My IPTV Provider",
    url: "https://example.com/playlist.m3u",
    to: profile
)
```

#### Xtream Codes
```swift
try sourceManager.addXtreamSource(
    name: "Xtream Server",
    url: "https://example.com",
    username: "user",
    password: "pass",
    to: profile
)
```

### Parsing with Source Tracking

#### M3U Parser
```swift
try M3UPlaylistParser.parse(
    data: playlistData,
    sourceID: source.sourceID,
    context: context
)
```

#### Xtream Parser
```swift
try await XtreamCodesParser.parse(
    url: serverURL,
    username: username,
    password: password,
    sourceID: source.sourceID,
    context: context
)
```

### Content Grouping

```swift
let contentManager = MultiSourceContentManager(context: context)
let movieGroups = try contentManager.groupMovies(for: profile)

for group in movieGroups {
    let primaryMovie = group.primaryItem
    let alternatives = group.alternativeItems
    let sourceCount = group.itemCount
    
    // Display content with multi-source UI
}
```

### Source Selection

```swift
// Automatic selection
let bestMovie = contentManager.selectBestItem(from: group)

// Manual selection
MultiSourceContentView(group: group, profile: profile, contentManager: contentManager) { selectedMovie in
    // Play selected movie
}
```

## Migration Guide

### From Single-Source to Multi-Source

Existing users with a single playlist will see:

1. Their existing playlist automatically converted to a `PlaylistSource`
2. Default mode set to "combined"
3. Prompt to add more sources (optional)

### Data Migration

The system handles migration automatically:

1. Existing content retains its data
2. New `sourceID` field starts as `nil` for existing content
3. Future refreshes will populate `sourceID` for all content
4. No data loss or breaking changes

### UI Integration

To integrate multi-source support:

1. **Settings**: Add link to `PlaylistSourcesView`
```swift
NavigationLink("Manage Sources") {
    PlaylistSourcesView(profile: currentProfile)
}
```

2. **Content Lists**: Use `MultiSourceContentView` for items
```swift
List(movieGroups, id: \.primaryItem) { group in
    MultiSourceContentView(
        group: group,
        profile: profile,
        contentManager: contentManager
    ) { selectedMovie in
        playMovie(selectedMovie)
    }
}
```

3. **First Run**: Show `SourceModePromptView` when multiple sources exist
```swift
.sheet(isPresented: $showModePrompt) {
    SourceModePromptView(profile: profile, sourceManager: sourceManager)
}
```

## Best Practices

### Source Naming
- Use descriptive names: "Provider A - HD Channels" vs "Source 1"
- Include quality or content type in name
- Keep names concise for mobile display

### Source Management
- Deactivate unused sources instead of deleting
- Regular refresh to keep content up-to-date
- Monitor source errors and address issues

### Mode Selection
- **Combined Mode**: Best for most users, provides unified experience
- **Single Mode**: Useful for troubleshooting, comparing providers, or debugging

### Quality Assessment
- System uses URL/name hints to assess quality
- 4K/2160p: 5 stars
- 1080p/FHD: 4 stars
- 720p/HD: 3 stars
- 480p/SD: 2 stars
- Unknown: 1 star

### Performance
- Grouping is performed in-memory for fast access
- Core Data batch operations used for large imports
- Source tracking adds minimal overhead

## Testing

Run the multi-source test suite:

```bash
# Run all multi-source tests
xcodebuild test -scheme StreamHaven -only-testing:StreamHavenTests/MultiSourceSystemTests

# Run specific test
xcodebuild test -scheme StreamHaven -only-testing:StreamHavenTests/MultiSourceSystemTests/testAddM3USource
```

Test coverage includes:
- Source CRUD operations
- Content grouping in both modes
- Quality assessment
- Source metadata retrieval
- Mode switching

## Troubleshooting

### Sources Not Appearing
- Verify source is active (toggle in source list)
- Check for errors in source row
- Ensure profile is in correct mode

### Duplicate Content
- Normal in combined mode (groups duplicates)
- Switch to single mode to view sources separately
- Use source picker to choose preferred stream

### Stream Not Playing
- Check source status and errors
- Try alternative stream from source picker
- Verify source URL/credentials are correct
- Test source in single mode

### Performance Issues
- Deactivate unused sources
- Reduce number of active sources
- Clear old cached data
- Consider using single mode

## Future Enhancements

Potential future improvements:

1. **Advanced Quality Detection**
   - Probe stream metadata (bitrate, codec, resolution)
   - Real-time quality monitoring
   - User feedback on stream quality

2. **Automatic Fallback**
   - Retry failed streams with next available source
   - Smart source ranking based on reliability
   - Background source health checks

3. **Source Synchronization**
   - iCloud sync for sources across devices
   - Encrypted credential storage
   - Cross-device source management

4. **Analytics**
   - Track most-used sources
   - Measure stream quality and buffering
   - Suggest optimal source combinations

5. **Import/Export**
   - Export source configuration
   - Share sources with other profiles
   - Bulk import from file

## Security Notes

### Credential Storage
Current implementation stores Xtream Codes passwords in Core Data. **Production recommendation**:
- Use iOS Keychain for password storage
- Implement `KeychainHelper` integration
- Never log or display passwords

### Network Security
- Enforce HTTPS for all source URLs
- Validate server certificates
- Implement timeout and retry logic

### Data Privacy
- Source credentials never leave device
- No analytics on source URLs
- User controls all source data

## Support

For issues or questions about multi-source support:
1. Check source status in Settings > Manage Sources
2. Review error messages for failed sources
3. Test sources individually in single mode
4. Refer to this documentation for configuration guidance

---

**Version**: 1.0  
**Last Updated**: October 2025  
**Component**: Multi-Source Playlist System
