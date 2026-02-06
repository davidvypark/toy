# Feature Landscape: Video Playback Quality

**Domain:** iOS video playback UX for short-form video greeting cards
**Researched:** 2026-02-06
**Overall Confidence:** HIGH (based on codebase analysis + AVFoundation documentation + industry patterns)

## Current State Analysis

Before listing features, here is what TOY does today and where it falls short. This grounds every recommendation in the actual codebase.

**What exists:**
- AVPlayer streaming from Supabase signed URLs (no local caching)
- Thumbnail generation at 0.5 seconds via `AVAssetImageGenerator` (150x200px)
- Kingfisher for thumbnail image caching with stable cache keys
- Buffer progress observation via `loadedTimeRanges` KVO
- `isReadyForDisplay` observation on `AVPlayerLayer` for crossfade
- Signed URL caching in ViewModel memory (lost on view model dealloc)
- Montage player caching in `CardDetailViewModel` for re-opening preview
- Published video signed URL cache in `HomeView` state (lost on app restart)

**What is broken (from project context):**
1. Loading progress jumps from 0% to 30% -- the signed URL fetch takes time, and there is no intermediate state
2. Video freezes ~1 second before first frame renders -- streaming startup latency
3. Re-visiting a published card shows full loading cycle again -- no disk cache, signed URLs expire
4. Thumbnails at 0.5 seconds often show awkward frames -- wrong time selection for 7-second clips

---

## Table Stakes

Features users expect. Missing = product feels amateurish. These are what Instagram, TikTok, and YouTube all do that TOY currently does not.

| # | Feature | Why Expected | Complexity | Current Gap | Dependencies |
|---|---------|-------------|------------|-------------|--------------|
| T1 | **Instant replay on re-visit (disk video cache)** | Every video app caches watched videos. Re-visiting should play from disk in <200ms, not re-stream from CDN. Instagram and TikTok both cache recently watched content locally. | HIGH | No disk caching at all. Every playback streams from a new signed URL. `StorageService` only creates signed URLs, never downloads to disk. | Need `VideoCacheService` actor, LRU eviction, cache-aware player setup |
| T2 | **Thumbnail as instant placeholder (blur-up pattern)** | Professional apps show the thumbnail as a full-screen blurred placeholder, then crossfade to crisp video. TOY already loads the thumbnail via Kingfisher but only shows it small with a dark overlay and "Loading video..." text. The thumbnail should fill the frame and the video should seamlessly replace it. | LOW | Thumbnail is loaded and displayed but with unnecessary overlay text. The opacity crossfade via `isPlayerReady` already exists but the thumbnail presentation undersells it. | Existing thumbnail infrastructure, minor view refactor |
| T3 | **Eliminate progress percentage text** | No professional video app shows "47% complete". They show either the thumbnail (implying loading), a subtle spinner, or a shimmer. The numeric percentage draws attention to slowness. | LOW | `PublishedCardPlayerView` and `MontagePreviewView` both show `"\(Int(loadingProgress * 100))% complete"`. | None -- removal only |
| T4 | **`automaticallyWaitsToMinimizeStalling = false`** | Apple's own WWDC 2016 session 503 recommends this for faster startup. When true (the default), AVPlayer waits to buffer enough to guarantee no stalls before starting playback. For 7-second clips, this adds noticeable delay. Setting to false starts playback immediately once any data is available. | LOW | `PublishedCardPlayerView` never sets this. `ClipPreviewSheet` already sets it to `false`. `MontagePreviewView` uses `true` (intentionally for queue transitions). | None -- one-line change for single-video playback |
| T5 | **Better thumbnail frame selection** | 0.5 seconds into a 7-second clip is often before the person is composed. Professional apps use 1-2 seconds in or let users select. For a greeting card where someone is speaking to camera, ~1.5 seconds captures a natural smile. | LOW | `RecordingViewModel.generateThumbnail()` hardcodes `CMTime(seconds: 0.5, preferredTimescale: 600)`. Only need to change the time constant. Existing thumbnails would need regeneration for already-uploaded clips. | None for new clips. Backfill migration for existing clips is optional. |
| T6 | **Signed URL refresh/management** | Signed URLs expire after 1 hour (the `expiresIn: 3600` default). If a user opens the app after 1 hour, cached signed URLs are stale. Apps should detect expiry and refresh transparently. | MEDIUM | `cachedSignedURLs` in `CardDetailViewModel` is memory-only with no TTL tracking. `publishedVideoURLCache` in `HomeView` is also memory-only. No expiry detection. | Need timestamp tracking per cached URL, auto-refresh logic |
| T7 | **Smooth loading transition (no black flash)** | Between thumbnail and video, there should be zero black frames. The current implementation uses opacity toggle on `isPlayerReady` but there is a moment where the player layer exists but has not rendered its first frame. | LOW | The `PlayerLayerView` observes `isReadyForDisplay` which should handle this, but the thumbnail has a dark overlay that disappears abruptly. The transition needs to be a seamless crossfade. | Refine existing opacity animation, ensure thumbnail stays visible until first video frame renders |

---

## Differentiators

Features that would elevate TOY above a basic video player. Not expected for v1 quality, but create a polished premium feel.

| # | Feature | Value Proposition | Complexity | Notes |
|---|---------|------------------|------------|-------|
| D1 | **Preload video on card list (prefetch before tap)** | When user sees a published card in the grid, begin downloading the first ~500KB of video data in the background. By the time they tap, the first few seconds are cached and playback starts instantly. Instagram does this for the first 2-3 videos in feed. | HIGH | Requires the disk cache from T1 plus a prefetch coordinator that respects bandwidth. Only prefetch over WiFi or when battery is sufficient. Must be careful not to waste data. For TOY's use case (small number of published cards per user), this is very feasible. |
| D2 | **Adaptive thumbnail generation (multiple candidates)** | Generate 3 thumbnail candidates (0.5s, 1.5s, 3.5s) during upload and store the "best" one (highest clarity/face detection score). Or let the host pick from candidates. | MEDIUM | Requires generating multiple thumbnails, scoring them (even simple sharpness/contrast heuristics help), and potentially UI for selection. Could use Vision framework for face detection to prefer frames with faces. |
| D3 | **Video prefetch for montage clips** | In `MontagePreviewView`, download all clip URLs in parallel before creating the `AVQueuePlayer`. Currently clips stream one at a time which can cause gaps between clips. Pre-downloading the small 7-second clips (each ~2-5MB) eliminates inter-clip buffering entirely. | MEDIUM | Already partially implemented -- `setupQueuePlayer()` fetches signed URLs in parallel. But the actual video data still streams. Downloading to disk first, then playing from local file URLs, would eliminate all network stalls during montage playback. |
| D4 | **Background audio session configuration** | Configure `AVAudioSession` for `.playback` category so video audio plays correctly when the device is in silent mode and when other audio is happening. | LOW | Not visible in current code. Without this, video may play silently if the device ringer switch is off. Standard for any video app. |
| D5 | **Seek-to-zero optimization for looping** | Current looping uses `NotificationCenter` for `AVPlayerItemDidPlayToEndTime` then `seek(to: .zero)` + `play()`. This causes a visible gap at the loop point. Using `AVPlayerLooper` with a template item eliminates the gap entirely for seamless looping. | LOW | `PublishedCardPlayerView` and `ClipPreviewSheet` both use the notification pattern. `AVPlayerLooper` is available since iOS 10 and designed exactly for this purpose. |
| D6 | **Placeholder shimmer animation** | Instead of a static thumbnail overlay during loading, use a subtle shimmer/wave animation over the thumbnail. Reduces perceived loading time by ~40% according to UX research. | LOW | SwiftUI's `.redacted(reason: .placeholder)` modifier or a custom shimmer overlay. Very small code change. |

---

## Anti-Features

Features to explicitly NOT build. Common mistakes in video app development that would waste effort or hurt UX for TOY's specific use case.

| Anti-Feature | Why Avoid | What to Do Instead |
|-------------|-----------|-------------------|
| **HLS / Adaptive bitrate streaming** | HLS is for long-form content where quality adaptation matters. TOY's videos are 7-second clips at a single resolution. HLS adds complexity (transcoding pipeline, manifest files) for zero benefit. The clips are small enough (~2-5MB) to download entirely in <1 second on modern connections. | Keep simple MP4/MOV files in Supabase Storage. Download-to-cache for instant replay. |
| **Custom video player controls** | TOY videos auto-play and loop. Adding play/pause buttons, scrub bars, and volume controls adds visual noise to a full-screen immersive experience. Users do not need to scrub a 7-second clip. | Keep the minimal chrome. The only controls should be dismiss and details panel. |
| **CDN / video transcoding service (Mux, Cloudflare Stream)** | These are designed for scale (millions of views, adaptive bitrate, analytics). TOY is a personal greeting card app with ~5-20 views per video. The complexity and cost of a video platform is not justified. | Keep Supabase Storage. If egress costs become an issue, consider Cloudflare R2 (S3-compatible, free egress) as a simple storage swap. |
| **Aggressive prefetching of all videos** | Pre-downloading all published cards on app launch wastes bandwidth and battery. Most users have 1-5 published cards, but the ones they watch are predictable (most recent). | Prefetch only the most recently published card (if any). Cache others on first watch. |
| **In-memory video data caching** | Caching entire video files in RAM (NSCache) for 7-second clips sounds appealing but 5 videos at ~3MB each = 15MB of RAM. iOS will purge this aggressively under memory pressure, and the cache is lost on app restart anyway. | Use disk cache (FileManager + Caches directory). iOS manages the Caches directory and can purge it under storage pressure, but it persists across app launches. |
| **Complex buffer progress UI** | The current buffer progress observation (`loadedTimeRanges` KVO) drives a percentage display. This is over-engineered for the UX -- no user cares about buffer percentage. The complexity of the observation code is not justified by the UX it enables. | Remove the percentage display. Show thumbnail until ready, then crossfade. If loading takes >2 seconds, show a subtle spinner over the thumbnail. |
| **Background video downloads** | URLSession background download tasks that continue when the app is suspended. Unnecessary for 7-second clips that download in <1 second on any reasonable connection. | Download in the foreground with a standard URLSession data task. |

---

## Feature Dependencies

```
T4 (automaticallyWaitsToMinimizeStalling) -- no dependencies, immediate win

T3 (remove % text) -- no dependencies, immediate win
    |
    v
T2 (blur-up thumbnail) -- depends on T3 being gone
    |
    v
T7 (smooth crossfade) -- depends on T2 thumbnail strategy

T5 (better thumbnail time) -- no dependencies, immediate win for new clips

T1 (disk video cache) -- most complex, independent
    |
    +-- T6 (signed URL management) -- natural companion to T1
    |
    +-- D1 (prefetch on card list) -- depends on T1 cache infrastructure
    |
    +-- D3 (montage clip prefetch) -- depends on T1 cache infrastructure

D5 (AVPlayerLooper) -- no dependencies, independent

D4 (audio session) -- no dependencies, independent

D6 (shimmer) -- no dependencies, can combine with T2
```

---

## MVP Recommendation

For the immediate milestone, prioritize in this order:

### Wave 1: Quick Wins (1-2 days, massive perceived improvement)
1. **T4** - Set `automaticallyWaitsToMinimizeStalling = false` for published card player
2. **T3** - Remove percentage text from loading overlays
3. **T5** - Change thumbnail time from 0.5s to 1.5s (for new clips)
4. **T2** - Full-bleed thumbnail with seamless crossfade (refine existing code)
5. **T7** - Polish the thumbnail-to-video transition
6. **D4** - Audio session configuration (if not already done elsewhere)
7. **D5** - Replace notification-based looping with `AVPlayerLooper`

### Wave 2: Core Infrastructure (3-5 days, eliminates re-loading on revisit)
1. **T1** - Build `VideoCacheService` with disk LRU cache
2. **T6** - Signed URL refresh with TTL tracking
3. **D6** - Shimmer animation on loading placeholder

### Wave 3: Premium Polish (2-3 days, Instagram-level smoothness)
1. **D1** - Prefetch most recent published card video on app launch
2. **D3** - Download montage clips to disk before queue player creation

**Defer to future milestones:**
- D2 (adaptive thumbnail candidates): Nice but not critical for playback quality
- Any streaming infrastructure changes: Current architecture is fine for TOY's scale

---

## Detailed Technical Notes

### T1: Disk Video Cache Architecture

The cache should be a standalone `VideoCacheService` actor with this interface:

- `cachedFileURL(for remoteURL: URL) -> URL?` -- check if cached
- `download(from remoteURL: URL) -> URL` -- download and cache, return local file URL
- `evictIfNeeded()` -- LRU eviction when total cache exceeds limit (e.g., 200MB)

Storage location: `FileManager.default.urls(for: .cachesDirectory)` + `/video-cache/`. The Caches directory is the correct iOS location -- the system can purge it under storage pressure, but it persists across app launches and is not backed up to iCloud.

For TOY's 7-second videos (~2-5MB each), a 200MB cache holds ~40-100 videos. Most users will never hit this limit.

The player setup changes from:
```
AVPlayerItem(url: signedURL)  // streams from network
```
to:
```
if let localURL = videoCacheService.cachedFileURL(for: signedURL) {
    AVPlayerItem(url: localURL)  // instant playback from disk
} else {
    // download first, then play from disk
    let localURL = await videoCacheService.download(from: signedURL)
    AVPlayerItem(url: localURL)
}
```

Playing from a local file URL eliminates all network latency, buffering, and the `isReadyForDisplay` delay. Playback starts in <100ms from a local file.

### T4: The Single Most Impactful One-Line Change

In `PublishedCardPlayerView.loadVideo()`, after creating the AVPlayer:

```swift
let avPlayer = AVPlayer(playerItem: playerItem)
avPlayer.automaticallyWaitsToMinimizeStalling = false  // ADD THIS
avPlayer.play()
```

This tells AVPlayer: "Start playing as soon as you have any buffered data, don't wait to guarantee stall-free playback." For a 7-second clip on a modern connection, this alone can cut perceived startup time from ~2 seconds to ~500ms.

### D5: AVPlayerLooper for Seamless Loops

Replace the current notification-based loop pattern:
```swift
// Current (has visible gap at loop point)
NotificationCenter.default.addObserver(
    forName: .AVPlayerItemDidPlayToEndTime, ...) { _ in
    avPlayer.seek(to: .zero)
    avPlayer.play()
}
```

With `AVPlayerLooper`:
```swift
// Seamless looping (no gap)
let loopPlayer = AVQueuePlayer()
let templateItem = AVPlayerItem(url: videoURL)
let looper = AVPlayerLooper(player: loopPlayer, templateItem: templateItem)
loopPlayer.play()
// Keep strong reference to looper
```

`AVPlayerLooper` pre-buffers the loop transition, eliminating the visible pause.

### T6: Signed URL TTL Management

Signed URLs expire after `expiresIn` seconds (currently 3600 = 1 hour). The cache should store:
```swift
struct CachedSignedURL {
    let url: URL
    let createdAt: Date
    let expiresIn: TimeInterval

    var isExpired: Bool {
        Date().timeIntervalSince(createdAt) > (expiresIn - 60) // 1 min safety margin
    }
}
```

Check expiry before using cached URL. If expired, fetch a new one. This is especially important when combined with the disk cache: the video file on disk is permanent, but the signed URL used to originally download it does not need to be re-used. The disk cache key should be based on the storage path (e.g., `{cardId}.mov`), not the signed URL (which changes every time).

---

## Sources

- [Apple: automaticallyWaitsToMinimizeStalling documentation](https://developer.apple.com/documentation/avfoundation/avplayer/automaticallywaitstominimizestalling)
- [Apple: preferredForwardBufferDuration documentation](https://developer.apple.com/documentation/avfoundation/avplayeritem/preferredforwardbufferduration)
- [Apple: AVAssetImageGenerator documentation](https://developer.apple.com/documentation/avfoundation/avassetimagegenerator)
- [Apple: Creating images from a video asset](https://developer.apple.com/documentation/avfoundation/creating-images-from-a-video-asset)
- [Shakuro: iOS AVFoundation Playback Benchmarks](https://shakuro.com/blog/ios-avfoundation-playback-benchmarks)
- [Building a Caching and Preloading AVPlayer](https://blog.iankoex.com/post/building-a-caching-and-preloading-avplayer.html)
- [AVPlayer Video Optimization (Sergey Mingalev)](https://medium.com/@sojik/avplayer-video-optimization-part-1-2a45ea002ea2)
- [CachingPlayerItem (GitHub)](https://github.com/neekeetab/CachingPlayerItem)
- [CachingPlayerItem by sukov (GitHub)](https://github.com/sukov/CachingPlayerItem)
- [Supabase: Signed URL discussion on video streaming](https://github.com/orgs/supabase/discussions/5566)
- [Skeleton loading screen design (LogRocket)](https://blog.logrocket.com/ux-design/skeleton-loading-screen-design/)
- [Efficient Caching Techniques in iOS (Medium)](https://medium.com/@adarsh.ranjan/efficient-caching-techniques-in-ios-from-beginner-to-advanced-9645acecdca5)
- [WWDC 2016 Session 503: Advances in AVFoundation Playback](https://asciiwwdc.com/2016/sessions/503)
