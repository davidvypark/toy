import SwiftUI
import TOYShared

/// A row component displaying a participant's status in a card.
struct ParticipantRow: View {
    let participant: Participant

    var body: some View {
        HStack(spacing: 12) {
            // Avatar placeholder
            Circle()
                .fill(Color.toySurface)
                .frame(width: 40, height: 40)
                .overlay {
                    Image(systemName: "person.fill")
                        .foregroundColor(.toyTextSecondary)
                }

            // Name and status
            VStack(alignment: .leading, spacing: 2) {
                TOYLabel(
                    participant.email ?? "Invited Guest",
                    style: .body
                )

                TOYLabel(
                    statusText,
                    style: .caption,
                    color: statusColor
                )
            }

            Spacer()

            // Checkmark for submitted status
            if participant.status == "submitted" {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
                    .font(.system(size: 20))
            }
        }
        .padding(.vertical, 4)
    }

    // MARK: - Private

    /// Maps status to human-readable text
    private var statusText: String {
        switch participant.status {
        case "invited":
            return "Waiting for response"
        case "viewed":
            return "Viewed invitation"
        case "recording":
            return "Recording in progress"
        case "submitted":
            return "Clip submitted"
        default:
            return participant.status
        }
    }

    /// Maps status to color
    private var statusColor: Color {
        switch participant.status {
        case "submitted":
            return .green
        case "recording":
            return .toyPrimary
        default:
            return .toyTextSecondary
        }
    }
}

// MARK: - Preview

#Preview("Participant Statuses") {
    List {
        ParticipantRow(participant: Participant(
            id: UUID(),
            cardId: UUID(),
            inviteToken: "abc123",
            email: "friend@example.com",
            status: "invited"
        ))

        ParticipantRow(participant: Participant(
            id: UUID(),
            cardId: UUID(),
            inviteToken: "def456",
            email: "colleague@example.com",
            status: "viewed"
        ))

        ParticipantRow(participant: Participant(
            id: UUID(),
            cardId: UUID(),
            inviteToken: "ghi789",
            email: "family@example.com",
            status: "recording"
        ))

        ParticipantRow(participant: Participant(
            id: UUID(),
            cardId: UUID(),
            inviteToken: "jkl012",
            email: "bestfriend@example.com",
            status: "submitted"
        ))

        ParticipantRow(participant: Participant(
            id: UUID(),
            cardId: UUID(),
            inviteToken: "mno345",
            status: "invited"
        ))
    }
}
