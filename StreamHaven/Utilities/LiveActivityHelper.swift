#if os(iOS)
import ActivityKit
import Foundation

/// Manages Live Activities for Now Playing or ongoing playback.
/// Separated from PlaybackManager for testability and modularity.
@available(iOS 16.1, *)
public final class LiveActivityHelper {
    public struct PlaybackAttributes: ActivityAttributes {
        public struct ContentState: Codable, Hashable {
            public var title: String
            public var progress: Double // 0..1
            public var isLive: Bool
            public var isPlaying: Bool
            public init(title: String, progress: Double, isLive: Bool, isPlaying: Bool) {
                self.title = title
                self.progress = progress
                self.isLive = isLive
                self.isPlaying = isPlaying
            }
        }
        public init() {}
    }
    
    private var activity: Activity<PlaybackAttributes>?
    
    public init() {}
    
    public func start(title: String, isLive: Bool) async {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }
        do {
            let initialState = PlaybackAttributes.ContentState(title: title, progress: 0, isLive: isLive, isPlaying: true)
            activity = try Activity<PlaybackAttributes>.request(attributes: .init(), contentState: initialState)
        } catch {
            // Silently ignore in production; could add logging
        }
    }
    
    public func update(progress: Double) async {
        guard let activity else { return }
        let current = activity.contentState
        await activity.update(using: .init(title: current.title, progress: progress, isLive: current.isLive, isPlaying: current.isPlaying))
    }
    
    public func pauseActivity() async {
        guard let activity else { return }
        let current = activity.contentState
        await activity.update(using: .init(title: current.title, progress: current.progress, isLive: current.isLive, isPlaying: false))
    }
    
    public func resumeActivity() async {
        guard let activity else { return }
        let current = activity.contentState
        await activity.update(using: .init(title: current.title, progress: current.progress, isLive: current.isLive, isPlaying: true))
    }
    
    public func endActivity() async {
        await activity?.end(dismissalPolicy: .immediate)
        activity = nil
    }
    
    public func stop() async {
        await endActivity()
    }
}
#endif
