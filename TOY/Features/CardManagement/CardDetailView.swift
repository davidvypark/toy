import AVFoundation
import SwiftUI
import TOYShared

/// The main card detail/management view for hosts.
/// Displays card info, participant+clip rows with thumbnails, and summary stats.
struct CardDetailView: View {
    let card: Card

    @State private var viewModel = CardDetailViewModel()
    @State private var selectedClip: Clip?
    @State private var showError = false

    // MARK: - Computed Properties

    /// All contributors including host as first entry
    private var allContributors: [ContributorRow] {
        var contributors: [ContributorRow] = []

        // Host is always first
        let hostClip = viewModel.clips.first { $0.orderPosition == 0 }
        contributors.append(ContributorRow(
            id: card.hostId,
            name: "You (Host)",
            clip: hostClip,
            isHost: true
        ))

        // Add participants with their clips
        for participant in viewModel.participants {
            let participantClip = viewModel.clips.first { $0.participantId == participant.id }
            contributors.append(ContributorRow(
                id: participant.id,
                name: participant.email ?? "Invited Guest",
                clip: participantClip,
                isHost: false,
                participant: participant
            ))
        }

        return contributors
    }

    /// Count of contributors who have submitted clips
    private var submittedCount: Int {
        allContributors.filter { $0.clip != nil }.count
    }

    /// Total duration of all clips in seconds
    private var totalDuration: Double {
        viewModel.clips.compactMap { $0.durationSeconds }
            .reduce(0) { $0 + NSDecimalNumber(decimal: $1).doubleValue }
    }

    /// Formatted total duration string
    private var formattedDuration: String {
        let minutes = Int(totalDuration) / 60
        let seconds = Int(totalDuration) % 60
        if minutes > 0 {
            return "\(minutes)m \(seconds)s"
        }
        return "\(seconds)s"
    }

    /// Invite URL for sharing
    private var inviteURL: URL? {
        guard let token = card.shareToken else { return nil }
        return URL(string: "https://toy.app/card/\(token)")
    }

    // MARK: - Body

    var body: some View {
        List {
            // Summary stats section
            Section {
                HStack(spacing: 24) {
                    // Clips submitted stat
                    VStack(spacing: 4) {
                        HStack(spacing: 4) {
                            Text("\(submittedCount)")
                                .font(.system(size: 28, weight: .bold))
                                .foregroundColor(.toyPrimary)
                            Text("of \(allContributors.count)")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(.toyTextSecondary)
                        }
                        TOYLabel("clips submitted", style: .caption, color: .toyTextSecondary)
                    }
                    .frame(maxWidth: .infinity)

                    // Divider
                    Rectangle()
                        .fill(Color.toyTextSecondary.opacity(0.3))
                        .frame(width: 1, height: 40)

                    // Total duration stat
                    VStack(spacing: 4) {
                        Text(formattedDuration)
                            .font(.system(size: 28, weight: .bold))
                            .foregroundColor(.toyPrimary)
                        TOYLabel("total duration", style: .caption, color: .toyTextSecondary)
                    }
                    .frame(maxWidth: .infinity)
                }
                .padding(.vertical, 8)
            }

            // Card info with re-share link
            Section {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        TOYLabel("For: ", style: .body, color: .toyTextSecondary)
                        TOYLabel(card.recipientName, style: .body)
                    }

                    if let url = inviteURL {
                        ShareLink(
                            item: url,
                            subject: Text("Join my TOY card!"),
                            message: Text("Record a video message for \(card.recipientName)")
                        ) {
                            HStack {
                                Image(systemName: "square.and.arrow.up")
                                    .font(.system(size: 14))
                                Text("Share Invite Link")
                                    .font(.subheadline.weight(.medium))
                            }
                            .foregroundColor(.toyPrimary)
                        }
                    }
                }
                .padding(.vertical, 4)
            }

            // Contributors section (participants + clips combined)
            Section {
                if allContributors.isEmpty && viewModel.isLoading {
                    // Skeleton loading placeholders for contributors
                    ForEach(0..<3, id: \.self) { _ in
                        ContributorSkeletonRow()
                    }
                } else {
                    ForEach(allContributors) { contributor in
                        ContributorClipRow(
                            contributor: contributor,
                            onTapClip: { clip in
                                selectedClip = clip
                            }
                        )
                    }
                }
            } header: {
                TOYLabel("Contributors", style: .caption)
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle(card.title)
        .navigationBarTitleDisplayMode(.inline)
        .refreshable {
            await viewModel.loadData(for: card.id)
        }
        .task {
            await viewModel.loadData(for: card.id)
        }
        .sheet(item: $selectedClip) { clip in
            ClipPreviewSheet(clip: clip) {
                await viewModel.deleteClip(clip)
            }
        }
        .onChange(of: viewModel.errorMessage) { _, newValue in
            showError = newValue != nil
        }
        .alert("Error", isPresented: $showError) {
            Button("OK") {
                viewModel.errorMessage = nil
            }
        } message: {
            if let error = viewModel.errorMessage {
                Text(error)
            }
        }
    }
}

// MARK: - Contributor Row Model

/// Represents a contributor (host or participant) with their optional clip
private struct ContributorRow: Identifiable {
    let id: UUID
    let name: String
    let clip: Clip?
    let isHost: Bool
    var participant: Participant?
}

// MARK: - Contributor Clip Row

/// A row displaying a contributor's name on the left and their clip thumbnail on the right
/// The entire row is tappable when a clip exists
private struct ContributorClipRow: View {
    let contributor: ContributorRow
    let onTapClip: (Clip) -> Void

    var body: some View {
        Button {
            if let clip = contributor.clip {
                onTapClip(clip)
            }
        } label: {
            HStack(spacing: 12) {
                // Avatar
                Circle()
                    .fill(contributor.isHost ? Color.toyPrimary.opacity(0.2) : Color.toySurface)
                    .frame(width: 40, height: 40)
                    .overlay {
                        Image(systemName: contributor.isHost ? "star.fill" : "person.fill")
                            .foregroundColor(contributor.isHost ? .toyPrimary : .toyTextSecondary)
                            .font(.system(size: 16))
                    }

                // Name and status
                VStack(alignment: .leading, spacing: 2) {
                    TOYLabel(contributor.name, style: .body)

                    if let clip = contributor.clip {
                        TOYLabel("Submitted", style: .caption, color: .green)
                    } else if let participant = contributor.participant {
                        TOYLabel(statusText(for: participant), style: .caption, color: statusColor(for: participant))
                    } else if !contributor.isHost {
                        TOYLabel("Not submitted", style: .caption, color: .toyTextSecondary)
                    }
                }

                Spacer()

                // Clip thumbnail or empty state
                if let clip = contributor.clip {
                    ClipThumbnailView(clip: clip)
                } else {
                    // Empty thumbnail placeholder
                    RoundedRectangle(cornerRadius: 8)
                        .strokeBorder(Color.toyTextSecondary.opacity(0.3), style: StrokeStyle(lineWidth: 1, dash: [4]))
                        .frame(width: 50, height: 66)
                        .overlay {
                            Image(systemName: "video.slash")
                                .font(.system(size: 14))
                                .foregroundColor(.toyTextSecondary.opacity(0.5))
                        }
                }
            }
            .padding(.vertical, 4)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(contributor.clip == nil)
    }

    private func statusText(for participant: Participant) -> String {
        switch participant.status {
        case "invited": return "Waiting"
        case "viewed": return "Viewed"
        case "recording": return "Recording..."
        case "submitted": return "Submitted"
        default: return participant.status
        }
    }

    private func statusColor(for participant: Participant) -> Color {
        switch participant.status {
        case "submitted": return .green
        case "recording": return .toyPrimary
        default: return .toyTextSecondary
        }
    }
}

// MARK: - Contributor Skeleton Row

/// A skeleton loading placeholder for contributor rows
private struct ContributorSkeletonRow: View {
    @State private var shimmerOffset: CGFloat = -1.0

    var body: some View {
        HStack(spacing: 12) {
            // Avatar skeleton
            Circle()
                .fill(Color(uiColor: UIColor.systemGray5))
                .frame(width: 40, height: 40)

            // Name and status skeleton
            VStack(alignment: .leading, spacing: 6) {
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color(uiColor: UIColor.systemGray5))
                    .frame(width: 120, height: 14)

                RoundedRectangle(cornerRadius: 4)
                    .fill(Color(uiColor: UIColor.systemGray5))
                    .frame(width: 70, height: 10)
            }

            Spacer()

            // Thumbnail skeleton
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(uiColor: UIColor.systemGray5))
                .frame(width: 50, height: 66)
        }
        .padding(.vertical, 4)
        .overlay {
            GeometryReader { geometry in
                LinearGradient(
                    gradient: Gradient(colors: [
                        .clear,
                        .white.opacity(0.4),
                        .clear
                    ]),
                    startPoint: .leading,
                    endPoint: .trailing
                )
                .frame(width: geometry.size.width * 0.4)
                .offset(x: shimmerOffset * geometry.size.width)
            }
            .clipped()
        }
        .onAppear {
            shimmerOffset = -1.0
            withAnimation(.linear(duration: 1.0).repeatForever(autoreverses: false)) {
                shimmerOffset = 1.5
            }
        }
    }
}

// MARK: - Clip Thumbnail View

/// A view that loads and displays a video thumbnail from a signed URL
private struct ClipThumbnailView: View {
    let clip: Clip

    @State private var thumbnail: UIImage?
    @State private var isLoading = true

    private let storageService = StorageService()

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.toySurface)
                .frame(width: 50, height: 66)

            if isLoading {
                // Loading shimmer
                ShimmerView()
                    .frame(width: 50, height: 66)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            } else if let thumbnail {
                // Actual thumbnail
                Image(uiImage: thumbnail)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 50, height: 66)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            } else {
                // Fallback play icon
                Image(systemName: "play.fill")
                    .font(.system(size: 16))
                    .foregroundColor(.toyTextSecondary)
            }

            // Play button overlay (when thumbnail loaded)
            if thumbnail != nil {
                Circle()
                    .fill(Color.black.opacity(0.5))
                    .frame(width: 24, height: 24)
                    .overlay {
                        Image(systemName: "play.fill")
                            .font(.system(size: 10))
                            .foregroundColor(.white)
                    }
            }

            // Duration label at bottom
            if let duration = clip.durationSeconds {
                VStack {
                    Spacer()
                    Text(formatDuration(NSDecimalNumber(decimal: duration).doubleValue))
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(.white)
                        .padding(.horizontal, 4)
                        .padding(.vertical, 2)
                        .background(Color.black.opacity(0.6))
                        .cornerRadius(4)
                        .padding(4)
                }
                .frame(width: 50, height: 66)
            }
        }
        .task {
            await loadThumbnail()
        }
    }

    private func loadThumbnail() async {
        isLoading = true
        defer { isLoading = false }

        do {
            // Get signed URL for the video
            let signedURL = try await storageService.createSignedURL(path: clip.videoUrl)

            // Generate thumbnail from video
            let asset = AVAsset(url: signedURL)
            let imageGenerator = AVAssetImageGenerator(asset: asset)
            imageGenerator.appliesPreferredTrackTransform = true
            imageGenerator.maximumSize = CGSize(width: 150, height: 200) // Higher res for quality

            // Get frame at 0.5 seconds (or start if video is shorter)
            let time = CMTime(seconds: 0.5, preferredTimescale: 600)
            let cgImage = try await imageGenerator.image(at: time).image
            thumbnail = UIImage(cgImage: cgImage)
        } catch {
            #if DEBUG
            print("Failed to load thumbnail: \(error)")
            #endif
            // Leave thumbnail nil, will show fallback
        }
    }

    private func formatDuration(_ seconds: Double) -> String {
        String(format: "%.1fs", seconds)
    }
}

// MARK: - Shimmer View

/// A simple shimmer loading effect for thumbnails
private struct ShimmerView: View {
    @State private var shimmerOffset: CGFloat = -1.0

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Color.toyTextSecondary.opacity(0.15)

                LinearGradient(
                    gradient: Gradient(colors: [
                        .clear,
                        .white.opacity(0.3),
                        .clear
                    ]),
                    startPoint: .leading,
                    endPoint: .trailing
                )
                .frame(width: geometry.size.width * 0.6)
                .offset(x: shimmerOffset * geometry.size.width)
            }
        }
        .onAppear {
            shimmerOffset = -1.0
            withAnimation(.linear(duration: 1.0).repeatForever(autoreverses: false)) {
                shimmerOffset = 1.5
            }
        }
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        CardDetailView(
            card: Card(
                id: UUID(),
                hostId: UUID(),
                title: "Happy Birthday Sarah!",
                recipientName: "Sarah",
                status: "collecting",
                shareToken: "abc123-test-token"
            )
        )
    }
}
