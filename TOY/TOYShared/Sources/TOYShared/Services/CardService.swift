import Foundation
import Supabase

// MARK: - Card Error

/// Errors that can occur during card operations
public enum CardError: LocalizedError, Sendable {
    case createFailed(String)
    case fetchFailed(String)
    case updateFailed(String)
    case clipCreateFailed(String)

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

    // MARK: - Clip Operations

    /// Creates a new clip record in the database.
    /// - Parameters:
    ///   - cardId: The ID of the card this clip belongs to
    ///   - participantId: The ID of the participant who recorded the clip
    ///   - videoUrl: The storage URL of the uploaded video
    ///   - durationSeconds: The duration of the clip in seconds (optional)
    ///   - orderPosition: The position in the montage order
    ///   - status: The clip status (default: "uploaded")
    /// - Returns: The created Clip
    /// - Throws: `CardError.clipCreateFailed` if creation fails
    public func createClip(
        cardId: UUID,
        participantId: UUID,
        videoUrl: String,
        durationSeconds: Decimal?,
        orderPosition: Int,
        status: String = "uploaded"
    ) async throws -> Clip {
        let newClip = NewClip(
            cardId: cardId,
            participantId: participantId,
            videoUrl: videoUrl,
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
}
