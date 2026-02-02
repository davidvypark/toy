import SwiftUI
import TOYShared

/// The main card detail/management view for hosts.
/// Displays card info, participant list, and clips with preview capability.
struct CardDetailView: View {
    let card: Card

    @State private var viewModel = CardDetailViewModel()
    @State private var selectedClip: Clip?
    @State private var showError = false

    var body: some View {
        List {
            // Card info section
            Section {
                VStack(alignment: .leading, spacing: 8) {
                    TOYLabel(card.title, style: .headline)

                    HStack {
                        TOYLabel("For: ", style: .body, color: .toyTextSecondary)
                        TOYLabel(card.recipientName, style: .body)
                    }
                }
                .padding(.vertical, 4)
            }

            // Participants section
            Section {
                if viewModel.participants.isEmpty && !viewModel.isLoading {
                    HStack {
                        Spacer()
                        VStack(spacing: 8) {
                            Image(systemName: "person.2.slash")
                                .font(.system(size: 32))
                                .foregroundColor(.toyTextSecondary)
                            TOYLabel("No participants yet", style: .body, color: .toyTextSecondary)
                        }
                        .padding(.vertical, 24)
                        Spacer()
                    }
                } else {
                    ForEach(viewModel.participants) { participant in
                        ParticipantRow(participant: participant)
                    }
                }
            } header: {
                TOYLabel("Participants", style: .caption)
            }

            // Clips section
            Section {
                if viewModel.clips.isEmpty && !viewModel.isLoading {
                    HStack {
                        Spacer()
                        VStack(spacing: 8) {
                            Image(systemName: "film.stack")
                                .font(.system(size: 32))
                                .foregroundColor(.toyTextSecondary)
                            TOYLabel("No clips submitted", style: .body, color: .toyTextSecondary)
                        }
                        .padding(.vertical, 24)
                        Spacer()
                    }
                } else {
                    ForEach(viewModel.clips) { clip in
                        ClipRow(clip: clip)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                selectedClip = clip
                            }
                    }
                }
            } header: {
                TOYLabel("Clips (\(viewModel.clips.count))", style: .caption)
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

// MARK: - Clip Row

/// A row component displaying a clip's info with preview indication.
private struct ClipRow: View {
    let clip: Clip

    var body: some View {
        HStack(spacing: 12) {
            // Video thumbnail placeholder
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.toySurface)
                .frame(width: 60, height: 80)
                .overlay {
                    Image(systemName: "play.fill")
                        .font(.system(size: 20))
                        .foregroundColor(.toyTextSecondary)
                }

            // Clip info
            VStack(alignment: .leading, spacing: 4) {
                TOYLabel(statusText, style: .body)

                if let duration = clip.durationSeconds {
                    TOYLabel(
                        "\(String(format: "%.1f", NSDecimalNumber(decimal: duration).doubleValue))s",
                        style: .caption,
                        color: .toyTextSecondary
                    )
                }
            }

            Spacer()

            // Chevron
            Image(systemName: "chevron.right")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.toyTextSecondary)
        }
        .padding(.vertical, 4)
    }

    private var statusText: String {
        switch clip.status {
        case "uploaded":
            return "Ready"
        case "processing":
            return "Processing..."
        case "transcoded":
            return "Transcoded"
        default:
            return clip.status.capitalized
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
                status: "collecting"
            )
        )
    }
}
