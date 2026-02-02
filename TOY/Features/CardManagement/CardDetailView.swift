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
                    HStack {
                        Spacer()
                        ProgressView()
                        Spacer()
                    }
                    .padding(.vertical, 16)
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
        .overlay {
            if viewModel.isLoading && viewModel.participants.isEmpty && viewModel.clips.isEmpty {
                ProgressView("Loading...")
            }
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
private struct ContributorClipRow: View {
    let contributor: ContributorRow
    let onTapClip: (Clip) -> Void

    var body: some View {
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
                Button {
                    onTapClip(clip)
                } label: {
                    ZStack {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.toySurface)
                            .frame(width: 50, height: 66)

                        Image(systemName: "play.fill")
                            .font(.system(size: 16))
                            .foregroundColor(.toyTextSecondary)

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
                }
                .buttonStyle(.plain)
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

    private func formatDuration(_ seconds: Double) -> String {
        String(format: "%.1fs", seconds)
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
