import AVFoundation
import Foundation
#if canImport(UIKit)
import UIKit
#endif

public final class VideoMerger {

    /// Brand text overlay for final videos
    private let overlayText = "Thinking Of You"

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
            // Use options to reduce memory footprint for large montages
            let asset = AVURLAsset(url: clipURL, options: [
                AVURLAssetPreferPreciseDurationAndTimingKey: false
            ])

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

        // Determine video size (9:16 vertical)
        let videoSize = CGSize(width: 720, height: 1280)

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

        // No text overlay for individual clips - overlay only added to final montage

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
            // Use options to reduce memory footprint for large montages
            let asset = AVURLAsset(url: clipURL, options: [
                AVURLAssetPreferPreciseDurationAndTimingKey: false
            ])

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

        // Determine video size (9:16 vertical)
        let videoSize = CGSize(width: 720, height: 1280)

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

        // Add text overlay video composition
        #if canImport(UIKit)
        let videoComposition = createVideoCompositionWithOverlay(
            for: composition,
            videoTrack: videoTrack,
            videoSize: videoSize,
            duration: composition.duration
        )
        exporter.videoComposition = videoComposition
        #endif

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

    // MARK: - Text Overlay

    #if canImport(UIKit)
    /// Creates a video composition with "Thinking Of You" text overlay at the bottom.
    private func createVideoCompositionWithOverlay(
        for composition: AVMutableComposition,
        videoTrack: AVMutableCompositionTrack,
        videoSize: CGSize,
        duration: CMTime
    ) -> AVMutableVideoComposition {
        // Create the video layer (where the actual video content goes)
        let videoLayer = CALayer()
        videoLayer.frame = CGRect(origin: .zero, size: videoSize)

        // Create the text overlay layer
        let textLayer = createTextOverlayLayer(size: videoSize)

        // Create parent layer that composites video and text
        let parentLayer = CALayer()
        parentLayer.frame = CGRect(origin: .zero, size: videoSize)
        parentLayer.addSublayer(videoLayer)
        parentLayer.addSublayer(textLayer)

        // Create video composition
        let videoComposition = AVMutableVideoComposition()
        videoComposition.renderSize = videoSize
        videoComposition.frameDuration = CMTime(value: 1, timescale: 30)

        // Create layer instruction for the video track
        let instruction = AVMutableVideoCompositionInstruction()
        instruction.timeRange = CMTimeRange(start: .zero, duration: duration)

        let layerInstruction = AVMutableVideoCompositionLayerInstruction(assetTrack: videoTrack)

        // Apply transform to fit video into the render size
        // Videos are recorded at 720x1280 (portrait), so we need to handle the transform
        let transform = videoTrack.preferredTransform
        layerInstruction.setTransform(transform, at: .zero)

        instruction.layerInstructions = [layerInstruction]
        videoComposition.instructions = [instruction]

        // Apply the animation tool to composite video + text layers
        videoComposition.animationTool = AVVideoCompositionCoreAnimationTool(
            postProcessingAsVideoLayer: videoLayer,
            in: parentLayer
        )

        return videoComposition
    }

    /// Creates a CATextLayer with the brand overlay text.
    private func createTextOverlayLayer(size: CGSize) -> CATextLayer {
        let textLayer = CATextLayer()

        // Font size relative to video width (approximately 7%)
        let fontSize: CGFloat = size.width * 0.07

        // Try to use DM Serif Display (same as home header), fall back to system font
        let font = UIFont(name: "DMSerifDisplay-Regular", size: fontSize)
            ?? UIFont.systemFont(ofSize: fontSize, weight: .regular)

        // Create attributed string with white fill (no stroke)
        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: UIColor.white
        ]

        let attributedString = NSAttributedString(string: overlayText, attributes: attributes)
        textLayer.string = attributedString

        // Subtle shadow for readability on light backgrounds
        textLayer.shadowColor = UIColor.black.cgColor
        textLayer.shadowOffset = CGSize(width: 0, height: 2)
        textLayer.shadowOpacity = 0.3
        textLayer.shadowRadius = 4

        // Calculate text size for positioning
        let textSize = attributedString.size()

        // Position at bottom center with padding (8% from bottom)
        let bottomPadding = size.height * 0.08
        let x = (size.width - textSize.width) / 2
        let y = bottomPadding

        textLayer.frame = CGRect(x: x, y: y, width: textSize.width + 10, height: textSize.height + 4)
        textLayer.alignmentMode = .center
        textLayer.contentsScale = UIScreen.main.scale

        // Disable implicit animations
        textLayer.actions = ["contents": NSNull(), "bounds": NSNull(), "position": NSNull()]

        return textLayer
    }
    #endif
}
