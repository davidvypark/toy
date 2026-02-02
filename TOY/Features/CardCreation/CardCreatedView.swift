import SwiftUI
import TOYShared

/// The celebration view shown after a host successfully creates a card and records their intro clip.
/// Provides a ShareLink for inviting participants to record their messages.
struct CardCreatedView: View {

    // MARK: - Properties

    let card: Card
    let onDone: () -> Void

    // MARK: - Body

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            // Success header
            VStack(spacing: 16) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 80))
                    .foregroundColor(.toyPrimary)

                TOYLabel.largeTitle("Card Created!")

                TOYLabel(
                    "Now invite friends and family to record their messages for \(card.recipientName)",
                    style: .body,
                    color: .toyTextSecondary
                )
                .multilineTextAlignment(.center)
            }

            // Card details summary
            VStack(alignment: .leading, spacing: 8) {
                TOYLabel(card.title, style: .headline)
                TOYLabel("For: \(card.recipientName)", style: .subheadline, color: .toyTextSecondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(16)
            .background(Color.toySurface)
            .cornerRadius(12)

            Spacer()

            // ShareLink button
            if let inviteURL = inviteURL(for: card) {
                ShareLink(
                    item: inviteURL,
                    subject: Text("Join my TOY card!"),
                    message: Text("Record a video message for \(card.recipientName)")
                ) {
                    Label("Share Invite Link", systemImage: "square.and.arrow.up")
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.toyPrimary)
                        .cornerRadius(12)
                }
                .padding(.top, 24)
            }

            // Done button
            TOYButton("Done", style: .secondary, size: .large) {
                onDone()
            }

            Spacer()
                .frame(height: 20)
        }
        .padding(.horizontal, 24)
        .background(Color.toyBackground)
    }

    // MARK: - Helpers

    /// Generates the invite URL for participants to join the card.
    /// Uses the placeholder domain per LINK-001 decision.
    private func inviteURL(for card: Card) -> URL? {
        guard let token = card.shareToken else { return nil }
        return URL(string: "https://toy.app/card/\(token)")
    }
}

// MARK: - Preview

#Preview {
    CardCreatedView(
        card: Card(
            id: UUID(),
            hostId: UUID(),
            title: "Happy Birthday Sarah!",
            recipientName: "Sarah",
            shareToken: "abc123-test-token"
        ),
        onDone: { print("Done tapped") }
    )
}
