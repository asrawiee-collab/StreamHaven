# Performance Monitoring Guide

This document describes how to profile StreamHaven and review runtime telemetry.

## Instruments: Leaks & Time Profiler

1. Open Xcode > Product > Profile.
2. Choose "Leaks" to find memory leaks and retain cycles.
3. Choose "Time Profiler" to profile CPU hotspots.
4. Start recording, navigate typical user flows, then stop and inspect call trees.

Tips:
- Filter by the `StreamHaven` module to focus on app code.
- Look for long-running SwiftUI view updates and Core Data fetches.

## HLS Analyzer / AVPlayer Metrics

- The app logs HLS metrics (bitrate, stalls, startup time) from `AVPlayerItem` access logs.
- View logs in Xcode Console or Console.app using subsystem `com.asrawiee.StreamHaven` and category `Playback`.

## Crash Reporting & Performance Tracing (Sentry)

- The app initializes Sentry if a DSN is provided via environment `SENTRY_DSN` or Info.plist key `SentryDSN`.
- Features enabled: crash reporting, app hang tracking, UI tracing, network tracking, Core Data tracing.

Set DSN locally by adding to the scheme's Environment Variables:
- Key: `SENTRY_DSN`
- Value: `<your DSN>`

## Analytics Hooks

- Use `PerformanceLogger.logPlayback|logNetwork|logCoreData` to track feature usage or important events.
- Events are logged to OSLog and also added as Sentry breadcrumbs (when Sentry is enabled).

## Core Data Monitoring

- The `PerformanceLogger.measure(label:threshold:_:)` helper can wrap costly fetches/saves.
- Sentry Core Data tracing is enabled when Sentry is active.

## Network Logging

- `NetworkLoggerURLProtocol` logs HTTP(S) requests/responses and timings.
- View logs by filtering category `Network`.

## CI/CD

- Logs and failures surface in GitHub Actions logs. SwiftLint enforces style consistency to keep diffs readable for performance work.
