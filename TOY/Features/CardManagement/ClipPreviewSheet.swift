import AVFoundation
import Kingfisher
import SwiftUI
import TOYShared

/// A sheet view for previewing and managing a clip.
struct ClipPreviewSheet: View {
    let clip: Clip
    let cachedURL: URL?
    let cachedThumbnailURL: URL?
    let localVideoFile: URL?
    let onDelete: () async -> Void

    @State private var signedURL: URL?
    @State private var thumbnailURL: URL?
    @State private var isLoading = true
    @State private var isPlayerReady = false
    @State private var loadError: String?
    @State private var showDeleteConfirmation = false
    @State private var player: AVPlayer?
    @State private var isDeleting = false
    @State private var playerStatusObserver: NSKeyValueObservation?
    @State private var playerLooper: AVPlayerLooper?
    @State private var isPaused = false

    @Environment(\.dismiss) private var dismiss

    private let storageService = StorageService()

    init(clip: Clip, cachedURL: URL? = nil, cachedThumbnailURL: URL? = nil, localVideoFile: URL? = nil, onDelete: @escaping () async -> Void) {
        self.clip = clip
        self.cachedURL = cachedURL
        self.cachedThumbnailURL = cachedThumbnailURL
        self.localVideoFile = localVideoFile
        self.onDelete = onDelete
    }

    var body: some View {
        NavigationStack {
            ZStack {
                TOYBackground()

                VStack(spacing: 0) {
                    // Video player area - takes up most of the screen
                    ZStack {
                        // Stable base — never swapped, light grey before thumbnail loads
                        Color.gray.opacity(0.2)
                            .overlay {
                                if let url = cachedThumbnailURL ?? thumbnailURL {
                                    KFImage(url)
                                        .resizable()
                                        .aspectRatio(contentMode: .fill)
                                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                                        .clipped()
                                }
                            }

                        // Video player — fades in on top of thumbnail
                        if let player {
                            ClipVideoPlayer(player: player) {
                                isPlayerReady = true
                            }
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

                        // Pause overlay
                        if isPaused && isPlayerReady {
                            Color.black.opacity(0.3)
                            Image(systemName: "play.fill")
                                .font(.system(size: 44))
                                .foregroundColor(.white)
                        }

                        if let error = loadError {
                            errorView(error)
                        }
                    }
                    .aspectRatio(9/16, contentMode: .fit)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .padding(.horizontal, 24)
                    .onTapGesture {
                        guard isPlayerReady else { return }
                        isPaused.toggle()
                        if isPaused {
                            player?.pause()
                        } else {
                            player?.play()
                        }
                    }

                    Spacer()

                    // Delete button - subtle, secondary action
                    Button {
                        showDeleteConfirmation = true
                    } label: {
                        HStack(spacing: TOYSpacing.sm) {
                            if isDeleting {
                                ProgressView()
                                    .tint(.toyTextSecondary)
                                    .scaleEffect(0.8)
                            } else {
                                Image(systemName: "trash")
                                    .font(.system(size: 14))
                            }
                            Text("Delete Clip")
                                .font(.toyCaption())
                        }
                        .foregroundColor(.toyTextSecondary)
                    }
                    .disabled(isDeleting)
                    .padding(.bottom, TOYSpacing.xl)
                }
            }
            .navigationTitle("Preview Clip")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .font(.toyBodyMedium())
                    .foregroundColor(.toyText)
                }
            }
            .task {
                await loadAndPlay()
            }
            .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
                if !isPaused { player?.play() }
            }
            .onDisappear {
                cleanupPlayer()
            }
            .confirmationDialog(
                "Delete this clip?",
                isPresented: $showDeleteConfirmation,
                titleVisibility: .visible
            ) {
                Button("Delete", role: .destructive) {
                    Task { await handleDelete() }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This action cannot be undone.")
            }
        }
    }

    // MARK: - Subviews

    private var loadingView: some View {
        VStack(spacing: TOYSpacing.md) {
            ProgressView()
                .tint(.warmCream)
                .scaleEffect(1.2)
            Text("Loading...")
                .font(.toyCaption())
                .foregroundColor(.warmGrayDark)
        }
    }

    private func errorView(_ error: String) -> some View {
        VStack(spacing: TOYSpacing.md) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 40, weight: .light))
                .foregroundColor(.warmGrayDark)

            Text("Failed to load video")
                .font(.toyBody())
                .foregroundColor(.warmCream)

            Text(error)
                .font(.toyCaption())
                .foregroundColor(.warmGrayDark)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
    }

    // MARK: - Actions

    private func loadAndPlay() async {
        isLoading = true
        loadError = nil

        // Load thumbnail
        if let cachedThumbnailURL {
            thumbnailURL = cachedThumbnailURL
        } else if let thumbnailPath = clip.thumbnailUrl {
            thumbnailURL = try? await storageService.createSignedURL(path: thumbnailPath)
        }

        // Resolve video URL: local file (instant) → cached signed URL → fresh fetch
        do {
            let videoURL: URL
            if let localVideoFile {
                videoURL = localVideoFile
            } else if let cachedURL {
                videoURL = cachedURL
            } else {
                videoURL = try await storageService.createSignedURL(path: clip.videoUrl)
            }

            signedURL = videoURL
            setupPlayer(with: videoURL)
        } catch {
            loadError = error.localizedDescription
        }

        isLoading = false
    }

    private func setupPlayer(with url: URL) {
        let playerItem = AVPlayerItem(url: url)
        let queuePlayer = AVQueuePlayer()
        queuePlayer.automaticallyWaitsToMinimizeStalling = false

        let looper = AVPlayerLooper(player: queuePlayer, templateItem: playerItem)

        playerStatusObserver = playerItem.observe(\.status, options: [.new]) { item, _ in
            DispatchQueue.main.async {
                if case .failed = item.status {
                    loadError = item.error?.localizedDescription ?? "Failed to load video"
                }
            }
        }

        queuePlayer.play()

        player = queuePlayer
        playerLooper = looper
    }

    private func cleanupPlayer() {
        playerStatusObserver?.invalidate()
        playerStatusObserver = nil
        playerLooper?.disableLooping()
        playerLooper = nil
        player?.pause()
        player?.replaceCurrentItem(with: nil)
        player = nil
        isPlayerReady = false
    }

    private func handleDelete() async {
        isDeleting = true
        await onDelete()
        isDeleting = false
        dismiss()
    }
}

// MARK: - Clip Video Player

private struct ClipVideoPlayer: UIViewRepresentable {
    let player: AVPlayer
    let onReadyToDisplay: () -> Void

    func makeUIView(context: Context) -> ClipPlayerUIView {
        let view = ClipPlayerUIView()
        view.onReadyToDisplay = onReadyToDisplay
        view.player = player
        return view
    }

    func updateUIView(_ uiView: ClipPlayerUIView, context: Context) {
        guard uiView.playerLayer.player !== player else { return }
        uiView.player = player
    }
}

private class ClipPlayerUIView: UIView {
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

// MARK: - Preview

#Preview {
    ClipPreviewSheet(
        clip: Clip(
            id: UUID(),
            cardId: UUID(),
            participantId: UUID(),
            videoUrl: "test-clip.mov",
            status: "uploaded"
        ),
        onDelete: {}
    )
}
