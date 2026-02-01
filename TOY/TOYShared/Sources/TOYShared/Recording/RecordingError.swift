import Foundation

public enum RecordingError: LocalizedError {
    case cameraUnavailable
    case microphoneUnavailable
    case cannotAddInput
    case cannotAddOutput
    case sessionNotRunning
    case writerNotReady
    case writeFailed(underlying: Error?)
    case exportFailed(underlying: Error?)
    case noClipsToMerge
    case permissionDenied(mediaType: String)

    public var errorDescription: String? {
        switch self {
        case .cameraUnavailable:
            return "Camera is not available"
        case .microphoneUnavailable:
            return "Microphone is not available"
        case .cannotAddInput:
            return "Cannot add camera input to capture session"
        case .cannotAddOutput:
            return "Cannot add output to capture session"
        case .sessionNotRunning:
            return "Capture session is not running"
        case .writerNotReady:
            return "Video writer is not ready"
        case .writeFailed(let error):
            return "Failed to write video: \(error?.localizedDescription ?? "unknown error")"
        case .exportFailed(let error):
            return "Failed to export video: \(error?.localizedDescription ?? "unknown error")"
        case .noClipsToMerge:
            return "No clips available to merge"
        case .permissionDenied(let mediaType):
            return "Permission denied for \(mediaType)"
        }
    }
}
