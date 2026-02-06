//
//  VideoPreviewView.swift
//  TOYShared
//
//  View for previewing a recorded video before submission.
//

import AVFoundation
import SwiftUI

/// View for previewing a recorded video before submission.
public struct VideoPreviewView: View {
    let videoURL: URL
    let onRetake: () -> Void
    let onConfirm: () -> Void

    @State private var player: AVPlayer?
    @State private var playerLooper: AVPlayerLooper?
    @State private var thumbnail: UIImage?
    @State private var isPlayerReady = false

    public init(
        videoURL: URL,
        onRetake: @escaping () -> Void,
        onConfirm: @escaping () -> Void
    ) {
        self.videoURL = videoURL
        self.onRetake = onRetake
        self.onConfirm = onConfirm
    }

    public var body: some View {
        VStack(spacing: 0) {
            // Video player - custom view without controls
            ZStack {
                if let player {
                    LoopingVideoPlayer(player: player) {
                        isPlayerReady = true
                    }
                    .aspectRatio(9/16, contentMode: .fit)
                    .opacity(isPlayerReady ? 1 : 0)
                    .overlay(alignment: .bottom) {
                        if isPlayerReady {
                            Text("Thinking Of You")
                                .font(.custom("DMSerifDisplay-Regular", size: 24))
                                .foregroundColor(.white)
                                .shadow(color: .black.opacity(0.3), radius: 4, x: 0, y: 2)
                                .padding(.bottom, 16)
                        }
                    }
                }

                // Thumbnail placeholder — shown until player renders first frame
                if !isPlayerReady {
                    if let thumbnail {
                        Image(uiImage: thumbnail)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(maxWidth: .infinity)
                            .aspectRatio(9/16, contentMode: .fit)
                            .clipped()
                    } else {
                        Rectangle()
                            .fill(Color.black)
                            .aspectRatio(9/16, contentMode: .fit)
                    }
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .padding(.horizontal, 24)

            Spacer()

            // Action buttons
            HStack(spacing: 24) {
                TOYButton(
                    "Retake",
                    style: .secondary,
                    size: .large,
                    action: onRetake
                )
                .frame(maxWidth: .infinity)

                TOYButton(
                    "Use Video",
                    style: .primary,
                    size: .large,
                    action: onConfirm
                )
                .frame(maxWidth: .infinity)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 32)
        }
        .background(Color.toyBackground)
        .onAppear {
            generateThumbnail()
            setupPlayer()
        }
        .onDisappear {
            playerLooper?.disableLooping()
            playerLooper = nil
            player?.pause()
            player?.replaceCurrentItem(with: nil)
            player = nil
        }
    }

    private func generateThumbnail() {
        let asset = AVURLAsset(url: videoURL)
        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        if let cgImage = try? generator.copyCGImage(at: .zero, actualTime: nil) {
            thumbnail = UIImage(cgImage: cgImage)
        }
    }

    private func setupPlayer() {
        let playerItem = AVPlayerItem(url: videoURL)
        let queuePlayer = AVQueuePlayer()

        // AVPlayerLooper handles seamless looping internally
        let looper = AVPlayerLooper(player: queuePlayer, templateItem: playerItem)

        queuePlayer.play()

        player = queuePlayer
        playerLooper = looper
    }
}

// MARK: - Custom Video Player (no controls)

/// A simple looping video player without playback controls.
private struct LoopingVideoPlayer: UIViewRepresentable {
    let player: AVPlayer
    let onReadyToDisplay: () -> Void

    func makeUIView(context: Context) -> PlayerUIView {
        let view = PlayerUIView()
        view.onReadyToDisplay = onReadyToDisplay
        view.player = player
        return view
    }

    func updateUIView(_ uiView: PlayerUIView, context: Context) {
        uiView.player = player
    }
}

private class PlayerUIView: UIView {
    private var layerObserver: NSKeyValueObservation?
    var onReadyToDisplay: (() -> Void)?

    override class var layerClass: AnyClass {
        AVPlayerLayer.self
    }

    var playerLayer: AVPlayerLayer {
        layer as! AVPlayerLayer
    }

    var player: AVPlayer? {
        get { playerLayer.player }
        set {
            playerLayer.player = newValue
            playerLayer.videoGravity = .resizeAspectFill

            layerObserver?.invalidate()
            layerObserver = playerLayer.observe(\.isReadyForDisplay, options: [.new]) { [weak self] layer, _ in
                if layer.isReadyForDisplay {
                    DispatchQueue.main.async {
                        self?.onReadyToDisplay?()
                    }
                }
            }

            if playerLayer.isReadyForDisplay {
                onReadyToDisplay?()
            }
        }
    }

    deinit {
        layerObserver?.invalidate()
    }
}

#Preview {
    VideoPreviewView(
        videoURL: URL(string: "https://example.com/video.mov")!,
        onRetake: { print("Retake") },
        onConfirm: { print("Confirm") }
    )
}
