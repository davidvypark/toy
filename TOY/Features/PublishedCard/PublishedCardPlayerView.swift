//
//  PublishedCardPlayerView.swift
//  TOY
//
//  Full screen video player for published cards.
//  "Intimate Raw" design: minimal chrome, type-forward details panel.
//

import AVKit
import SwiftUI
import TOYShared

struct PublishedCardPlayerView: View {
    let card: Card
    @Environment(\.dismiss) private var dismiss

    @State private var player: AVPlayer?
    @State private var isLoading = true
    @State private var error: String?
    @State private var showDetails = false
    @State private var clips: [Clip] = []
    @State private var showCopiedToast = false

    private let storageService = StorageService()
    private let cardService = CardService()

    private let detailsPanelHeight: CGFloat = UIScreen.main.bounds.height * 0.55

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // True black background
                Color.black.ignoresSafeArea()

                // Video player
                if let player = player {
                    VideoPlayerView(player: player, showDetails: showDetails, geometry: geometry)
                        .onTapGesture {
                            if showDetails {
                                withAnimation(.easeOut(duration: 0.2)) {
                                    showDetails = false
                                }
                            }
                        }
                } else if isLoading {
                    ProgressView()
                        .tint(.warmCream)
                } else if let error = error {
                    VStack(spacing: TOYSpacing.md) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.system(size: 40, weight: .light))
                            .foregroundColor(.warmGrayDark)
                        Text(error)
                            .font(.toyBody())
                            .foregroundColor(.warmCream)
                            .multilineTextAlignment(.center)
                    }
                    .padding()
                }

                // Overlay content
                VStack {
                    // Top bar - minimal close button
                    HStack {
                        Button {
                            dismiss()
                        } label: {
                            Image(systemName: "xmark")
                                .font(.system(size: 18, weight: .light))
                                .foregroundColor(.warmCream)
                        }
                        Spacer()
                    }
                    .padding(.horizontal, TOYSpacing.lg)
                    .padding(.top, TOYSpacing.md)

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
                        if !showDetails && value.translation.height < -20 {
                            withAnimation(.easeOut(duration: 0.2)) {
                                showDetails = true
                            }
                        } else if showDetails && value.translation.height > 20 {
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
                            .foregroundColor(.warmCream)
                            .toyLetterSpacing(1)
                            .padding(.horizontal, TOYSpacing.lg)
                            .padding(.vertical, TOYSpacing.sm)
                            .background(Color.warmBlack)
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
        }
        .task {
            await loadVideo()
            await loadClips()
        }
        .onDisappear {
            player?.pause()
        }
    }

    private func loadVideo() async {
        guard let videoPath = card.videoUrl else {
            error = "No video available"
            isLoading = false
            return
        }

        do {
            let signedURL = try await storageService.createSignedVideoURL(path: videoPath)
            await MainActor.run {
                let avPlayer = AVPlayer(url: signedURL)
                avPlayer.play()

                NotificationCenter.default.addObserver(
                    forName: .AVPlayerItemDidPlayToEndTime,
                    object: avPlayer.currentItem,
                    queue: .main
                ) { _ in
                    avPlayer.seek(to: .zero)
                    avPlayer.play()
                }

                self.player = avPlayer
                self.isLoading = false
            }
        } catch {
            await MainActor.run {
                self.error = error.localizedDescription
                self.isLoading = false
            }
        }
    }

    private func loadClips() async {
        do {
            clips = try await cardService.fetchClipsForCard(cardId: card.id)
        } catch {
            #if DEBUG
            print("Failed to load clips: \(error)")
            #endif
        }
    }
}

// MARK: - Video Player View

private struct VideoPlayerView: View {
    let player: AVPlayer
    let showDetails: Bool
    let geometry: GeometryProxy

    var body: some View {
        let videoHeight = showDetails ? geometry.size.height * 0.40 : geometry.size.height
        let videoWidth = showDetails ? geometry.size.width * 0.85 : geometry.size.width

        VideoPlayer(player: player)
            .disabled(true)
            .frame(width: videoWidth, height: videoHeight)
            .clipped()
            .background(Color.black)
            .animation(.easeOut(duration: 0.2), value: showDetails)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: showDetails ? .top : .center)
            .padding(.top, showDetails ? 50 : 0)
    }
}

// MARK: - Details Panel

private struct DetailsPanel: View {
    let card: Card
    let clips: [Clip]
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
                VStack(alignment: .leading, spacing: TOYSpacing.sm) {
                    Text(shareURL)
                        .font(.system(.caption, design: .monospaced))
                        .foregroundColor(.warmCream)
                        .lineLimit(1)

                    // Bottom border
                    Rectangle()
                        .fill(Color.dividerDark)
                        .frame(height: 1)
                }
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
        HStack(alignment: .firstTextBaseline, spacing: TOYSpacing.sm) {
            // Simple number
            Text("\(index).")
                .font(.toyCaption())
                .foregroundColor(.warmGrayDark)
                .frame(width: 20, alignment: .trailing)

            VStack(alignment: .leading, spacing: TOYSpacing.xs) {
                HStack(spacing: TOYSpacing.sm) {
                    Text(isDirector ? "Director" : "Contributor \(index)")
                        .font(.toyBody())
                        .foregroundColor(.warmCream)
                }

                if let duration = clip.durationSeconds {
                    Text("\(NSDecimalNumber(decimal: duration).doubleValue, specifier: "%.1f")s")
                        .font(.toyCaption())
                        .foregroundColor(.warmGrayDark)
                }
            }

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
