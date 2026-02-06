# Technology Stack: Video Playback Quality

**Project:** TOY - Group Video Greeting Card App
**Milestone:** Professional-grade video playback (Instagram/TikTok-level smoothness)
**Researched:** 2026-02-06
**Research Type:** Subsequent Milestone (Stack dimension only)

---

## Executive Summary

TOY's current video playback infrastructure has four separate AVPlayer+AVPlayerLayer implementations with no shared code, no disk caching, and no preloading. Videos stream directly from Supabase signed URLs every time, causing visible loading spinners and progress jumps. For 7-second clips and short montages (under 60 seconds), the optimal strategy is **download-first-then-play-from-disk** rather than streaming optimization. This is a fundamentally different approach from what TikTok/Instagram do (HLS streaming with segment caching) because TOY's videos are small enough to download entirely in under a second on any reasonable connection.

**Core recommendation:** Build a custom `VideoCacheService` using native `URLSession` + `FileManager` (no third-party caching library needed), unify the four player implementations into a single reusable `TOYVideoPlayerView`, and add a preloading pipeline that downloads upcoming videos to disk before the user navigates to them. This approach avoids new dependencies, works cleanly with Supabase signed URLs, and makes playback instant from local files.

---

## 1. What to Build (No New Dependencies)

### 1.1 Video Cache Layer (Custom, Native)

| Component | Technology | Why |
|-----------|-----------|-----|
| **Download engine** | URLSession (native) | Already available, handles background downloads, no dependency needed |
| **Disk storage** | FileManager + Caches directory | OS-managed cleanup, sandboxed, no dependency needed |
| **Memory index** | Dictionary<String, URL> (in-memory lookup) | Fast cache-hit checks without disk I/O |
| **Cache key strategy** | Storage path (e.g., `clips/{clipId}.mov`) | Stable identifier that survives signed URL rotation |
| **Eviction** | LRU by access date + size cap (500MB) | Prevents unbounded disk growth |

**Rationale -- Why NOT use a third-party video caching library:**

The third-party options (CachingPlayerItem, SZAVPlayer, KTVHTTPCache, ZPlayerCacher) all solve a different problem: streaming large videos while simultaneously caching byte ranges via `AVAssetResourceLoaderDelegate`. This is the right approach for long-form content (Netflix, YouTube) but **wrong for TOY** because:

1. **TOY's videos are tiny.** A 7-second clip at 1080p/30fps is ~2-5MB. A 5-clip montage is ~10-25MB. These download in 0.5-2 seconds on LTE. Download-first eliminates buffering entirely.
2. **AVAssetResourceLoaderDelegate requires custom URL schemes.** You must replace `https://` with a fake scheme like `cachingplayeritem://` so the delegate gets invoked. This adds complexity and breaks standard AVPlayer behavior.
3. **Signed URL expiry complicates streaming caches.** These libraries cache by URL, but Supabase signed URLs change every hour. A streaming cache would treat the same video as a cache miss every time the URL rotates. A download cache keyed by storage path avoids this entirely.
4. **Small libraries, low maintenance.** CachingPlayerItem (sukov) has ~78 GitHub stars. SZAVPlayer has similar scale. For a critical path like video playback, a 200-line custom solution you fully control is lower risk than a small third-party dependency.

**Confidence: HIGH** -- This is a well-established pattern (URLSession download + FileManager) using only Apple frameworks. No novel technology involved.

### 1.2 Unified Player Component (Refactor, No New Deps)

| Component | Technology | Why |
|-----------|-----------|-----|
| **Player view** | Single `TOYVideoPlayerView` (UIViewRepresentable) | Eliminates 4 duplicate implementations |
| **Player management** | AVPlayer with `replaceCurrentItem(with:)` | Reuses render pipeline, lower memory |
| **Looping** | AVPlayerLooper + AVQueuePlayer (for loops) | Apple's built-in looping, no manual seek-to-zero |
| **Ready-to-display** | AVPlayerLayer.isReadyForDisplay KVO | Already used in current code, reliable |
| **Queue playback** | AVQueuePlayer (montage preview) | Already used in MontagePreviewView, proven |

**Rationale -- Why unify players:**

The codebase currently has four nearly identical `UIViewRepresentable` wrappers:
- `PlayerLayerView` in PublishedCardPlayerView.swift
- `QueuePlayerUIView` in MontagePreviewView.swift
- `ClipPlayerUIView` in ClipPreviewSheet.swift
- `PlayerUIView` in VideoPreviewView.swift (TOYShared)

All four do the same thing: wrap AVPlayerLayer in a UIView with `.resizeAspectFill` gravity and optional `isReadyForDisplay` observation. This duplication means bug fixes and performance optimizations must be applied four times. A single component with configuration options (looping, queue mode, ready callback) replaces all four.

**Confidence: HIGH** -- Pure refactoring of existing code. No new technology.

### 1.3 Preloading Pipeline (Custom, Native)

| Component | Technology | Why |
|-----------|-----------|-----|
| **Signed URL prefetch** | Existing `StorageService.createSignedURL()` | Already exists, just needs earlier invocation |
| **Video download** | URLSession.shared.download(from:) | Native async/await API, returns temp file URL |
| **Trigger points** | HomeView card list load, CardDetail open | Download videos user is likely to view next |
| **Concurrency control** | TaskGroup with max 3 concurrent downloads | Prevents bandwidth saturation |

**Rationale -- Where Instagram/TikTok lessons apply:**

The key insight from Instagram/TikTok architecture is **prefetching in the scroll direction**. For TOY, this translates to:

1. When HomeView loads, prefetch signed URLs for all cards with clips (already partially done in CardDetailViewModel).
2. When a card is tapped (CardDetailView opens), immediately begin downloading all clip videos to disk cache.
3. When montage preview opens, videos are already cached -- instant playback.
4. When published card is viewed, check cache first. If cached, play from disk. If not, download then play.

The existing `cachedSignedURLs` dictionary in `CardDetailViewModel` is a good start but only caches URLs (not video data). The new pipeline caches the actual video files.

**Confidence: HIGH** -- Standard URLSession download pattern. The challenge is orchestration, not technology.

### 1.4 Thumbnail Optimization (Leverage Existing Kingfisher)

| Component | Technology | Why |
|-----------|-----------|-----|
| **Remote thumbnails** | Kingfisher (already in project, v8.x) | Disk + memory cache built-in, already integrated |
| **Local thumbnails** | AVAssetImageGenerator (native) | Generate from cached video files, no network needed |
| **Placeholder** | Kingfisher's `.placeholder` modifier | Already used in codebase |

**Rationale:**

Kingfisher already handles thumbnail caching well. The only addition is generating thumbnails locally from cached video files using `AVAssetImageGenerator`, which avoids a network round-trip for thumbnail signed URLs when the video is already on disk. Use `generator.maximumSize = CGSize(width: 400, height: 710)` to avoid generating full-resolution thumbnails.

**Confidence: HIGH** -- Kingfisher is mature (8.x, 10 years, 23k+ stars). AVAssetImageGenerator is stable native API.

---

## 2. Recommended Stack Additions Summary

### New Components (Zero New Dependencies)

| Component | What It Is | Where It Lives |
|-----------|-----------|---------------|
| `VideoCacheService` | Actor-based disk cache for video files | `TOYShared/Sources/TOYShared/Services/` |
| `TOYVideoPlayerView` | Unified UIViewRepresentable player | `TOYShared/Sources/TOYShared/Recording/UI/` |
| `VideoPreloadManager` | Coordinates prefetch and download | `TOYShared/Sources/TOYShared/Services/` |
| `SignedURLManager` | Caches and refreshes signed URLs | `TOYShared/Sources/TOYShared/Services/` |

### Existing Dependencies (No Changes)

| Package | Version | Role in This Milestone |
|---------|---------|----------------------|
| Kingfisher | 8.x (already installed) | Thumbnail caching (already works) |
| supabase-swift | 2.x (already installed) | Signed URL generation (already works) |
| AVFoundation | Native (iOS 18.2+) | Player, thumbnail generation |

### Explicitly NOT Adding

| Library | Why Not |
|---------|---------|
| **CachingPlayerItem** (sukov, ~78 stars) | Solves streaming-while-caching for large videos. TOY's videos are small enough to download-first. Custom URL scheme requirement adds complexity. Signed URL rotation breaks URL-based cache keys. |
| **SZAVPlayer** (~similar scale) | Same streaming-cache approach. CocoaPods-primary distribution. Unnecessary complexity for short videos. |
| **KTVHTTPCache** | Objective-C, designed for HLS segment caching. Wrong level of abstraction for TOY's simple .mov files. |
| **VIMediaCache** | Objective-C, similar streaming-cache approach. Not actively maintained. |
| **Nuke** (for video frames) | Image loading library. Kingfisher already handles thumbnails. Adding a second image library creates confusion. |
| **Any HLS infrastructure** | TOY serves .mov files via signed URLs, not HLS streams. Converting to HLS would add server-side complexity for marginal benefit on sub-60-second videos. |

---

## 3. Architecture of Key New Components

### 3.1 VideoCacheService

```
Role: Download, store, and retrieve video files from disk
Pattern: Actor (thread-safe, matches existing StorageService pattern)
Cache location: FileManager.default.urls(for: .cachesDirectory)/"VideoCache"
Cache key: SHA256 hash of storage path (e.g., "clips/{uuid}.mov")
Max size: 500MB with LRU eviction
File format: .mov (same as uploaded, no transcoding)
```

**Integration with Supabase signed URLs:**

The critical insight is separating the **cache key** (stable storage path like `clips/abc123.mov`) from the **download URL** (ephemeral signed URL that expires in 1 hour). When checking the cache, use the storage path. When downloading, use the current signed URL. This means a video cached from yesterday's signed URL is still a valid cache hit today.

```
Lookup flow:
1. videoCacheService.cachedFileURL(for: "clips/abc123.mov")
2. If hit: return local file URL -> AVPlayer plays instantly from disk
3. If miss: download from signed URL -> save to cache -> return local file URL
```

### 3.2 TOYVideoPlayerView

```
Role: Single reusable SwiftUI video player component
Replaces: PlayerLayerView, QueuePlayerUIView, ClipPlayerUIView, PlayerUIView
Configuration options:
  - videoSource: .localFile(URL) | .remoteURL(URL) | .playerItem(AVPlayerItem)
  - playbackMode: .once | .loop | .queue([URL])
  - gravity: .resizeAspectFill (default) | .resizeAspect
  - onReadyToDisplay: (() -> Void)?
  - onPlaybackFinished: (() -> Void)?
```

### 3.3 VideoPreloadManager

```
Role: Coordinate background downloads for videos user will likely view
Pattern: Actor with priority queue
Trigger points:
  1. HomeView appears -> preload first clip thumbnail + signed URLs
  2. Card tapped -> preload all clip videos for that card
  3. Published card appears in list -> preload montage video
Concurrency: max 3 concurrent downloads via TaskGroup
Cancellation: cancel preloads when user navigates away
```

### 3.4 SignedURLManager

```
Role: Cache signed URLs with TTL awareness, batch refresh
Pattern: Actor
TTL tracking: Store (signedURL, createdAt) tuples
Refresh threshold: Refresh if URL is > 45 minutes old (15-min buffer before 1-hour expiry)
Batch operations: Refresh all URLs for a card's clips in one call
```

---

## 4. AVPlayer Configuration Recommendations

These are settings to apply in the unified player component based on research.

### For Cached (Local File) Playback

```swift
// Playing from disk -- no network buffering needed
player.automaticallyWaitsToMinimizeStalling = false
playerItem.preferredForwardBufferDuration = 0  // Not relevant for local files
```

### For Network Playback (Fallback When Not Cached)

```swift
// Streaming from signed URL -- optimize for fast start
player.automaticallyWaitsToMinimizeStalling = false  // Start immediately, don't wait for buffer
playerItem.preferredForwardBufferDuration = 3  // Buffer 3 seconds ahead (half a clip)
playerItem.canUseNetworkResourcesForLiveStreamingWhilePaused = false
```

### Player Instance Management

```swift
// Reuse players -- do NOT create new AVPlayer per video
// The system has a limited number of "render pipelines"
// (player + playerItem associations). Creating too many causes:
// - Memory pressure
// - GPU/CPU overhead
// - Potential system-level throttling

// GOOD: Reuse player
existingPlayer.replaceCurrentItem(with: newItem)

// BAD: Create new player per video
let newPlayer = AVPlayer(playerItem: newItem)  // Avoid in repeated contexts
```

### Looping (Replace Manual NotificationCenter Pattern)

```swift
// Current codebase uses NotificationCenter .AVPlayerItemDidPlayToEndTime + seek(.zero)
// Better: Use AVPlayerLooper for seamless looping without seek gap
let templateItem = AVPlayerItem(url: localFileURL)
let queuePlayer = AVQueuePlayer()
let looper = AVPlayerLooper(player: queuePlayer, templateItem: templateItem)
// looper must be retained as a stored property
```

**Confidence: HIGH** -- All settings are from Apple's official AVPlayer documentation.

---

## 5. Signed URL Strategy

The 1-hour signed URL expiry creates a unique caching challenge. Here is the recommended approach:

### Cache Key Design

| What | Cache Key | Why |
|------|-----------|-----|
| **Video files on disk** | Storage path hash (e.g., SHA256 of `clips/{uuid}.mov`) | Stable across URL rotations. Same video = same key regardless of signed URL. |
| **Signed URLs in memory** | Storage path string | Fast lookup. TTL-tracked so we know when to refresh. |
| **Thumbnails** | Storage path (Kingfisher custom key) | Already handled by Kingfisher with custom cache key support. |

### URL Lifecycle

```
1. Card loads -> SignedURLManager generates/caches signed URLs (1-hour TTL)
2. User views video -> VideoCacheService checks disk cache by storage path
3a. CACHE HIT: Play from local file. No signed URL needed at all.
3b. CACHE MISS: Use signed URL to download -> save to disk cache -> play from disk
4. After 45 minutes -> SignedURLManager proactively refreshes URLs for visible cards
5. Video file stays in disk cache indefinitely (until LRU eviction at 500MB cap)
```

**Key insight:** Once a video is downloaded to disk, the signed URL is irrelevant. The file lives in the cache keyed by storage path. This means frequently viewed videos load instantly regardless of URL expiry.

---

## 6. What This Stack Enables (Playback Timeline)

### Current State (No Cache)

```
User taps "View Card" ->
  [200-500ms] Fetch signed URL from Supabase
  [0ms] Create AVPlayerItem with remote URL
  [500-3000ms] AVPlayer buffers from network (progress jumps: 10%...30%...80%...100%)
  [100-300ms] AVPlayerLayer renders first frame
  Total: 800ms - 3.8 seconds of loading spinner
```

### Target State (With Cache)

```
WARM CACHE (video previously viewed or preloaded):
User taps "View Card" ->
  [0ms] VideoCacheService returns local file URL (in-memory lookup)
  [0ms] Create AVPlayerItem with file:// URL
  [50-100ms] AVPlayerLayer renders first frame (disk I/O only)
  Total: 50-100ms -- appears instant

COLD CACHE (first view, not preloaded):
User taps "View Card" ->
  [200-500ms] Fetch signed URL (or use cached signed URL: 0ms)
  [500-2000ms] Download video to disk cache
  [50-100ms] AVPlayerLayer renders first frame from disk
  Total: 750ms - 2.6 seconds
  Note: Still faster because playing from disk eliminates streaming stalls

PRELOADED (video downloaded in background while user was on HomeView):
User taps "View Card" ->
  Same as warm cache: 50-100ms
```

---

## 7. Integration Points with Existing Code

### StorageService (Existing -- Minor Extension)

Current: `createSignedURL(path:)` and `createSignedVideoURL(path:)`
Change: These remain as-is. The new `SignedURLManager` wraps them with TTL caching.

### CardDetailViewModel (Existing -- Replace URL Cache)

Current: `cachedSignedURLs: [UUID: URL]` caches signed URLs only.
Change: Replace with `VideoCacheService` integration. Instead of caching URLs, cache actual video files. The ViewModel calls `videoCacheService.getVideo(storagePath:signedURL:)` which returns a local file URL.

### HomeView (Existing -- Add Preload Triggers)

Current: Fetches cards and thumbnails on appear.
Change: After fetching card data, trigger `VideoPreloadManager.preloadThumbnails(for: cards)` and `VideoPreloadManager.preloadSignedURLs(for: cards)`. When user taps a card, trigger `VideoPreloadManager.preloadClipVideos(for: card)`.

### MontagePreviewView (Existing -- Simplify)

Current: Complex `setupQueuePlayer()` that fetches signed URLs, creates AVPlayerItems, observes buffering.
Change: Simplify to: get local file URLs from cache -> create AVQueuePlayer with local file items -> play immediately. The buffering observation and progress tracking become unnecessary for cached files.

### PublishedCardPlayerView (Existing -- Simplify)

Current: Fetches signed URL, streams with progress tracking, KVO buffer observation.
Change: Check cache first. If cached, play from disk (no progress UI needed). If not cached, download with progress -> play from disk.

---

## 8. Risk Assessment

| Risk | Severity | Mitigation |
|------|----------|------------|
| **Disk space pressure** | Medium | 500MB cap with LRU eviction. iOS purges Caches directory when disk is low (only when app is not running). |
| **Stale cache after video re-upload** | Low | Videos in TOY are immutable once uploaded. Re-publishing creates a new storage path. Old cache entries naturally evict via LRU. |
| **Concurrent access to cache** | Low | Actor isolation on VideoCacheService prevents data races. Same pattern as existing StorageService. |
| **Background download interruption** | Low | URLSession download tasks can resume. For 2-5MB files, interruption is unlikely. Fallback: stream from signed URL if download fails. |
| **Memory pressure from preloading** | Low | Preloading writes to disk, not memory. Only the currently-playing video's AVPlayerItem is in memory. |

---

## 9. Estimated Implementation Effort

| Component | Complexity | Estimated Effort | Dependencies |
|-----------|-----------|-----------------|--------------|
| `VideoCacheService` | Medium | 1-2 days | None (native APIs) |
| `TOYVideoPlayerView` (unified) | Medium | 1-2 days | None (refactor existing code) |
| `SignedURLManager` | Low | 0.5-1 day | Existing StorageService |
| `VideoPreloadManager` | Medium | 1-2 days | VideoCacheService, SignedURLManager |
| Migrate 4 player views | Medium | 1-2 days | TOYVideoPlayerView |
| Integration + testing | Medium | 1-2 days | All above |
| **Total** | | **5-10 days** | |

---

## 10. Decision Log

| Decision | Rationale |
|----------|-----------|
| **Custom video cache over third-party library** | TOY's 7-second clips (2-5MB) are small enough to download-first. Third-party streaming caches solve the wrong problem. Custom URL scheme requirement and signed URL rotation make them actively harmful for this use case. |
| **Download-first over streaming optimization** | Sub-5MB files download faster than they buffer. Playing from disk eliminates all buffering jank. This is the single highest-impact change. |
| **Unified player component** | Four duplicated UIViewRepresentable implementations mean 4x the maintenance and 4x the bug surface. One component with configuration options is strictly better. |
| **Actor-based services** | Matches existing `StorageService` pattern. Thread safety guaranteed by Swift concurrency. No manual locking. |
| **500MB cache cap** | 7-second clip = ~3MB. 500MB holds ~160 clips or ~20 full montages. Generous enough for active use, small enough to not anger users about storage. |
| **Storage path as cache key** | Signed URLs expire and change. Storage paths are stable identifiers. This decouples cache validity from URL lifetime. |
| **No HLS conversion** | Adding HLS would require server-side transcoding infrastructure (Mux, FFmpeg). For sub-60-second videos, the complexity-to-benefit ratio is terrible. Direct .mov files with disk caching achieve the same result. |
| **AVPlayerLooper over manual seek** | Current code uses NotificationCenter + seek(.zero) for looping, which causes a brief visual stutter at the loop point. AVPlayerLooper provides seamless looping. |

---

## Sources

**Apple Documentation:**
- [AVPlayer](https://developer.apple.com/documentation/avfoundation/avplayer) -- preferredForwardBufferDuration, automaticallyWaitsToMinimizeStalling
- [AVPlayerItem](https://developer.apple.com/documentation/avfoundation/avplayeritem/preferredforwardbufferduration) -- buffer configuration
- [AVAssetImageGenerator](https://developer.apple.com/documentation/avfoundation/avassetimagegenerator) -- thumbnail generation
- [AVPlayerLooper](https://developer.apple.com/documentation/avfoundation/avplayerlooper) -- seamless looping

**Architecture Research:**
- [AVPlayer Video Optimization (Medium)](https://medium.com/@sojik/avplayer-video-optimization-part-1-2a45ea002ea2) -- buffer settings, player reuse
- [iOS Performance: AVPlayer edition (Medium)](https://medium.com/tech-romance/ios-performance-avplayer-edition-257c9575e3ea) -- render pipeline limits
- [Building TikTok: Smooth scrolling on iOS (Mux)](https://www.mux.com/blog/building-tiktok-smooth-scrolling-on-ios) -- prefetch architecture
- [How TikTok Optimizes Video Streaming](https://hw.glich.co/p/how-tiktok-optimizes-video-streaming) -- player reuse, preloading

**Caching Research:**
- [Caching in Swift (Swift by Sundell)](https://www.swiftbysundell.com/articles/caching-in-swift/) -- LRU patterns, FileManager cache
- [Multilayer Caching in Swift (Medium)](https://medium.com/@khachatur.hakobyan2023/mastering-multilayer-caching-in-ios-nscache-urlcache-filemanager-cdn-beyond-6b5e70d9fb3e) -- disk + memory strategy
- [Supabase Smart CDN](https://supabase.com/docs/guides/storage/cdn/smart-cdn) -- signed URL caching behavior

**Libraries Evaluated (Not Recommended):**
- [CachingPlayerItem (sukov)](https://github.com/sukov/CachingPlayerItem) -- ~78 stars, streaming cache via AVAssetResourceLoaderDelegate
- [SZAVPlayer](https://github.com/eroscai/SZAVPlayer) -- lightweight but streaming-focused
- [KTVHTTPCache](https://github.com/ChangbaDevs/KTVHTTPCache) -- Objective-C, HLS-focused
- [ZPlayerCacher](https://github.com/ZhgChgLi/ZPlayerCacher) -- lightweight AVAssetResourceLoaderDelegate wrapper

---

## Confidence Assessment

| Area | Confidence | Reason |
|------|------------|--------|
| Custom cache vs third-party | HIGH | Clear mismatch between library capabilities (streaming cache) and TOY's needs (download-first for short videos). Verified by examining library source and architecture. |
| Download-first strategy | HIGH | Well-established pattern for short-form content. Math checks out: 3MB / 10Mbps LTE = 0.3 seconds download time. |
| Unified player component | HIGH | Pure refactoring. All four implementations already read, differences are cosmetic. |
| AVPlayer configuration | HIGH | Settings from Apple's official documentation. Standard recommendations confirmed by multiple sources. |
| Preloading pipeline | MEDIUM | Architecture is sound but orchestration details (when exactly to trigger, priority ordering, cancellation) need phase-specific design work. |
| Cache size / eviction | MEDIUM | 500MB cap is a reasonable starting point based on video file sizes, but may need tuning based on real usage patterns. |
