import AVFoundation
import SwiftUI
import TOYShared

/// ViewModel for the recording screen.
@MainActor
public final class RecordingViewModel: ObservableObject {
    // MARK: - Published State

    @Published public var permissionStatus: PermissionStatus = .unknown
    @Published public var showPreview: Bool = false

    // MARK: - Dependencies

    public let recorder = VideoRecorder()

    // MARK: - Permission Status

    public enum PermissionStatus {
        case unknown
        case granted
        case denied
        case restricted
    }

    // MARK: - Initialization

    public init() {}

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
        // Will be wired to submission in Phase 3
        // For now, just mark as done
        guard case .completed(let url) = recorder.state else { return }
        print("Video confirmed at: \(url)")
    }

    // MARK: - Computed Properties

    public var canFinish: Bool {
        recorder.state.hasContent && !recorder.state.isRecording
    }
}
