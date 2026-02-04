import AVFoundation
import SwiftUI
import TOYShared

/// A sheet view for previewing and managing a clip.
struct ClipPreviewSheet: View {
    let clip: Clip
    let cachedURL: URL?
    let onDelete: () async -> Void

    @State private var signedURL: URL?
    @State private var isLoading = true
    @State private var isPlayerReady = false
    @State private var loadError: String?
    @State private var showDeleteConfirmation = false
    @State private var player: AVPlayer?
    @State private var isDeleting = false
    @State private var playerStatusObserver: NSKeyValueObservation?

    @Environment(\.dismiss) private var dismiss

    private let storageService = StorageService()

    init(clip: Clip, cachedURL: URL? = nil, onDelete: @escaping () async -> Void) {
        self.clip = clip
        self.cachedURL = cachedURL
        self.onDelete = onDelete
    }

    var body: some View {
        NavigationStack {
            ZStack {
                TOYBackground()

                VStack(spacing: 0) {
                    // Video player area - takes up most of the screen
                    ZStack {
                        if let player {
                            ClipVideoPlayer(player: player) {
                                isPlayerReady = true
                            }
                            .opacity(isPlayerReady ? 1 : 0)
                        }

                        if isLoading || !isPlayerReady {
                            loadingView
                        }

                        if let error = loadError {
                            errorView(error)
                        }
                    }
                    .aspectRatio(9/16, contentMode: .fit)
                    .frame(maxWidth: .infinity)
                    .background(Color.toyVideoContainer)
                    .clipped()
                    .padding(.horizontal, TOYSpacing.lg)
                    .padding(.top, TOYSpacing.md)

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
                await loadSignedURL()
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

    private func loadSignedURL() async {
        isLoading = true
        loadError = nil

        do {
            let url: URL
            if let cachedURL {
                url = cachedURL
            } else {
                url = try await storageService.createSignedURL(path: clip.videoUrl)
            }

            signedURL = url
            setupPlayer(with: url)
        } catch {
            loadError = error.localizedDescription
        }

        isLoading = false
    }

    private func setupPlayer(with url: URL) {
        let newPlayer = AVPlayer(url: url)
        newPlayer.automaticallyWaitsToMinimizeStalling = false
        newPlayer.play()

        playerStatusObserver = newPlayer.currentItem?.observe(\.status, options: [.new]) { item, _ in
            DispatchQueue.main.async {
                if case .failed = item.status {
                    loadError = item.error?.localizedDescription ?? "Failed to load video"
                }
            }
        }

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

    private func cleanupPlayer() {
        playerStatusObserver?.invalidate()
        playerStatusObserver = nil
        player?.pause()
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
        view.player = player
        view.onReadyToDisplay = onReadyToDisplay
        return view
    }

    func updateUIView(_ uiView: ClipPlayerUIView, context: Context) {
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
