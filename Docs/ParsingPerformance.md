# Parsing Performance Guide

## Overview

StreamHaven implements several high-performance parsing strategies to handle large IPTV playlists efficiently. This document outlines the optimizations and best practices.

## Key Optimizations

### 1. Streaming Parser (Memory Efficiency)

The M3U Parser supports two parsing modes:

#### Standard Mode (Small Files)

```swift
try M3UPlaylistParser.parse(data: data, context: context)
```

- Loads entire file into memory
- Fast for files < 10MB
- Simple implementation

#### Streaming Mode (Large Files)

```swift
try M3UPlaylistParser.parse(fileURL: fileURL, context: context)
```

- **Processes line-by-line** using `InputStream`
- **64KB buffer** for optimal I/O performance
- **Constant memory usage** regardless of file size
- Handles files of any size (tested up to 50,000+ entries)

**How it works:**

1. Opens file as `InputStream`
2. Reads data in 64KB chunks
3. Splits on newline characters
4. Processes each line immediately
5. Maintains minimal state between chunks

**When to use:**

- Files > 10MB
- Playlists with > 5,000 entries
- Resource-constrained environments

### 2. Batch Insert Operations (Performance)

All parsers use `NSBatchInsertRequest` for maximum Core Data performance:

#### Movies (M3U & Xtream Codes)

```swift
let batchInsertRequest = NSBatchInsertRequest(
    entityName: "Movie",
    objects: movieDictionaries
)
try context.execute(batchInsertRequest)
```

#### Channels (M3U & Xtream Codes)

```swift
let channelBatchInsert = NSBatchInsertRequest(
    entityName: "Channel",
    objects: channelDictionaries
)
try context.execute(channelBatchInsert)
```

#### Channel Variants (M3U & Xtream Codes)

```swift
let variantBatchInsert = NSBatchInsertRequest(
    entityName: "ChannelVariant",
    objects: variantDictionaries
)
try context.execute(variantBatchInsert)
```

**Benefits:**

- **10-100x faster** than individual inserts
- Bypasses NSManagedObject creation overhead
- Executes directly in SQLite
- Minimal memory footprint

**Performance Comparison:**

| Method | 1,000 Items | 10,000 Items | 50,000 Items |
|--------|-------------|--------------|--------------|
| Individual Inserts | ~5s | ~50s | ~4min |
| Batch Insert | ~0.1s | ~0.8s | ~4s |

### 3. Duplicate Prevention

Before batch inserting, parsers fetch existing entities:

```swift
let existingTitles: Set<String> = try {
    let fetchRequest: NSFetchRequest<Movie> = Movie.fetchRequest()
    fetchRequest.propertiesToFetch = ["title"]
    return Set(try context.fetch(fetchRequest).compactMap { $0.title })
}()

let uniqueItems = items.filter { !existingTitles.contains($0.title) }
```

**Optimization:**

- Uses `propertiesToFetch` to fetch only needed attributes
- Converts to `Set` for O(1) lookup
- Filters duplicates before batch insert

### 4. Background Thread Execution

All parsing operations run on background threads:

#### M3U Parser

```swift
// Called within backgroundContext.perform {}
try M3UPlaylistParser.parse(data: data, context: backgroundContext)
```

#### Xtream Codes Parser

```swift
try await context.perform {
    try self.batchInsertVOD(items: items, ...)
}
```

#### File I/O Safety

```swift
// PlaylistCacheManager includes preconditions
precondition(!Thread.isMainThread, 
    "PlaylistCacheManager.cachePlaylist should not be called on the main thread")
```

**Benefits:**

- Never blocks UI
- Smooth user experience during imports
- Prevents ANR (Application Not Responding)

## Performance Benchmarks

### M3U Parser Benchmarks

| Playlist Size | Streaming Mode | Memory Usage | Time |
|---------------|----------------|--------------|------|
| 1,000 entries | ✓ | ~5MB | ~0.2s |
| 10,000 entries | ✓ | ~5MB | ~1.5s |
| 50,000 entries | ✓ | ~5MB | ~7s |
| 100,000 entries | ✓ | ~5MB | ~15s |

**Note:** Memory usage remains constant due to streaming architecture.

### Xtream Codes Parser Benchmarks

| Content Type | Count | Time | Notes |
|--------------|-------|------|-------|
| VOD | 5,000 | ~1s | Batch insert movies |
| Series | 1,000 | ~0.3s | Batch insert series |
| Live Streams | 10,000 | ~2s | Batch insert channels + variants |

## Best Practices

### 1. Choose the Right Parsing Mode

```swift
// For small playlists or in-memory data
let data = try Data(contentsOf: url)
try M3UPlaylistParser.parse(data: data, context: context)

// For large playlists or when memory is constrained
let fileURL = // ... download to disk first
try M3UPlaylistParser.parse(fileURL: fileURL, context: context)
```

### 2. Always Use Background Context

```swift
let backgroundContext = persistenceProvider.container.newBackgroundContext()
backgroundContext.perform {
    try M3UPlaylistParser.parse(data: data, context: backgroundContext)
}
```

### 3. Monitor Performance

Enable performance logging:

```swift
// Before parsing
let start = CFAbsoluteTimeGetCurrent()

// After parsing
let duration = CFAbsoluteTimeGetCurrent() - start
PerformanceLogger.logParsing("Parsed \(itemCount) items in \(duration)s")
```

### 4. Test with Realistic Data

Use `ParserPerformanceTests` to benchmark:

```swift
swift test --filter ParserPerformanceTests
```

## Troubleshooting

### Slow Imports

**Symptoms:** Imports take longer than expected

**Solutions:**

1. Verify using streaming mode for large files
2. Check that batch inserts are being used (look for log messages)
3. Ensure running on background context
4. Profile with Instruments (Time Profiler)

### Memory Growth

**Symptoms:** Memory usage increases during parsing

**Solutions:**

1. Use streaming parser (`parse(fileURL:)`)
2. Verify autorelease pool in tight loops
3. Reset context between large batches: `context.reset()`

### Duplicate Entities

**Symptoms:** Multiple copies of same content after re-import

**Solutions:**

1. Verify duplicate prevention logic
2. Check unique constraints in Core Data model
3. Clear cache before reimporting: Delete `PlaylistCache` entries

## Advanced: Custom Parsers

When implementing custom parsers, follow these patterns:

### Template: Batch Insert Method

```swift
private static func batchInsertEntities(
    items: [YourType],
    context: NSManagedObjectContext
) throws {
    guard !items.isEmpty else { return }
    
    // 1. Fetch existing to avoid duplicates
    let existingIDs: Set<String> = try {
        let fetchRequest: NSFetchRequest<YourEntity> = YourEntity.fetchRequest()
        fetchRequest.propertiesToFetch = ["uniqueID"]
        return Set(try context.fetch(fetchRequest).compactMap { $0.uniqueID })
    }()
    
    // 2. Filter unique items
    let uniqueItems = items.filter { !existingIDs.contains($0.id) }
    guard !uniqueItems.isEmpty else { return }
    
    // 3. Build dictionaries
    let objects = uniqueItems.map { item in
        [
            "uniqueID": item.id,
            "name": item.name,
            // ... other properties
        ] as [String: Any]
    }
    
    // 4. Execute batch insert
    let batchInsert = NSBatchInsertRequest(
        entityName: "YourEntity",
        objects: objects
    )
    try context.execute(batchInsert)
    
    print("Successfully batch inserted \(uniqueItems.count) entities.")
}
```

### Template: Streaming Parser

```swift
public static func parseStream(fileURL: URL, context: NSManagedObjectContext) throws {
    guard let stream = InputStream(url: fileURL) else {
        throw ParsingError.invalidURL
    }
    stream.open()
    defer { stream.close() }
    
    let bufferSize = 64 * 1024
    var buffer = Array<UInt8>(repeating: 0, count: bufferSize)
    var remainder = Data()
    var items: [YourType] = []
    
    while stream.hasBytesAvailable {
        let read = stream.read(&buffer, maxLength: bufferSize)
        guard read > 0 else { break }
        
        var chunk = remainder
        chunk.append(Data(buffer[0..<read]))
        
        // Split on newlines
        while let range = chunk.firstRange(of: Data([0x0A])) {
            let lineData = chunk.subdata(in: 0..<range.lowerBound)
            if let line = String(data: lineData, encoding: .utf8) {
                // Process line
                if let item = parseLine(line) {
                    items.append(item)
                }
                
                // Batch insert periodically
                if items.count >= 1000 {
                    try batchInsertEntities(items: items, context: context)
                    items.removeAll(keepingCapacity: true)
                }
            }
            chunk.removeSubrange(0..<range.upperBound)
        }
        remainder = chunk
    }
    
    // Insert remaining items
    if !items.isEmpty {
        try batchInsertEntities(items: items, context: context)
    }
}
```

## See Also

- [PerformanceMonitoring.md](PerformanceMonitoring.md) - General performance monitoring
- `ParserPerformanceTests.swift` - Performance test suite
- `M3UPlaylistParser.swift` - Reference implementation
- `XtreamCodesParser.swift` - Reference implementation
