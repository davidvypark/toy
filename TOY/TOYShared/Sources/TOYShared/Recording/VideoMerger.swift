import AVFoundation
import Foundation

public final class VideoMerger {

    public init() {}

    /// Merges multiple video clips into a single video file.
    /// - Parameter clipURLs: Array of URLs to video clips, in order
    /// - Returns: URL to the merged video file
    /// - Throws: RecordingError if merge fails
    public func mergeClips(_ clipURLs: [URL]) async throws -> URL {
        guard !clipURLs.isEmpty else {
            throw RecordingError.noClipsToMerge
        }

        // Single clip - no merge needed, just return it
        if clipURLs.count == 1 {
            return clipURLs[0]
        }

        let composition = AVMutableComposition()

        guard let videoTrack = composition.addMutableTrack(
            withMediaType: .video,
            preferredTrackID: kCMPersistentTrackID_Invalid
        ) else {
            throw RecordingError.exportFailed(underlying: nil)
        }

        guard let audioTrack = composition.addMutableTrack(
            withMediaType: .audio,
            preferredTrackID: kCMPersistentTrackID_Invalid
        ) else {
            throw RecordingError.exportFailed(underlying: nil)
        }

        var insertTime = CMTime.zero
        var firstTransform: CGAffineTransform?

        for clipURL in clipURLs {
            let asset = AVURLAsset(url: clipURL)

            // Load duration
            let duration = try await asset.load(.duration)
            let timeRange = CMTimeRange(start: .zero, duration: duration)

            // Insert video track
            if let sourceVideoTrack = try await asset.loadTracks(withMediaType: .video).first {
                try videoTrack.insertTimeRange(timeRange, of: sourceVideoTrack, at: insertTime)

                // Capture transform from first clip for consistent orientation
                if firstTransform == nil {
                    firstTransform = try await sourceVideoTrack.load(.preferredTransform)
                }
            }

            // Insert audio track
            if let sourceAudioTrack = try await asset.loadTracks(withMediaType: .audio).first {
                try audioTrack.insertTimeRange(timeRange, of: sourceAudioTrack, at: insertTime)
            }

            insertTime = CMTimeAdd(insertTime, duration)
        }

        // Apply first clip's transform for consistent orientation
        if let transform = firstTransform {
            videoTrack.preferredTransform = transform
        }

        // Create output URL in temp directory
        let outputURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("mov")

        // Export merged composition
        guard let exporter = AVAssetExportSession(
            asset: composition,
            presetName: AVAssetExportPreset1280x720
        ) else {
            throw RecordingError.exportFailed(underlying: nil)
        }

        exporter.outputURL = outputURL
        exporter.outputFileType = .mov
        exporter.shouldOptimizeForNetworkUse = true

        await exporter.export()

        switch exporter.status {
        case .completed:
            return outputURL
        case .failed:
            throw RecordingError.exportFailed(underlying: exporter.error)
        case .cancelled:
            throw RecordingError.exportFailed(underlying: nil)
        default:
            throw RecordingError.exportFailed(underlying: nil)
        }
    }

    /// Merges multiple video clips with progress reporting.
    /// - Parameters:
    ///   - clipURLs: Array of URLs to video clips, in order
    ///   - onProgress: Callback with progress value (0.0 to 1.0)
    /// - Returns: URL to the merged video file
    /// - Throws: RecordingError if merge fails
    public func mergeClipsWithProgress(
        _ clipURLs: [URL],
        onProgress: @escaping @Sendable (Float) -> Void
    ) async throws -> URL {
        guard !clipURLs.isEmpty else {
            throw RecordingError.noClipsToMerge
        }

        // Single clip - copy to output location (don't return original as it may be deleted)
        if clipURLs.count == 1 {
            let outputURL = FileManager.default.temporaryDirectory
                .appendingPathComponent(UUID().uuidString)
                .appendingPathExtension("mov")
            try FileManager.default.copyItem(at: clipURLs[0], to: outputURL)
            await MainActor.run { onProgress(1.0) }
            return outputURL
        }

        let composition = AVMutableComposition()

        guard let videoTrack = composition.addMutableTrack(
            withMediaType: .video,
            preferredTrackID: kCMPersistentTrackID_Invalid
        ) else {
            throw RecordingError.exportFailed(underlying: nil)
        }

        guard let audioTrack = composition.addMutableTrack(
            withMediaType: .audio,
            preferredTrackID: kCMPersistentTrackID_Invalid
        ) else {
            throw RecordingError.exportFailed(underlying: nil)
        }

        var insertTime = CMTime.zero
        var firstTransform: CGAffineTransform?

        for clipURL in clipURLs {
            let asset = AVURLAsset(url: clipURL)

            // Load duration
            let duration = try await asset.load(.duration)
            let timeRange = CMTimeRange(start: .zero, duration: duration)

            // Insert video track
            if let sourceVideoTrack = try await asset.loadTracks(withMediaType: .video).first {
                try videoTrack.insertTimeRange(timeRange, of: sourceVideoTrack, at: insertTime)

                // Capture transform from first clip for consistent orientation
                if firstTransform == nil {
                    firstTransform = try await sourceVideoTrack.load(.preferredTransform)
                }
            }

            // Insert audio track
            if let sourceAudioTrack = try await asset.loadTracks(withMediaType: .audio).first {
                try audioTrack.insertTimeRange(timeRange, of: sourceAudioTrack, at: insertTime)
            }

            insertTime = CMTimeAdd(insertTime, duration)
        }

        // Apply first clip's transform for consistent orientation
        if let transform = firstTransform {
            videoTrack.preferredTransform = transform
        }

        // Create output URL in temp directory
        let outputURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("mov")

        // Export merged composition
        guard let exporter = AVAssetExportSession(
            asset: composition,
            presetName: AVAssetExportPreset1280x720
        ) else {
            throw RecordingError.exportFailed(underlying: nil)
        }

        exporter.outputURL = outputURL
        exporter.outputFileType = .mov
        exporter.shouldOptimizeForNetworkUse = true

        // Start progress monitoring task
        let progressTask = Task {
            while !Task.isCancelled {
                await MainActor.run {
                    onProgress(exporter.progress)
                }
                try? await Task.sleep(nanoseconds: 100_000_000) // 0.1s
                if exporter.status == .completed || exporter.status == .failed || exporter.status == .cancelled {
                    break
                }
            }
        }

        await exporter.export()
        progressTask.cancel()

        // Final progress update
        await MainActor.run { onProgress(1.0) }

        switch exporter.status {
        case .completed:
            return outputURL
        case .failed:
            throw RecordingError.exportFailed(underlying: exporter.error)
        case .cancelled:
            throw RecordingError.exportFailed(underlying: nil)
        default:
            throw RecordingError.exportFailed(underlying: nil)
        }
    }

    /// Deletes clip files to free storage.
    /// - Parameter clipURLs: URLs of clips to delete
    public func deleteClips(_ clipURLs: [URL]) {
        for url in clipURLs {
            try? FileManager.default.removeItem(at: url)
        }
    }

    /// Calculates total duration of clips.
    /// - Parameter clipURLs: Array of clip URLs
    /// - Returns: Total duration in seconds
    public func totalDuration(of clipURLs: [URL]) async throws -> TimeInterval {
        var total: CMTime = .zero

        for url in clipURLs {
            let asset = AVURLAsset(url: url)
            let duration = try await asset.load(.duration)
            total = CMTimeAdd(total, duration)
        }

        return CMTimeGetSeconds(total)
    }
}
