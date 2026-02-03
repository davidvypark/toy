import SwiftUI
import TOYShared

/// A row component displaying a participant's status in a card.
struct ParticipantRow: View {
    let participant: Participant

    var body: some View {
        HStack(spacing: TOYSpacing.md) {
            // Avatar
            Circle()
                .stroke(Color.toyDivider, lineWidth: 1)
                .frame(width: 40, height: 40)
                .overlay {
                    Text(String((participant.email ?? "G").prefix(1)).uppercased())
                        .font(.toySubheadline())
                        .foregroundColor(.toyTextSecondary)
                }

            // Name and status
            VStack(alignment: .leading, spacing: TOYSpacing.xs) {
                Text(participant.email ?? "Invited Guest")
                    .font(.toyBody())
                    .foregroundColor(.toyText)

                Text(statusText)
                    .font(.toyCaption())
                    .foregroundColor(.toyTextSecondary)
            }

            Spacer()

            // Checkmark for submitted status
            if participant.status == "submitted" {
                Image(systemName: "checkmark")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.toyText)
            }
        }
        .padding(.vertical, TOYSpacing.sm)
    }

    private var statusText: String {
        switch participant.status {
        case "invited": return "Waiting"
        case "viewed": return "Viewed"
        case "recording": return "Recording..."
        case "submitted": return "Submitted"
        default: return participant.status
        }
    }
}

// MARK: - Preview

#Preview("Participant Statuses") {
    VStack(spacing: 0) {
        ParticipantRow(participant: Participant(
            id: UUID(),
            cardId: UUID(),
            inviteToken: "abc123",
            email: "friend@example.com",
            status: "invited"
        ))
        Divider()
        ParticipantRow(participant: Participant(
            id: UUID(),
            cardId: UUID(),
            inviteToken: "def456",
            email: "colleague@example.com",
            status: "submitted"
        ))
    }
    .padding()
    .toyBackground()
}
