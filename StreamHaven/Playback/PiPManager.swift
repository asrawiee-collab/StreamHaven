#if os(iOS)
import Foundation
import AVKit
import AVFoundation

/// Manages Picture in Picture independently of PlaybackManager to reduce complexity.
@MainActor
public final class PiPManager: ObservableObject {
    @Published public private(set) var isPictureInPictureActive: Bool = false
    private var pipController: AVPictureInPictureController?
    
    public init() {}
    
    /// Configure PiP with an AVPlayerLayer
    public func configure(with playerLayer: AVPlayerLayer) {
        if AVPictureInPictureController.isPictureInPictureSupported() {
            pipController = AVPictureInPictureController(playerLayer: playerLayer)
            pipController?.delegate = self
        } else {
            pipController = nil
        }
    }
    
    public func start() {
        pipController?.startPictureInPicture()
    }
    
    public func stop() {
        pipController?.stopPictureInPicture()
    }
}

extension PiPManager: AVPictureInPictureControllerDelegate {
    public func pictureInPictureControllerWillStartPictureInPicture(_ pictureInPictureController: AVPictureInPictureController) {
        isPictureInPictureActive = true
    }
    public func pictureInPictureControllerDidStopPictureInPicture(_ pictureInPictureController: AVPictureInPictureController) {
        isPictureInPictureActive = false
    }
}
#endif
