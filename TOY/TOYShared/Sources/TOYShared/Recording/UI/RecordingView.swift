//
//  RecordingView.swift
//  TOYShared
//
//  Main view for the video recording experience.
//

import AVFoundation
import SwiftUI

public struct RecordingView: View {
    @StateObject private var viewModel: RecordingViewModel
    @Environment(\.dismiss) private var dismiss

    public init(
        cardId: UUID? = nil,
        participantId: UUID? = nil,
        isHostClip: Bool = false,
        onParticipantClipUploaded: ((Card) async -> Void)? = nil
    ) {
        let vm = RecordingViewModel(
            cardId: cardId,
            participantId: participantId,
            isHostClip: isHostClip
        )
        vm.onParticipantClipUploaded = onParticipantClipUploaded
        _viewModel = StateObject(wrappedValue: vm)
    }

    /// Initializer that accepts an external view model (used by App Clip).
    public init(viewModel: RecordingViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }

    public var body: some View {
        ZStack {
            // Background
            Color.black.ignoresSafeArea()

            switch viewModel.permissionStatus {
            case .unknown:
                ProgressView()
                    .tint(.white)

            case .denied, .restricted:
                permissionDeniedView

            case .granted:
                if viewModel.showPreview,
                   case .completed(let url) = viewModel.recorder.state {
                    VideoPreviewView(
                        videoURL: url,
                        onRetake: { viewModel.startOver() },
                        onConfirm: { viewModel.confirmVideo() }
                    )
                } else {
                    recordingView
                }
            }
        }
        .overlay {
            if let uploadState = viewModel.uploadState {
                UploadProgressView(
                    state: uploadState,
                    onRetry: { viewModel.retryUpload() },
                    onDismiss: {
                        if viewModel.dismissUpload() {
                            // Upload succeeded - go back to home
                            dismiss()
                        }
                        // Otherwise just hides overlay, stays on preview
                    }
                )
            }
        }
        .task {
            await viewModel.onAppear()
        }
        .onDisappear {
            viewModel.onDisappear()
        }
    }

    // MARK: - Recording View

    private var recordingView: some View {
        ZStack {
            // Camera preview - always mounted to prevent view recreation during state changes
            // Using opacity instead of conditional rendering prevents SwiftUI from
            // unmounting/remounting the UIViewRepresentable during segment transitions
            CameraPreview(session: viewModel.recorder.captureSession.session)
                .ignoresSafeArea()
                .opacity(viewModel.recorder.isSessionReady ? 1 : 0)

            // Overlay controls
            VStack {
                // Top bar with close and time
                HStack {
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark")
                            .font(.title2)
                            .foregroundStyle(.white)
                            .padding(12)
                            .background(.ultraThinMaterial)
                            .clipShape(Circle())
                    }

                    Spacer()

                    // Time display
                    timeDisplay
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)

                Spacer()

                // Bottom controls
                bottomControls
                    .padding(.bottom, 40)
            }
        }
    }

    // MARK: - Time Display

    private var timeDisplay: some View {
        HStack(spacing: 4) {
            Image(systemName: "record.circle.fill")
                .foregroundStyle(viewModel.recorder.state.isRecording ? .red : .white.opacity(0.6))

            Text(timeString)
                .font(.system(.body, design: .monospaced))
                .foregroundStyle(.white)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(.ultraThinMaterial)
        .clipShape(Capsule())
    }

    private var timeString: String {
        let elapsed = viewModel.recorder.elapsedTime
        return String(format: "%.1f / %.1f", elapsed, viewModel.recorder.maxDuration)
    }

    // MARK: - Bottom Controls

    private var bottomControls: some View {
        HStack(spacing: 40) {
            // Start Over button (left)
            if viewModel.recorder.state.hasContent {
                Button(action: { viewModel.startOver() }) {
                    VStack(spacing: 4) {
                        Image(systemName: "arrow.counterclockwise")
                            .font(.title2)
                        Text("Start Over")
                            .font(.caption)
                    }
                    .foregroundStyle(.white)
                }
                .frame(width: 70)
            } else {
                Spacer()
                    .frame(width: 70)
            }

            // Record button (center) - hide when max duration reached
            if viewModel.recorder.progress < 1.0 {
                recordButton
            } else {
                Spacer()
                    .frame(width: 80)
            }

            // Done button (right)
            if viewModel.canFinish {
                Button(action: {
                    Task { await viewModel.finishRecording() }
                }) {
                    VStack(spacing: 4) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.title)
                        Text("Done")
                            .font(.caption)
                    }
                    .foregroundStyle(.white)
                }
                .frame(width: 70)
            } else {
                Spacer()
                    .frame(width: 70)
            }
        }
    }

    // MARK: - Record Button

    private var recordButton: some View {
        let isReady = viewModel.recorder.isSessionReady

        return ZStack {
            // Progress ring
            Circle()
                .stroke(Color.white.opacity(isReady ? 0.3 : 0.1), lineWidth: 6)
                .frame(width: 80, height: 80)

            Circle()
                .trim(from: 0, to: viewModel.recorder.progress)
                .stroke(Color.red, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                .frame(width: 80, height: 80)
                .rotationEffect(.degrees(-90))
                .animation(.linear(duration: 0.1), value: viewModel.recorder.progress)

            // Inner button - show loading state when session not ready
            if isReady {
                Circle()
                    .fill(viewModel.recorder.state.isRecording ? Color.red : Color.white)
                    .frame(width: 60, height: 60)
                    .scaleEffect(viewModel.recorder.state.isRecording ? 0.8 : 1.0)
                    .animation(.easeInOut(duration: 0.15), value: viewModel.recorder.state.isRecording)
            } else {
                Circle()
                    .fill(Color.white.opacity(0.3))
                    .frame(width: 60, height: 60)
                    .overlay {
                        ProgressView()
                            .tint(.white)
                    }
            }
        }
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in
                    // Only allow recording when session is ready
                    if isReady && !viewModel.recorder.state.isRecording && viewModel.recorder.state.canStartRecording {
                        viewModel.startRecording()
                    }
                }
                .onEnded { _ in
                    if viewModel.recorder.state.isRecording {
                        viewModel.stopRecording()
                    }
                }
        )
    }

    // MARK: - Permission Denied View

    private var permissionDeniedView: some View {
        VStack(spacing: 24) {
            Image(systemName: "camera.fill")
                .font(.system(size: 60))
                .foregroundStyle(.secondary)

            VStack(spacing: 8) {
                Text("Camera Access Required")
                    .font(.title2)
                    .fontWeight(.semibold)

                Text("TOY needs camera and microphone access to record video messages.")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            }

            Button("Open Settings") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
            .buttonStyle(.borderedProminent)
        }
        .foregroundStyle(.white)
    }
}

#Preview {
    RecordingView()
}
