import SwiftUI
import TOYShared

/// Success view shown after card is published
struct PublishedCardView: View {
    let card: Card
    let videoURL: URL
    let onDone: () -> Void

    @Environment(\.dismiss) private var dismiss

    /// The shareable recipient link
    private var recipientURL: URL? {
        guard let token = card.shareToken else { return nil }
        // Recipient link (different from invite link pattern)
        return URL(string: "https://toy.app/watch/\(token)")
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 32) {
                Spacer()

                // Success icon
                ZStack {
                    Circle()
                        .fill(Color.toyPrimary.opacity(0.15))
                        .frame(width: 120, height: 120)

                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 64))
                        .foregroundColor(.toyPrimary)
                }

                // Success message
                VStack(spacing: 8) {
                    TOYLabel("Card Published!", style: .title)
                    TOYLabel(
                        "Your montage for \(card.recipientName) is ready to share",
                        style: .body,
                        color: .toyTextSecondary
                    )
                    .multilineTextAlignment(.center)
                }
                .padding(.horizontal, 32)

                // Stats
                VStack(spacing: 4) {
                    TOYLabel("\(card.title)", style: .headline)
                    if let url = recipientURL {
                        Text(url.absoluteString)
                            .font(.caption)
                            .foregroundColor(.toyTextSecondary)
                            .lineLimit(1)
                    }
                }
                .padding()
                .background(Color.toySurface)
                .cornerRadius(12)
                .padding(.horizontal)

                Spacer()

                // Action buttons
                VStack(spacing: 12) {
                    if let url = recipientURL {
                        ShareLink(
                            item: url,
                            subject: Text("A video message for \(card.recipientName)"),
                            message: Text("Someone made a special video card for you!")
                        ) {
                            HStack {
                                Image(systemName: "square.and.arrow.up")
                                Text("Share with \(card.recipientName)")
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(Color.toyPrimary)
                            .foregroundColor(.white)
                            .cornerRadius(12)
                        }
                    }

                    TOYButton("Done", style: .text) {
                        onDone()
                    }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 32)
            }
            .background(Color.toyBackground)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        onDone()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.toyTextSecondary)
                    }
                }
            }
        }
    }
}

// MARK: - Preview

#Preview {
    PublishedCardView(
        card: Card(
            id: UUID(),
            hostId: UUID(),
            title: "Happy Birthday Sarah!",
            recipientName: "Sarah",
            status: "published",
            shareToken: "abc123-test-token"
        ),
        videoURL: URL(string: "https://example.com/video.mov")!
    ) {
        print("Done tapped")
    }
}
