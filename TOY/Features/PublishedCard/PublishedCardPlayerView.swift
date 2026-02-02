//
//  PublishedCardPlayerView.swift
//  TOY
//
//  TikTok-style full screen video player for published cards.
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
    @State private var detailsOffset: CGFloat = 0
    @State private var showDetails = false
    @State private var clips: [Clip] = []
    @State private var showCopiedToast = false

    private let storageService = StorageService()
    private let cardService = CardService()

    // Details panel height (half screen)
    private let detailsPanelHeight: CGFloat = UIScreen.main.bounds.height * 0.5

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Black background
                Color.black.ignoresSafeArea()

                // Video player
                if let player = player {
                    VideoPlayerView(player: player, showDetails: showDetails, geometry: geometry)
                } else if isLoading {
                    ProgressView()
                        .tint(.white)
                } else if let error = error {
                    VStack(spacing: 16) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.largeTitle)
                            .foregroundColor(.orange)
                        Text(error)
                            .foregroundColor(.white)
                            .multilineTextAlignment(.center)
                    }
                    .padding()
                }

                // Overlay content
                VStack {
                    // Top bar with close button
                    HStack {
                        Button {
                            dismiss()
                        } label: {
                            Image(systemName: "xmark")
                                .font(.title2)
                                .foregroundStyle(.white)
                                .padding(12)
                                .background(.ultraThinMaterial)
                                .clipShape(Circle())
                        }
                        Spacer()
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 8)

                    Spacer()

                    // Bottom hint text (only when details hidden)
                    if !showDetails {
                        VStack(spacing: 4) {
                            Image(systemName: "chevron.up")
                                .font(.caption)
                            Text("swipe up for details")
                                .font(.caption2)
                        }
                        .foregroundColor(.white.opacity(0.7))
                        .padding(.bottom, 40)
                    }
                }
                .opacity(showDetails ? 0.3 : 1)

                // Details panel (slides up from bottom)
                VStack(spacing: 0) {
                    Spacer()

                    DetailsPanel(
                        card: card,
                        clips: clips,
                        onDismiss: {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
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
                            // Swiping up - show details
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                showDetails = true
                            }
                        } else if showDetails && value.translation.height > 20 {
                            // Swiping down - hide details
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                showDetails = false
                            }
                        }
                    }
            )
            .overlay {
                // Copied toast
                if showCopiedToast {
                    VStack {
                        Spacer()
                        Text("Link copied!")
                            .font(.subheadline.weight(.medium))
                            .foregroundColor(.white)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 12)
                            .background(Color.black.opacity(0.8))
                            .cornerRadius(25)
                            .padding(.bottom, 100)
                    }
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
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

                // Loop video
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
        let videoHeight = showDetails ? geometry.size.height * 0.45 : geometry.size.height
        let videoWidth = showDetails ? geometry.size.width * 0.9 : geometry.size.width

        VideoPlayer(player: player)
            .disabled(true)  // Disable default controls
            .frame(width: videoWidth, height: videoHeight)
            .clipped()
            .background(Color.black)
            .animation(.spring(response: 0.3, dampingFraction: 0.8), value: showDetails)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: showDetails ? .top : .center)
            .padding(.top, showDetails ? 60 : 0)
    }
}

// MARK: - Details Panel

private struct DetailsPanel: View {
    let card: Card
    let clips: [Clip]
    let onDismiss: () -> Void
    @Binding var showCopiedToast: Bool

    var body: some View {
        VStack(spacing: 0) {
            // Drag handle
            Capsule()
                .fill(Color.white.opacity(0.4))
                .frame(width: 36, height: 5)
                .padding(.top, 12)
                .padding(.bottom, 16)
                .frame(maxWidth: .infinity)
                .background(Color.black.opacity(0.95))
                .onTapGesture {
                    onDismiss()
                }

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Card Info
                    VStack(alignment: .leading, spacing: 8) {
                        Text(card.title)
                            .font(.title2.weight(.bold))
                            .foregroundColor(.white)

                        Text("For \(card.recipientName)")
                            .font(.subheadline)
                            .foregroundColor(.white.opacity(0.7))

                        if let publishedAt = card.publishedAt {
                            Text("Published \(publishedAt.formatted(date: .abbreviated, time: .omitted))")
                                .font(.caption)
                                .foregroundColor(.white.opacity(0.5))
                        }
                    }

                    // Share Link
                    if let shareToken = card.shareToken {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Share Link")
                                .font(.caption)
                                .foregroundColor(.white.opacity(0.5))

                            let shareURL = "https://sendtoycard.com/view/\(shareToken)"

                            Button {
                                UIPasteboard.general.string = shareURL
                                showCopiedToast = true
                            } label: {
                                HStack {
                                    Text(shareURL)
                                        .font(.system(.caption, design: .monospaced))
                                        .lineLimit(1)

                                    Spacer()

                                    Image(systemName: "doc.on.doc")
                                        .font(.caption)
                                }
                                .foregroundColor(.toyPrimary)
                                .padding(12)
                                .background(Color.white.opacity(0.1))
                                .cornerRadius(8)
                            }
                        }
                    }

                    // Contributors
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Contributors (\(clips.count))")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.5))

                        if clips.isEmpty {
                            Text("No clips yet")
                                .font(.subheadline)
                                .foregroundColor(.white.opacity(0.5))
                        } else {
                            ForEach(Array(clips.enumerated()), id: \.element.id) { index, clip in
                                ContributorRow(
                                    index: index + 1,
                                    clip: clip,
                                    isDirector: clip.orderPosition == 0
                                )
                            }
                        }
                    }
                }
                .padding(20)
            }
            .background(Color.black.opacity(0.95))
        }
        .background(Color.black.opacity(0.95))
        .cornerRadius(20, corners: [.topLeft, .topRight])
    }
}

// MARK: - Contributor Row

private struct ContributorRow: View {
    let index: Int
    let clip: Clip
    let isDirector: Bool

    var body: some View {
        HStack(spacing: 12) {
            // Avatar placeholder
            Circle()
                .fill(Color.toyPrimary.opacity(0.3))
                .frame(width: 36, height: 36)
                .overlay {
                    Text("\(index)")
                        .font(.caption.weight(.bold))
                        .foregroundColor(.toyPrimary)
                }

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text("Contributor \(index)")
                        .font(.subheadline)
                        .foregroundColor(.white)

                    if isDirector {
                        Text("Director")
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundColor(.toyPrimary)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.toyPrimary.opacity(0.2))
                            .cornerRadius(4)
                    }
                }

                if let duration = clip.durationSeconds {
                    Text("\(NSDecimalNumber(decimal: duration).doubleValue, specifier: "%.1f")s clip")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.5))
                }
            }

            Spacer()
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Corner Radius Extension

private extension View {
    func cornerRadius(_ radius: CGFloat, corners: UIRectCorner) -> some View {
        clipShape(RoundedCorner(radius: radius, corners: corners))
    }
}

private struct RoundedCorner: Shape {
    var radius: CGFloat = .infinity
    var corners: UIRectCorner = .allCorners

    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(
            roundedRect: rect,
            byRoundingCorners: corners,
            cornerRadii: CGSize(width: radius, height: radius)
        )
        return Path(path.cgPath)
    }
}

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
