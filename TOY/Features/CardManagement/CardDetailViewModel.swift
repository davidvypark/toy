import Foundation
import SwiftUI
import TOYShared

/// ViewModel for the card detail/management screen.
/// Manages participant list, clips, and deletion operations.
@MainActor
@Observable
final class CardDetailViewModel {

    // MARK: - State

    var participants: [Participant] = []
    var clips: [Clip] = []
    var isLoading = false
    var errorMessage: String?

    // MARK: - Dependencies

    private let cardService = CardService()
    private let storageService = StorageService()

    // MARK: - Data Loading

    /// Loads participants and clips for a card in parallel.
    /// - Parameter cardId: The ID of the card to load data for
    func loadData(for cardId: UUID) async {
        isLoading = true
        errorMessage = nil

        do {
            #if DEBUG
            print("Loading data for card: \(cardId)")
            #endif

            // Fetch participants and clips in parallel
            async let fetchedParticipants = cardService.fetchParticipantsForCard(cardId: cardId)
            async let fetchedClips = cardService.fetchClipsForCard(cardId: cardId)

            participants = try await fetchedParticipants
            clips = try await fetchedClips

            #if DEBUG
            print("Loaded \(participants.count) participants and \(clips.count) clips")
            for clip in clips {
                print("[DURATION DEBUG] Clip \(clip.id): duration = \(String(describing: clip.durationSeconds))")
            }
            #endif
        } catch {
            #if DEBUG
            print("Failed to load card data: \(error)")
            #endif
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    // MARK: - Clip Operations

    /// Deletes a clip from storage and database.
    /// - Parameter clip: The clip to delete
    func deleteClip(_ clip: Clip) async {
        do {
            #if DEBUG
            print("Deleting clip: \(clip.id)")
            #endif

            try await cardService.deleteClip(clipId: clip.id, storagePath: clip.videoUrl)

            // Remove from local array on success
            clips.removeAll { $0.id == clip.id }

            #if DEBUG
            print("Clip deleted successfully")
            #endif
        } catch {
            #if DEBUG
            print("Failed to delete clip: \(error)")
            #endif
            errorMessage = error.localizedDescription
        }
    }

    /// Gets a signed URL for accessing a clip's video.
    /// - Parameter clip: The clip to get a URL for
    /// - Returns: A time-limited signed URL
    /// - Throws: UploadError if URL generation fails
    func getSignedURL(for clip: Clip) async throws -> URL {
        return try await storageService.createSignedURL(path: clip.videoUrl)
    }
}
