import AVFoundation
import Kingfisher
import SwiftUI
import TOYShared

/// The main card detail/management view for hosts.
struct CardDetailView: View {
    let card: Card
    var initialClips: [Clip] = []
    var initialProfiles: [UUID: (displayName: String?, avatarURL: URL?)] = [:]
    var initialThumbnailURLs: [UUID: URL] = [:]  // clipId -> signedURL
    var currentUser: User?

    @State private var viewModel = CardDetailViewModel()
    @State private var selectedClip: Clip?
    @State private var showError = false
    @State private var showMontagePreview = false
    @State private var showUpgradeSheet = false
    @State private var showDeleteConfirmation = false
    @State private var showFinalDeleteConfirmation = false
    @State private var isDeleting = false

    @Environment(\.dismiss) private var dismiss
    private let cardService = CardService()

    // MARK: - Computed Properties

    private var allContributors: [ContributorRow] {
        var contributors: [ContributorRow] = []

        // Use viewModel clips if available, otherwise fall back to initialClips
        let clips = viewModel.clips.isEmpty ? initialClips : viewModel.clips

        // Host is always first - use currentUser avatar (already in memory) for instant display
        let hostClip = clips.first { $0.participantId == card.hostId }
        let hostDuration = hostClip.flatMap { viewModel.effectiveDuration(for: $0) }
        let hostThumbnailURL = hostClip.flatMap { initialThumbnailURLs[$0.id] }
        contributors.append(ContributorRow(
            id: card.hostId,
            name: "You (Host)",
            clip: hostClip,
            isHost: true,
            effectiveDuration: hostDuration,
            avatarURL: currentUser?.avatarURL,
            thumbnailURL: hostThumbnailURL
        ))

        // Clip-driven approach: iterate through clips, use participantId (which IS the userId) for profiles
        let participantClips = clips.filter { $0.participantId != card.hostId }

        for clip in participantClips {
            let userId = clip.participantId  // participantId IS the userId for logged-in users
            let profile = viewModel.participantProfiles[userId]
            let participant = viewModel.participants.first { $0.userId == userId }

            contributors.append(ContributorRow(
                id: userId,
                name: profile?.displayName ?? "Contributor",
                clip: clip,
                isHost: false,
                participant: participant,
                effectiveDuration: viewModel.effectiveDuration(for: clip),
                avatarURL: profile?.avatarURL,
                thumbnailURL: initialThumbnailURLs[clip.id]
            ))
        }

        return contributors
    }

    private var submittedCount: Int {
        allContributors.filter { $0.clip != nil }.count
    }

    private var totalDuration: Double {
        viewModel.clips.compactMap { viewModel.effectiveDuration(for: $0) }
            .reduce(0, +)
    }

    private var formattedDuration: String {
        let minutes = Int(totalDuration) / 60
        let seconds = Int(totalDuration) % 60
        if minutes > 0 {
            return "\(minutes)m \(seconds)s"
        }
        return "\(seconds)s"
    }

    private var inviteURL: URL? {
        guard let token = card.shareToken else { return nil }
        return URL(string: "https://sendtoycard.com/card/\(token)")
    }

    private var needsUpgrade: Bool {
        viewModel.participants.count >= card.maxParticipants && card.maxParticipants < 999
    }

    // MARK: - Body

    var body: some View {
        ZStack {
            TOYBackground()

            ScrollView {
                VStack(alignment: .leading, spacing: TOYSpacing.xl) {
                    // Card title and recipient
                    VStack(alignment: .leading, spacing: TOYSpacing.xs) {
                        Text(card.title)
                            .font(.toyTitle())
                            .foregroundColor(.toyText)
                            .lineSpacing(-4)
                            .frame(maxWidth: .infinity, alignment: .leading)

                        HStack(spacing: TOYSpacing.xs) {
                            Text("For")
                                .font(.toyBody())
                                .foregroundColor(.toyTextSecondary)
                            Text(card.recipientName)
                                .font(.toyBodyMedium())
                                .foregroundColor(.toyText)
                        }
                    }
                    .padding(.top, TOYSpacing.sm)

                    // Invite link - prominent CTA
                    inviteLinkView

                    // Summary stats
                    summaryStatsView

                    // Upgrade banner
                    if needsUpgrade {
                        upgradeBannerView
                    }

                    // Contributors section
                    contributorsSection

                    // Preview montage
                    if !viewModel.clips.isEmpty {
                        previewMontageView
                    }
                }
                .padding(.horizontal, TOYSpacing.lg)
                .padding(.vertical, TOYSpacing.lg)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                EmptyView()
            }
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button(role: .destructive) {
                        showDeleteConfirmation = true
                    } label: {
                        Label("Delete Card", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.toyText)
                }
            }
        }
        .refreshable {
            await viewModel.loadData(for: card.id, hostId: card.hostId)
        }
        .task {
            await viewModel.loadData(
                for: card.id,
                hostId: card.hostId,
                initialClips: initialClips.isEmpty ? nil : initialClips,
                initialProfiles: initialProfiles.isEmpty ? nil : initialProfiles
            )
        }
        .sheet(item: $selectedClip) { clip in
            ClipPreviewSheet(
                clip: clip,
                cachedURL: viewModel.cachedSignedURLs[clip.id]
            ) {
                await viewModel.deleteClip(clip)
            }
        }
        .fullScreenCover(isPresented: $showMontagePreview) {
            NavigationStack {
                MontagePreviewView(
                    card: card,
                    clips: viewModel.clips,
                    cachedSignedURLs: viewModel.cachedSignedURLs
                ) {
                    showMontagePreview = false
                    Task { await viewModel.loadData(for: card.id, hostId: card.hostId) }
                }
            }
        }
        .sheet(isPresented: $showUpgradeSheet) {
            CardUpgradeView(
                card: card,
                currentParticipantCount: viewModel.participants.count
            )
        }
        .onChange(of: viewModel.errorMessage) { _, newValue in
            showError = newValue != nil
        }
        .alert("Error", isPresented: $showError) {
            Button("OK") { viewModel.errorMessage = nil }
        } message: {
            if let error = viewModel.errorMessage {
                Text(error)
            }
        }
        .alert("Delete Card?", isPresented: $showDeleteConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                showFinalDeleteConfirmation = true
            }
        } message: {
            Text("This will permanently delete \"\(card.title)\" and all \(viewModel.clips.count) video clips. This action cannot be undone.")
        }
        .alert("Are you sure?", isPresented: $showFinalDeleteConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Delete Forever", role: .destructive) {
                Task { await deleteCard() }
            }
        } message: {
            Text("This is your final warning. All videos and participant data will be permanently lost.")
        }
    }

    // MARK: - Delete Card

    private func deleteCard() async {
        isDeleting = true
        do {
            try await cardService.deleteCard(cardId: card.id)
            await MainActor.run {
                dismiss()
            }
        } catch {
            await MainActor.run {
                viewModel.errorMessage = error.localizedDescription
                isDeleting = false
            }
        }
    }

    // MARK: - Summary Stats

    private var summaryStatsView: some View {
        HStack(spacing: TOYSpacing.lg) {
            VStack(alignment: .leading, spacing: TOYSpacing.xs) {
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text("\(submittedCount)")
                        .font(.toyDisplaySmall())
                        .foregroundColor(.toyText)
                    Text("of \(allContributors.count)")
                        .font(.toySubheadline())
                        .foregroundColor(.toyTextSecondary)
                }
                Text("clips submitted")
                    .font(.toyCaption())
                    .foregroundColor(.toyTextSecondary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: TOYSpacing.xs) {
                Text(formattedDuration)
                    .font(.toyDisplaySmall())
                    .foregroundColor(.toyText)
                Text("total duration")
                    .font(.toyCaption())
                    .foregroundColor(.toyTextSecondary)
            }
        }
        .padding(.vertical, TOYSpacing.md)
    }

    // MARK: - Invite Link

    @ViewBuilder
    private var inviteLinkView: some View {
        if let url = inviteURL {
            ShareLink(
                item: url,
                subject: Text("Join my TOY card!"),
                message: Text("Record a video message for \(card.recipientName)")
            ) {
                HStack(spacing: TOYSpacing.md) {
                    VStack(alignment: .leading, spacing: TOYSpacing.xs) {
                        Text("Invite Contributors")
                            .font(.toyBodyMedium())
                            .foregroundColor(.toyText)
                        Text("Share this link with friends and family")
                            .font(.toyCaption())
                            .foregroundColor(.toyTextSecondary)
                    }

                    Spacer()

                    Image(systemName: "square.and.arrow.up")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.toyText)
                }
                .padding(TOYSpacing.md)
                .background(
                    Rectangle()
                        .stroke(Color.toyText, lineWidth: 1)
                )
            }
        }
    }

    // MARK: - Upgrade Banner

    private var upgradeBannerView: some View {
        Button {
            showUpgradeSheet = true
        } label: {
            HStack(spacing: TOYSpacing.md) {
                VStack(alignment: .leading, spacing: TOYSpacing.xs) {
                    Text("Card is full")
                        .font(.toyBodyMedium())
                        .foregroundColor(.toyText)
                    Text("Upgrade for unlimited participants")
                        .font(.toyCaption())
                        .foregroundColor(.toyTextSecondary)
                }

                Spacer()

                Image(systemName: "arrow.right")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.toyText)
            }
            .padding(TOYSpacing.md)
            .background(
                Rectangle()
                    .stroke(Color.toyDivider, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Contributors Section

    private var contributorsSection: some View {
        VStack(alignment: .leading, spacing: TOYSpacing.md) {
            Text("CONTRIBUTORS")
                .font(.toyCaption())
                .foregroundColor(.toyTextSecondary)
                .toyLetterSpacing(1.5)

            // Show contributors immediately - names may update when participants load
            ForEach(allContributors) { contributor in
                ContributorClipRow(
                    contributor: contributor,
                    onTapClip: { clip in
                        selectedClip = clip
                    }
                )

                if contributor.id != allContributors.last?.id {
                    Rectangle()
                        .fill(Color.toyDivider)
                        .frame(height: 1)
                }
            }
        }
    }

    // MARK: - Preview Montage

    private var previewMontageView: some View {
        Button {
            showMontagePreview = true
        } label: {
            HStack(spacing: TOYSpacing.md) {
                VStack(alignment: .leading, spacing: TOYSpacing.xs) {
                    Text("Preview Montage")
                        .font(.toyBodyMedium())
                        .foregroundColor(.toyBackground)
                    Text("\(viewModel.clips.count) clips - \(formattedDuration) total")
                        .font(.toyCaption())
                        .foregroundColor(.toyBackground.opacity(0.7))
                }

                Spacer()

                Image(systemName: "play.fill")
                    .font(.system(size: 14))
                    .foregroundColor(.toyBackground)
            }
            .padding(TOYSpacing.md)
            .background(
                Rectangle()
                    .fill(Color.toyText)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Contributor Row Model

private struct ContributorRow: Identifiable {
    let id: UUID
    let name: String
    let clip: Clip?
    let isHost: Bool
    var participant: Participant?
    var effectiveDuration: Double?
    var avatarURL: URL?
    var thumbnailURL: URL?  // Pre-fetched signed URL for instant display
}

// MARK: - Contributor Clip Row

private struct ContributorClipRow: View {
    let contributor: ContributorRow
    let onTapClip: (Clip) -> Void

    var body: some View {
        Button {
            if let clip = contributor.clip {
                onTapClip(clip)
            }
        } label: {
            HStack(spacing: TOYSpacing.md) {
                // Avatar
                if let avatarURL = contributor.avatarURL {
                    KFImage(avatarURL)
                        .placeholder {
                            Circle()
                                .fill(Color.toyDivider)
                        }
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 40, height: 40)
                        .clipShape(Circle())
                } else {
                    Circle()
                        .stroke(Color.toyDivider, lineWidth: 1)
                        .frame(width: 40, height: 40)
                        .overlay {
                            if contributor.isHost {
                                Text("H")
                                    .font(.toySubheadline())
                                    .foregroundColor(.toyText)
                            } else {
                                Text(String(contributor.name.prefix(1)).uppercased())
                                    .font(.toySubheadline())
                                    .foregroundColor(.toyTextSecondary)
                            }
                        }
                }

                // Name and status
                VStack(alignment: .leading, spacing: TOYSpacing.xs) {
                    Text(contributor.name)
                        .font(.toyBody())
                        .foregroundColor(.toyText)

                    if let clip = contributor.clip {
                        Text("Submitted")
                            .font(.toyCaption())
                            .foregroundColor(.toyTextSecondary)
                    } else if let participant = contributor.participant {
                        Text(statusText(for: participant))
                            .font(.toyCaption())
                            .foregroundColor(.toyTextSecondary)
                    } else if !contributor.isHost {
                        Text("Not submitted")
                            .font(.toyCaption())
                            .foregroundColor(.toyTextSecondary)
                    }
                }

                Spacer()

                // Clip thumbnail
                if let clip = contributor.clip {
                    ClipThumbnailView(clip: clip, effectiveDuration: contributor.effectiveDuration, signedURL: contributor.thumbnailURL)
                } else {
                    Rectangle()
                        .strokeBorder(Color.toyDivider, style: StrokeStyle(lineWidth: 1, dash: [4]))
                        .frame(width: 50, height: 66)
                        .overlay {
                            Image(systemName: "video.slash")
                                .font(.system(size: 14))
                                .foregroundColor(.toyTextSecondary)
                        }
                }
            }
            .padding(.vertical, TOYSpacing.sm)
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
}

// MARK: - Contributor Skeleton Row

private struct ContributorSkeletonRow: View {
    @State private var shimmerOffset: CGFloat = -1.0

    var body: some View {
        HStack(spacing: TOYSpacing.md) {
            Circle()
                .fill(Color.toyDivider)
                .frame(width: 40, height: 40)

            VStack(alignment: .leading, spacing: TOYSpacing.sm) {
                Rectangle()
                    .fill(Color.toyDivider)
                    .frame(width: 120, height: 14)

                Rectangle()
                    .fill(Color.toyDivider)
                    .frame(width: 70, height: 10)
            }

            Spacer()

            Rectangle()
                .fill(Color.toyDivider)
                .frame(width: 50, height: 66)
        }
        .padding(.vertical, TOYSpacing.sm)
    }
}

// MARK: - Clip Thumbnail View

private struct ClipThumbnailView: View {
    let clip: Clip
    let effectiveDuration: Double?
    var signedURL: URL?  // Pre-fetched from HomeView for instant display

    @State private var fetchedURL: URL?  // Fallback if not pre-fetched
    @State private var isLoading = false

    private let storageService = StorageService()

    // Use pre-fetched URL if available, otherwise fallback to fetched
    private var effectiveURL: URL? {
        signedURL ?? fetchedURL
    }

    var body: some View {
        ZStack {
            Rectangle()
                .fill(Color.toyVideoContainer)
                .frame(width: 50, height: 66)

            if let url = effectiveURL, let cacheKey = clip.thumbnailUrl {
                // KFImage handles all caching automatically
                KFImage(source: .network(KF.ImageResource(downloadURL: url, cacheKey: cacheKey)))
                    .placeholder {
                        ProgressView()
                            .tint(.warmCream)
                            .scaleEffect(0.6)
                    }
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 50, height: 66)
                    .clipped()
            } else if isLoading {
                ProgressView()
                    .tint(.warmCream)
                    .scaleEffect(0.6)
            } else {
                Image(systemName: "play.fill")
                    .font(.system(size: 16))
                    .foregroundColor(.warmCream)
            }

            // Duration label
            if let duration = effectiveDuration, effectiveURL != nil {
                VStack {
                    Spacer()
                    Text(String(format: "%.1fs", duration))
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(.white)
                        .padding(.horizontal, 4)
                        .padding(.vertical, 2)
                        .background(Color.black.opacity(0.6))
                        .padding(4)
                }
                .frame(width: 50, height: 66)
            }
        }
        .task {
            // Only fetch if not pre-fetched
            if signedURL == nil {
                await loadSignedURL()
            }
        }
    }

    private func loadSignedURL() async {
        isLoading = true
        defer { isLoading = false }
        guard let thumbnailPath = clip.thumbnailUrl else { return }

        do {
            fetchedURL = try await storageService.createSignedURL(path: thumbnailPath)
        } catch {
            #if DEBUG
            print("Failed to get signed URL: \(error)")
            #endif
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
