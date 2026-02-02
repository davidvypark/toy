import Foundation

// MARK: - Clip

/// Represents an individual video clip recorded by a participant.
public struct Clip: Codable, Identifiable, Sendable, Equatable {
    public let id: UUID
    public let cardId: UUID
    public let participantId: UUID
    public let videoUrl: String
    public let durationSeconds: Decimal?
    public let orderPosition: Int?
    public let status: String
    public let uploadedAt: Date?
    public let createdAt: Date

    public init(
        id: UUID,
        cardId: UUID,
        participantId: UUID,
        videoUrl: String,
        durationSeconds: Decimal? = nil,
        orderPosition: Int? = nil,
        status: String = "pending",
        uploadedAt: Date? = nil,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.cardId = cardId
        self.participantId = participantId
        self.videoUrl = videoUrl
        self.durationSeconds = durationSeconds
        self.orderPosition = orderPosition
        self.status = status
        self.uploadedAt = uploadedAt
        self.createdAt = createdAt
    }

    enum CodingKeys: String, CodingKey {
        case id
        case cardId = "card_id"
        case participantId = "participant_id"
        case videoUrl = "video_url"
        case durationSeconds = "duration_seconds"
        case orderPosition = "order_position"
        case status
        case uploadedAt = "uploaded_at"
        case createdAt = "created_at"
    }
}

// MARK: - NewClip

/// A struct for creating new clips (only includes insertable fields).
public struct NewClip: Encodable, Sendable {
    public let cardId: UUID
    public let participantId: UUID
    public let videoUrl: String
    public let durationSeconds: Decimal?
    public let orderPosition: Int
    public let status: String

    public init(
        cardId: UUID,
        participantId: UUID,
        videoUrl: String,
        durationSeconds: Decimal? = nil,
        orderPosition: Int,
        status: String = "uploaded"
    ) {
        self.cardId = cardId
        self.participantId = participantId
        self.videoUrl = videoUrl
        self.durationSeconds = durationSeconds
        self.orderPosition = orderPosition
        self.status = status
    }

    enum CodingKeys: String, CodingKey {
        case cardId = "card_id"
        case participantId = "participant_id"
        case videoUrl = "video_url"
        case durationSeconds = "duration_seconds"
        case orderPosition = "order_position"
        case status
    }
}
