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
