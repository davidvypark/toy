import AVFoundation
import SwiftUI
import TOYShared

/// Full-screen montage preview with publish action
struct MontagePreviewView: View {
    let card: Card
    let clips: [Clip]
    let onPublished: () -> Void

    @State private var viewModel = PublishViewModel()
    @State private var player: AVPlayer?
    @State private var isPlayerReady = false
    @State private var showPublishedView = false

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 0) {
                // Video player area
                if let player {
                    MontageVideoPlayer(player: player) {
                        isPlayerReady = true
                    }
                    .aspectRatio(9/16, contentMode: .fit)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .padding()
                    .opacity(isPlayerReady ? 1 : 0)
                }

                if viewModel.state.isInProgress || (player != nil && !isPlayerReady) {
                    // Progress view during generation or loading
                    progressView
                } else if player == nil {
                    // Placeholder before generation
                    VStack(spacing: 16) {
                        Image(systemName: "film.stack")
                            .font(.system(size: 48))
                            .foregroundColor(.white.opacity(0.6))
                        TOYLabel("Generating preview...", style: .body, color: .white.opacity(0.8))
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }

                Spacer()

                // Action buttons
                actionButtons
                    .padding(.horizontal, 24)
                    .padding(.bottom, 32)
            }
        }
        .navigationTitle("Preview Montage")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                if viewModel.montageURL != nil && !viewModel.state.isInProgress {
                    Button("Regenerate") {
                        Task {
                            player = nil
                            isPlayerReady = false
                            await viewModel.generatePreview(card: card, clips: clips)
                            setupPlayer()
                        }
                    }
                    .foregroundColor(.white)
                }
            }
        }
        .task {
            // Auto-generate preview on appear
            await viewModel.generatePreview(card: card, clips: clips)
            setupPlayer()
        }
        .onDisappear {
            player?.pause()
            player = nil
            isPlayerReady = false
            viewModel.cleanup()
        }
        .onChange(of: viewModel.state) { _, newState in
            if case .success = newState {
                showPublishedView = true
            }
        }
        .fullScreenCover(isPresented: $showPublishedView) {
            if case .success(let videoURL) = viewModel.state {
                PublishedCardView(card: card, videoURL: videoURL) {
                    showPublishedView = false
                    onPublished()
                }
            }
        }
        .alert("Error", isPresented: .init(
            get: { viewModel.state.isFailed },
            set: { if !$0 { viewModel.reset() } }
        )) {
            Button("OK") { viewModel.reset() }
        } message: {
            if case .failed(let error) = viewModel.state {
                Text(error)
            }
        }
    }

    // MARK: - Subviews

    @ViewBuilder
    private var progressView: some View {
        VStack(spacing: 24) {
            ProgressView()
                .scaleEffect(1.5)
                .tint(.white)

            switch viewModel.state {
            case .generating(let progress, let phase):
                VStack(spacing: 8) {
                    TOYLabel(phase, style: .body, color: .white)
                    ProgressView(value: progress)
                        .progressViewStyle(.linear)
                        .tint(.toyPrimary)
                        .frame(width: 200)
                }
            case .uploading:
                TOYLabel("Uploading video...", style: .body, color: .white)
            case .publishing:
                TOYLabel("Finalizing...", style: .body, color: .white)
            default:
                EmptyView()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    @ViewBuilder
    private var actionButtons: some View {
        VStack(spacing: 12) {
            // Publish button
            TOYButton(
                "Publish Card",
                style: .primary,
                isLoading: viewModel.state.isInProgress && viewModel.montageURL != nil
            ) {
                Task {
                    await viewModel.publish(
                        card: card,
                        clipCount: clips.count,
                        participantCount: Set(clips.map(\.participantId)).count
                    )
                }
            }
            .disabled(viewModel.montageURL == nil || viewModel.state.isInProgress)

            // Info text
            if viewModel.montageURL == nil && !viewModel.state.isInProgress {
                TOYLabel(
                    "Generate preview first",
                    style: .caption,
                    color: .white.opacity(0.6)
                )
            }
        }
    }

    // MARK: - Helpers

    private func setupPlayer() {
        guard let url = viewModel.montageURL else { return }
        isPlayerReady = false
        let newPlayer = AVPlayer(url: url)
        newPlayer.automaticallyWaitsToMinimizeStalling = false
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

// MARK: - Montage Video Player

/// A simple looping video player without controls (no AirPlay, skip buttons).
/// Reports when the layer is ready to display via onReadyToDisplay callback.
private struct MontageVideoPlayer: UIViewRepresentable {
    let player: AVPlayer
    let onReadyToDisplay: () -> Void

    func makeUIView(context: Context) -> MontagePlayerUIView {
        let view = MontagePlayerUIView()
        view.player = player
        view.onReadyToDisplay = onReadyToDisplay
        return view
    }

    func updateUIView(_ uiView: MontagePlayerUIView, context: Context) {
        uiView.player = player
    }
}

/// UIView subclass using AVPlayerLayer for video rendering.
private class MontagePlayerUIView: UIView {
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

            // Observe when layer actually has frames to display
            layerObserver?.invalidate()
            layerObserver = playerLayer.observe(\.isReadyForDisplay, options: [.new]) { [weak self] layer, _ in
                if layer.isReadyForDisplay {
                    DispatchQueue.main.async {
                        self?.onReadyToDisplay?()
                    }
                }
            }

            // Check if already ready
            if playerLayer.isReadyForDisplay {
                onReadyToDisplay?()
            }
        }
    }

    deinit {
        layerObserver?.invalidate()
    }
}
