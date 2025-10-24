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

## Finalizing App Metadata

To ensure the app displays correctly and functions properly, a few manual steps are required in your Xcode project target settings.

### 1. Configure the Asset Catalog

The app icon and any other media assets are stored in `StreamHaven/Resources/Media.xcassets`. To make sure Xcode uses this catalog, you need to link it to your app's target:

1.  In Xcode, select the `StreamHaven` project in the Project Navigator.
2.  Select your main app target (e.g., "StreamHaven").
3.  Go to the **General** tab.
4.  Scroll down to the **App Icons and Launch Screen** section.
5.  In the **App Icons** -> **Source** dropdown, select **"Media"**.
6.  The `AppIcon.appiconset` provided in the catalog will now be used. You can drag and drop your final icon `.png` files into the appropriate slots in the asset catalog.

### 2. Configure `Info.plist` for Network Access

Many IPTV and VOD providers use standard `http` URLs. By default, iOS and tvOS block these connections for security. To allow the app to load these playlists, you must add the following key to your target's `Info.plist` file:

```xml
<key>NSAppTransportSecurity</key>
<dict>
    <key>NSAllowsArbitraryLoads</key>
    <true/>
</dict>
```

**To add this:**
1.  In Xcode, select your app target.
2.  Go to the **Info** tab.
3.  Hover over any key and click the `+` button.
4.  From the dropdown, select **"App Transport Security Settings"**.
5.  Click the `+` button next to this new entry and select **"Allow Arbitrary Loads"**.
6.  Set the value for this key to **"YES"**.

### 3. Configure OpenSubtitles API Key (Optional)

The app supports searching for and downloading subtitles from OpenSubtitles.com. To enable this feature, you must obtain a free API key:

1.  **Register an account** at [OpenSubtitles.com](https://www.opensubtitles.com/).
2.  Navigate to the **[API Consumers](https://www.opensubtitles.com/en/consumers)** section of your profile.
3.  Create a new consumer to generate an API key.
4.  Once you have your key, add it to your target's `Info.plist` file:
    1.  In Xcode, select your app target and go to the **Info** tab.
    2.  Click the `+` button to add a new key.
    3.  For the key name, enter `OpenSubtitlesAPIKey`.
    4.  Set the value to the API key you generated.

### 5. Configure TMDb API Key (Optional)

To enable the automatic fetching of IMDb IDs (which is required for subtitle search), you must obtain a free API key from The Movie Database (TMDb).

1.  **Register an account** at [themoviedb.org](https://www.themoviedb.org/).
2.  Go to your account **Settings -> API** section to request an API key.
3.  Once you have your key, add it to your target's `Info.plist` file:
    1.  In Xcode, select your app target and go to the **Info** tab.
    2.  Click the `+` button to add a new key.
    3.  For the key name, enter `TMDbAPIKey`.
    4.  Set the value to your TMDb API key.

### 4. Update Core Data Model for Subtitle Search

To enable subtitle search, the `Movie` entity in the Core Data model must be updated to include an IMDb ID.

1.  Open the `.xcdatamodeld` file in Xcode.
2.  Select the `Movie` entity.
3.  Add a new attribute named `imdbID` of type `String`.
