import Foundation
import Auth

/// Represents an authenticated user in the app.
public struct User: Identifiable, Codable, Sendable, Equatable {
    public let id: UUID
    public let email: String?
    public let displayName: String?
    public let avatarURL: URL?
    public let createdAt: Date

    public init(
        id: UUID,
        email: String?,
        displayName: String? = nil,
        avatarURL: URL? = nil,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.email = email
        self.displayName = displayName
        self.avatarURL = avatarURL
        self.createdAt = createdAt
    }

    /// Creates a User from Supabase auth user
    public init(from authUser: Auth.User) {
        self.id = authUser.id
        self.email = authUser.email
        self.displayName = authUser.userMetadata["display_name"]?.stringValue
        self.avatarURL = authUser.userMetadata["avatar_url"]?.stringValue.flatMap { URL(string: $0) }
        self.createdAt = authUser.createdAt
    }
}

// MARK: - Convenience

public extension User {
    /// Display name or email prefix for UI
    var displayNameOrEmail: String {
        if let name = displayName, !name.isEmpty {
            return name
        }
        if let email = email {
            return email.components(separatedBy: "@").first ?? email
        }
        return "User"
    }
}
