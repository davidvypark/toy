import SwiftUI
import TOYShared

/// Success view shown after card is published
struct PublishedCardView: View {
    let card: Card
    let videoURL: URL
    let onDone: () -> Void

    @Environment(\.dismiss) private var dismiss

    private var recipientURL: URL? {
        guard let token = card.shareToken else { return nil }
        return URL(string: "https://sendtoycard.com/watch/\(token)")
    }

    var body: some View {
        NavigationStack {
            ZStack {
                TOYBackground()

                VStack(spacing: TOYSpacing.xl) {
                    Spacer()

                    // Success message - type-forward
                    VStack(alignment: .leading, spacing: TOYSpacing.md) {
                        Text("Card\nPublished")
                            .font(.toyTitle())
                            .foregroundColor(.toyText)
                            .lineSpacing(-4)

                        Text("Your montage for \(card.recipientName) is ready to share.")
                            .font(.toyBody())
                            .foregroundColor(.toyTextSecondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    // Card info
                    VStack(alignment: .leading, spacing: TOYSpacing.xs) {
                        Text(card.title)
                            .font(.toyHeadline())
                            .foregroundColor(.toyText)

                        if let url = recipientURL {
                            Text(url.absoluteString)
                                .font(.toyCaption())
                                .foregroundColor(.toyTextSecondary)
                                .lineLimit(1)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(TOYSpacing.lg)
                    .overlay(
                        Rectangle()
                            .stroke(Color.toyDivider, lineWidth: 1)
                    )

                    Spacer()

                    // Action buttons
                    VStack(spacing: TOYSpacing.md) {
                        if let url = recipientURL {
                            ShareLink(
                                item: url,
                                subject: Text("A video message for \(card.recipientName)"),
                                message: Text("Someone made a special video card for you!")
                            ) {
                                HStack(spacing: TOYSpacing.sm) {
                                    Image(systemName: "square.and.arrow.up")
                                    Text("Share with \(card.recipientName)")
                                }
                                .font(.toyBodyMedium())
                                .foregroundColor(.toyBackground)
                                .frame(maxWidth: .infinity)
                                .frame(height: TOYSpacing.buttonHeight)
                                .background(Color.toyText)
                            }
                        }

                        TOYButton("Done", style: .text) {
                            onDone()
                        }
                    }
                    .padding(.bottom, TOYSpacing.xl)
                }
                .padding(.horizontal, TOYSpacing.lg)
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        onDone()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 16, weight: .medium))
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
    ) {}
}
