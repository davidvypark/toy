import Foundation

/// State machine for multi-clip video recording.
public enum RecordingState: Equatable {
    /// Ready to record, no clips captured yet
    case idle

    /// Currently capturing video (finger down)
    case recording

    /// Between clips, finger up, under 7 seconds total
    case paused

    /// 7 seconds reached or user manually finished
    case completed(videoURL: URL)

    /// Playing back merged video before submission
    case previewing(videoURL: URL)

    /// Something went wrong
    case error(message: String)

    public static func == (lhs: RecordingState, rhs: RecordingState) -> Bool {
        switch (lhs, rhs) {
        case (.idle, .idle):
            return true
        case (.recording, .recording):
            return true
        case (.paused, .paused):
            return true
        case (.completed(let lhsURL), .completed(let rhsURL)):
            return lhsURL == rhsURL
        case (.previewing(let lhsURL), .previewing(let rhsURL)):
            return lhsURL == rhsURL
        case (.error(let lhsMsg), .error(let rhsMsg)):
            return lhsMsg == rhsMsg
        default:
            return false
        }
    }
}

extension RecordingState {
    /// Whether recording can start (finger down)
    public var canStartRecording: Bool {
        switch self {
        case .idle, .paused:
            return true
        default:
            return false
        }
    }

    /// Whether recording is in progress
    public var isRecording: Bool {
        if case .recording = self { return true }
        return false
    }

    /// Whether user has recorded any content
    public var hasContent: Bool {
        switch self {
        case .paused, .completed, .previewing:
            return true
        default:
            return false
        }
    }
}
