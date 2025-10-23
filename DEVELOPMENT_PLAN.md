# 🍿 StreamHaven — iOS/tvOS MVP Development Plan (v2.0)

## 📘 Overview

**StreamHaven** is a native **Swift-based IPTV player** designed for iPhone, iPad, and Apple TV.
It provides a beautiful and fluid **SwiftUI interface**, **high-performance AVKit-based playback**, and **support for m3u playlists, Xtream Codes APIs, and EPG integration.**

The MVP targets:

* A fully working native iOS/tvOS app
* Modern Apple UX with SwiftUI
* Local + remote playlist support
* Live TV and VOD playback with adaptive streaming
* EPG guide and favorites

---

## 🎯 MVP Objectives

1. **Native SwiftUI App** optimized for iPhone, iPad, and Apple TV.
2. **Full IPTV support:** `.m3u` and Xtream Codes login.
3. **AVKit-powered player** with custom overlay controls.
4. **Dynamic EPG timeline** with Now/Next data.
5. **Favorites, History, and Resume Playback**.
6. **Offline local storage** using Core Data.
7. **Clean, Apple-style UX** with focus navigation for tvOS.

---

## 🏗️ Architecture Overview

### 1. **App Layers**

| Layer              | Framework / Tool                 | Description                                           |
| ------------------ | -------------------------------- | ----------------------------------------------------- |
| UI Layer           | SwiftUI                          | Unified adaptive UI across iPhone, iPad, and Apple TV |
| Player Layer       | AVKit / AVPlayer                 | Handles HLS playback with adaptive bitrate            |
| Data Layer         | Core Data + Codable              | Local database for playlists, favorites, and history  |
| Networking         | URLSession / Combine             | REST & playlist fetching                              |
| Caching            | NSCache + FileManager            | Thumbnail and EPG caching                             |
| EPG Engine         | Custom XMLTV parser              | Parses & caches EPG data                              |
| Backend (optional) | Vapor (Swift) / FastAPI (Python) | For remote sync, login, and shared user data          |

---

## 🧩 Core MVP Features

### 1. **Playlist Management**

* Import `.m3u` URLs or files.
* Xtream Codes API login.
* Parse, store, and categorize channels (Movies, Series, Live TV).
* Auto-refresh playlists.

### 2. **Player**

* AVPlayer with custom SwiftUI overlay.
* Adaptive bitrate streaming (HLS).
* Playback controls: Play/Pause, Next/Prev, Seek, Volume, AirPlay.
* Channel Info + Now/Next overlay.
* Resume last watched channel.

### 3. **EPG (Electronic Program Guide)**

* XMLTV parser for EPG URLs.
* Display Now/Next and full-day timeline.
* Channel-EPG linking via `tvg-id` or channel name.
* Cache EPG locally for offline access.

### 4. **User Experience**

* SwiftUI layout optimized for:

  * Touch (iPhone, iPad)
  * Focus (tvOS remote)
* Dark mode and system adaptive colors.
* Favorites and recently watched channels.
* Channel search and category filters.

### 5. **Data Persistence**

* Core Data entities:

  * `Playlist`
  * `Channel`
  * `EPGEntry`
  * `WatchHistory`
  * `UserPreference`
* Codable models for easy import/export.

---

## ⚙️ Technical Stack

| Component        | Technology                                 |
| ---------------- | ------------------------------------------ |
| Language         | Swift 5.10+                                |
| UI Framework     | SwiftUI                                    |
| Player           | AVKit / AVPlayer                           |
| Data Persistence | Core Data                                  |
| Networking       | URLSession + Combine                       |
| EPG Parsing      | XMLParser / Codable XML                    |
| Image Caching    | NSCache / URLCache                         |
| Platform Targets | iOS 17+, iPadOS 17+, tvOS 17+              |
| Testing          | XCTest / XCUITest                          |
| Build System     | Xcode 16+                                  |
| CI/CD            | GitHub Actions + Fastlane (for TestFlight) |

---

## 🧱 Project Structure

```
StreamHaven/
│
├── StreamHavenApp.swift         # Entry point
├── Models/                      # Codable + Core Data models
│   ├── Channel.swift
│   ├── Playlist.swift
│   ├── EPGEntry.swift
│   └── WatchHistory.swift
│
├── Views/                       # SwiftUI screens
│   ├── MainTabView.swift
│   ├── PlayerView.swift
│   ├── ChannelListView.swift
│   ├── EPGView.swift
│   ├── FavoritesView.swift
│   └── SettingsView.swift
│
├── ViewModels/                  # ObservableObjects
│   ├── PlaylistViewModel.swift
│   ├── PlayerViewModel.swift
│   ├── EPGViewModel.swift
│   └── FavoritesViewModel.swift
│
├── Services/                    # Networking & Logic
│   ├── PlaylistLoader.swift
│   ├── EPGParser.swift
│   ├── NetworkManager.swift
│   └── CacheManager.swift
│
├── Resources/                   # Assets & Fonts
│   ├── AppColors.swift
│   ├── PreviewData.swift
│   └── Assets.xcassets
│
├── CoreData/                    # Persistence layer
│   └── StreamHaven.xcdatamodeld
│
└── Tests/
    ├── Unit/
    └── UI/
```

---

## 🔄 Development Phases

### **Phase 1: Foundation (Week 1–2)**

* [ ] Set up Xcode project with SwiftUI + Core Data
* [ ] Implement basic UI navigation (tab-based)
* [ ] Core Data entities: `Playlist`, `Channel`, `WatchHistory`
* [ ] Playlist importer (m3u URL and file picker)

### **Phase 2: Player Core (Week 3–4)**

* [ ] Integrate AVPlayer with SwiftUI
* [ ] Add controls overlay (SwiftUI + gestures)
* [ ] Implement resume playback
* [ ] Handle network streams (HLS)

### **Phase 3: EPG Engine (Week 5–6)**

* [ ] XMLTV parser for EPG
* [ ] Link channels to EPG entries
* [ ] Display Now/Next + timeline
* [ ] Cache EPG for offline use

### **Phase 4: UI Enhancements (Week 7–8)**

* [ ] Build Favorites, History, and Search
* [ ] Add settings: dark mode, auto-refresh, playback quality
* [ ] Add responsive SwiftUI layout for iPad and tvOS

### **Phase 5: Testing & Distribution (Week 9–10)**

* [ ] Unit tests (Playlist + EPG parsers)
* [ ] UI tests (XCUITest flows)
* [ ] Integrate Fastlane for TestFlight
* [ ] Prepare for App Store submission

---

## 🧠 Post-MVP Enhancements

| Category          | Feature                               |
| ----------------- | ------------------------------------- |
| Sync              | iCloud sync for playlists and history |
| Parental Control  | PIN-protected profiles                |
| VOD Metadata      | Artwork and descriptions from TMDb    |
| AirPlay 2         | Multi-device playback                 |
| Siri Shortcuts    | “Play favorite channel” voice command |
| WidgetKit         | Quick launch and now playing widgets  |
| WatchOS Companion | Channel control via Apple Watch       |

---

## 🤝 Contribution Workflow

1. **Clone repo**

   ```bash
   git clone https://github.com/asrawiee-collab/StreamHaven.git
   ```
2. **Create a new feature branch**

   ```bash
   git checkout -b feature/epg-parser
   ```
3. **Commit with clear message**

   ```bash
   git commit -m "Added XMLTV EPG parser"
   ```
4. **Push and open PR**

   ```bash
   git push origin feature/epg-parser
   ```

**Code Style Guide**

* Use SwiftLint for consistent code style.
* Avoid UIKit unless necessary.
* Follow Apple’s Human Interface Guidelines.
* Write unit tests for every major service or model.

---

## 🧪 Testing Plan

| Type        | Tool        | Coverage                          |
| ----------- | ----------- | --------------------------------- |
| Unit Tests  | XCTest      | Models, parsers, network calls    |
| UI Tests    | XCUITest    | Player, EPG, favorites            |
| Performance | Instruments | Memory + streaming performance    |
| Manual QA   | TestFlight  | Device tests (iPhone, iPad, tvOS) |

---

## 🔐 Security & Compliance

* Validate all playlist URLs before use.
* Sandboxed storage — no remote writes.
* No credentials stored in plaintext.
* Use `SecureEnclave` for Xtream login credentials.
* GDPR-compliant data deletion.

---

## 🚀 Deployment Pipeline

**Fastlane Tasks**

* `fastlane test` → Run tests
* `fastlane beta` → Upload to TestFlight
* `fastlane release` → App Store submission

**Environments**

* Development: Local storage only
* Beta: Optional backend sync (Vapor/FastAPI)
* Production: App Store-ready, sandboxed

---

## 🗓️ Estimated Timeline (10 Weeks)

| Phase   | Duration | Deliverables                             |
| ------- | -------- | ---------------------------------------- |
| Phase 1 | 2 weeks  | Base project, Core Data, playlist import |
| Phase 2 | 2 weeks  | AVPlayer + overlay controls              |
| Phase 3 | 2 weeks  | EPG engine & Now/Next UI                 |
| Phase 4 | 2 weeks  | UI polish + Favorites & Search           |
| Phase 5 | 2 weeks  | Tests, CI/CD, TestFlight                 |

---

## 📎 Companion Docs

* `README.md` → App overview & setup guide
* `CONTRIBUTING.md` → Coding and PR guidelines
* `API_REFERENCE.md` → Optional if backend sync exists
* `DESIGN_SYSTEM.md` → SwiftUI style tokens (colors, icons, layout)

---
