# StreamHaven

![Tests](https://github.com/asrawiee-collab/StreamHaven/actions/workflows/test.yml/badge.svg?branch=main)

StreamHaven is a local-first streaming hub for iOS, iPadOS, and tvOS that allows you to aggregate and manage your IPTV playlists (M3U/Xtream Codes) in one place. All your data is stored locally on your device using Core Data, ensuring privacy and offline access.

## Table of Contents

- [Features](#features)
- [Architecture](#architecture)
- [Getting Started](#getting-started)
- [Core Data Model Updates](#core-data-model-updates)
- [Finalizing App Metadata](#finalizing-app-metadata)

## Features

- **Local-First:** All data is stored locally in Core Data.
- **Playlist Parsing:** Supports M3U and Xtream Codes playlists.
- **User Profiles:** Separate "Adult" and "Kids" profiles with content filtering.
- **Playback:** AVKit-based playback for a reliable experience.
- **SwiftUI:** A modern, SwiftUI-based interface.
- **Adaptive UI:** A responsive UI that adapts to different screen sizes on iPhone and iPad.
- **tvOS Support:** A dedicated tvOS interface for a cinematic experience.
- **Subtitle Search:** Search for and download subtitles from OpenSubtitles.com.

## Architecture

StreamHaven is built using the MVVM (Model-View-ViewModel) architecture pattern, with a Core Data stack for local persistence. The project is structured into the following modules:

- **App:** The main entry point of the application.
- **Models:** The Core Data managed object models.
- **Parsing:** Parsers for M3U and Xtream Codes playlists.
- **Persistence:** The Core Data stack and related components.
- **Playback:** The `AVPlayer`-based playback manager and related components.
- **UI:** The SwiftUI views and related components.
- **User:** Managers for user profiles, favorites, and settings.
- **Utilities:** Helper classes and enums.

## Getting Started

To run the project, open the `Package.swift` file in Xcode 16 or later. Xcode will automatically resolve the package and generate the necessary project files.

**Note:** This project is designed to be opened directly from the `Package.swift` file. There is no `.xcodeproj` file included in the repository.

## Core Data

Automatic lightweight migration is already enabled in `PersistenceController`. When evolving the model, prefer additive changes compatible with lightweight migration. The app attempts safe recovery if the store fails to load and reports errors via logging (and Sentry if enabled).

## Finalizing App Metadata

To ensure the app displays correctly and functions properly, a few manual steps are required in your Xcode project target settings.

### 1. Configure the Asset Catalog

The app icon and any other media assets are stored in `StreamHaven/Resources/Media.xcassets`. To make sure Xcode uses this catalog, you need to link it to your app's target:

1. In Xcode, select the `StreamHaven` project in the Project Navigator.
2. Select your main app target (e.g., "StreamHaven").
3. Go to the **General** tab.
4. Scroll down to the **App Icons and Launch Screen** section.
5. In the **App Icons** -> **Source** dropdown, select **"Media"**.
6. The `AppIcon.appiconset` provided in the catalog will now be used. You can drag and drop your final icon `.png` files into the appropriate slots in the asset catalog.

### 2. App Transport Security (ATS)

Prefer HTTPS for all endpoints. Do not disable ATS globally. If specific third-party domains require HTTP, create a targeted exception per domain:

```xml
<key>NSAppTransportSecurity</key>
<dict>
  <key>NSExceptionDomains</key>
  <dict>
     <key>example.com</key>
     <dict>
        <key>NSIncludesSubdomains</key>
        <true/>
        <key>NSExceptionAllowsInsecureHTTPLoads</key>
        <true/>
     </dict>
  </dict>
    <key>NSAllowsArbitraryLoads</key>
    <false/>
    <key>NSAllowsArbitraryLoadsInWebContent</key>
    <false/>
    <key>NSAllowsLocalNetworking</key>
    <true/>
</dict>
```

Replace `example.com` with the minimal set of domains you control or trust that cannot serve HTTPS.
Do not enable NSAllowsArbitraryLoads. Add only the specific domains under NSExceptionDomains that truly require HTTP.

### 3. Configure OpenSubtitles API Key (Secure)

4. Store the key securely in the Keychain during development using the app's helper:

```swift
// e.g., in a one-off dev tool or a debug-only code path
KeychainHelper.savePassword(password: "<YOUR_OS_API_KEY>", for: "OpenSubtitlesAPIKey", service: "StreamHaven.API")
```

The app reads `OpenSubtitlesAPIKey` from the Keychain at runtime. Do not commit keys to Info.plist or source code.

1. **Register an account** at [OpenSubtitles.com](https://www.opensubtitles.com/).
2. Navigate to the **[API Consumers](https://www.opensubtitles.com/en/consumers)** section of your profile.
3. Create a new consumer to generate an API key.
4. Do not store API keys in Info.plist. Keep them only in the Keychain during development and retrieve at runtime.

### 4. Configure TMDb API Key (Secure)

3. Store the key securely in the Keychain during development:

```swift
KeychainHelper.savePassword(password: "<YOUR_TMDB_API_KEY>", for: "TMDbAPIKey", service: "StreamHaven.API")
```

The app reads `TMDbAPIKey` from the Keychain at runtime.

1. **Register an account** at [themoviedb.org](https://www.themoviedb.org/).
2. Go to your account **Settings -> API** section to request an API key.
3. Do not store API keys in Info.plist. Keep them only in the Keychain during development and retrieve at runtime.
