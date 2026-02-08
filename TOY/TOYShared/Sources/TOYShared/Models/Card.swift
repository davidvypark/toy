import Foundation

// MARK: - Card

/// Represents a group video greeting card created by a host.
public struct Card: Codable, Identifiable, Sendable, Equatable, Hashable {
    public let id: UUID
    public let hostId: UUID
    public let title: String
    public let recipientName: String
    public let occasion: String?
    public let status: String
    public let publishedAt: Date?
    public let videoUrl: String?
    public let shareToken: String?
    public let maxParticipants: Int
    public let createdAt: Date
    public let updatedAt: Date

    public init(
        id: UUID,
        hostId: UUID,
        title: String,
        recipientName: String,
        occasion: String? = nil,
        status: String = "draft",
        publishedAt: Date? = nil,
        videoUrl: String? = nil,
        shareToken: String? = nil,
        /// Maximum number of participants. New cards default to 5 (free tier). Legacy cards may have 8 (grandfathered).
        maxParticipants: Int = 5,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.hostId = hostId
        self.title = title
        self.recipientName = recipientName
        self.occasion = occasion
        self.status = status
        self.publishedAt = publishedAt
        self.videoUrl = videoUrl
        self.shareToken = shareToken
        self.maxParticipants = maxParticipants
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    enum CodingKeys: String, CodingKey {
        case id
        case hostId = "host_id"
        case title
        case recipientName = "recipient_name"
        case occasion
        case status
        case publishedAt = "published_at"
        case videoUrl = "video_url"
        case shareToken = "share_token"
        case maxParticipants = "max_participants"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

// MARK: - NewCard

/// A struct for creating new cards (only includes insertable fields).
public struct NewCard: Encodable, Sendable {
    public let hostId: UUID
    public let title: String
    public let recipientName: String
    public let occasion: String?
    public let shareToken: String

    public init(
        hostId: UUID,
        title: String,
        recipientName: String,
        occasion: String? = nil,
        shareToken: String
    ) {
        self.hostId = hostId
        self.title = title
        self.recipientName = recipientName
        self.occasion = occasion
        self.shareToken = shareToken
    }

    enum CodingKeys: String, CodingKey {
        case hostId = "host_id"
        case title
        case recipientName = "recipient_name"
        case occasion
        case shareToken = "share_token"
    }
}
