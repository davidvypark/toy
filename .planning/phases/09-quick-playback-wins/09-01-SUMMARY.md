---
phase: 09-quick-playback-wins
plan: 01
subsystem: video-playback
tags: [avplayer, loading-ux, buffering, progressview]
requires: [phase-8]
provides: [clean-loading-overlays, fast-playback-start]
affects: [phase-10, phase-12]
tech-stack:
  added: []
  patterns: [immediate-playback-start, spinner-only-loading]
key-files:
  created: []
  modified:
    - TOY/Features/PublishedCard/PublishedCardPlayerView.swift
    - TOY/Features/Publishing/MontagePreviewView.swift
key-decisions:
  - Retained loadingProgress state and observeBuffering for internal state transitions despite removing visible text
  - Did not touch MontagePreviewView buffering strategy (automaticallyWaitsToMinimizeStalling = true) since queue player needs it
duration: ~3min
completed: 2026-02-06
---

# Phase 9 Plan 01: Remove Percentage Text and Enable Fast Playback Summary

Replaced percentage loading text with spinner-only overlays in both video player views and enabled immediate playback start via automaticallyWaitsToMinimizeStalling = false for published card single-clip player.

## What Was Done

### Task 1: Remove percentage text from loading overlays (LOAD-02)
**Commit:** 864101e

Replaced the VStack containing "Loading video..." / "XX% complete" text in PublishedCardPlayerView with a simple `ProgressView()` spinner. Did the same for MontagePreviewView's "Stitching videos..." / "XX% complete" text.

Key detail: The `loadingProgress` state variable, `observeBuffering()` method, and `bufferObserver` were intentionally retained in both files. These are still used for internal state transitions (driving `isPlayerReady` logic and `isLoadingURLs` flag) even though the progress is no longer displayed to the user.

**Files modified:**
- `TOY/Features/PublishedCard/PublishedCardPlayerView.swift` -- loading overlay simplified to spinner
- `TOY/Features/Publishing/MontagePreviewView.swift` -- loading overlay simplified to spinner

### Task 2: Enable immediate playback start for published cards (LOAD-04)
**Commit:** b0a5036

Added `avPlayer.automaticallyWaitsToMinimizeStalling = false` immediately after AVPlayer creation in PublishedCardPlayerView's `loadVideo()` method. This tells AVPlayer to begin playback as soon as any buffered data is available, rather than waiting for enough data to guarantee stall-free playback.

For 7-second clips (2-5MB), the default wait behavior was causing 1-3 second delays that are unnecessary on any reasonable connection.

**Files modified:**
- `TOY/Features/PublishedCard/PublishedCardPlayerView.swift` -- added automaticallyWaitsToMinimizeStalling = false

**Intentionally not changed:**
- `MontagePreviewView.swift` -- keeps `automaticallyWaitsToMinimizeStalling = true` because the queue player benefits from buffering ahead to prevent black flashes between clips
- `ClipPreviewSheet.swift` -- already has `automaticallyWaitsToMinimizeStalling = false`
- `VideoPreviewView.swift` -- plays from local files where buffering is irrelevant

## Deviations from Plan

None -- plan executed exactly as written.

## Decisions Made

| Decision | Rationale |
|----------|-----------|
| Keep loadingProgress and observeBuffering internal logic | Still drives isPlayerReady transitions; removing would break state machine |
| Spinner-only loading (no text at all) | Cleaner UX; text was adding noise without actionable information |
| No stall recovery observers added | For 7-second clips on any reasonable connection, stalling is extremely unlikely |

## Verification Results

1. Build succeeds with no errors
2. Zero instances of "% complete" text in PublishedCardPlayerView.swift or MontagePreviewView.swift
3. PublishedCardPlayerView.swift contains `automaticallyWaitsToMinimizeStalling = false`
4. MontagePreviewView.swift still contains `automaticallyWaitsToMinimizeStalling = true` (unchanged)
5. ClipPreviewSheet.swift was not modified

## Next Phase Readiness

Plan 09-02 (thumbnail timing + audio session) can proceed immediately. No blockers introduced.
