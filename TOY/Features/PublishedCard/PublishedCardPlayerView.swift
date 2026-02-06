//
//  PublishedCardPlayerView.swift
//  TOY
//
//  Full screen video player for published cards.
//  "Intimate Raw" design: minimal chrome, type-forward details panel.
//

import AVKit
import Kingfisher
import SwiftUI
import TOYShared

struct PublishedCardPlayerView: View {
    let card: Card
    var currentUserId: UUID? = nil
    var cachedVideoURL: URL? = nil
    var cachedVideoAsset: AVURLAsset? = nil
    var onVideoURLLoaded: ((URL) -> Void)? = nil
    @Environment(\.dismiss) private var dismiss

    @State private var player: AVPlayer?
    @State private var isLoading = true
    @State private var isPlayerReady = false
    @State private var loadingProgress: Double = 0
    @State private var error: String?
    @State private var showDetails = false
    @State private var clips: [Clip] = []
    @State private var profiles: [UUID: (displayName: String?, avatarURL: URL?)] = [:]
    @State private var showCopiedToast = false
    @State private var bufferObserver: NSKeyValueObservation?
    @State private var playerLooper: AVPlayerLooper?
    @State private var firstClipThumbnailURL: URL?

    private let storageService = StorageService()
    private let cardService = CardService()

    private let detailsPanelHeight: CGFloat = UIScreen.main.bounds.height * 0.55

    var body: some View {
        ZStack {
            TOYBackground()

            VStack(spacing: 0) {
                // Top bar - back button
                HStack {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 20, weight: .medium))
                            .foregroundColor(.toyText)
                            .frame(width: 44, height: 44)
                            .contentShape(Rectangle())
                    }
                    Spacer()
                }
                .padding(.horizontal, TOYSpacing.sm)
                .padding(.top, TOYSpacing.sm)

                // Video card
                ZStack {
                    if let player = player {
                        PlayerLayerView(player: player, onReadyToDisplay: {
                            isPlayerReady = true
                            loadingProgress = 1.0
                        })
                        .opacity(isPlayerReady ? 1 : 0)
                    }

                    // Thumbnail placeholder
                    if !isPlayerReady && error == nil {
                        ZStack(alignment: .bottom) {
                            if let thumbnailURL = firstClipThumbnailURL {
                                KFImage(thumbnailURL)
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                                    .frame(maxWidth: .infinity)
                                    .clipped()
                            } else {
                                Rectangle().fill(Color.black)
                            }

                            TOYLoadingBar()
                        }
                    }

                    if let error = error {
                        VStack(spacing: TOYSpacing.md) {
                            Image(systemName: "exclamationmark.triangle")
                                .font(.system(size: 40, weight: .light))
                                .foregroundColor(.warmGrayDark)
                            Text(error)
                                .font(.toyBody())
                                .foregroundColor(.toyText)
                                .multilineTextAlignment(.center)
                        }
                        .padding()
                    }
                }
                .aspectRatio(9/16, contentMode: .fit)
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .padding(.horizontal, 24)
                .onTapGesture {
                    if showDetails {
                        withAnimation(.easeOut(duration: 0.2)) {
                            showDetails = false
                        }
                    }
                }

                Spacer()

                // Bottom hint - tappable with up arrow
                if !showDetails {
                    Button {
                        withAnimation(.easeOut(duration: 0.2)) {
                            showDetails = true
                        }
                    } label: {
                        VStack(spacing: TOYSpacing.xs) {
                            Image(systemName: "chevron.up")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(.warmGrayDark)
                            Text("DETAILS")
                                .font(.toyCaption2())
                                .foregroundColor(.warmGrayDark)
                                .toyLetterSpacing(2)
                        }
                    }
                    .padding(.bottom, TOYSpacing.xxl)
                }
            }
            .opacity(showDetails ? 0.3 : 1)

            // Details panel (slides up)
            VStack(spacing: 0) {
                Spacer()

                DetailsPanel(
                    card: card,
                    clips: clips,
                    profiles: profiles,
                    currentUserId: currentUserId,
                    onDismiss: {
                        withAnimation(.easeOut(duration: 0.2)) {
                            showDetails = false
                        }
                    },
                    showCopiedToast: $showCopiedToast
                )
                .frame(height: detailsPanelHeight)
                .offset(y: showDetails ? 0 : detailsPanelHeight + 50)
            }
        }
        .gesture(
            DragGesture()
                .onChanged { value in
                    // Swipe up to show details
                    if !showDetails && value.translation.height < -20 {
                        withAnimation(.easeOut(duration: 0.2)) {
                            showDetails = true
                        }
                    }
                    // Swipe down to hide details
                    else if showDetails && value.translation.height > 20 {
                        withAnimation(.easeOut(duration: 0.2)) {
                            showDetails = false
                        }
                    }
                }
        )
        .overlay {
            // Copied toast - minimal
            if showCopiedToast {
                VStack {
                    Spacer()
                    Text("Copied")
                        .font(.toyCaption())
                        .foregroundColor(.black)
                        .toyLetterSpacing(1)
                        .padding(.horizontal, TOYSpacing.lg)
                        .padding(.vertical, TOYSpacing.sm)
                        .background(Color.white)
                        .padding(.bottom, 100)
                }
                .transition(.opacity)
                .onAppear {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                        withAnimation {
                            showCopiedToast = false
                        }
                    }
                }
            }
        }
        .animation(.easeInOut(duration: 0.2), value: showCopiedToast)
        .task {
            // Load clips and video in parallel — they're independent
            async let clipsTask: () = loadClips()
            async let videoTask: () = loadVideo()
            _ = await (clipsTask, videoTask)
        }
        .onDisappear {
            playerLooper?.disableLooping()
            playerLooper = nil
            player?.pause()
            player?.replaceCurrentItem(with: nil)
            player = nil
            bufferObserver?.invalidate()
            bufferObserver = nil
        }
    }

    private func loadVideo() async {
        guard let videoPath = card.videoUrl else {
            error = "Video not available"
            return
        }

        loadingProgress = 0.1

        do {
            // Build playerItem from best available source:
            // 1. Pre-fetched AVURLAsset (connection already warm, data partially downloaded)
            // 2. Cached signed URL (skip API call)
            // 3. Fresh signed URL fetch (slowest path)
            let playerItem: AVPlayerItem
            if let cachedVideoAsset {
                playerItem = AVPlayerItem(asset: cachedVideoAsset)
                loadingProgress = 0.5
            } else if let cachedVideoURL {
                playerItem = AVPlayerItem(url: cachedVideoURL)
                loadingProgress = 0.3
            } else {
                let signedURL = try await storageService.createSignedVideoURL(path: videoPath)
                loadingProgress = 0.3
                onVideoURLLoaded?(signedURL)
                playerItem = AVPlayerItem(url: signedURL)
            }

            await MainActor.run {
                let queuePlayer = AVQueuePlayer()
                queuePlayer.automaticallyWaitsToMinimizeStalling = false

                observeBuffering(item: playerItem)

                let looper = AVPlayerLooper(player: queuePlayer, templateItem: playerItem)

                queuePlayer.play()

                self.player = queuePlayer
                self.playerLooper = looper
            }
        } catch {
            await MainActor.run {
                self.error = "Unable to load video. Please try again."
            }
        }
    }

    private func observeBuffering(item: AVPlayerItem) {
        bufferObserver = item.observe(\.loadedTimeRanges, options: [.new]) { [self] observedItem, _ in
            let duration = observedItem.duration.seconds
            guard duration.isFinite && duration > 0 else {
                // Duration not yet known - animate progress slowly
                DispatchQueue.main.async {
                    if loadingProgress < 0.8 {
                        loadingProgress = min(loadingProgress + 0.05, 0.8)
                    }
                }
                return
            }

            let bufferedTime = observedItem.loadedTimeRanges
                .compactMap { $0.timeRangeValue }
                .reduce(0) { $0 + $1.duration.seconds }

            let bufferProgress = min(bufferedTime / duration, 1.0)
            // Map to 30% → 100% range (30% was URL fetch)
            let progress = 0.3 + (bufferProgress * 0.7)

            DispatchQueue.main.async {
                if progress > loadingProgress {
                    loadingProgress = progress
                }
            }
        }
    }

    private func loadClips() async {
        do {
            clips = try await cardService.fetchClipsForCard(cardId: card.id)
            #if DEBUG
            print("[PUBLISHED] Loaded \(clips.count) clips for card \(card.id)")
            #endif

            // Fetch thumbnail URL for first clip (host clip first, or first clip)
            let firstClip = clips.first { $0.participantId == card.hostId } ?? clips.first
            #if DEBUG
            print("[PUBLISHED] First clip thumbnail path: \(firstClip?.thumbnailUrl ?? "nil")")
            #endif
            if let thumbnailPath = firstClip?.thumbnailUrl {
                firstClipThumbnailURL = try? await storageService.createSignedURL(path: thumbnailPath)
                #if DEBUG
                print("[PUBLISHED] Thumbnail URL: \(firstClipThumbnailURL?.absoluteString ?? "nil")")
                #endif
            }

            // Fetch profiles for all participants
            let participantIds = clips.map(\.participantId)
            if !participantIds.isEmpty {
                profiles = try await cardService.fetchProfiles(userIds: participantIds)
            }
        } catch {
            #if DEBUG
            print("[PUBLISHED] Failed to load clips: \(error)")
            #endif
        }
    }
}

// MARK: - Player Layer View (UIViewRepresentable for isReadyForDisplay)

private struct PlayerLayerView: UIViewRepresentable {
    let player: AVPlayer
    let onReadyToDisplay: () -> Void

    func makeUIView(context: Context) -> PlayerUIView {
        let view = PlayerUIView()
        view.player = player
        view.onReadyToDisplay = onReadyToDisplay
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

// MARK: - Details Panel

private struct DetailsPanel: View {
    let card: Card
    let clips: [Clip]
    let profiles: [UUID: (displayName: String?, avatarURL: URL?)]
    let currentUserId: UUID?
    let onDismiss: () -> Void
    @Binding var showCopiedToast: Bool

    @State private var scrollOffset: CGFloat = 0
    @State private var isDragging = false

    var body: some View {
        ZStack {
            // Film grain texture on black
            Color.black
            TOYTextureOverlay(opacity: 0.04)

            VStack(spacing: 0) {
                // Drag indicator - minimal line
                Rectangle()
                    .fill(Color.warmGrayDark)
                    .frame(width: 32, height: 2)
                    .padding(.top, TOYSpacing.lg)
                    .padding(.bottom, TOYSpacing.xl)
                    .frame(maxWidth: .infinity)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        onDismiss()
                    }
                    .gesture(
                        DragGesture()
                            .onChanged { value in
                                if value.translation.height > 30 {
                                    onDismiss()
                                }
                            }
                    )

                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: TOYSpacing.xxl) {
                        // Card title - large serif, type-forward
                        VStack(alignment: .leading, spacing: TOYSpacing.sm) {
                            Text(card.title)
                                .font(.toyLargeTitle())
                                .foregroundColor(.warmCream)
                                .lineLimit(3)

                            Text("For \(card.recipientName)")
                                .font(.toyBody())
                                .foregroundColor(.warmGrayDark)

                            if let publishedAt = card.publishedAt {
                                Text(publishedAt.formatted(date: .abbreviated, time: .omitted))
                                    .font(.toyCaption())
                                    .foregroundColor(.warmGrayDark)
                                    .padding(.top, TOYSpacing.xs)
                            }
                        }

                        // Share link - bottom border style
                        if let shareToken = card.shareToken {
                            shareLinkSection(shareToken: shareToken)
                        }

                        // Contributors - simple numbered list
                        contributorsSection
                    }
                    .padding(.horizontal, TOYSpacing.lg)
                    .padding(.bottom, TOYSpacing.xxl)
                    .background(
                        GeometryReader { geo in
                            Color.clear.preference(
                                key: ScrollOffsetPreferenceKey.self,
                                value: geo.frame(in: .named("detailsScroll")).minY
                            )
                        }
                    )
                }
                .coordinateSpace(name: "detailsScroll")
                .onPreferenceChange(ScrollOffsetPreferenceKey.self) { value in
                    scrollOffset = value
                }
                .simultaneousGesture(
                    DragGesture()
                        .onChanged { value in
                            // If at top (scrollOffset >= 0) and dragging down
                            if scrollOffset >= 0 && value.translation.height > 50 {
                                onDismiss()
                            }
                        }
                )
            }
        }
        // No rounded corners - sharp edges
    }

    @ViewBuilder
    private func shareLinkSection(shareToken: String) -> some View {
        let shareURL = "https://sendtoycard.com/view/\(shareToken)"

        VStack(alignment: .leading, spacing: TOYSpacing.md) {
            Text("SHARE")
                .font(.toyCaption())
                .foregroundColor(.warmGrayDark)
                .toyLetterSpacing(1.5)

            Button {
                UIPasteboard.general.string = shareURL
                showCopiedToast = true
            } label: {
                HStack(spacing: TOYSpacing.sm) {
                    Image(systemName: "link")
                        .font(.system(size: 14, weight: .medium))
                    Text("Copy Link")
                        .font(.toyBodyMedium())
                }
                .foregroundColor(.black)
                .frame(maxWidth: .infinity)
                .padding(.vertical, TOYSpacing.md)
                .background(Color.warmCream)
            }
        }
    }

    @ViewBuilder
    private var contributorsSection: some View {
        VStack(alignment: .leading, spacing: TOYSpacing.lg) {
            Text("CONTRIBUTORS")
                .font(.toyCaption())
                .foregroundColor(.warmGrayDark)
                .toyLetterSpacing(1.5)

            if clips.isEmpty {
                Text("No clips yet")
                    .font(.toyBody())
                    .foregroundColor(.warmGrayDark)
            } else {
                VStack(alignment: .leading, spacing: TOYSpacing.md) {
                    ForEach(Array(clips.enumerated()), id: \.element.id) { index, clip in
                        contributorRow(index: index + 1, clip: clip, isDirector: clip.orderPosition == 0)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func contributorRow(index: Int, clip: Clip, isDirector: Bool) -> some View {
        let profile = profiles[clip.participantId]
        let isMe = clip.participantId == currentUserId
        let displayName = profile?.displayName ?? (isDirector ? "Director" : "Contributor")

        HStack(spacing: TOYSpacing.sm) {
            // Profile photo
            if let avatarURL = profile?.avatarURL {
                KFImage(avatarURL)
                    .placeholder {
                        Circle()
                            .fill(Color.warmGrayDark.opacity(0.3))
                    }
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 32, height: 32)
                    .clipShape(Circle())
            } else {
                Circle()
                    .fill(Color.warmGrayDark.opacity(0.3))
                    .frame(width: 32, height: 32)
                    .overlay {
                        Text(String(displayName.prefix(1)).uppercased())
                            .font(.toyCaption())
                            .foregroundColor(.warmCream)
                    }
            }

            Text(isMe ? "\(displayName) (me)" : displayName)
                .font(.toyBody())
                .foregroundColor(.warmCream)

            Spacer()
        }
    }
}

// MARK: - Scroll Offset Preference Key

private struct ScrollOffsetPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

// MARK: - Preview

#Preview {
    PublishedCardPlayerView(card: Card(
        id: UUID(),
        hostId: UUID(),
        title: "Happy Birthday!",
        recipientName: "Sarah",
        status: "published",
        shareToken: "abc123"
    ))
}
