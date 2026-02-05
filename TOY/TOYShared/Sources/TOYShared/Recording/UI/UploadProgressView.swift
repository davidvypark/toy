//
//  UploadProgressView.swift
//  TOYShared
//
//  Full-screen overlay showing upload progress.
//

import SwiftUI

/// States for the upload progress view.
public enum UploadState: Equatable {
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
            Color.black.opacity(0.8)
                .ignoresSafeArea()

            // Content card
            VStack(spacing: TOYSpacing.lg) {
                switch state {
                case .uploading:
                    ProgressView()
                        .scaleEffect(1.5)
                        .tint(.warmCream)
                    Text("Uploading...")
                        .font(.toyHeadline())
                        .foregroundColor(.warmCream)

                case .success:
                    Image(systemName: "checkmark")
                        .font(.system(size: 48, weight: .light))
                        .foregroundColor(.warmCream)
                    Text("Uploaded")
                        .font(.toyHeadline())
                        .foregroundColor(.warmCream)
                    TOYButton("Done", style: .primary, size: .large, action: onDismiss)
                        .environment(\.colorScheme, .dark)
                        .frame(maxWidth: 200)

                case .failed(let error):
                    Image(systemName: "exclamationmark.triangle")
                        .font(.system(size: 48, weight: .light))
                        .foregroundColor(.toyDestructive)
                    Text("Upload Failed")
                        .font(.toyHeadline())
                        .foregroundColor(.warmCream)
                    Text(error)
                        .font(.toyBody())
                        .foregroundColor(.warmGrayDark)
                        .multilineTextAlignment(.center)
                    HStack(spacing: TOYSpacing.md) {
                        TOYButton("Cancel", style: .secondary, size: .medium, action: onDismiss)
                        TOYButton("Retry", style: .primary, size: .medium, action: onRetry)
                    }
                }
            }
            .padding(TOYSpacing.xl)
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
