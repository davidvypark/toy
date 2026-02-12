import SwiftUI
import TOYShared

/// The celebration view shown after a host successfully creates a card and records their intro clip.
struct CardCreatedView: View {

    // MARK: - Properties

    let card: Card
    let onDone: () -> Void

    @State private var showNotificationPrompt = false
    @State private var hasRequestedNotifications = false

    // MARK: - Body

    var body: some View {
        ZStack {
            TOYBackground()

            VStack(spacing: TOYSpacing.xl) {
                Spacer()

                // Success header - minimal, type-forward
                VStack(alignment: .leading, spacing: TOYSpacing.md) {
                    Text("Card\nCreated")
                        .font(.toyTitle())
                        .foregroundColor(.toyText)
                        .lineSpacing(-4)

                    Text("Now invite friends and family to record their messages for \(card.recipientName).")
                        .font(.toyBody())
                        .foregroundColor(.toyTextSecondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                // Card details summary
                VStack(alignment: .leading, spacing: TOYSpacing.xs) {
                    Text(card.title)
                        .font(.toyHeadline())
                        .foregroundColor(.toyText)

                    Text("For \(card.recipientName)")
                        .font(.toySubheadline())
                        .foregroundColor(.toyTextSecondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(TOYSpacing.lg)
                .background(
                    Rectangle()
                        .stroke(Color.toyDivider, lineWidth: 1)
                )

                Spacer()

                // ShareLink button - primary CTA
                if let inviteURL = inviteURL(for: card) {
                    ShareLink(
                        item: "Record up to a 7 second video message for \(card.recipientName)\n\(inviteURL.absoluteString)",
                        subject: Text("Join my TOY card!")
                    ) {
                        HStack(spacing: TOYSpacing.sm) {
                            Image(systemName: "square.and.arrow.up")
                            Text("Share Invite Link")
                        }
                        .font(.toyBodyMedium())
                        .foregroundColor(.toyBackground)
                        .frame(maxWidth: .infinity)
                        .frame(height: TOYSpacing.buttonHeight)
                        .background(
                            RoundedRectangle(cornerRadius: TOYSpacing.cornerRadius)
                                .fill(Color.toyText)
                        )
                    }
                }

                // Notification prompt - shown if permission not yet requested
                if showNotificationPrompt && !hasRequestedNotifications {
                    notificationPromptView
                }

                // Done button - secondary
                TOYButton("Done", style: .text) {
                    onDone()
                }
                .padding(.bottom, TOYSpacing.lg)
            }
            .padding(.horizontal, TOYSpacing.lg)
            .task {
                // Check if we should show notification prompt
                showNotificationPrompt = await NotificationService.shared.needsPermissionRequest()
            }
        }
    }

    // MARK: - Notification Prompt

    private var notificationPromptView: some View {
        VStack(spacing: TOYSpacing.md) {
            HStack(spacing: TOYSpacing.sm) {
                Image(systemName: "bell.fill")
                    .foregroundColor(.toyText)
                Text("Get notified when people submit clips")
                    .font(.toyBody())
                    .foregroundColor(.toyText)
            }

            Button {
                Task {
                    hasRequestedNotifications = true
                    _ = await NotificationService.shared.requestPermissionForDirector()
                }
            } label: {
                Text("Enable Notifications")
                    .font(.toyBodyMedium())
                    .foregroundColor(.toyTextSecondary)
                    .underline()
            }
        }
        .padding(TOYSpacing.md)
        .frame(maxWidth: .infinity)
        .background(
            Rectangle()
                .stroke(Color.toyDivider, lineWidth: 1)
        )
    }

    // MARK: - Helpers

    private func inviteURL(for card: Card) -> URL? {
        guard let token = card.shareToken else { return nil }
        return URL(string: "https://sendtoycard.com/card/\(token)")
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
