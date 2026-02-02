import AVFoundation
import Foundation

public final class ClipWriter {
    private var assetWriter: AVAssetWriter?
    private var videoInput: AVAssetWriterInput?
    private var audioInput: AVAssetWriterInput?
    private var isWriting = false
    private var startTime: CMTime?

    public private(set) var outputURL: URL?

    public var duration: CMTime {
        guard let startTime, let writer = assetWriter else { return .zero }
        // Duration is tracked via the last sample buffer timestamp
        return .zero // Will be calculated from actual file after finish
    }

    public init() {}

    public func startWriting(to url: URL) throws {
        outputURL = url
        assetWriter = try AVAssetWriter(outputURL: url, fileType: .mov)

        // Video settings for H.264 720p 30fps
        // Capture is 1280x720 landscape, we keep those dimensions and use transform for portrait display
        let videoSettings: [String: Any] = [
            AVVideoCodecKey: AVVideoCodecType.h264,
            AVVideoWidthKey: 1280,  // Keep capture width
            AVVideoHeightKey: 720,  // Keep capture height
            AVVideoCompressionPropertiesKey: [
                AVVideoAverageBitRateKey: 2_000_000,
                AVVideoProfileLevelKey: AVVideoProfileLevelH264High41,
                AVVideoMaxKeyFrameIntervalKey: 30,
                AVVideoExpectedSourceFrameRateKey: 30
            ]
        ]

        videoInput = AVAssetWriterInput(mediaType: .video, outputSettings: videoSettings)
        videoInput?.expectsMediaDataInRealTime = true

        // Front camera transform for portrait display:
        // Rotate 90° counterclockwise and flip vertically for proper orientation
        videoInput?.transform = CGAffineTransform(rotationAngle: .pi / 2)
            .scaledBy(x: 1, y: -1)

        // Audio settings for AAC
        let audioSettings: [String: Any] = [
            AVFormatIDKey: kAudioFormatMPEG4AAC,
            AVSampleRateKey: 44100,
            AVNumberOfChannelsKey: 1,
            AVEncoderBitRateKey: 128_000
        ]

        audioInput = AVAssetWriterInput(mediaType: .audio, outputSettings: audioSettings)
        audioInput?.expectsMediaDataInRealTime = true

        if let videoInput, assetWriter?.canAdd(videoInput) == true {
            assetWriter?.add(videoInput)
        }

        if let audioInput, assetWriter?.canAdd(audioInput) == true {
            assetWriter?.add(audioInput)
        }

        isWriting = true
        startTime = nil
    }

    public func append(_ sampleBuffer: CMSampleBuffer, isVideo: Bool) {
        guard isWriting, let writer = assetWriter else { return }

        // Start writing on first sample
        if writer.status == .unknown {
            let timestamp = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
            writer.startWriting()
            writer.startSession(atSourceTime: timestamp)
            startTime = timestamp
        }

        guard writer.status == .writing else { return }

        let input = isVideo ? videoInput : audioInput
        if input?.isReadyForMoreMediaData == true {
            input?.append(sampleBuffer)
        }
    }

    public func finishWriting() async throws -> URL {
        guard let writer = assetWriter, let url = outputURL else {
            throw RecordingError.writerNotReady
        }

        guard isWriting else {
            throw RecordingError.writerNotReady
        }

        // Only mark as finished if the writer was actually started
        // (status is .writing). If still .unknown, no samples were written
        // and calling markAsFinished would crash.
        if writer.status == .writing {
            videoInput?.markAsFinished()
            audioInput?.markAsFinished()
        }

        await writer.finishWriting()

        isWriting = false

        if writer.status == .failed {
            throw RecordingError.writeFailed(underlying: writer.error)
        }

        return url
    }

    public func cancelWriting() {
        assetWriter?.cancelWriting()
        isWriting = false

        // Clean up temp file
        if let url = outputURL {
            try? FileManager.default.removeItem(at: url)
        }

        outputURL = nil
        assetWriter = nil
        videoInput = nil
        audioInput = nil
        startTime = nil
    }
}
