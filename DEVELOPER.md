# Developer Guide

This document provides guidance for developers working on the StreamHaven project.

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

## Blocked and Future Tasks

### Full-Text Search (FTS5)

Core Data does not directly support FTS5. The current search implementation uses `CONTAINS[cd]` predicates, which is sufficient for small to medium-sized libraries. For larger libraries, a more performant solution would be to use a dedicated search engine like FTS5. This would require a separate SQLite database to be created and managed alongside the Core Data store.

### Core Data Schema Migrations

Automatic lightweight migration is enabled in `PersistenceController` via `shouldMigrateStoreAutomatically` and `shouldInferMappingModelAutomatically`. Prefer additive, lightweight-migration-friendly schema changes. If a store fails to load, the app attempts recovery and logs the error (reported to Sentry if configured). Remove any instructions suggesting manual migration is required by default.
