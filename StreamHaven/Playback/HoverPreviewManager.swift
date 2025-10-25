//
//  HoverPreviewManager.swift
//  StreamHaven
//
//  Created on October 25, 2025.
//

#if os(tvOS)
import Foundation
import AVKit
import Combine

/// Manages hover preview video playback for tvOS content cards.
/// Loads and plays short preview clips when users focus on content items.
@MainActor
public class HoverPreviewManager: ObservableObject {
    
    // MARK: - Published Properties
    
    @Published public var currentPlayer: AVPlayer?
    @Published public var isPlaying: Bool = false
    @Published public var currentPreviewURL: String?
    
    // MARK: - Properties
    
    private var previewPlayers: [String: AVPlayer] = [:]
    private var focusDelayTask: Task<Void, Never>?
    private var loopObserver: NSObjectProtocol?
    
    /// Cache for preview URLs to avoid repeated lookups
    private var previewCache: [String: String] = [:]
    
    // MARK: - Settings
    
    private let settingsManager: SettingsManager
    
    // MARK: - Initialization
    
    public init(settingsManager: SettingsManager) {
        self.settingsManager = settingsManager
    }
    
    deinit {
        cleanup()
    }
    
    // MARK: - Preview Management
    
    /// Called when content receives focus
    public func onFocus(contentID: String, previewURL: String?) {
        guard settingsManager.enableHoverPreviews, let previewURL = previewURL, !previewURL.isEmpty else {
            return
        }
        
        // Cancel any pending preview
        focusDelayTask?.cancel()
        
        // Start delay timer before showing preview
        focusDelayTask = Task {
            try? await Task.sleep(nanoseconds: UInt64(settingsManager.hoverPreviewDelay * 1_000_000_000))
            
            // Check if still valid after delay
            guard !Task.isCancelled else { return }
            
            await startPreview(contentID: contentID, previewURL: previewURL)
        }
    }
    
    /// Called when content loses focus
    public func onBlur(contentID: String) {
        // Cancel pending preview
        focusDelayTask?.cancel()
        
        // Stop current preview if it matches
        if currentPreviewURL == contentID {
            stopPreview()
        }
    }
    
    /// Starts playing a preview video
    private func startPreview(contentID: String, previewURL: String) {
        // Stop current preview if playing
        stopPreview()
        
        // Get or create player for this preview
        let player = getOrCreatePlayer(for: previewURL)
        
        currentPlayer = player
        currentPreviewURL = contentID
        isPlaying = true
        
        // Start playback
        player.seek(to: .zero)
        player.play()
        
        // Set up loop observer
        setupLoopObserver(for: player)
    }
    
    /// Stops the current preview
    public func stopPreview() {
        currentPlayer?.pause()
        currentPlayer = nil
        currentPreviewURL = nil
        isPlaying = false
        
        // Remove loop observer
        if let observer = loopObserver {
            NotificationCenter.default.removeObserver(observer)
            loopObserver = nil
        }
    }
    
    /// Gets existing player or creates new one for URL
    private func getOrCreatePlayer(for urlString: String) -> AVPlayer {
        // Check cache
        if let existingPlayer = previewPlayers[urlString] {
            return existingPlayer
        }
        
        // Create new player
        guard let url = URL(string: urlString) else {
            // Return empty player if URL is invalid
            return AVPlayer()
        }
        
        let player = AVPlayer(url: url)
        player.isMuted = true // Previews are silent
        player.actionAtItemEnd = .none // We'll handle looping manually
        
        previewPlayers[urlString] = player
        
        return player
    }
    
    /// Sets up observer to loop video playback
    private func setupLoopObserver(for player: AVPlayer) {
        loopObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: player.currentItem,
            queue: .main
        ) { [weak self, weak player] _ in
            guard let player = player else { return }
            player.seek(to: .zero)
            player.play()
        }
    }
    
    // MARK: - Cache Management
    
    /// Caches a preview URL for quick lookup
    public func cachePreviewURL(_ url: String, for contentID: String) {
        previewCache[contentID] = url
    }
    
    /// Retrieves cached preview URL
    public func getCachedPreviewURL(for contentID: String) -> String? {
        return previewCache[contentID]
    }
    
    /// Clears preview cache
    public func clearCache() {
        previewCache.removeAll()
        
        // Also clear player cache
        for player in previewPlayers.values {
            player.pause()
        }
        previewPlayers.removeAll()
    }
    
    // MARK: - Cleanup
    
    /// Cleans up resources
    public func cleanup() {
        stopPreview()
        focusDelayTask?.cancel()
        
        // Clean up all players
        for player in previewPlayers.values {
            player.pause()
            player.replaceCurrentItem(with: nil)
        }
        previewPlayers.removeAll()
        previewCache.removeAll()
    }
    
    // MARK: - Configuration
    
    /// Updates preview delay setting
    public func updateDelay(_ delay: TimeInterval) {
        // Delay will be used on next focus
    }
    
    /// Enables or disables hover previews
    public func setEnabled(_ enabled: Bool) {
        isEnabled = enabled
        
        if !enabled {
            stopPreview()
        }
    }
}
#endif
