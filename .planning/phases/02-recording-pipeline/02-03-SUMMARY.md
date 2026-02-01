---
phase: 02-recording-pipeline
plan: 03
subsystem: video-capture
tags: [avfoundation, swiftui, uikit-bridge, permissions, camera-preview]
dependency-graph:
  requires: [02-01]
  provides: [camera-preview-component, privacy-permissions]
  affects: [02-04, 02-05]
tech-stack:
  added: []
  patterns: [uiviewrepresentable, layer-class-override]
key-files:
  created:
    - TOY/TOYShared/Sources/TOYShared/Components/CameraPreview.swift
  modified:
    - TOY/Info.plist
decisions: []
metrics:
  duration: ~1min
  completed: 2026-02-02
---

# Phase 02 Plan 03: Camera Preview and Permissions Summary

CameraPreview UIViewRepresentable bridges AVCaptureVideoPreviewLayer to SwiftUI with layerClass override pattern for efficient layer management.

## What Was Built

### Task 1: CameraPreview UIViewRepresentable

Created `/TOY/TOYShared/Sources/TOYShared/Components/CameraPreview.swift`:

- **CameraPreview struct**: UIViewRepresentable that accepts AVCaptureSession and displays live camera feed
- **PreviewView class**: Custom UIView using `layerClass` override for AVCaptureVideoPreviewLayer
- **Video gravity**: `resizeAspectFill` for edge-to-edge preview
- **Black background**: Shows when camera not running
- **SwiftUI Preview**: Placeholder for design-time visualization

Key implementation pattern:
```swift
public override class var layerClass: AnyClass {
    AVCaptureVideoPreviewLayer.self
}
```
This approach is more efficient than adding sublayers because the view's backing layer is directly the preview layer.

### Task 2: Permission Descriptions

Updated `/TOY/Info.plist` with user-friendly permission descriptions:

- **NSCameraUsageDescription**: "TOY needs access to your camera to record video messages for your friends and family."
- **NSMicrophoneUsageDescription**: "TOY needs access to your microphone to record audio with your video messages."

These descriptions appear in the system permission dialogs and clearly explain the purpose.

## Files Changed

| File | Change | Purpose |
|------|--------|---------|
| Components/CameraPreview.swift | Created | UIViewRepresentable for live camera preview |
| TOY/Info.plist | Modified | Camera and microphone usage descriptions |

## Commits

| Hash | Type | Description |
|------|------|-------------|
| a459834 | feat | Create CameraPreview UIViewRepresentable |
| 34cae4d | feat | Configure camera and microphone permission descriptions |

## Deviations from Plan

None - plan executed exactly as written.

## Verification Results

- [x] CameraPreview.swift exists in Components/
- [x] CameraPreview uses UIViewRepresentable pattern
- [x] PreviewView uses layerClass override for AVCaptureVideoPreviewLayer
- [x] Video gravity set to resizeAspectFill
- [x] Info.plist contains NSCameraUsageDescription
- [x] Info.plist contains NSMicrophoneUsageDescription
- [x] Permission descriptions are user-friendly and explain purpose
- [x] Info.plist passes plutil validation: OK
- [x] TOY scheme builds successfully: BUILD SUCCEEDED

## Integration Points

**Uses from 02-01:**
- `AVCaptureSession` from CaptureSession.swift (passed to CameraPreview.session)

**Consumed by 02-04 (RecordingViewModel):**
- CameraPreview will be used in recording view to display live camera feed
- RecordingViewModel will provide the CaptureSession.session to CameraPreview

## Next Phase Readiness

Ready for 02-04 (RecordingViewModel) which will:
- Coordinate CaptureSession, ClipWriter, and VideoMerger
- Provide session to CameraPreview for display
- Handle permission requests using the configured descriptions
