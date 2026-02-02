import Foundation

// MARK: - Participant

/// Represents a participant invited to contribute to a card.
public struct Participant: Codable, Identifiable, Sendable, Equatable {
    public let id: UUID
    public let cardId: UUID
    public let userId: UUID?
    public let inviteToken: String
    public let email: String?
    public let status: String
    public let invitedAt: Date
    public let submittedAt: Date?

    public init(
        id: UUID,
        cardId: UUID,
        userId: UUID? = nil,
        inviteToken: String,
        email: String? = nil,
        status: String = "invited",
        invitedAt: Date = Date(),
        submittedAt: Date? = nil
    ) {
        self.id = id
        self.cardId = cardId
        self.userId = userId
        self.inviteToken = inviteToken
        self.email = email
        self.status = status
        self.invitedAt = invitedAt
        self.submittedAt = submittedAt
    }

    enum CodingKeys: String, CodingKey {
        case id
        case cardId = "card_id"
        case userId = "user_id"
        case inviteToken = "invite_token"
        case email
        case status
        case invitedAt = "invited_at"
        case submittedAt = "submitted_at"
    }
}
