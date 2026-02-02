import SwiftUI
import TOYShared

/// States for the upload progress view.
public enum UploadState {
    case uploading
    case success(storagePath: String)
    case failed(error: String)
}

/// Full-screen overlay showing upload progress.
public struct UploadProgressView: View {
    let state: UploadState
    let onRetry: () -> Void
    let onDismiss: () -> Void

    public init(
        state: UploadState,
        onRetry: @escaping () -> Void,
        onDismiss: @escaping () -> Void
    ) {
        self.state = state
        self.onRetry = onRetry
        self.onDismiss = onDismiss
    }

    public var body: some View {
        ZStack {
            // Semi-transparent background
            Color.black.opacity(0.6)
                .ignoresSafeArea()

            // Content card
            VStack(spacing: 24) {
                switch state {
                case .uploading:
                    ProgressView()
                        .scaleEffect(1.5)
                        .tint(.toyPrimary)
                    TOYLabel("Uploading...", style: .headline)

                case .success:
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 48))
                        .foregroundStyle(.green)
                    TOYLabel("Uploaded!", style: .headline)
                    TOYButton("Done", style: .primary, size: .large, action: onDismiss)
                        .frame(maxWidth: 200)

                case .failed(let error):
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 48))
                        .foregroundStyle(.red)
                    TOYLabel("Upload Failed", style: .headline)
                    TOYLabel(error, style: .body)
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.toyTextSecondary)
                    HStack(spacing: 16) {
                        TOYButton("Cancel", style: .secondary, size: .medium, action: onDismiss)
                        TOYButton("Retry", style: .primary, size: .medium, action: onRetry)
                    }
                }
            }
            .padding(32)
            .background(Color.toySurface)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .shadow(radius: 20)
            .padding(32)
        }
    }
}

#Preview("Uploading") {
    UploadProgressView(
        state: .uploading,
        onRetry: {},
        onDismiss: {}
    )
}

#Preview("Success") {
    UploadProgressView(
        state: .success(storagePath: "abc123.mov"),
        onRetry: {},
        onDismiss: {}
    )
}

#Preview("Failed") {
    UploadProgressView(
        state: .failed(error: "Network connection lost"),
        onRetry: {},
        onDismiss: {}
    )
}
