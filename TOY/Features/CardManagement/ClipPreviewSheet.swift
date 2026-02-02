import AVFoundation
import SwiftUI
import TOYShared

/// A sheet view for previewing and managing a clip.
/// Displays looping video playback with delete confirmation.
struct ClipPreviewSheet: View {
    let clip: Clip
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

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                // Video player area
                ZStack {
                    // Show skeleton until player is ready to play
                    if isLoading || !isPlayerReady {
                        loadingView
                    }

                    if let error = loadError {
                        errorView(error)
                    } else if let player, isPlayerReady {
                        ClipVideoPlayer(player: player)
                            .aspectRatio(9/16, contentMode: .fit)
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 24)

                Spacer()

                // Delete button
                TOYButton(
                    "Delete Clip",
                    style: .destructive,
                    size: .large,
                    isLoading: isDeleting
                ) {
                    showDeleteConfirmation = true
                }
                .disabled(isDeleting)
                .padding(.horizontal, 24)
                .padding(.bottom, 32)
            }
            .background(Color.toyBackground)
            .navigationTitle("Preview Clip")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
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
                    Task {
                        await handleDelete()
                    }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This action cannot be undone. The clip will be permanently removed from the card.")
            }
        }
    }

    // MARK: - Subviews

    private var loadingView: some View {
        RoundedRectangle(cornerRadius: 16)
            .fill(Color.toySurface)
            .aspectRatio(9/16, contentMode: .fit)
            .overlay {
                SkeletonLoadingView()
            }
    }

    private func errorView(_ error: String) -> some View {
        RoundedRectangle(cornerRadius: 16)
            .fill(Color.toySurface)
            .aspectRatio(9/16, contentMode: .fit)
            .overlay {
                VStack(spacing: 12) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.system(size: 40))
                        .foregroundColor(.toyTextSecondary)

                    TOYLabel("Failed to load video", style: .body)

                    TOYLabel(error, style: .caption, color: .toyTextSecondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
            }
    }

    // MARK: - Actions

    private func loadSignedURL() async {
        isLoading = true
        loadError = nil

        do {
            #if DEBUG
            print("Loading signed URL for clip: \(clip.id)")
            #endif

            let url = try await storageService.createSignedURL(path: clip.videoUrl)
            signedURL = url
            setupPlayer(with: url)

            #if DEBUG
            print("Signed URL loaded successfully")
            #endif
        } catch {
            #if DEBUG
            print("Failed to load signed URL: \(error)")
            #endif
            loadError = error.localizedDescription
        }

        isLoading = false
    }

    private func setupPlayer(with url: URL) {
        let newPlayer = AVPlayer(url: url)

        // Observe player item status to know when video is ready
        playerStatusObserver = newPlayer.currentItem?.observe(\.status, options: [.new]) { [weak newPlayer] item, _ in
            DispatchQueue.main.async {
                switch item.status {
                case .readyToPlay:
                    #if DEBUG
                    print("Player ready to play")
                    #endif
                    isPlayerReady = true
                    newPlayer?.play()
                case .failed:
                    #if DEBUG
                    print("Player failed: \(item.error?.localizedDescription ?? "unknown")")
                    #endif
                    loadError = item.error?.localizedDescription ?? "Failed to load video"
                case .unknown:
                    break
                @unknown default:
                    break
                }
            }
        }

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

// MARK: - Skeleton Loading View

/// A skeleton loading view with animated shimmer effect
private struct SkeletonLoadingView: View {
    @State private var shimmerOffset: CGFloat = -1.0

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Base background - dark gray to be visible
                Color(uiColor: UIColor.systemGray5)

                // Base skeleton content
                VStack(spacing: 16) {
                    Spacer()

                    // Play button skeleton
                    Circle()
                        .fill(Color(uiColor: UIColor.systemGray4))
                        .frame(width: 70, height: 70)
                        .overlay {
                            Image(systemName: "play.fill")
                                .font(.system(size: 28))
                                .foregroundColor(Color(uiColor: UIColor.systemGray3))
                        }

                    // Loading text
                    Text("Loading video...")
                        .font(.subheadline)
                        .foregroundColor(Color(uiColor: UIColor.systemGray2))

                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)

                // Shimmer overlay
                LinearGradient(
                    gradient: Gradient(colors: [
                        .clear,
                        .white.opacity(0.4),
                        .clear
                    ]),
                    startPoint: .leading,
                    endPoint: .trailing
                )
                .frame(width: geometry.size.width * 0.6)
                .offset(x: shimmerOffset * geometry.size.width)
            }
            .clipShape(RoundedRectangle(cornerRadius: 16))
        }
        .onAppear {
            // Start with shimmer off-screen to the left
            shimmerOffset = -1.0
            // Animate to the right, repeating forever
            withAnimation(.linear(duration: 1.2).repeatForever(autoreverses: false)) {
                shimmerOffset = 1.5
            }
        }
    }
}

// MARK: - Clip Video Player

/// A simple looping video player for clip preview.
private struct ClipVideoPlayer: UIViewRepresentable {
    let player: AVPlayer

    func makeUIView(context: Context) -> ClipPlayerUIView {
        let view = ClipPlayerUIView()
        view.player = player
        return view
    }

    func updateUIView(_ uiView: ClipPlayerUIView, context: Context) {
        uiView.player = player
    }
}

/// UIView subclass using AVPlayerLayer for video rendering.
private class ClipPlayerUIView: UIView {
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
        }
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
        onDelete: {
            print("Delete tapped")
        }
    )
}
