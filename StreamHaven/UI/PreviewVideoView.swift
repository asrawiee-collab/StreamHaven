//
//  PreviewVideoView.swift
//  StreamHaven
//
//  Created on October 25, 2025.
//

#if os(tvOS)
import AVKit
import SwiftUI

/// A view that displays a looping video preview with smooth transitions.
struct PreviewVideoView: View {
    let player: AVPlayer
    @State private var opacity: Double = 0.0
    
    var body: some View {
        VideoPlayer(player: player)
            .disabled(true) // Disable controls
            .opacity(opacity)
            .onAppear {
                withAnimation(.easeIn(duration: 0.3)) {
                    opacity = 1.0
                }
            }
            .onDisappear {
                opacity = 0.0
            }
    }
}

/// A card view that shows video preview on focus (tvOS only).
struct HoverPreviewCard: View {
    @EnvironmentObject var previewManager: HoverPreviewManager
    @FocusState private var isFocused: Bool
    
    let contentID: String
    let previewURL: String?
    let posterURL: String?
    let title: String
    let onSelect: () -> Void
    
    var body: some View {
        Button(action: onSelect) {
            ZStack {
                // Poster image (always shown)
                if let posterURL = posterURL, let url = URL(string: posterURL) {
                    AsyncImage(url: url) { image in
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    } placeholder: {
                        Rectangle()
                            .fill(Color.gray.opacity(0.3))
                    }
                } else {
                    Rectangle()
                        .fill(Color.gray.opacity(0.3))
                        .overlay(
                            Image(systemName: "film")
                                .font(.system(size: 60))
                                .foregroundColor(.white.opacity(0.5))
                        )
                }
                
                // Video preview (shown on focus if available)
                if isFocused, let player = previewManager.currentPlayer, previewManager.currentPreviewURL == contentID {
                    PreviewVideoView(player: player)
                }
                
                // Title overlay (visible when not focused or no preview)
                if !isFocused || previewURL == nil {
                    VStack {
                        Spacer()
                        HStack {
                            Text(title)
                                .font(.headline)
                                .foregroundColor(.white)
                                .lineLimit(2)
                                .padding(8)
                                .background(
                                    LinearGradient(
                                        colors: [.clear, .black.opacity(0.8)], startPoint: .top, endPoint: .bottom
                                    )
                                )
                            Spacer()
                        }
                    }
                }
            }
            .frame(width: 400, height: 225)
            .cornerRadius(12)
            .shadow(radius: isFocused ? 10: 5)
            .scaleEffect(isFocused ? 1.05: 1.0)
            .animation(.easeInOut(duration: 0.2), value: isFocused)
        }
        .buttonStyle(.plain)
        .focused($isFocused)
        .onChange(of: isFocused) { focused in
            if focused {
                previewManager.onFocus(contentID: contentID, previewURL: previewURL)
            } else {
                previewManager.onBlur(contentID: contentID)
            }
        }
    }
}

/// A grid card for movies with hover preview support.
struct MovieCardWithPreview: View {
    @EnvironmentObject var previewManager: HoverPreviewManager
    @FocusState private var isFocused: Bool
    
    let movie: Movie
    let onSelect: () -> Void
    
    var body: some View {
        HoverPreviewCard(
            contentID: movie.objectID.uriRepresentation().absoluteString, previewURL: movie.previewURL, posterURL: movie.posterURL, title: movie.title ?? "Unknown Movie", onSelect: onSelect
        )
        .environmentObject(previewManager)
    }
}

/// A grid card for series with hover preview support.
struct SeriesCardWithPreview: View {
    @EnvironmentObject var previewManager: HoverPreviewManager
    @FocusState private var isFocused: Bool
    
    let series: Series
    let onSelect: () -> Void
    
    var body: some View {
        HoverPreviewCard(
            contentID: series.objectID.uriRepresentation().absoluteString, previewURL: series.previewURL, posterURL: series.posterURL, title: series.title ?? "Unknown Series", onSelect: onSelect
        )
        .environmentObject(previewManager)
    }
}
#endif
