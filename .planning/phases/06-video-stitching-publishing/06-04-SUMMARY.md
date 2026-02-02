# Summary: 06-04 Wire Navigation & Human Verify

## What Was Done

1. **Added Preview Montage navigation to CardDetailView**
   - Added `@State private var showMontagePreview = false` state variable
   - Added "Publish" section with "Preview Montage" button showing clip count and total duration
   - Added fullScreenCover navigation to MontagePreviewView with card and clips
   - onPublished callback refreshes card data

2. **Human verification checkpoint passed**
   - Three bugs reported and fixed during verification:

   **Bug 1: "The video file could not be found" error**
   - Root cause: VideoMerger.mergeClipsWithProgress returned the original clip URL when only 1 clip existed
   - MontageService then deleted all downloaded clips including that original, leaving montageURL pointing to deleted file
   - Fix: Modified VideoMerger to copy single clips to a new output file instead of returning the original (VideoMerger.swift:117-124)

   **Bug 2: Video player showing AirPlay and skip buttons**
   - Root cause: Used AVKit's VideoPlayer which includes default playback controls
   - Fix: Created custom MontageVideoPlayer using AVPlayerLayer (same pattern as ClipVideoPlayer)
   - Added MontagePlayerUIView with isReadyForDisplay observation for proper skeleton timing

   **Bug 3: Wrong domain (toy.app instead of sendtoycard.com)**
   - Fix: Changed recipient URL in PublishedCardView from "https://toy.app/watch/" to "https://sendtoycard.com/watch/"

## Artifacts

| File | Change |
|------|--------|
| TOY/Features/CardManagement/CardDetailView.swift | Added Preview Montage section and navigation |
| TOY/TOYShared/Sources/TOYShared/Recording/VideoMerger.swift | Fixed single clip handling (copy instead of return original) |
| TOY/Features/Publishing/MontagePreviewView.swift | Replaced VideoPlayer with custom MontageVideoPlayer (no controls) |
| TOY/Features/Publishing/PublishedCardView.swift | Changed domain to sendtoycard.com |

## Decisions

| ID | Decision | Rationale |
|----|----------|-----------|
| MERGE-001 | Copy single clip to new file instead of returning original | Original file gets deleted by cleanup; returning a copy prevents file-not-found errors |
| UI-010 | Custom AVPlayerLayer for montage preview | Removes unwanted AVKit controls (AirPlay, skip buttons) for cleaner preview |
| URL-001 | Recipient URL domain: sendtoycard.com | User-specified domain for production |

## Verification

- [x] CardDetailView has Preview Montage section with navigation
- [x] Full flow: CardDetail -> MontagePreview -> Publish -> PublishedCard
- [x] Video plays without AirPlay/skip buttons
- [x] Publish succeeds and uploads to videos bucket
- [x] Shareable link shows sendtoycard.com domain
- [x] Human approval received

## Duration

~15 minutes (including bug fixes)

## Notes

- The sendtoycard.com/watch/{token} URL is generated but the web viewer doesn't exist yet
- Web viewer for recipients would be a separate future phase
- Phase 6 complete - all success criteria verified
