# StreamHaven

StreamHaven is a local-first streaming hub for iOS, iPadOS, and tvOS.

## Getting Started

To run the project, open the `Package.swift` file in Xcode 16 or later. Xcode will automatically resolve the package and generate the necessary project files.

**Note:** This project is designed to be opened directly from the `Package.swift` file. There is no `.xcodeproj` file included in the repository.

## Features

*   **Local-First:** All data is stored locally in Core Data.
*   **Playlist Parsing:** Supports M3U and Xtream Codes playlists.
*   **User Profiles:** Separate "Adult" and "Kids" profiles with content filtering.
*   **Playback:** AVKit-based playback for a reliable experience.
*   **SwiftUI:** A modern, SwiftUI-based interface.

## Future Improvements

### Smart Grouping

The current Core Data model does not support grouping multiple stream sources for a single movie or episode. To implement this, the following changes are required:

1.  **Create `MovieVariant` and `EpisodeVariant` Entities:**
    *   Add new entities named `MovieVariant` and `EpisodeVariant`.
    *   Each should have `name` (String) and `streamURL` (String) attributes.

2.  **Update `Movie` Entity:**
    *   Remove the `streamURL` attribute.
    *   Add a one-to-many relationship named `variants` to the `MovieVariant` entity.

3.  **Update `Episode` Entity:**
    *   Remove the `streamURL` attribute.
    *   Add a one-to-many relationship named `variants` to the `EpisodeVariant` entity.

After these changes are made in the `.xcdatamodeld` file and the managed object subclasses are regenerated, the parsing logic can be updated to support grouping.

---

## 🧠 GOAL: Smart Grouping for Multiple Stream Sources

### 🎯 Problem

Currently, each `Movie` and `Episode` has a single `streamURL` attribute.
This makes it impossible to support multiple servers or stream variants (e.g. 720p, 1080p, backup links, dubbed/subbed versions).

### ✅ Solution

Introduce **MovieVariant** and **EpisodeVariant** entities, and replace `streamURL` attributes with relationships.

---

## ⚙️ STEP 1: Modify Core Data Model (`StreamHaven.xcdatamodeld`)

Open **StreamHaven.xcdatamodeld** in Xcode and perform the following:

### **1. Create `MovieVariant` Entity**

| Attribute   | Type   | Optional | Notes                                        |
| ----------- | ------ | -------- | -------------------------------------------- |
| `name`      | String | Yes      | e.g. "1080p", "Backup Server", "English Dub" |
| `streamURL` | String | No       | Direct HLS or M3U8 URL                       |

**Relationships:**

| Name    | Destination | Type   | Inverse        | Delete Rule |
| ------- | ----------- | ------ | -------------- | ----------- |
| `movie` | Movie       | To-One | Movie.variants | Cascade     |

---

### **2. Create `EpisodeVariant` Entity**

| Attribute   | Type   | Optional | Notes                         |
| ----------- | ------ | -------- | ----------------------------- |
| `name`      | String | Yes      | e.g. "720p", "Server 2", etc. |
| `streamURL` | String | No       | Direct stream link            |

**Relationships:**

| Name      | Destination | Type   | Inverse          | Delete Rule |
| --------- | ----------- | ------ | ---------------- | ----------- |
| `episode` | Episode     | To-One | Episode.variants | Cascade     |

---

### **3. Update `Movie` Entity**

**Remove:**

* `streamURL` (String)

**Add:**

| Name       | Destination  | Type    | Inverse            | Delete Rule |
| ---------- | ------------ | ------- | ------------------ | ----------- |
| `variants` | MovieVariant | To-Many | MovieVariant.movie | Cascade     |

---

### **4. Update `Episode` Entity**

**Remove:**

* `streamURL` (String)

**Add:**

| Name       | Destination    | Type    | Inverse                | Delete Rule |
| ---------- | -------------- | ------- | ---------------------- | ----------- |
| `variants` | EpisodeVariant | To-Many | EpisodeVariant.episode | Cascade     |

---

## 🧩 STEP 2: Regenerate Managed Object Subclasses

After saving the model:

1. In Xcode, select **Editor → Create NSManagedObject Subclass**.
2. Choose your `StreamHaven.xcdatamodeld`.
3. Select the following entities:

   * `Movie`, `MovieVariant`, `Episode`, `EpisodeVariant`
4. Save them to the `Models/` directory (overwrite existing `Movie.swift` and `Episode.swift`).

This will regenerate your updated Core Data classes with new relationships.

---

## 🧠 STEP 3: Update Your Models (Example Swift Classes)

### `Movie.swift`

```swift
import CoreData

@objc(Movie)
public class Movie: NSManagedObject {}

extension Movie {
    @nonobjc public class func fetchRequest() -> NSFetchRequest<Movie> {
        return NSFetchRequest<Movie>(entityName: "Movie")
    }

    @NSManaged public var title: String
    @NSManaged public var descriptionText: String?
    @NSManaged public var releaseDate: Date?
    @NSManaged public var posterURL: String?
    @NSManaged public var variants: Set<MovieVariant>?
}

// MARK: - Computed Accessors
extension Movie {
    public var primaryVariant: MovieVariant? {
        return variants?.first
    }

    public var sortedVariants: [MovieVariant] {
        return (variants ?? []).sorted { $0.name ?? "" < $1.name ?? "" }
    }
}
```

---

### `MovieVariant.swift`

```swift
import CoreData

@objc(MovieVariant)
public class MovieVariant: NSManagedObject {}

extension MovieVariant {
    @nonobjc public class func fetchRequest() -> NSFetchRequest<MovieVariant> {
        return NSFetchRequest<MovieVariant>(entityName: "MovieVariant")
    }

    @NSManaged public var name: String?
    @NSManaged public var streamURL: String
    @NSManaged public var movie: Movie?
}
```

---

### `Episode.swift`

```swift
import CoreData

@objc(Episode)
public class Episode: NSManagedObject {}

extension Episode {
    @nonobjc public class func fetchRequest() -> NSFetchRequest<Episode> {
        return NSFetchRequest<Episode>(entityName: "Episode")
    }

    @NSManaged public var title: String
    @NSManaged public var number: Int16
    @NSManaged public var descriptionText: String?
    @NSManaged public var variants: Set<EpisodeVariant>?
}

extension Episode {
    public var primaryVariant: EpisodeVariant? {
        return variants?.first
    }
}
```

---

### `EpisodeVariant.swift`

```swift
import CoreData

@objc(EpisodeVariant)
public class EpisodeVariant: NSManagedObject {}

extension EpisodeVariant {
    @nonobjc public class func fetchRequest() -> NSFetchRequest<EpisodeVariant> {
        return NSFetchRequest<EpisodeVariant>(entityName: "EpisodeVariant")
    }

    @NSManaged public var name: String?
    @NSManaged public var streamURL: String
    @NSManaged public var episode: Episode?
}
```

---

## 🔄 STEP 4: Update the Parsing Logic

Wherever your app currently sets:

```swift
movie.streamURL = url
```

Replace with:

```swift
let variant = MovieVariant(context: context)
variant.name = "Default"
variant.streamURL = url
movie.addToVariants(variant)
```

Same pattern applies for episodes.

If your parser supports multiple stream links for the same movie/episode (e.g., in an M3U with grouped streams or Xtream responses), just create one `MovieVariant` or `EpisodeVariant` per link.

---

## 🧠 STEP 5: Playback Integration

When playing a video:

```swift
if let variant = movie.primaryVariant {
    player.playStream(from: variant.streamURL)
}
```

You can even add a “Choose Source” button in the player overlay:

```swift
ForEach(movie.sortedVariants, id: \.self) { variant in
    Button(variant.name ?? "Unknown") {
        playerViewModel.play(url: variant.streamURL)
    }
}
```

---

## ✅ STEP 6: Testing Checklist

| Task                                       | Status | Notes                             |
| ------------------------------------------ | ------ | --------------------------------- |
| Modify `.xcdatamodeld` with 2 new entities | ☐      | Done via Xcode                    |
| Regenerate NSManagedObject subclasses      | ☐      | Overwrite old Movie/Episode       |
| Update parsing logic                       | ☐      | Replace streamURL writes          |
| Migrate Core Data (optional)               | ☐      | Add lightweight migration         |
| Update player UI                           | ☐      | Add variant selector              |
| Test multi-source playback                 | ☐      | Verify switching works seamlessly |

---
