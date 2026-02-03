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
                    .padding()
                    .opacity(isPlayerReady ? 1 : 0)
                }

                if viewModel.state.isInProgress || (player != nil && !isPlayerReady) {
                    progressView
                } else if player == nil {
                    VStack(spacing: TOYSpacing.md) {
                        Image(systemName: "film.stack")
                            .font(.system(size: 48, weight: .light))
                            .foregroundColor(.warmGrayDark)
                        Text("Generating preview...")
                            .font(.toyBody())
                            .foregroundColor(.warmGrayDark)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }

                Spacer()

                actionButtons
                    .padding(.horizontal, TOYSpacing.lg)
                    .padding(.bottom, TOYSpacing.xl)
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
                    .font(.toyBody())
                    .foregroundColor(.warmCream)
                }
            }
        }
        .task {
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
        VStack(spacing: TOYSpacing.lg) {
            ProgressView()
                .scaleEffect(1.5)
                .tint(.warmCream)

            switch viewModel.state {
            case .generating(let progress, let phase):
                VStack(spacing: TOYSpacing.sm) {
                    Text(phase)
                        .font(.toyBody())
                        .foregroundColor(.warmCream)
                    ProgressView(value: progress)
                        .progressViewStyle(.linear)
                        .tint(.warmCream)
                        .frame(width: 200)
                }
            case .uploading:
                Text("Uploading video...")
                    .font(.toyBody())
                    .foregroundColor(.warmCream)
            case .publishing:
                Text("Finalizing...")
                    .font(.toyBody())
                    .foregroundColor(.warmCream)
            default:
                EmptyView()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    @ViewBuilder
    private var actionButtons: some View {
        VStack(spacing: TOYSpacing.md) {
            TOYButton.primary(
                viewModel.state.isInProgress && viewModel.montageURL != nil ? "Publishing..." : "Publish Card",
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

            if viewModel.montageURL == nil && !viewModel.state.isInProgress {
                Text("Generate preview first")
                    .font(.toyCaption())
                    .foregroundColor(.warmGrayDark)
            }
        }
    }

    private func setupPlayer() {
        guard let url = viewModel.montageURL else { return }
        isPlayerReady = false
        let newPlayer = AVPlayer(url: url)
        newPlayer.automaticallyWaitsToMinimizeStalling = false
        newPlayer.play()

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
