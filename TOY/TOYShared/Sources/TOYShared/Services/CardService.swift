import Foundation
import Supabase

// MARK: - Card Error

/// Errors that can occur during card operations
public enum CardError: LocalizedError, Sendable {
    case createFailed(String)
    case fetchFailed(String)
    case updateFailed(String)
    case clipCreateFailed(String)
    case deleteFailed(String)

    public var errorDescription: String? {
        switch self {
        case .createFailed(let message):
            return "Failed to create card: \(message)"
        case .fetchFailed(let message):
            return "Failed to fetch cards: \(message)"
        case .updateFailed(let message):
            return "Failed to update card: \(message)"
        case .clipCreateFailed(let message):
            return "Failed to create clip: \(message)"
        case .deleteFailed(let message):
            return "Failed to delete: \(message)"
        }
    }
}

// MARK: - Card Service

/// Actor-based service for card and clip CRUD operations.
/// Uses actor isolation for thread safety with async operations.
public actor CardService {

    public init() {}

    // MARK: - Card Operations

    /// Creates a new card in the database.
    /// - Parameters:
    ///   - title: The title of the card (e.g., "Happy Birthday Sarah!")
    ///   - recipientName: The name of the recipient
    ///   - occasion: The occasion type (optional)
    ///   - hostId: The ID of the user creating the card
    /// - Returns: The created Card
    /// - Throws: `CardError.createFailed` if creation fails
    public func createCard(
        title: String,
        recipientName: String,
        occasion: String?,
        hostId: UUID
    ) async throws -> Card {
        let newCard = NewCard(
            hostId: hostId,
            title: title,
            recipientName: recipientName,
            occasion: occasion,
            shareToken: UUID().uuidString.lowercased()
        )

        do {
            let card: Card = try await supabase
                .from("cards")
                .insert(newCard)
                .select()
                .single()
                .execute()
                .value

            #if DEBUG
            print("📝 Created card: \(card.title) (id: \(card.id))")
            #endif

            return card
        } catch {
            throw CardError.createFailed(error.localizedDescription)
        }
    }

    /// Fetches all cards for a given host, ordered by creation date (newest first).
    /// - Parameter hostId: The ID of the host user
    /// - Returns: Array of Cards
    /// - Throws: `CardError.fetchFailed` if fetch fails
    public func fetchCardsForHost(hostId: UUID) async throws -> [Card] {
        do {
            let cards: [Card] = try await supabase
                .from("cards")
                .select()
                .eq("host_id", value: hostId)
                .order("created_at", ascending: false)
                .execute()
                .value

            #if DEBUG
            print("📋 Fetched \(cards.count) cards for host \(hostId)")
            #endif

            return cards
        } catch {
            throw CardError.fetchFailed(error.localizedDescription)
        }
    }

    /// Fetches a card by its ID.
    /// - Parameter cardId: The ID of the card
    /// - Returns: The Card if found
    /// - Throws: `CardError.fetchFailed` if not found or fetch fails
    public func fetchCardById(cardId: UUID) async throws -> Card {
        do {
            let card: Card = try await supabase
                .from("cards")
                .select()
                .eq("id", value: cardId)
                .single()
                .execute()
                .value

            #if DEBUG
            print("📋 Fetched card by ID: \(card.title)")
            #endif

            return card
        } catch {
            throw CardError.fetchFailed(error.localizedDescription)
        }
    }

    /// Fetches a card by its share token (for unauthenticated access).
    /// - Parameter shareToken: The unique share token from the invite URL
    /// - Returns: The Card if found
    /// - Throws: `CardError.fetchFailed` if not found or fetch fails
    public func fetchCardByShareToken(shareToken: String) async throws -> Card {
        do {
            let card: Card = try await supabase
                .from("cards")
                .select()
                .eq("share_token", value: shareToken)
                .single()
                .execute()
                .value

            #if DEBUG
            print("📋 Fetched card by shareToken: \(card.title)")
            #endif

            return card
        } catch {
            throw CardError.fetchFailed(error.localizedDescription)
        }
    }

    /// Updates the status of a card.
    /// - Parameters:
    ///   - cardId: The ID of the card to update
    ///   - status: The new status (draft, collecting, stitching, published)
    /// - Throws: `CardError.updateFailed` if update fails
    public func updateCardStatus(cardId: UUID, status: String) async throws {
        do {
            try await supabase
                .from("cards")
                .update(["status": status])
                .eq("id", value: cardId)
                .execute()

            #if DEBUG
            print("✅ Updated card \(cardId) status to: \(status)")
            #endif
        } catch {
            throw CardError.updateFailed(error.localizedDescription)
        }
    }

    /// Publishes a card with the final montage video URL.
    /// - Parameters:
    ///   - cardId: The ID of the card to publish
    ///   - videoUrl: The storage path of the uploaded montage
    /// - Throws: `CardError.updateFailed` if update fails
    public func publishCard(cardId: UUID, videoUrl: String) async throws {
        do {
            try await supabase
                .from("cards")
                .update([
                    "status": "published",
                    "video_url": videoUrl,
                    "published_at": ISO8601DateFormatter().string(from: Date())
                ])
                .eq("id", value: cardId)
                .execute()

            #if DEBUG
            print("✅ Published card \(cardId) with video: \(videoUrl)")
            #endif
        } catch {
            throw CardError.updateFailed(error.localizedDescription)
        }
    }

    /// Updates a card's maximum participant limit (for upgrades).
    /// - Parameters:
    ///   - cardId: The ID of the card to update
    ///   - maxParticipants: The new maximum participant limit (999 = unlimited)
    /// - Throws: `CardError.updateFailed` if update fails
    public func updateCardMaxParticipants(cardId: UUID, maxParticipants: Int) async throws {
        do {
            try await supabase
                .from("cards")
                .update(["max_participants": maxParticipants])
                .eq("id", value: cardId)
                .execute()

            #if DEBUG
            print("✅ Updated card \(cardId) maxParticipants to: \(maxParticipants)")
            #endif
        } catch {
            throw CardError.updateFailed(error.localizedDescription)
        }
    }

    /// Permanently deletes a card and all associated data (clips, participants).
    /// - Parameter cardId: The ID of the card to delete
    /// - Throws: `CardError.deleteFailed` if deletion fails
    public func deleteCard(cardId: UUID) async throws {
        // Delete associated clips from storage first
        let clips = try await fetchClipsForCard(cardId: cardId)
        let bucket = supabase.storage.from("clips")

        for clip in clips {
            do {
                try await bucket.remove(paths: [clip.videoUrl])
            } catch {
                #if DEBUG
                print("⚠️ Storage delete failed for clip: \(error.localizedDescription)")
                #endif
            }
        }

        // Database cascade will handle clips and participants
        do {
            try await supabase
                .from("cards")
                .delete()
                .eq("id", value: cardId)
                .execute()

            #if DEBUG
            print("🗑️ Deleted card: \(cardId)")
            #endif
        } catch {
            throw CardError.deleteFailed(error.localizedDescription)
        }
    }

    // MARK: - Clip Operations

    /// Creates a new clip record in the database.
    /// - Parameters:
    ///   - cardId: The ID of the card this clip belongs to
    ///   - participantId: The ID of the participant who recorded the clip
    ///   - videoUrl: The storage URL of the uploaded video
    ///   - thumbnailUrl: The storage URL of the pre-generated thumbnail (optional)
    ///   - durationSeconds: The duration of the clip in seconds (optional)
    ///   - orderPosition: The position in the montage order
    ///   - status: The clip status (default: "uploaded")
    /// - Returns: The created Clip
    /// - Throws: `CardError.clipCreateFailed` if creation fails
    public func createClip(
        cardId: UUID,
        participantId: UUID,
        videoUrl: String,
        thumbnailUrl: String? = nil,
        durationSeconds: Decimal?,
        orderPosition: Int,
        status: String = "uploaded"
    ) async throws -> Clip {
        let newClip = NewClip(
            cardId: cardId,
            participantId: participantId,
            videoUrl: videoUrl,
            thumbnailUrl: thumbnailUrl,
            durationSeconds: durationSeconds,
            orderPosition: orderPosition,
            status: status
        )

        do {
            let clip: Clip = try await supabase
                .from("clips")
                .insert(newClip)
                .select()
                .single()
                .execute()
                .value

            #if DEBUG
            print("🎬 Created clip for card \(cardId) (id: \(clip.id))")
            #endif

            return clip
        } catch {
            throw CardError.clipCreateFailed(error.localizedDescription)
        }
    }

    // MARK: - Participant Operations

    /// Fetches all participants for a given card, ordered by invitation date.
    /// - Parameter cardId: The ID of the card
    /// - Returns: Array of Participants
    /// - Throws: `CardError.fetchFailed` if fetch fails
    public func fetchParticipantsForCard(cardId: UUID) async throws -> [Participant] {
        do {
            let participants: [Participant] = try await supabase
                .from("participants")
                .select()
                .eq("card_id", value: cardId)
                .order("invited_at", ascending: true)
                .execute()
                .value

            #if DEBUG
            print("👥 Fetched \(participants.count) participants for card \(cardId)")
            #endif

            return participants
        } catch {
            throw CardError.fetchFailed(error.localizedDescription)
        }
    }

    /// Fetches all clips for a given card, ordered by position.
    /// - Parameter cardId: The ID of the card
    /// - Returns: Array of Clips ordered by order_position
    /// - Throws: `CardError.fetchFailed` if fetch fails
    public func fetchClipsForCard(cardId: UUID) async throws -> [Clip] {
        do {
            let clips: [Clip] = try await supabase
                .from("clips")
                .select()
                .eq("card_id", value: cardId)
                .order("order_position", ascending: true)
                .execute()
                .value

            #if DEBUG
            print("🎬 Fetched \(clips.count) clips for card \(cardId)")
            #endif

            return clips
        } catch {
            throw CardError.fetchFailed(error.localizedDescription)
        }
    }

    /// Fetches profile data for multiple users.
    /// - Parameter userIds: Array of user IDs to fetch profiles for
    /// - Returns: Dictionary mapping user ID to profile data (displayName, avatarURL)
    /// - Throws: `CardError.fetchFailed` if fetch fails
    public func fetchProfiles(userIds: [UUID]) async throws -> [UUID: (displayName: String?, avatarURL: URL?)] {
        guard !userIds.isEmpty else { return [:] }

        struct ProfileRow: Decodable {
            let id: UUID
            let displayName: String?
            let avatarUrl: String?

            enum CodingKeys: String, CodingKey {
                case id
                case displayName = "display_name"
                case avatarUrl = "avatar_url"
            }
        }

        do {
            let profiles: [ProfileRow] = try await supabase
                .from("profiles")
                .select("id, display_name, avatar_url")
                .in("id", values: userIds.map(\.uuidString))
                .execute()
                .value

            #if DEBUG
            print("👤 Fetched \(profiles.count) profiles")
            #endif

            var result: [UUID: (displayName: String?, avatarURL: URL?)] = [:]
            for profile in profiles {
                result[profile.id] = (
                    displayName: profile.displayName,
                    avatarURL: profile.avatarUrl.flatMap { URL(string: $0) }
                )
            }

            return result
        } catch {
            throw CardError.fetchFailed(error.localizedDescription)
        }
    }

    /// Joins a card as a participant without recording yet (for "Save for Later").
    /// - Parameters:
    ///   - userId: The ID of the user joining
    ///   - shareToken: The share token from the invite link
    ///   - email: The user's email (optional, for display purposes)
    ///   - displayName: The user's display name (optional, for display purposes)
    /// - Returns: The card that was joined
    /// - Throws: `CardError.fetchFailed` if card not found or join fails
    public func joinCard(userId: UUID, shareToken: String, email: String? = nil, displayName: String? = nil) async throws -> Card {
        // Fetch the card
        let card = try await fetchCardByShareToken(shareToken: shareToken)

        // Check if already a participant
        let existing: [Participant] = try await supabase
            .from("participants")
            .select()
            .eq("card_id", value: card.id)
            .eq("user_id", value: userId)
            .execute()
            .value

        if existing.isEmpty {
            // Create participant record with user info for display
            var newParticipant: [String: String] = [
                "card_id": card.id.uuidString,
                "user_id": userId.uuidString,
                "invite_token": UUID().uuidString,
                "status": "viewed"
            ]
            if let email {
                newParticipant["email"] = email
            }
            try await supabase
                .from("participants")
                .insert(newParticipant)
                .execute()

            #if DEBUG
            print("👤 User \(userId) joined card \(card.id)")
            #endif
        }

        return card
    }

    /// Fetches cards where the user is a participant (not host), along with their submission status.
    /// - Parameter userId: The ID of the user
    /// - Returns: Array of tuples containing the card and whether the user has submitted a clip
    /// - Throws: `CardError.fetchFailed` if fetch fails
    public func fetchParticipatingCards(userId: UUID) async throws -> [(card: Card, hasSubmitted: Bool)] {
        do {
            // First get all participants for this user
            let participants: [Participant] = try await supabase
                .from("participants")
                .select()
                .eq("user_id", value: userId)
                .execute()
                .value

            guard !participants.isEmpty else { return [] }

            // Get unique card IDs
            let cardIds = participants.map(\.cardId)

            // Fetch those cards (excluding where user is host)
            let cards: [Card] = try await supabase
                .from("cards")
                .select()
                .in("id", values: cardIds)
                .neq("host_id", value: userId)
                .neq("status", value: "published")  // Only in-progress cards
                .order("created_at", ascending: false)
                .execute()
                .value

            // For each card, check if user has submitted a clip
            var results: [(card: Card, hasSubmitted: Bool)] = []
            for card in cards {
                let clips: [Clip] = try await supabase
                    .from("clips")
                    .select()
                    .eq("card_id", value: card.id)
                    .eq("participant_id", value: userId)
                    .execute()
                    .value

                results.append((card: card, hasSubmitted: !clips.isEmpty))
            }

            #if DEBUG
            print("📋 Fetched \(results.count) participating cards for user \(userId)")
            #endif

            return results
        } catch {
            throw CardError.fetchFailed(error.localizedDescription)
        }
    }

    /// Fetches published cards where the user was a participant (not host).
    /// - Parameter userId: The ID of the user
    /// - Returns: Array of published Cards the user participated in
    /// - Throws: `CardError.fetchFailed` if fetch fails
    public func fetchPublishedParticipatingCards(userId: UUID) async throws -> [Card] {
        do {
            // Get all participants for this user
            let participants: [Participant] = try await supabase
                .from("participants")
                .select()
                .eq("user_id", value: userId)
                .execute()
                .value

            guard !participants.isEmpty else { return [] }

            let cardIds = participants.map(\.cardId)

            // Fetch published cards (excluding where user is host)
            let cards: [Card] = try await supabase
                .from("cards")
                .select()
                .in("id", values: cardIds)
                .neq("host_id", value: userId)
                .eq("status", value: "published")
                .order("published_at", ascending: false)
                .execute()
                .value

            #if DEBUG
            print("📋 Fetched \(cards.count) published participating cards for user \(userId)")
            #endif

            return cards
        } catch {
            throw CardError.fetchFailed(error.localizedDescription)
        }
    }

    /// Deletes a clip from storage and database.
    /// - Parameters:
    ///   - clipId: The ID of the clip to delete
    ///   - storagePath: The storage path of the video file
    /// - Throws: `CardError.deleteFailed` if database delete fails
    public func deleteClip(clipId: UUID, storagePath: String) async throws {
        // First, attempt to delete from storage (file may already be deleted)
        let bucket = supabase.storage.from("clips")
        do {
            try await bucket.remove(paths: [storagePath])
            #if DEBUG
            print("🗑️ Deleted storage file: \(storagePath)")
            #endif
        } catch {
            // Log but continue - file may already be deleted
            #if DEBUG
            print("⚠️ Storage delete failed (may already be deleted): \(error.localizedDescription)")
            #endif
        }

        // Then delete from database
        do {
            try await supabase
                .from("clips")
                .delete()
                .eq("id", value: clipId)
                .execute()

            #if DEBUG
            print("🗑️ Deleted clip record: \(clipId)")
            #endif
        } catch {
            throw CardError.deleteFailed(error.localizedDescription)
        }
    }
}
