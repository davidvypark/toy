import AVFoundation
import SwiftUI
import TOYShared

/// Full-screen montage preview with publish action
struct MontagePreviewView: View {
    let card: Card
    let clips: [Clip]
    let cachedSignedURLs: [UUID: URL]
    let onPublished: () -> Void

    @State private var viewModel = PublishViewModel()
    @State private var queuePlayer: AVQueuePlayer?
    @State private var signedURLs: [URL] = []
    @State private var isLoadingURLs = true
    @State private var isPlayerReady = false
    @State private var showPublishedView = false
    @State private var looper: AVPlayerLooper?

    @Environment(\.dismiss) private var dismiss
    private let storageService = StorageService()

    init(card: Card, clips: [Clip], cachedSignedURLs: [UUID: URL] = [:], onPublished: @escaping () -> Void) {
        self.card = card
        self.clips = clips
        self.cachedSignedURLs = cachedSignedURLs
        self.onPublished = onPublished
    }

    // MARK: - Sorted Clips

    private var sortedClips: [Clip] {
        // Host clip first, then by orderPosition/createdAt
        let hostClip = clips.first { $0.participantId == card.hostId }
        let participantClips = clips
            .filter { $0.participantId != card.hostId }
            .sorted { clip1, clip2 in
                if let pos1 = clip1.orderPosition, let pos2 = clip2.orderPosition {
                    if pos1 != pos2 { return pos1 < pos2 }
                }
                return clip1.createdAt < clip2.createdAt
            }
        return [hostClip].compactMap { $0 } + participantClips
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 0) {
                // Video player area - always reserve space
                ZStack {
                    // Video player
                    if let queuePlayer {
                        QueueVideoPlayer(player: queuePlayer) {
                            isPlayerReady = true
                        }
                        .opacity(isPlayerReady ? 1 : 0)
                    }

                    // Loading overlay - centered in video area
                    if !isPlayerReady && !viewModel.state.isInProgress {
                        VStack(spacing: TOYSpacing.md) {
                            ProgressView()
                                .scaleEffect(1.5)
                                .tint(.warmCream)
                            Text("Loading preview...")
                                .font(.toyBody())
                                .foregroundColor(.warmGrayDark)
                        }
                    }

                    // Progress overlay during publishing
                    if viewModel.state.isInProgress {
                        progressView
                            .background(Color.black.opacity(0.8))
                    }
                }
                .aspectRatio(9/16, contentMode: .fit)
                .background(Color.toyVideoContainer)
                .padding()

                Spacer()

                actionButtons
                    .padding(.horizontal, TOYSpacing.lg)
                    .padding(.bottom, TOYSpacing.xl)
            }
        }
        .navigationTitle("Preview")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.warmCream)
                }
            }
        }
        .task {
            await setupQueuePlayer()
        }
        .onDisappear {
            queuePlayer?.pause()
            queuePlayer = nil
            looper = nil
            signedURLs = []
            isPlayerReady = false
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
        .padding(TOYSpacing.lg)
    }

    @ViewBuilder
    private var actionButtons: some View {
        VStack(spacing: TOYSpacing.md) {
            TOYButton.primary(
                viewModel.state.isInProgress ? "Publishing..." : "Publish Card",
                isLoading: viewModel.state.isInProgress
            ) {
                Task {
                    await viewModel.publishWithStitching(
                        card: card,
                        clips: sortedClips
                    )
                }
            }
            .disabled(isLoadingURLs || viewModel.state.isInProgress)
        }
    }

    // MARK: - Queue Player Setup

    private func setupQueuePlayer() async {
        isLoadingURLs = true
        defer { isLoadingURLs = false }

        // Use cached URLs when available, fetch only missing ones
        let urls = await withTaskGroup(of: (Int, URL?).self) { group in
            for (index, clip) in sortedClips.enumerated() {
                group.addTask {
                    // Use cached URL if available (fast path)
                    if let cachedURL = cachedSignedURLs[clip.id] {
                        return (index, cachedURL)
                    }
                    // Otherwise fetch (slow path)
                    do {
                        let url = try await storageService.createSignedURL(path: clip.videoUrl)
                        return (index, url)
                    } catch {
                        #if DEBUG
                        print("Failed to get signed URL for clip \(clip.id): \(error)")
                        #endif
                        return (index, nil)
                    }
                }
            }

            var results: [(Int, URL?)] = []
            for await result in group {
                results.append(result)
            }
            return results.sorted { $0.0 < $1.0 }.compactMap { $0.1 }
        }

        guard !urls.isEmpty else { return }
        signedURLs = urls

        // Single clip: use AVPlayerLooper for seamless looping
        if urls.count == 1 {
            let item = AVPlayerItem(url: urls[0])
            let player = AVQueuePlayer(playerItem: item)
            looper = AVPlayerLooper(player: player, templateItem: item)
            player.play()
            queuePlayer = player
        } else {
            // Multiple clips: create queue player
            let items = urls.map { AVPlayerItem(url: $0) }
            let player = AVQueuePlayer(items: items)
            player.actionAtItemEnd = .advance
            player.play()
            queuePlayer = player

            // Observe when last item finishes to loop
            setupLooping(player: player)
        }
    }

    private func setupLooping(player: AVQueuePlayer) {
        NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: nil,
            queue: .main
        ) { [self] _ in
            // Check if queue is empty (all items played)
            if player.items().count <= 1 {
                // Re-queue all items from stored URLs
                for url in signedURLs {
                    let newItem = AVPlayerItem(url: url)
                    player.insert(newItem, after: nil)
                }
            }
        }
    }
}

// MARK: - Queue Video Player

private struct QueueVideoPlayer: UIViewRepresentable {
    let player: AVQueuePlayer
    let onReadyToDisplay: () -> Void

    func makeUIView(context: Context) -> QueuePlayerUIView {
        let view = QueuePlayerUIView()
        view.player = player
        view.onReadyToDisplay = onReadyToDisplay
        return view
    }

    func updateUIView(_ uiView: QueuePlayerUIView, context: Context) {
        uiView.player = player
    }
}

private class QueuePlayerUIView: UIView {
    private var layerObserver: NSKeyValueObservation?
    var onReadyToDisplay: (() -> Void)?

    override class var layerClass: AnyClass {
        AVPlayerLayer.self
    }

    var playerLayer: AVPlayerLayer {
        layer as! AVPlayerLayer
    }

    var player: AVQueuePlayer? {
        get { playerLayer.player as? AVQueuePlayer }
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
