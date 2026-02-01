# Phase 2: Recording Pipeline - Research

**Researched:** 2026-02-01
**Domain:** iOS Video Capture with AVFoundation (Vine-style recording)
**Confidence:** HIGH

## Summary

This phase implements Vine-style video recording: hold to record, release to pause, with automatic stop at 7 seconds total and the ability to preview before submission. The core technology is AVFoundation, specifically AVCaptureSession for live preview and capture, combined with AVAssetWriter for fine-grained control over video segments.

The recommended approach is a **multi-clip architecture**: each hold-to-record gesture creates a separate video clip file, and clips are merged using AVMutableComposition when the user finishes recording. This approach is more reliable than trying to pause/resume a single recording session, which has significant edge cases on iOS.

**Primary recommendation:** Use AVCaptureVideoDataOutput + AVAssetWriter for recording individual clips, then merge with AVMutableComposition and export as H.264/720p/30fps using AVAssetExportSession.

## Standard Stack

The established libraries/tools for this domain:

### Core
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| AVFoundation | iOS 18.2+ | Video capture, encoding, composition | Apple's native multimedia framework, no alternatives |
| AVKit | iOS 18.2+ | Video preview playback | Native VideoPlayer view for SwiftUI |

### Supporting
| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| Photos | iOS 18.2+ | Camera roll access (optional) | If saving to camera roll is needed |
| UIKit | iOS 18.2+ | UIViewRepresentable for preview | Bridge AVCaptureVideoPreviewLayer to SwiftUI |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| Native AVFoundation | NextLevel library | NextLevel simplifies Vine-style recording but adds binary size (bad for App Clip) and dependency |
| Native AVFoundation | Aespa library | SwiftUI-friendly but less control, adds dependency |
| AVAssetWriter | AVCaptureMovieFileOutput | MovieFileOutput is simpler but pause/resume is unreliable on iOS |

**No Installation Required:**
AVFoundation and AVKit are system frameworks, included with iOS. Add import statements only:
```swift
import AVFoundation
import AVKit
```

## Architecture Patterns

### Recommended Project Structure
```
TOY/
├── TOYShared/
│   └── Sources/TOYShared/
│       ├── Recording/
│       │   ├── CaptureSession.swift       # AVCaptureSession wrapper
│       │   ├── VideoRecorder.swift        # Multi-clip recording coordinator
│       │   ├── ClipWriter.swift           # AVAssetWriter wrapper per clip
│       │   └── VideoMerger.swift          # AVMutableComposition merger
│       └── Components/
│           └── CameraPreview.swift        # UIViewRepresentable preview
└── TOY/
    └── Features/
        └── Recording/
            ├── RecordingView.swift        # Main recording UI
            ├── RecordingViewModel.swift   # Recording state machine
            └── VideoPreviewView.swift     # Playback preview
```

### Pattern 1: Multi-Clip Recording Architecture
**What:** Each press-and-hold creates a separate clip file. Clips are merged on completion.
**When to use:** Vine-style hold-to-record with pause capability
**Why:** More reliable than pause/resume on a single file; allows easy "start over" (just delete clips)

**State Machine:**
```swift
enum RecordingState {
    case idle                    // Ready to record, no clips yet
    case recording               // Currently capturing (finger down)
    case paused                  // Between clips (finger up, < 7 seconds)
    case completed               // 7 seconds reached or user finished
    case previewing              // Playing back merged video
    case error(Error)            // Something went wrong
}
```

### Pattern 2: SwiftUI + UIViewRepresentable Camera Preview
**What:** Wrap AVCaptureVideoPreviewLayer in UIViewRepresentable
**When to use:** Displaying live camera feed in SwiftUI
**Example:**
```swift
// Source: Apple AVCam sample, community patterns
struct CameraPreview: UIViewRepresentable {
    let session: AVCaptureSession

    func makeUIView(context: Context) -> PreviewView {
        let view = PreviewView()
        view.previewLayer.session = session
        view.previewLayer.videoGravity = .resizeAspectFill
        return view
    }

    func updateUIView(_ uiView: PreviewView, context: Context) {}
}

class PreviewView: UIView {
    override class var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }
    var previewLayer: AVCaptureVideoPreviewLayer { layer as! AVCaptureVideoPreviewLayer }
}
```

### Pattern 3: Recording Coordinator with Combine/Async
**What:** ObservableObject that manages capture session, clips, and state
**When to use:** Connecting recording logic to SwiftUI views
```swift
@MainActor
final class RecordingViewModel: ObservableObject {
    @Published var state: RecordingState = .idle
    @Published var elapsedTime: TimeInterval = 0
    @Published var clips: [URL] = []

    private let captureSession: CaptureSession
    private let maxDuration: TimeInterval = 7.0

    func startRecording() async { /* ... */ }
    func stopRecording() { /* ... */ }
    func finishAndMerge() async throws -> URL { /* ... */ }
    func startOver() { /* delete clips, reset state */ }
}
```

### Anti-Patterns to Avoid
- **AVCaptureMovieFileOutput with pause/resume:** While the API exists, it's unreliable on iOS. Use multi-clip approach instead.
- **Recording on main thread:** Always use a dedicated serial queue for capture session operations.
- **Ignoring orientation:** Videos recorded in portrait appear rotated without proper transform handling.
- **Synchronous session start:** `startRunning()` is blocking; always call from background queue.

## Don't Hand-Roll

Problems that look simple but have existing solutions:

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Video preview playback | Custom AVPlayer wrapper | SwiftUI VideoPlayer or AVPlayerViewController | Handles play/pause, scrubbing, orientation automatically |
| Video merging | Manual frame-by-frame composition | AVMutableComposition + AVAssetExportSession | Handles timing, orientation, audio sync correctly |
| Camera permission flow | Custom permission checking | AVCaptureDevice.requestAccess(for: .video) | Apple's built-in permission dialog, required for App Store |
| Video compression | Manual VideoToolbox encoding | AVAssetExportSession presets | Presets handle H.264 encoding, bitrate, profile level |
| Session configuration | Manual device discovery | AVCaptureDevice.DiscoverySession | Handles multi-camera, fallbacks, device capabilities |

**Key insight:** AVFoundation has been heavily optimized by Apple. Custom implementations of video encoding, merging, or compression will be slower, less reliable, and larger in binary size.

## Common Pitfalls

### Pitfall 1: Main Thread Blocking
**What goes wrong:** App freezes when starting camera session
**Why it happens:** `AVCaptureSession.startRunning()` is a blocking call
**How to avoid:** Always start session on a dedicated background queue
**Warning signs:** UI jank when camera view appears
```swift
// WRONG
captureSession.startRunning() // Blocks main thread

// CORRECT
sessionQueue.async {
    self.captureSession.startRunning()
}
```

### Pitfall 2: Missing Audio Permission
**What goes wrong:** Video has no audio, or app crashes
**Why it happens:** Microphone requires separate permission from camera
**How to avoid:** Request both `.video` and `.audio` authorization, add `NSMicrophoneUsageDescription` to Info.plist
**Warning signs:** Silent videos, permission denied errors

### Pitfall 3: Video Orientation Issues
**What goes wrong:** Merged video appears rotated or upside down
**Why it happens:** iOS captures in landscape by default, applies metadata for display
**How to avoid:** Apply `preferredTransform` from source track to composition, or set `AVAssetWriterInput.transform`
**Warning signs:** Portrait videos appearing sideways

### Pitfall 4: Memory Pressure During Recording
**What goes wrong:** App crashes or recording stops on older devices
**Why it happens:** Holding too many frames in memory, high-res capture
**How to avoid:** Use 720p preset, ensure `expectsMediaDataInRealTime = true`, drop frames if writer not ready
**Warning signs:** Memory warnings, choppy recording

### Pitfall 5: Time Calculation Errors in Multi-Clip
**What goes wrong:** Merged video has gaps or audio sync issues
**Why it happens:** Incorrect presentation time stamps when merging clips
**How to avoid:** Track cumulative duration, insert each clip at `previousClipEndTime`
```swift
var insertTime = CMTime.zero
for clipURL in clipURLs {
    let asset = AVURLAsset(url: clipURL)
    let duration = asset.duration
    try videoTrack.insertTimeRange(
        CMTimeRange(start: .zero, duration: duration),
        of: asset.tracks(withMediaType: .video).first!,
        at: insertTime
    )
    insertTime = CMTimeAdd(insertTime, duration)
}
```

### Pitfall 6: Forgetting to Remove Temp Files
**What goes wrong:** Storage fills up with orphaned clips
**Why it happens:** Clips not deleted after merge or on "start over"
**How to avoid:** Clean up temp directory clips after successful merge or cancel
**Warning signs:** Growing app storage size

## Code Examples

Verified patterns from official sources and community best practices:

### Setup AVCaptureSession for Video + Audio
```swift
// Source: Apple AVFoundation documentation patterns
actor CaptureSession {
    private let session = AVCaptureSession()
    private let sessionQueue = DispatchQueue(label: "capture.session")

    func configure() async throws {
        session.beginConfiguration()
        session.sessionPreset = .hd1280x720 // 720p for 15MB App Clip limit

        // Video input
        guard let videoDevice = AVCaptureDevice.default(
            .builtInWideAngleCamera,
            for: .video,
            position: .front
        ) else { throw CaptureError.noCamera }

        let videoInput = try AVCaptureDeviceInput(device: videoDevice)
        guard session.canAddInput(videoInput) else { throw CaptureError.cannotAddInput }
        session.addInput(videoInput)

        // Audio input
        guard let audioDevice = AVCaptureDevice.default(for: .audio) else {
            throw CaptureError.noMicrophone
        }
        let audioInput = try AVCaptureDeviceInput(device: audioDevice)
        if session.canAddInput(audioInput) {
            session.addInput(audioInput)
        }

        // Data outputs for AVAssetWriter
        let videoOutput = AVCaptureVideoDataOutput()
        videoOutput.setSampleBufferDelegate(self, queue: sessionQueue)
        guard session.canAddOutput(videoOutput) else { throw CaptureError.cannotAddOutput }
        session.addOutput(videoOutput)

        let audioOutput = AVCaptureAudioDataOutput()
        audioOutput.setSampleBufferDelegate(self, queue: sessionQueue)
        if session.canAddOutput(audioOutput) {
            session.addOutput(audioOutput)
        }

        session.commitConfiguration()
    }

    func start() {
        sessionQueue.async { self.session.startRunning() }
    }

    func stop() {
        sessionQueue.async { self.session.stopRunning() }
    }
}
```

### Request Camera/Microphone Permissions
```swift
// Source: Apple documentation
func requestPermissions() async -> Bool {
    let videoStatus = AVCaptureDevice.authorizationStatus(for: .video)
    let audioStatus = AVCaptureDevice.authorizationStatus(for: .audio)

    var videoGranted = videoStatus == .authorized
    var audioGranted = audioStatus == .authorized

    if videoStatus == .notDetermined {
        videoGranted = await AVCaptureDevice.requestAccess(for: .video)
    }

    if audioStatus == .notDetermined {
        audioGranted = await AVCaptureDevice.requestAccess(for: .audio)
    }

    return videoGranted && audioGranted
}
```

### AVAssetWriter for Single Clip
```swift
// Source: Community patterns, Apple sample code
final class ClipWriter {
    private var assetWriter: AVAssetWriter?
    private var videoInput: AVAssetWriterInput?
    private var audioInput: AVAssetWriterInput?
    private var isWriting = false
    private var startTime: CMTime?

    func startWriting(to url: URL) throws {
        assetWriter = try AVAssetWriter(outputURL: url, fileType: .mov)

        // Video settings for H.264 720p
        let videoSettings: [String: Any] = [
            AVVideoCodecKey: AVVideoCodecType.h264,
            AVVideoWidthKey: 1280,
            AVVideoHeightKey: 720,
            AVVideoCompressionPropertiesKey: [
                AVVideoAverageBitRateKey: 2_000_000, // 2 Mbps
                AVVideoProfileLevelKey: AVVideoProfileLevelH264High41,
                AVVideoMaxKeyFrameIntervalKey: 30
            ]
        ]

        videoInput = AVAssetWriterInput(mediaType: .video, outputSettings: videoSettings)
        videoInput?.expectsMediaDataInRealTime = true
        videoInput?.transform = CGAffineTransform(rotationAngle: .pi / 2) // Portrait

        // Audio settings
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
    }

    func append(_ sampleBuffer: CMSampleBuffer, isVideo: Bool) {
        guard isWriting, let writer = assetWriter else { return }

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

    func finishWriting() async throws -> URL {
        guard let writer = assetWriter else { throw ClipError.noWriter }

        videoInput?.markAsFinished()
        audioInput?.markAsFinished()

        await writer.finishWriting()

        if writer.status == .failed {
            throw writer.error ?? ClipError.writeFailed
        }

        isWriting = false
        return writer.outputURL
    }
}
```

### Merge Clips with AVMutableComposition
```swift
// Source: Apple documentation, IMG.LY blog
func mergeClips(_ clipURLs: [URL]) async throws -> URL {
    let composition = AVMutableComposition()

    guard let videoTrack = composition.addMutableTrack(
        withMediaType: .video,
        preferredTrackID: kCMPersistentTrackID_Invalid
    ) else { throw MergeError.cannotCreateTrack }

    guard let audioTrack = composition.addMutableTrack(
        withMediaType: .audio,
        preferredTrackID: kCMPersistentTrackID_Invalid
    ) else { throw MergeError.cannotCreateTrack }

    var insertTime = CMTime.zero

    for clipURL in clipURLs {
        let asset = AVURLAsset(url: clipURL)
        let duration = try await asset.load(.duration)
        let timeRange = CMTimeRange(start: .zero, duration: duration)

        if let sourceVideoTrack = try await asset.loadTracks(withMediaType: .video).first {
            try videoTrack.insertTimeRange(timeRange, of: sourceVideoTrack, at: insertTime)
            // Apply orientation transform from first clip
            if insertTime == .zero {
                let transform = try await sourceVideoTrack.load(.preferredTransform)
                videoTrack.preferredTransform = transform
            }
        }

        if let sourceAudioTrack = try await asset.loadTracks(withMediaType: .audio).first {
            try audioTrack.insertTimeRange(timeRange, of: sourceAudioTrack, at: insertTime)
        }

        insertTime = CMTimeAdd(insertTime, duration)
    }

    // Export merged video
    let outputURL = FileManager.default.temporaryDirectory
        .appendingPathComponent(UUID().uuidString)
        .appendingPathExtension("mov")

    guard let exporter = AVAssetExportSession(
        asset: composition,
        presetName: AVAssetExportPreset1280x720 // 720p H.264
    ) else { throw MergeError.cannotCreateExporter }

    exporter.outputURL = outputURL
    exporter.outputFileType = .mov

    await exporter.export()

    if exporter.status == .failed {
        throw exporter.error ?? MergeError.exportFailed
    }

    return outputURL
}
```

### VideoPlayer for Preview
```swift
// Source: Apple SwiftUI documentation
import AVKit

struct VideoPreviewView: View {
    let videoURL: URL
    @State private var player: AVPlayer?

    var body: some View {
        VideoPlayer(player: player)
            .onAppear {
                player = AVPlayer(url: videoURL)
                player?.play()
            }
            .onDisappear {
                player?.pause()
                player = nil
            }
    }
}
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| AVCaptureMovieFileOutput | AVCaptureVideoDataOutput + AVAssetWriter | iOS 6+ | More control, multi-clip support |
| Delegate-based sample buffer | async/await with actors | iOS 15+ | Cleaner code, safer concurrency |
| AVAsset.tracks(withMediaType:) sync | asset.loadTracks(withMediaType:) async | iOS 15+ | Non-blocking media loading |
| UIImagePickerController | AVFoundation + custom UI | Always | Full control for Vine-style UX |

**Deprecated/outdated:**
- `AVCaptureConnection.videoOrientation`: Use `videoRotationAngle` instead (iOS 17+)
- Synchronous asset property access: Use async `.load()` methods (iOS 15+)
- `AVAssetExportSession.exportAsynchronously`: Use `export()` async method (iOS 18+)

## Open Questions

Things that couldn't be fully resolved:

1. **Front vs Back Camera Default**
   - What we know: Selfie-style recording is common for personal messages
   - What's unclear: Should we default to front camera or let user choose?
   - Recommendation: Default to front camera for Phase 2, add camera flip in future if needed

2. **Audio-Only Clips**
   - What we know: User might briefly tap without holding
   - What's unclear: Minimum clip duration to be valid?
   - Recommendation: Discard clips < 0.5 seconds, treat as accidental taps

3. **Concurrent Recording Timer UI**
   - What we know: Need to show elapsed time (0-7 seconds)
   - What's unclear: Best way to sync timer with actual recorded duration
   - Recommendation: Use CMTime from sample buffers for accuracy, not wall clock

## Sources

### Primary (HIGH confidence)
- Apple Developer Documentation - AVCaptureSession, AVAssetWriter, AVMutableComposition
- [objc.io - Capturing Video on iOS](https://www.objc.io/issues/23-video/capturing-video/) - Authoritative iOS video patterns
- [NextLevel GitHub](https://github.com/NextLevel/NextLevel) - Reference implementation for Vine-style recording

### Secondary (MEDIUM confidence)
- [IMG.LY - Merge Videos in iOS with Swift](https://img.ly/blog/combine-video-clips-into-a-new-file-in-ios-with-swift/) - AVMutableComposition patterns
- [Kodeco - How to Play, Record and Merge Videos](https://www.kodeco.com/10857372-how-to-play-record-and-merge-videos-in-ios-and-swift) - End-to-end video workflow
- [TestFairy - Fine Tuned Video Compression](https://testfairy.com/blog/fine-tuned-video-compression-in-ios-swift-4-no-dependencies/) - H.264 encoding settings

### Tertiary (LOW confidence)
- Various Medium articles on SwiftUI camera integration - Used for UIViewRepresentable patterns

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH - AVFoundation is the only option for custom video capture on iOS
- Architecture: HIGH - Multi-clip pattern is well-established (NextLevel, PBJVision use it)
- Pitfalls: HIGH - Common issues are well-documented in Apple forums and community

**Research date:** 2026-02-01
**Valid until:** 2026-03-01 (AVFoundation is stable, 30-day validity)
