---
phase: 02-recording-pipeline
plan: 01
subsystem: recording
tags: [avfoundation, video-capture, asset-writer, ios]

dependency_graph:
  requires: [01-01]
  provides: [capture-session, clip-writer, recording-errors]
  affects: [02-02, 02-03, 02-04]

tech_stack:
  added: []
  patterns: [delegate-pattern, background-queue, sample-buffer-delegate]

key_files:
  created:
    - TOY/TOYShared/Sources/TOYShared/Recording/RecordingError.swift
    - TOY/TOYShared/Sources/TOYShared/Recording/CaptureSession.swift
    - TOY/TOYShared/Sources/TOYShared/Recording/ClipWriter.swift
  modified: []

decisions:
  - id: REC-001
    decision: Use AVCaptureVideoDataOutput instead of MovieFileOutput
    rationale: Provides sample buffer access for multi-clip recording without file switching
  - id: REC-002
    decision: Portrait dimensions (720x1280) with transform
    rationale: Front camera captures landscape; transform rotates for portrait display
  - id: REC-003
    decision: Dedicated sessionQueue for all capture operations
    rationale: AVCaptureSession.startRunning() blocks until hardware ready; never block main thread

metrics:
  duration: ~3 minutes
  completed: 2026-02-02
---

# Phase 2 Plan 1: Core Video Capture Infrastructure Summary

AVFoundation capture session and asset writer wrappers for Vine-style multi-clip recording with 720p H.264 encoding and background queue operation.

## What Was Built

### Recording Directory Structure
Created `/TOY/TOYShared/Sources/TOYShared/Recording/` with three core files establishing the video capture foundation.

### RecordingError.swift
Comprehensive error types covering the full recording pipeline:
- Camera/microphone unavailability
- Input/output configuration failures
- Writer state errors
- Write/export failures with underlying error passthrough
- Permission denied with media type context

All cases implement `LocalizedError` for user-facing messages.

### CaptureSession.swift
AVCaptureSession wrapper with:
- **720p preset** (`.hd1280x720`) - optimal for App Clip 15MB limit
- **Front camera default** - selfie-style for personal video messages
- **Background sessionQueue** - all session operations run off main thread
- **AVCaptureVideoDataOutput** - sample buffer access via delegate pattern
- **AVCaptureAudioDataOutput** - audio samples for synchronized recording
- **CaptureSessionDelegate protocol** - notifies of video/audio sample buffers

Key implementation detail: `session.startRunning()` is called via `sessionQueue.async` to prevent main thread blocking during hardware initialization.

### ClipWriter.swift
AVAssetWriter wrapper with:
- **H.264 codec** at 720p with 2Mbps bitrate
- **AAC audio** at 44.1kHz mono, 128kbps
- **Portrait transform** - CGAffineTransform(rotationAngle: .pi/2).scaledBy(x: -1, y: 1)
- **expectsMediaDataInRealTime = true** - critical for live capture
- **Async finishWriting()** - proper Swift concurrency integration
- **cancelWriting()** with temp file cleanup

Video settings configured for portrait output (720x1280 dimensions) while input comes in landscape from camera.

## Key Decisions

| ID | Decision | Rationale |
|----|----------|-----------|
| REC-001 | AVCaptureVideoDataOutput over MovieFileOutput | Sample buffer access enables seamless multi-clip recording |
| REC-002 | Portrait dimensions with transform | Camera captures landscape; transform handles rotation + front camera mirroring |
| REC-003 | Dedicated sessionQueue | startRunning() blocks until hardware ready; must never block main thread |

## Commits

| Hash | Description |
|------|-------------|
| 09bca64 | feat(02-01): create Recording directory and error types |
| e3c8515 | feat(02-01): create CaptureSession wrapper for AVFoundation capture |
| 8b50621 | feat(02-01): create ClipWriter wrapper for AVAssetWriter |

## Deviations from Plan

None - plan executed exactly as written.

## Technical Notes

### Front Camera Mirroring
Front camera preview is mirrored but captured video is not. The transform `CGAffineTransform(rotationAngle: .pi/2).scaledBy(x: -1, y: 1)` handles:
1. Rotation from landscape to portrait
2. Horizontal flip to match user expectation (selfie should look like preview)

### Sample Buffer Flow
```
AVCaptureSession -> AVCaptureVideoDataOutput
                          |
                          v
                   sessionQueue (background)
                          |
                          v
              captureOutput(_:didOutput:from:)
                          |
                          v
                CaptureSessionDelegate
                          |
                          v
                ClipWriter.append(_:isVideo:)
```

### Writer State Machine
```
unknown -> (startWriting) -> writing -> (markAsFinished) -> completed
                               |
                               v
                        (cancelWriting)
                               |
                               v
                           cancelled
```

## Next Phase Readiness

Ready for 02-02 (Multi-clip Recorder):
- CaptureSession provides sample buffer stream via delegate
- ClipWriter can be instantiated per clip
- Background queue operation prevents UI blocking
- Error types cover all failure modes

## Files Created

- `TOY/TOYShared/Sources/TOYShared/Recording/RecordingError.swift` (39 lines)
- `TOY/TOYShared/Sources/TOYShared/Recording/CaptureSession.swift` (95 lines)
- `TOY/TOYShared/Sources/TOYShared/Recording/ClipWriter.swift` (126 lines)
