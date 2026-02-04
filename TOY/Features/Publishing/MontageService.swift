import AVFoundation
import Foundation
import TOYShared

/// Errors that can occur during montage generation
enum MontageError: LocalizedError {
    case noClips
    case downloadFailed(String)
    case stitchingFailed(String)

    var errorDescription: String? {
        switch self {
        case .noClips:
            return "No clips available to create montage"
        case .downloadFailed(let message):
            return "Failed to download clip: \(message)"
        case .stitchingFailed(let message):
            return "Failed to stitch video: \(message)"
        }
    }
}

/// Progress state for montage generation
struct MontageProgress: Sendable {
    enum Phase: Sendable {
        case downloading(current: Int, total: Int)
        case stitching(progress: Float)
    }

    let phase: Phase

    var overallProgress: Float {
        switch phase {
        case .downloading(let current, let total):
            // Download is 40% of total progress
            return Float(current) / Float(total) * 0.4
        case .stitching(let progress):
            // Stitching is 60% of total progress (starts at 40%)
            return 0.4 + progress * 0.6
        }
    }
}

/// Service that orchestrates montage generation: download clips, stitch, return local URL.
/// Does NOT handle upload - that's the caller's responsibility.
actor MontageService {
    private let storageService = StorageService()
    private let videoMerger = VideoMerger()

    /// Generates a montage from clips, ordered with host first then chronological.
    /// - Parameters:
    ///   - clips: Array of clips to stitch
    ///   - hostId: The host's user ID (their clip appears first)
    ///   - onProgress: Progress callback
    /// - Returns: Local URL to the stitched montage file
    /// - Throws: MontageError if generation fails
    func generateMontage(
        clips: [Clip],
        hostId: UUID,
        onProgress: (@Sendable (MontageProgress) -> Void)? = nil
    ) async throws -> URL {
        guard !clips.isEmpty else {
            throw MontageError.noClips
        }

        // 1. Sort clips: host first, then by orderPosition/createdAt
        let sortedClips = sortClipsForMontage(clips, hostId: hostId)

        // 2. Download clips to temp directory
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("montage-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)

        var localURLs: [URL] = []
        for (index, clip) in sortedClips.enumerated() {
            onProgress?(.init(phase: .downloading(current: index, total: sortedClips.count)))

            let localURL = try await downloadClip(clip, to: tempDir)
            localURLs.append(localURL)

            #if DEBUG
            print("Downloaded clip \(index + 1)/\(sortedClips.count): \(clip.id)")
            #endif
        }

        // Final download progress
        onProgress?(.init(phase: .downloading(current: sortedClips.count, total: sortedClips.count)))

        // 3. Stitch using VideoMerger
        let montageURL: URL
        do {
            montageURL = try await videoMerger.mergeClipsWithProgress(localURLs) { progress in
                onProgress?(.init(phase: .stitching(progress: progress)))
            }
        } catch {
            throw MontageError.stitchingFailed(error.localizedDescription)
        }

        // 4. Cleanup temp clip files (keep montage)
        for url in localURLs {
            try? FileManager.default.removeItem(at: url)
        }
        try? FileManager.default.removeItem(at: tempDir)

        #if DEBUG
        print("Montage generated at: \(montageURL)")
        #endif

        return montageURL
    }

    /// Generates a montage with parallel downloads for faster processing.
    /// Clips should already be sorted (host first).
    /// - Parameters:
    ///   - clips: Array of clips to stitch (pre-sorted)
    ///   - hostId: The host's user ID
    ///   - onProgress: Progress callback
    /// - Returns: Local URL to the stitched montage file
    /// - Throws: MontageError if generation fails
    func generateMontageParallel(
        clips: [Clip],
        hostId: UUID,
        onProgress: (@Sendable (MontageProgress) -> Void)? = nil
    ) async throws -> URL {
        guard !clips.isEmpty else {
            throw MontageError.noClips
        }

        // 1. Create temp directory
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("montage-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)

        // 2. Download all clips in parallel
        onProgress?(.init(phase: .downloading(current: 0, total: clips.count)))

        let downloadResults = await withTaskGroup(of: (Int, URL?, Error?).self) { group in
            for (index, clip) in clips.enumerated() {
                group.addTask { [self] in
                    do {
                        let localURL = try await self.downloadClip(clip, to: tempDir)
                        return (index, localURL, nil)
                    } catch {
                        return (index, nil, error)
                    }
                }
            }

            var results: [(Int, URL?, Error?)] = []
            for await result in group {
                results.append(result)
                // Update progress as each download completes
                let completedCount = results.count
                onProgress?(.init(phase: .downloading(current: completedCount, total: clips.count)))
            }
            return results.sorted { $0.0 < $1.0 }
        }

        // Check for download errors and collect URLs in order
        var localURLs: [URL] = []
        for (index, url, error) in downloadResults {
            if let error {
                throw MontageError.downloadFailed("Clip \(index + 1): \(error.localizedDescription)")
            }
            guard let url else {
                throw MontageError.downloadFailed("Clip \(index + 1): No URL returned")
            }
            localURLs.append(url)
        }

        #if DEBUG
        print("Downloaded \(localURLs.count) clips in parallel")
        #endif

        // 3. Stitch using VideoMerger
        let montageURL: URL
        do {
            montageURL = try await videoMerger.mergeClipsWithProgress(localURLs) { progress in
                onProgress?(.init(phase: .stitching(progress: progress)))
            }
        } catch {
            throw MontageError.stitchingFailed(error.localizedDescription)
        }

        // 4. Cleanup temp clip files (keep montage)
        for url in localURLs {
            try? FileManager.default.removeItem(at: url)
        }
        try? FileManager.default.removeItem(at: tempDir)

        #if DEBUG
        print("Montage generated at: \(montageURL)")
        #endif

        return montageURL
    }

    // MARK: - Private Helpers

    /// Sorts clips with host first, then by orderPosition, then by createdAt
    private func sortClipsForMontage(_ clips: [Clip], hostId: UUID) -> [Clip] {
        // Host clip first (identified by participantId == hostId per HOST-001)
        let hostClip = clips.first { $0.participantId == hostId }

        // Remaining clips sorted by orderPosition, then createdAt
        let participantClips = clips
            .filter { $0.participantId != hostId }
            .sorted { clip1, clip2 in
                // Sort by orderPosition if both have it
                if let pos1 = clip1.orderPosition, let pos2 = clip2.orderPosition {
                    if pos1 != pos2 { return pos1 < pos2 }
                }
                // Fall back to createdAt
                return clip1.createdAt < clip2.createdAt
            }

        return [hostClip].compactMap { $0 } + participantClips
    }

    /// Downloads a clip from Supabase storage to local temp directory
    private func downloadClip(_ clip: Clip, to directory: URL) async throws -> URL {
        // Get signed URL
        let signedURL: URL
        do {
            signedURL = try await storageService.createSignedURL(path: clip.videoUrl)
        } catch {
            throw MontageError.downloadFailed("Could not get signed URL: \(error.localizedDescription)")
        }

        // Download to local file
        let localURL = directory.appendingPathComponent("\(clip.id).mov")

        let (tempURL, response) = try await URLSession.shared.download(from: signedURL)

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw MontageError.downloadFailed("HTTP error downloading clip")
        }

        // Move to our temp directory
        if FileManager.default.fileExists(atPath: localURL.path) {
            try FileManager.default.removeItem(at: localURL)
        }
        try FileManager.default.moveItem(at: tempURL, to: localURL)

        return localURL
    }
}
