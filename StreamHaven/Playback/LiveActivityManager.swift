import Foundation
import ActivityKit
import SwiftUI

#if os(iOS)
import UIKit

/// Attributes for StreamHaven Live Activities
@available(iOS 16.1, *)
struct StreamHavenActivityAttributes: ActivityAttributes {
    /// Static content that doesn't change during the activity
    public struct ContentState: Codable, Hashable {
        /// The title of the currently playing content
        var contentTitle: String
        /// The current playback progress (0.0 to 1.0)
        var progress: Double
        /// Whether playback is currently active
        var isPlaying: Bool
        /// The elapsed time in seconds
        var elapsedSeconds: TimeInterval
        /// The total duration in seconds
        var totalSeconds: TimeInterval
        /// Optional thumbnail URL
        var thumbnailURL: String?
        /// Content type (movie, episode, channel)
        var contentType: String
        /// Optional series/season info for episodes
        var seriesInfo: String?
    }
    
    /// The stream URL (used as identifier)
    var streamIdentifier: String
}

/// Manages Live Activities for playback on iOS 16.1+
@available(iOS 16.1, *)
@MainActor
public class LiveActivityManager: ObservableObject {
    
    // MARK: - Published Properties
    
    @Published var isActivityActive = false
    @Published var activityError: Error?
    
    // MARK: - Properties
    
    private var currentActivity: Activity<StreamHavenActivityAttributes>?
    private var activityUpdateTask: Task<Void, Never>?
    
    // MARK: - Initialization
    
    public init() {
        // Check for existing activities on init
        checkExistingActivities()
    }
    
    deinit {
        activityUpdateTask?.cancel()
    }
    
    // MARK: - Public Methods
    
    /// Starts a new Live Activity for the given content
    /// - Parameters:
    ///   - title: The content title
    ///   - contentType: Type of content (movie, episode, channel)
    ///   - streamIdentifier: Unique identifier for the stream
    ///   - thumbnailURL: Optional thumbnail URL
    ///   - seriesInfo: Optional series/season info for episodes
    ///   - duration: Total duration in seconds
    public func startActivity(
        title: String,
        contentType: String,
        streamIdentifier: String,
        thumbnailURL: String? = nil,
        seriesInfo: String? = nil,
        duration: TimeInterval
    ) async throws {
        // End any existing activity first
        await endActivity()
        
        guard ActivityAuthorizationInfo().areActivitiesEnabled else {
            throw LiveActivityError.notAuthorized
        }
        
        let attributes = StreamHavenActivityAttributes(streamIdentifier: streamIdentifier)
        let initialState = StreamHavenActivityAttributes.ContentState(
            contentTitle: title,
            progress: 0.0,
            isPlaying: true,
            elapsedSeconds: 0,
            totalSeconds: duration,
            thumbnailURL: thumbnailURL,
            contentType: contentType,
            seriesInfo: seriesInfo
        )
        
        do {
            let activity = try Activity<StreamHavenActivityAttributes>.request(
                attributes: attributes,
                content: .init(state: initialState, staleDate: nil),
                pushType: nil
            )
            
            currentActivity = activity
            isActivityActive = true
            activityError = nil
            
            print("✅ Live Activity started: \(title)")
            
        } catch {
            activityError = error
            isActivityActive = false
            print("❌ Failed to start Live Activity: \(error.localizedDescription)")
            throw error
        }
    }
    
    /// Updates the current Live Activity with new playback state
    /// - Parameters:
    ///   - progress: Current progress (0.0 to 1.0)
    ///   - isPlaying: Whether playback is active
    ///   - elapsedSeconds: Elapsed time in seconds
    public func updateActivity(
        progress: Double,
        isPlaying: Bool,
        elapsedSeconds: TimeInterval
    ) async {
        guard let activity = currentActivity else {
            print("⚠️ No active Live Activity to update")
            return
        }
        
        let updatedState = StreamHavenActivityAttributes.ContentState(
            contentTitle: activity.content.state.contentTitle,
            progress: progress,
            isPlaying: isPlaying,
            elapsedSeconds: elapsedSeconds,
            totalSeconds: activity.content.state.totalSeconds,
            thumbnailURL: activity.content.state.thumbnailURL,
            contentType: activity.content.state.contentType,
            seriesInfo: activity.content.state.seriesInfo
        )
        
        let alertConfiguration = AlertConfiguration(
            title: isPlaying ? "Playing" : "Paused",
            body: activity.content.state.contentTitle,
            sound: .default
        )
        
        await activity.update(
            .init(state: updatedState, staleDate: nil),
            alertConfiguration: alertConfiguration
        )
    }
    
    /// Ends the current Live Activity
    public func endActivity() async {
        guard let activity = currentActivity else {
            return
        }
        
        let finalState = activity.content.state
        
        await activity.end(
            .init(state: finalState, staleDate: nil),
            dismissalPolicy: .immediate
        )
        
        currentActivity = nil
        isActivityActive = false
        
        print("🛑 Live Activity ended")
    }
    
    /// Pauses the Live Activity (updates to paused state)
    public func pauseActivity() async {
        guard let activity = currentActivity else { return }
        
        await updateActivity(
            progress: activity.content.state.progress,
            isPlaying: false,
            elapsedSeconds: activity.content.state.elapsedSeconds
        )
    }
    
    /// Resumes the Live Activity (updates to playing state)
    public func resumeActivity() async {
        guard let activity = currentActivity else { return }
        
        await updateActivity(
            progress: activity.content.state.progress,
            isPlaying: true,
            elapsedSeconds: activity.content.state.elapsedSeconds
        )
    }
    
    // MARK: - Private Methods
    
    private func checkExistingActivities() {
        let activities = Activity<StreamHavenActivityAttributes>.activities
        if let activity = activities.first {
            currentActivity = activity
            isActivityActive = true
            print("📱 Found existing Live Activity")
        }
    }
    
    // MARK: - Helper Methods
    
    /// Checks if Live Activities are supported on this device
    public static var isSupported: Bool {
        if #available(iOS 16.1, *) {
            return true
        }
        return false
    }
    
    /// Checks if Live Activities are authorized by the user
    public static var areActivitiesEnabled: Bool {
        if #available(iOS 16.1, *) {
            return ActivityAuthorizationInfo().areActivitiesEnabled
        }
        return false
    }
}

// MARK: - Error Types

@available(iOS 16.1, *)
enum LiveActivityError: LocalizedError {
    case notAuthorized
    case activityNotFound
    case updateFailed
    case startFailed(Error)
    
    var errorDescription: String? {
        switch self {
        case .notAuthorized:
            return "Live Activities are not enabled. Please enable them in Settings."
        case .activityNotFound:
            return "No active Live Activity found."
        case .updateFailed:
            return "Failed to update Live Activity."
        case .startFailed(let error):
            return "Failed to start Live Activity: \(error.localizedDescription)"
        }
    }
}

// MARK: - Fallback for older iOS versions

#else
// Fallback for non-iOS platforms (tvOS, macOS)
@MainActor
public class LiveActivityManager: ObservableObject {
    @Published public var isActivityActive = false
    @Published public var activityError: Error?
    
    public init() {}
    
    public func startActivity(
        title: String,
        contentType: String,
        streamIdentifier: String,
        thumbnailURL: String? = nil,
        seriesInfo: String? = nil,
        duration: TimeInterval
    ) async throws {
        // No-op on non-iOS platforms
    }
    
    public func updateActivity(
        progress: Double,
        isPlaying: Bool,
        elapsedSeconds: TimeInterval
    ) async {
        // No-op on non-iOS platforms
    }
    
    public func endActivity() async {
        // No-op on non-iOS platforms
    }
    
    public func pauseActivity() async {
        // No-op on non-iOS platforms
    }
    
    public func resumeActivity() async {
        // No-op on non-iOS platforms
    }
    
    public static var isSupported: Bool { false }
    public static var areActivitiesEnabled: Bool { false }
}
#endif
