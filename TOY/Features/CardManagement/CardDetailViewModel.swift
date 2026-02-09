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

    /// Cached signed URLs for clips (valid for 1 hour)
    /// Key is clip ID, value is signed URL
    var cachedSignedURLs: [UUID: URL] = [:]

    /// Cached profiles for participants
    /// Key is user ID, value is profile data (displayName, avatarURL)
    var participantProfiles: [UUID: (displayName: String?, avatarURL: URL?)] = [:]

    // MARK: - Montage Player Cache

    /// Cached montage player for instant re-opening
    var montagePlayer: AVQueuePlayer?
    var montageSignedURLs: [URL] = []
    var isMontageReady = false

    // MARK: - Dependencies

    private let cardService = CardService()
    private let storageService = StorageService()

    // MARK: - Data Loading

    /// The host's user ID (needed for profile fetching)
    private var hostId: UUID?

    /// Loads participants and clips for a card.
    /// - Parameters:
    ///   - cardId: The ID of the card to load data for
    ///   - hostId: The host's user ID (for profile fetching)
    ///   - initialClips: Optional pre-fetched clips from HomeView to avoid re-fetching
    ///   - initialProfiles: Optional pre-fetched profiles from HomeView for instant display
    func loadData(
        for cardId: UUID,
        hostId: UUID? = nil,
        initialClips: [Clip]? = nil,
        initialProfiles: [UUID: (displayName: String?, avatarURL: URL?)]? = nil
    ) async {
        self.hostId = hostId
        isLoading = true
        errorMessage = nil

        // Use initial profiles immediately if provided (eliminates "Contributor" flash)
        if let initialProfiles {
            for (userId, profile) in initialProfiles {
                participantProfiles[userId] = profile
            }
        }

        do {
            #if DEBUG
            print("Loading data for card: \(cardId)")
            #endif

            // Use initial clips if provided, otherwise fetch
            if let initialClips {
                clips = initialClips
                // Only fetch participants
                participants = try await cardService.fetchParticipantsForCard(cardId: cardId)
            } else {
                // Fetch participants and clips in parallel
                async let fetchedParticipants = cardService.fetchParticipantsForCard(cardId: cardId)
                async let fetchedClips = cardService.fetchClipsForCard(cardId: cardId)

                participants = try await fetchedParticipants
                clips = try await fetchedClips
            }

            #if DEBUG
            print("Loaded \(participants.count) participants and \(clips.count) clips")
            #endif

        } catch {
            if !Task.isCancelled {
                #if DEBUG
                print("Failed to load card data: \(error)")
                #endif
                errorMessage = error.localizedDescription
            }
        }

        isLoading = false

        // Pre-fetch signed URLs in background
        Task {
            await prefetchSignedURLs()
        }
        // Only fetch profiles if we don't have initial profiles
        if initialProfiles == nil {
            Task {
                await fetchParticipantProfiles()
            }
        }
    }

    /// Fetches profile data for all users who have clips (using clip.participantId which IS the user ID)
    private func fetchParticipantProfiles() async {
        // Get unique user IDs from clips (participantId = userId for logged-in users)
        var userIds = Set(clips.map(\.participantId)).filter { participantProfiles[$0] == nil }

        // Also include host if not already covered
        if let hostId, participantProfiles[hostId] == nil {
            userIds.insert(hostId)
        }

        guard !userIds.isEmpty else { return }

        do {
            let profiles = try await cardService.fetchProfiles(userIds: Array(userIds))
            for (userId, profile) in profiles {
                participantProfiles[userId] = profile
            }
        } catch {
            #if DEBUG
            print("[PROFILES] Failed to fetch profiles: \(error)")
            #endif
        }
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
    /// Uses cached URL if available, otherwise fetches and caches.
    /// - Parameter clip: The clip to get a URL for
    /// - Returns: A time-limited signed URL
    /// - Throws: UploadError if URL generation fails
    func getSignedURL(for clip: Clip) async throws -> URL {
        // Return cached URL if available
        if let cached = cachedSignedURLs[clip.id] {
            #if DEBUG
            print("🔗 Using cached signed URL for clip \(clip.id)")
            #endif
            return cached
        }

        // Fetch and cache
        let url = try await storageService.createSignedURL(path: clip.videoUrl)
        cachedSignedURLs[clip.id] = url
        return url
    }

    /// Gets the duration for a clip from the database.
    /// - Parameter clip: The clip to get duration for
    /// - Returns: Duration in seconds, or nil if not stored in DB
    func effectiveDuration(for clip: Clip) -> Double? {
        guard let dbDuration = clip.durationSeconds else {
            return nil  // Don't try to load - just show "—" in UI
        }
        return NSDecimalNumber(decimal: dbDuration).doubleValue
    }

    // MARK: - Tier Status

    #if DEBUG
    /// Set to a number to spoof clip count for tier testing.
    /// Set to nil for normal behavior. NEVER commit with a non-nil value.
    static let debugClipCount: Int? = 6 // e.g. 7, 12, 50, 150
    #endif

    /// The effective clip count for tier calculations and display.
    var effectiveClipCount: Int {
        #if DEBUG
        if let override = Self.debugClipCount { return override }
        #endif
        return clips.count
    }

    /// The minimum tier required to publish this card based on clip count
    func requiredTier(for card: Card) -> CardTier {
        CardTier.requiredTier(for: effectiveClipCount)
    }

    /// The tier this card currently has (from database maxParticipants)
    func purchasedTier(for card: Card) -> CardTier {
        CardTier.fromMaxParticipants(card.maxParticipants)
    }

    /// Whether the card needs a tier upgrade before publishing
    func needsUpgradeToPublish(for card: Card) -> Bool {
        requiredTier(for: card) > purchasedTier(for: card)
    }

    // MARK: - Private Methods

    /// Pre-fetches signed URLs for all clips concurrently.
    /// This speeds up thumbnail loading and preview opening.
    private func prefetchSignedURLs() async {
        // Only fetch URLs we don't already have cached
        let clipsNeedingURLs = clips.filter { cachedSignedURLs[$0.id] == nil }

        guard !clipsNeedingURLs.isEmpty else {
            #if DEBUG
            print("[URL CACHE] All clips already have cached URLs")
            #endif
            return
        }

        #if DEBUG
        print("[URL CACHE] Pre-fetching URLs for \(clipsNeedingURLs.count) clips")
        #endif

        await withTaskGroup(of: (UUID, URL?).self) { group in
            for clip in clipsNeedingURLs {
                group.addTask {
                    do {
                        let url = try await self.storageService.createSignedURL(path: clip.videoUrl)
                        return (clip.id, url)
                    } catch {
                        #if DEBUG
                        print("[URL CACHE] Failed to fetch URL for clip \(clip.id): \(error)")
                        #endif
                        return (clip.id, nil)
                    }
                }
            }

            for await (clipId, url) in group {
                if let url {
                    cachedSignedURLs[clipId] = url
                }
            }
        }

        #if DEBUG
        print("[URL CACHE] Cached \(cachedSignedURLs.count) signed URLs")
        #endif
    }
}
