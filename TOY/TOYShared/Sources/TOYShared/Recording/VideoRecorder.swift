import AVFoundation
import Foundation

/// Coordinates multi-clip video recording with automatic time limit.
@MainActor
public final class VideoRecorder: ObservableObject {
    // MARK: - Published State

    @Published public private(set) var state: RecordingState = .idle
    @Published public private(set) var elapsedTime: TimeInterval = 0
    @Published public private(set) var isSessionReady: Bool = false

    // MARK: - Configuration

    public let maxDuration: TimeInterval = 7.0
    private let minimumClipDuration: TimeInterval = 0.5 // Discard accidental taps

    // MARK: - Dependencies

    public let captureSession: CaptureSession
    private let merger = VideoMerger()

    // MARK: - Internal State

    private var clipWriter: ClipWriter?
    private var clipURLs: [URL] = []
    private var currentClipStartTime: CMTime?
    private var accumulatedDuration: TimeInterval = 0
    private var recordingTimer: Timer?
    private var clipStartWallTime: TimeInterval = 0
    private var isFinishingClip: Bool = false

    // MARK: - Initialization

    public init() {
        self.captureSession = CaptureSession()
        captureSession.delegate = self
    }

    // MARK: - Session Management

    public func setupSession() async throws {
        try captureSession.configure()
        captureSession.start()
        isSessionReady = true
    }

    public func teardownSession() {
        captureSession.stop()
        isSessionReady = false
    }

    // MARK: - Recording Control

    /// Start recording (finger down)
    public func startRecording() {
        guard isSessionReady else { return } // Can't record without capture session
        guard state.canStartRecording else { return }
        guard !isFinishingClip else { return } // Wait for previous clip to finish
        guard accumulatedDuration < maxDuration else { return }

        // Create new clip writer
        let clipURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("mov")

        clipWriter = ClipWriter()
        do {
            try clipWriter?.startWriting(to: clipURL)
        } catch {
            state = .error(message: error.localizedDescription)
            return
        }

        currentClipStartTime = nil
        clipStartWallTime = CACurrentMediaTime()
        state = .recording

        // Start timer for UI updates
        startTimer()
    }

    /// Stop recording (finger up)
    public func stopRecording() {
        guard state.isRecording else { return }

        stopTimer()
        isFinishingClip = true

        // Calculate clip duration from wall clock (more reliable than async asset load)
        let clipDuration = currentClipDuration

        // Update state immediately so UI responds
        // Will be adjusted to .completed if max duration reached
        if clipURLs.isEmpty && clipDuration < minimumClipDuration {
            // Very short first tap - stay idle
            state = .idle
        } else {
            state = .paused
        }

        // Finish current clip asynchronously
        Task {
            await finishCurrentClip(estimatedDuration: clipDuration)
        }
    }

    /// Finish recording and merge clips
    public func finishAndMerge() async throws {
        // Stop any in-progress recording first
        if state.isRecording {
            stopTimer()
            await finishCurrentClip(estimatedDuration: currentClipDuration)
        }

        guard !clipURLs.isEmpty else {
            throw RecordingError.noClipsToMerge
        }

        let mergedURL = try await merger.mergeClips(clipURLs)
        state = .completed(videoURL: mergedURL)
    }

    /// Preview the merged video
    public func preview() async throws {
        guard case .completed(let videoURL) = state else { return }
        state = .previewing(videoURL: videoURL)
    }

    /// Start over - delete all clips and reset
    public func startOver() {
        stopTimer()
        clipWriter?.cancelWriting()
        clipWriter = nil
        isFinishingClip = false

        // Delete all temp clips
        merger.deleteClips(clipURLs)

        // Also delete merged video if exists
        if case .completed(let url) = state {
            try? FileManager.default.removeItem(at: url)
        }
        if case .previewing(let url) = state {
            try? FileManager.default.removeItem(at: url)
        }

        clipURLs = []
        accumulatedDuration = 0
        elapsedTime = 0
        currentClipStartTime = nil
        clipStartWallTime = 0
        state = .idle
    }

    // MARK: - Private Methods

    private func finishCurrentClip(estimatedDuration: TimeInterval) async {
        defer { isFinishingClip = false }

        guard let writer = clipWriter else {
            // No writer - ensure we're in a valid state
            if state == .recording {
                state = clipURLs.isEmpty ? .idle : .paused
            }
            return
        }

        do {
            let clipURL = try await writer.finishWriting()

            // Use estimated duration from wall clock (asset.load can fail for short clips)
            let clipDuration = estimatedDuration

            // Discard clips shorter than minimum (accidental taps)
            if clipDuration < minimumClipDuration {
                try? FileManager.default.removeItem(at: clipURL)
            } else {
                clipURLs.append(clipURL)
                accumulatedDuration += clipDuration
            }

            clipWriter = nil

            // Check if we've reached max duration
            if accumulatedDuration >= maxDuration {
                // Auto-finish
                let mergedURL = try await merger.mergeClips(clipURLs)
                state = .completed(videoURL: mergedURL)
            } else {
                // State was already set to .paused in stopRecording
                // Update to .idle if we discarded the clip and have no content
                if clipURLs.isEmpty {
                    state = .idle
                }
            }
        } catch {
            // On error, restore to a usable state
            clipWriter = nil
            state = clipURLs.isEmpty ? .idle : .paused
            print("Clip finish error: \(error.localizedDescription)")
        }
    }

    private func startTimer() {
        recordingTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self, self.state.isRecording else { return }
                self.elapsedTime = min(self.accumulatedDuration + self.currentClipDuration, self.maxDuration)

                // Auto-stop if we hit max duration
                if self.elapsedTime >= self.maxDuration {
                    self.stopRecording()
                }
            }
        }
    }

    private func stopTimer() {
        recordingTimer?.invalidate()
        recordingTimer = nil
    }

    private var currentClipDuration: TimeInterval {
        guard clipStartWallTime > 0 else { return 0 }
        return CACurrentMediaTime() - clipStartWallTime
    }

    // MARK: - Remaining Time

    public var remainingTime: TimeInterval {
        max(0, maxDuration - elapsedTime)
    }

    public var progress: Double {
        min(1.0, elapsedTime / maxDuration)
    }
}

// MARK: - CaptureSessionDelegate

extension VideoRecorder: CaptureSessionDelegate {
    nonisolated public func captureSession(
        _ session: CaptureSession,
        didOutput sampleBuffer: CMSampleBuffer,
        isVideo: Bool
    ) {
        // This is called on sessionQueue (background thread)
        Task { @MainActor in
            guard self.state.isRecording else { return }

            // Track start time for duration calculation
            if isVideo && self.currentClipStartTime == nil {
                self.currentClipStartTime = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
            }

            self.clipWriter?.append(sampleBuffer, isVideo: isVideo)
        }
    }
}
