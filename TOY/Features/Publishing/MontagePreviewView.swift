import AVFoundation
import Kingfisher
import SwiftUI
import TOYShared

/// Full-screen montage preview with publish action
struct MontagePreviewView: View {
    let card: Card
    let clips: [Clip]
    let cachedSignedURLs: [UUID: URL]
    let firstClipThumbnailURL: URL?
    var cardViewModel: CardDetailViewModel?
    let onPublished: () -> Void

    @State private var publishViewModel = PublishViewModel()
    @State private var queuePlayer: AVQueuePlayer?
    @State private var signedURLs: [URL] = []
    @State private var isLoadingURLs = true
    @State private var isPlayerReady = false
    @State private var showPublishedView = false
    @State private var isPlaybackFinished = false
    @State private var isPaused = false
    @State private var showCheckout = false
    @State private var hasPurchased = false

    @Environment(\.dismiss) private var dismiss
    private let storageService = StorageService()

    init(card: Card, clips: [Clip], cachedSignedURLs: [UUID: URL] = [:], firstClipThumbnailURL: URL? = nil, cardViewModel: CardDetailViewModel? = nil, onPublished: @escaping () -> Void) {
        self.card = card
        self.clips = clips
        self.cachedSignedURLs = cachedSignedURLs
        self.firstClipThumbnailURL = firstClipThumbnailURL
        self.cardViewModel = cardViewModel
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

    /// The clip count used for tier logic — respects debug override.
    private var effectiveClipCount: Int {
        #if DEBUG
        if let override = CardDetailViewModel.debugClipCount { return override }
        #endif
        return sortedClips.count
    }

    /// Whether this publish attempt needs a tier upgrade.
    /// Uses card.maxParticipants directly (not CardTier comparison) to respect grandfathered cards.
    private var needsUpgrade: Bool {
        effectiveClipCount > card.maxParticipants
    }

    var body: some View {
        ZStack {
            TOYBackground()

            VStack(spacing: 0) {
                // Video player area - always reserve space
                ZStack {
                    // 1. Thumbnail — always underneath as safety net against white flash
                    thumbnailOrBlack

                    // 2. Loading bar (before player ready)
                    if !isPlayerReady && !publishViewModel.state.isInProgress {
                        VStack {
                            Spacer()
                            TOYLoadingBar()
                        }
                    }

                    // 3. Video player with brand overlay — fades in on top of thumbnail
                    if let queuePlayer {
                        QueueVideoPlayer(player: queuePlayer) {
                            isPlayerReady = true
                        }
                        .opacity(isPlayerReady ? 1 : 0)
                        .overlay(alignment: .bottom) {
                            if isPlayerReady && !isPlaybackFinished {
                                Text("Thinking Of You")
                                    .font(.custom("DMSerifDisplay-Regular", size: 24))
                                    .foregroundColor(.white)
                                    .shadow(color: .black.opacity(0.3), radius: 4, x: 0, y: 2)
                                    .padding(.bottom, 16)
                            }
                        }
                    }

                    // 4. Playback finished overlay — replay button
                    if isPlaybackFinished {
                        Color.black.opacity(0.3)

                        Button {
                            replayVideo()
                        } label: {
                            Circle()
                                .fill(Color.black.opacity(0.5))
                                .frame(width: 72, height: 72)
                                .overlay {
                                    Image(systemName: "play.fill")
                                        .font(.system(size: 28))
                                        .foregroundColor(.white)
                                        .offset(x: 2)
                                }
                        }
                    }

                    // 5. Pause overlay
                    if isPaused && isPlayerReady && !isPlaybackFinished {
                        Color.black.opacity(0.3)
                        Image(systemName: "play.fill")
                            .font(.system(size: 44))
                            .foregroundColor(.white)
                    }

                    // 6. Progress overlay during publishing
                    if publishViewModel.state.isInProgress {
                        progressView
                            .background(Color.black.opacity(0.8))
                    }
                }
                .aspectRatio(9/16, contentMode: .fit)
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .padding(.horizontal, 24)
                .onTapGesture {
                    guard isPlayerReady, !isPlaybackFinished, !publishViewModel.state.isInProgress else { return }
                    isPaused.toggle()
                    if isPaused {
                        queuePlayer?.pause()
                    } else {
                        queuePlayer?.play()
                    }
                }

                Spacer()

                actionButtons
                    .padding(.horizontal, TOYSpacing.lg)
                    .padding(.bottom, TOYSpacing.xl)
            }
        }
        .navigationTitle("Preview")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.toyText)
                }
            }
        }
        .task {
            // Check for cached player first (instant playback on re-open)
            if let cachedPlayer = cardViewModel?.montagePlayer, cardViewModel?.isMontageReady == true {
                queuePlayer = cachedPlayer
                signedURLs = cardViewModel?.montageSignedURLs ?? []
                isPlayerReady = true
                isLoadingURLs = false
                isPlaybackFinished = false

                // Re-queue items for multiple clips (items are consumed after playback)
                if signedURLs.count > 1 {
                    cachedPlayer.removeAllItems()
                    for url in signedURLs {
                        let newItem = AVPlayerItem(url: url)
                        newItem.preferredForwardBufferDuration = 5
                        cachedPlayer.insert(newItem, after: nil)
                    }
                    if let lastItem = cachedPlayer.items().last {
                        setupPlaybackEndObserver(for: lastItem)
                    }
                } else if signedURLs.count == 1 {
                    // Single clip - seek to start and set up observer
                    await cachedPlayer.seek(to: .zero)
                    if let currentItem = cachedPlayer.currentItem {
                        setupPlaybackEndObserver(for: currentItem)
                    }
                }

                cachedPlayer.play()
            } else {
                await setupQueuePlayer()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
            if !isPlaybackFinished && !isPaused {
                queuePlayer?.play()
            }
        }
        .onDisappear {
            // Pause but don't destroy - cache for re-opening
            queuePlayer?.pause()

            // Cache player state in cardViewModel for re-use
            if let cardViewModel {
                cardViewModel.montagePlayer = queuePlayer
                cardViewModel.montageSignedURLs = signedURLs
                cardViewModel.isMontageReady = isPlayerReady
            }
        }
        .onChange(of: publishViewModel.state) { _, newState in
            if case .success = newState {
                showPublishedView = true
            }
        }
        .fullScreenCover(isPresented: $showPublishedView) {
            if case .success(let videoURL) = publishViewModel.state {
                PublishedCardView(card: card, videoURL: videoURL) {
                    showPublishedView = false
                    onPublished()
                }
            }
        }
        .onChange(of: showCheckout) { _, isShowing in
            if isShowing {
                queuePlayer?.pause()
            } else if !isPlaybackFinished {
                // Force player layer to re-render after sheet dismiss
                Task {
                    if let player = queuePlayer {
                        await player.seek(to: player.currentTime())
                        if !isPaused {
                            player.play()
                        }
                    }
                }
            }
        }
        .sheet(isPresented: $showCheckout) {
            CheckoutSheet(
                card: card,
                clipCount: effectiveClipCount,
                onPurchaseComplete: {
                    hasPurchased = true
                    Task {
                        await publishViewModel.publishWithStitching(
                            card: card,
                            clips: sortedClips
                        )
                    }
                },
                onCancel: {
                    // Do nothing -- host stays on montage preview
                }
            )
        }
        .alert("Error", isPresented: .init(
            get: { publishViewModel.state.isFailed },
            set: { if !$0 { publishViewModel.reset() } }
        )) {
            Button("OK") { publishViewModel.reset() }
        } message: {
            if case .failed(let error) = publishViewModel.state {
                Text(error)
            }
        }
    }

    // MARK: - Subviews

    @ViewBuilder
    private var thumbnailOrBlack: some View {
        Color.gray.opacity(0.2)
            .overlay {
                if let thumbnailURL = firstClipThumbnailURL {
                    KFImage(thumbnailURL)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .clipped()
                }
            }
    }

    @ViewBuilder
    private var progressView: some View {
        VStack(spacing: TOYSpacing.lg) {
            ProgressView()
                .scaleEffect(1.5)
                .tint(.warmCream)

            switch publishViewModel.state {
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
                publishViewModel.state.isInProgress ? "Publishing..." : "Publish Card",
                isLoading: publishViewModel.state.isInProgress
            ) {
                if !hasPurchased && needsUpgrade {
                    showCheckout = true
                } else {
                    Task {
                        await publishViewModel.publishWithStitching(
                            card: card,
                            clips: sortedClips
                        )
                    }
                }
            }
            .disabled(isLoadingURLs || publishViewModel.state.isInProgress)
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

        // Single clip: play once
        if urls.count == 1 {
            let item = AVPlayerItem(url: urls[0])
            let player = AVQueuePlayer(playerItem: item)
            player.play()
            queuePlayer = player
            setupPlaybackEndObserver(for: item)
        } else {
            // Multiple clips: create queue player with pre-buffered items
            let items = urls.map { url -> AVPlayerItem in
                let item = AVPlayerItem(url: url)
                // Pre-buffer more aggressively to prevent black flash
                item.preferredForwardBufferDuration = 5
                return item
            }

            let player = AVQueuePlayer(items: items)
            player.actionAtItemEnd = .advance
            // Wait for buffering to prevent black flash between clips
            player.automaticallyWaitsToMinimizeStalling = true
            player.play()
            queuePlayer = player

            // Observe when last item finishes to show play button
            if let lastItem = items.last {
                setupPlaybackEndObserver(for: lastItem)
            }
        }
    }

    /// Observes when playback ends to show the replay button
    private func setupPlaybackEndObserver(for item: AVPlayerItem) {
        NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: item,
            queue: .main
        ) { [self] _ in
            Task { @MainActor in
                // Seek back to start and pause
                await queuePlayer?.seek(to: .zero)
                queuePlayer?.pause()
                isPlaybackFinished = true
            }
        }
    }

    /// Replays the video from the beginning
    private func replayVideo() {
        isPlaybackFinished = false
        isPaused = false

        // Re-queue all items for multiple clips
        if signedURLs.count > 1, let player = queuePlayer {
            // Remove remaining items and re-add all
            player.removeAllItems()
            for url in signedURLs {
                let newItem = AVPlayerItem(url: url)
                newItem.preferredForwardBufferDuration = 5
                player.insert(newItem, after: nil)
            }
            // Observe last item for playback end
            if let lastItem = player.items().last {
                setupPlaybackEndObserver(for: lastItem)
            }
        }

        queuePlayer?.play()
    }

}

// MARK: - Queue Video Player

private struct QueueVideoPlayer: UIViewRepresentable {
    let player: AVQueuePlayer
    let onReadyToDisplay: () -> Void

    func makeUIView(context: Context) -> QueuePlayerUIView {
        let view = QueuePlayerUIView()
        view.onReadyToDisplay = onReadyToDisplay
        view.player = player
        return view
    }

    func updateUIView(_ uiView: QueuePlayerUIView, context: Context) {
        guard uiView.playerLayer.player !== player else { return }
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
            playerLayer.backgroundColor = UIColor.clear.cgColor

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
