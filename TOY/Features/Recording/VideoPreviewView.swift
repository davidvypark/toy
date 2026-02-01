import AVKit
import SwiftUI
import TOYShared

/// View for previewing a recorded video before submission.
public struct VideoPreviewView: View {
    let videoURL: URL
    let onRetake: () -> Void
    let onConfirm: () -> Void

    @State private var player: AVPlayer?

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
            // Video player
            ZStack {
                if let player {
                    VideoPlayer(player: player)
                        .aspectRatio(9/16, contentMode: .fit)
                } else {
                    Rectangle()
                        .fill(Color.black)
                        .aspectRatio(9/16, contentMode: .fit)
                        .overlay {
                            ProgressView()
                                .tint(.white)
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
            setupPlayer()
        }
        .onDisappear {
            player?.pause()
            player = nil
        }
    }

    private func setupPlayer() {
        let newPlayer = AVPlayer(url: videoURL)
        newPlayer.play()

        // Loop playback
        NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: newPlayer.currentItem,
            queue: .main
        ) { _ in
            newPlayer.seek(to: .zero)
            newPlayer.play()
        }

        player = newPlayer
    }
}

#Preview {
    VideoPreviewView(
        videoURL: URL(string: "https://example.com/video.mov")!,
        onRetake: { print("Retake") },
        onConfirm: { print("Confirm") }
    )
}
