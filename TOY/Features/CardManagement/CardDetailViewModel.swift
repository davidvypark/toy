import AVFoundation
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

    /// Loaded durations for clips where durationSeconds is nil in DB
    /// Key is clip ID, value is duration in seconds
    var loadedDurations: [UUID: Double] = [:]

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

            // Load durations for clips that don't have them in the database
            await loadMissingDurations()
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

    /// Gets the effective duration for a clip, using loaded duration if DB value is nil.
    /// - Parameter clip: The clip to get duration for
    /// - Returns: Duration in seconds, or nil if not available
    func effectiveDuration(for clip: Clip) -> Double? {
        if let dbDuration = clip.durationSeconds {
            return NSDecimalNumber(decimal: dbDuration).doubleValue
        }
        return loadedDurations[clip.id]
    }

    // MARK: - Private Methods

    /// Loads durations from video assets for clips that don't have duration in the database.
    private func loadMissingDurations() async {
        let clipsNeedingDuration = clips.filter { $0.durationSeconds == nil }

        guard !clipsNeedingDuration.isEmpty else {
            #if DEBUG
            print("[DURATION] All clips have duration in database")
            #endif
            return
        }

        #if DEBUG
        print("[DURATION] Loading duration for \(clipsNeedingDuration.count) clips")
        #endif

        // Load durations concurrently
        await withTaskGroup(of: (UUID, Double?).self) { group in
            for clip in clipsNeedingDuration {
                group.addTask {
                    do {
                        let signedURL = try await self.storageService.createSignedURL(path: clip.videoUrl)
                        let asset = AVAsset(url: signedURL)
                        let duration = try await asset.load(.duration)
                        let seconds = CMTimeGetSeconds(duration)

                        #if DEBUG
                        print("[DURATION] Loaded duration for clip \(clip.id): \(seconds)s")
                        #endif

                        return (clip.id, seconds.isNaN ? nil : seconds)
                    } catch {
                        #if DEBUG
                        print("[DURATION] Failed to load duration for clip \(clip.id): \(error)")
                        #endif
                        return (clip.id, nil)
                    }
                }
            }

            for await (clipId, duration) in group {
                if let duration {
                    loadedDurations[clipId] = duration
                }
            }
        }

        #if DEBUG
        print("[DURATION] Loaded \(loadedDurations.count) durations from video assets")
        #endif
    }
}
