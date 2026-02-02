---
phase: 06
plan: 02
subsystem: video-processing
tags: [avfoundation, video-merge, stitching, montage]
depends_on: [06-01]
provides: [montage-generation, progress-reporting]
affects: [06-03, 06-04]

tech-stack:
  added: []
  patterns: [actor-isolation, progress-callback, async-download]

key-files:
  created:
    - TOY/Features/Publishing/MontageService.swift
  modified:
    - TOY/TOYShared/Sources/TOYShared/Recording/VideoMerger.swift

decisions: []

metrics:
  duration: ~2min
  completed: 2026-02-02
---

# Phase 6 Plan 02: Montage Stitching Logic Summary

MontageService actor that orchestrates downloading clips, ordering them correctly (host first), and stitching into a single montage video with progress reporting.

## What Was Built

### VideoMerger Extension
- Added `mergeClipsWithProgress(_ clipURLs:onProgress:)` method
- Progress callback is `@Sendable (Float) -> Void` reporting 0.0 to 1.0
- Monitors AVAssetExportSession.progress at 0.1s intervals
- Progress task cancelled when export completes
- Existing `mergeClips()` method unchanged for backward compatibility

### MontageService Actor
- Thread-safe actor orchestrating full montage pipeline
- `generateMontage(clips:hostId:onProgress:)` method:
  1. Sorts clips: host first (participantId == hostId per HOST-001), then by orderPosition, then by createdAt
  2. Downloads clips from Supabase storage via signed URLs to temp directory
  3. Stitches using VideoMerger with progress reporting
  4. Cleans up temp clip files (keeps montage)

### Progress Reporting
- `MontageProgress` struct with two phases:
  - `.downloading(current:total:)` - 40% of overall progress
  - `.stitching(progress:)` - 60% of overall progress
- `overallProgress` computed property combines phases

### Error Handling
- `MontageError` enum:
  - `.noClips` - empty clips array
  - `.downloadFailed(String)` - signed URL or HTTP download failure
  - `.stitchingFailed(String)` - VideoMerger failure

## Key Implementation Details

### Clip Ordering (sortClipsForMontage)
```swift
// Host clip first (identified by participantId == hostId per HOST-001)
let hostClip = clips.first { $0.participantId == hostId }

// Remaining clips sorted by orderPosition, then createdAt
let participantClips = clips
    .filter { $0.participantId != hostId }
    .sorted { clip1, clip2 in
        if let pos1 = clip1.orderPosition, let pos2 = clip2.orderPosition {
            if pos1 != pos2 { return pos1 < pos2 }
        }
        return clip1.createdAt < clip2.createdAt
    }

return [hostClip].compactMap { $0 } + participantClips
```

### Download Flow
- Uses `StorageService.createSignedURL(path:)` for secure access
- URLSession.shared.download() for HTTP download
- Moves downloaded file to temp directory for processing

## Commits

| Hash | Message |
|------|---------|
| 47cbfc5 | feat(06-02): add mergeClipsWithProgress to VideoMerger |
| 42e67f0 | feat(06-02): create MontageService for video stitching orchestration |

## Deviations from Plan

None - plan executed exactly as written.

## Verification Results

1. VideoMerger has mergeClipsWithProgress() method - line 108
2. MontageService.swift exists in TOY/Features/Publishing/ (162 lines)
3. MontageService has generateMontage() method - line 57
4. Clip ordering puts host clip first (uses participantId == hostId) - lines 116-121
5. Project builds without errors

## Next Phase Readiness

Ready for 06-03 (Publishing UI):
- MontageService provides generateMontage() with progress reporting
- MontageProgress.overallProgress gives 0.0-1.0 for UI progress bar
- MontageError provides user-facing error messages
- Returns local URL ready for upload via StorageService.uploadMontage()
