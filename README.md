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
