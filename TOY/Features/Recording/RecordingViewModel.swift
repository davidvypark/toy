import AVFoundation
import Combine
import SwiftUI
import TOYShared

/// ViewModel for the recording screen.
@MainActor
public final class RecordingViewModel: ObservableObject {
    // MARK: - Published State

    @Published public var permissionStatus: PermissionStatus = .unknown
    @Published public var showPreview: Bool = false
    @Published public var uploadState: UploadState? = nil
    @Published public var uploadedPath: String? = nil
    @Published public var createdClip: Clip? = nil

    // MARK: - Card Context

    public var cardId: UUID?
    public var participantId: UUID?
    public var isHostClip: Bool

    // MARK: - Dependencies

    public let recorder = VideoRecorder()
    private var cancellables = Set<AnyCancellable>()
    private let storageService = StorageService()
    private let cardService = CardService()

    // MARK: - Upload State

    private var currentVideoURL: URL?
    private var uploadRetryCount = 0
    private let maxRetries = 3

    // MARK: - Permission Status

    public enum PermissionStatus {
        case unknown
        case granted
        case denied
        case restricted
    }

    // MARK: - Initialization

    public init(cardId: UUID? = nil, participantId: UUID? = nil, isHostClip: Bool = false) {
        self.cardId = cardId
        self.participantId = participantId
        self.isHostClip = isHostClip

        // Forward changes from nested ObservableObject to trigger view updates
        recorder.objectWillChange
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.objectWillChange.send()
            }
            .store(in: &cancellables)
    }

    // MARK: - Lifecycle

    public func onAppear() async {
        await checkAndRequestPermissions()
    }

    public func onDisappear() {
        recorder.teardownSession()
    }

    // MARK: - Permissions

    private func checkAndRequestPermissions() async {
        let cameraStatus = AVCaptureDevice.authorizationStatus(for: .video)
        let micStatus = AVCaptureDevice.authorizationStatus(for: .audio)

        // Check if already granted
        if cameraStatus == .authorized && micStatus == .authorized {
            permissionStatus = .granted
            await setupRecorder()
            return
        }

        // Check if restricted or denied
        if cameraStatus == .restricted || micStatus == .restricted {
            permissionStatus = .restricted
            return
        }

        if cameraStatus == .denied || micStatus == .denied {
            permissionStatus = .denied
            return
        }

        // Request permissions
        var cameraGranted = cameraStatus == .authorized
        var micGranted = micStatus == .authorized

        if cameraStatus == .notDetermined {
            cameraGranted = await AVCaptureDevice.requestAccess(for: .video)
        }

        if micStatus == .notDetermined {
            micGranted = await AVCaptureDevice.requestAccess(for: .audio)
        }

        if cameraGranted && micGranted {
            permissionStatus = .granted
            await setupRecorder()
        } else {
            permissionStatus = .denied
        }
    }

    private func setupRecorder() async {
        do {
            try await recorder.setupSession()
        } catch {
            // Handle setup error
            print("Failed to setup recorder: \(error)")
        }
    }

    // MARK: - Actions

    public func startRecording() {
        recorder.startRecording()
    }

    public func stopRecording() {
        recorder.stopRecording()
    }

    public func finishRecording() async {
        do {
            try await recorder.finishAndMerge()
            showPreview = true
        } catch {
            // Error is captured in recorder.state
        }
    }

    public func startOver() {
        showPreview = false
        recorder.startOver()
    }

    public func confirmVideo() {
        guard case .completed(let url) = recorder.state else { return }
        currentVideoURL = url
        uploadRetryCount = 0
        uploadState = .uploading
        Task {
            await performUpload()
        }
    }

    private func performUpload() async {
        guard let videoURL = currentVideoURL else {
            uploadState = .failed(error: "No video to upload")
            return
        }

        let clipId = UUID()

        do {
            // Calculate video duration before upload
            let duration = await getVideoDuration(url: videoURL)

            let path = try await storageService.uploadVideo(fileURL: videoURL, clipId: clipId)
            uploadedPath = path
            uploadState = .success(storagePath: path)
            print("Upload successful: \(path)")

            // Create clip record if we have card context
            if let cardId = cardId, let participantId = participantId {
                do {
                    // Host clip = orderPosition 0 (appears first in montage)
                    let orderPosition = isHostClip ? 0 : 1
                    let clip = try await cardService.createClip(
                        cardId: cardId,
                        participantId: participantId,
                        videoUrl: path,
                        durationSeconds: duration,
                        orderPosition: orderPosition,
                        status: "uploaded"
                    )
                    createdClip = clip

                    // If host clip, update card status to 'collecting'
                    if isHostClip {
                        try await cardService.updateCardStatus(cardId: cardId, status: "collecting")
                    }
                } catch {
                    // Best-effort: don't fail the upload if clip record fails
                    print("Failed to create clip record: \(error)")
                }
            }
        } catch {
            let message = (error as? UploadError)?.errorDescription ?? error.localizedDescription
            uploadState = .failed(error: message)
            print("Upload failed: \(error)")
        }
    }

    /// Gets the duration of a video file in seconds.
    /// - Parameter url: The local URL of the video file
    /// - Returns: Duration as Decimal, or nil if cannot be determined
    private func getVideoDuration(url: URL) async -> Decimal? {
        let asset = AVAsset(url: url)
        do {
            let duration = try await asset.load(.duration)
            let seconds = CMTimeGetSeconds(duration)
            guard seconds.isFinite && seconds > 0 else { return nil }
            // Round to 1 decimal place for cleaner display
            return Decimal(Double(round(seconds * 10) / 10))
        } catch {
            print("Failed to load video duration: \(error)")
            return nil
        }
    }

    public func retryUpload() {
        guard uploadRetryCount < maxRetries else {
            uploadState = .failed(error: "Maximum retries exceeded")
            return
        }

        uploadRetryCount += 1
        let delay = pow(2.0, Double(uploadRetryCount)) // 2s, 4s, 8s

        uploadState = .uploading
        Task {
            try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            await performUpload()
        }
    }

    /// Dismisses the upload overlay. Returns true if upload was successful (caller should navigate away).
    @discardableResult
    public func dismissUpload() -> Bool {
        let wasSuccess: Bool
        if case .success = uploadState {
            wasSuccess = true
        } else {
            wasSuccess = false
        }
        uploadState = nil
        return wasSuccess
    }

    // MARK: - Computed Properties

    public var canFinish: Bool {
        recorder.state.hasContent && !recorder.state.isRecording
    }
}
