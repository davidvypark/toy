# Architecture Patterns: Unified Video Playback Infrastructure

**Domain:** iOS video playback unification for Supabase-backed short-form video app
**Researched:** 2026-02-06
**Confidence:** HIGH (based on direct codebase analysis + established AVFoundation patterns)

## Current State Analysis

The app has **4 independent player implementations**, each with its own AVPlayer lifecycle, signed URL resolution, buffering logic, and UIViewRepresentable wrapper. They share zero infrastructure.

### Existing Player Inventory

| View | Player Type | URL Source | Looping | Caching | UIViewRepresentable |
|------|------------|-----------|---------|---------|---------------------|
| `PublishedCardPlayerView` | `AVPlayer` | StorageService.createSignedVideoURL (videos bucket) | Yes (NotificationCenter) | Optional cachedVideoURL from HomeView memory dict | `PlayerLayerView` / `PlayerUIView` |
| `MontagePreviewView` | `AVQueuePlayer` | StorageService.createSignedURL (clips bucket) | No (play once, replay button) | Caches player instance in CardDetailViewModel | `QueueVideoPlayer` / `QueuePlayerUIView` |
| `ClipPreviewSheet` | `AVPlayer` | StorageService.createSignedURL (clips bucket) | Yes (NotificationCenter) | Optional cachedURL from CardDetailViewModel | `ClipVideoPlayer` / `ClipPlayerUIView` |
| `VideoPreviewView` | `AVPlayer` | Local file URL | Yes (NotificationCenter) | N/A (local file) | `LoopingVideoPlayer` / `PlayerUIView` |

### Duplicated Code Across Players

1. **UIViewRepresentable wrappers** -- 4 separate implementations of nearly identical `UIView` subclasses that set `layerClass = AVPlayerLayer.self`. The `PlayerUIView`, `QueuePlayerUIView`, `ClipPlayerUIView`, and `PlayerUIView` (in TOYShared) are functionally identical except `PublishedCardPlayerView`'s version adds `isReadyForDisplay` KVO observation.

2. **Looping logic** -- 3 of 4 players use the same `NotificationCenter.addObserver(forName: .AVPlayerItemDidPlayToEndTime)` pattern with seek-to-zero-and-play, copy-pasted each time.

3. **Loading/buffering progress** -- `PublishedCardPlayerView` and `MontagePreviewView` both implement `observeBuffering(item:)` with identical KVO on `loadedTimeRanges`, identical duration-checking, identical progress-mapping math.

4. **Signed URL resolution** -- Each view independently creates `StorageService()` instances and calls `createSignedURL` / `createSignedVideoURL`. There is no centralized URL resolution with caching.

5. **Player lifecycle** -- Every view creates players in `.task`/`.onAppear` and tears them down in `.onDisappear`, with no reuse.

### Current Caching (Ad Hoc)

- `HomeView` maintains `publishedVideoURLCache: [UUID: URL]` -- in-memory dict of card ID to signed video URL, passed to `PublishedCardPlayerView` as `cachedVideoURL`
- `CardDetailViewModel` maintains `cachedSignedURLs: [UUID: URL]` -- in-memory dict of clip ID to signed URL, passed to `ClipPreviewSheet` and `MontagePreviewView`
- `CardDetailViewModel` caches the `montagePlayer: AVQueuePlayer?` instance itself for re-opening MontagePreviewView without re-fetching
- **No disk caching** of video data anywhere
- **No signed URL expiry tracking** -- URLs are cached indefinitely in memory (valid for 1 hour per StorageService default)

---

## Recommended Architecture

### Overview: Three-Layer Video Infrastructure

```
+-----------------------------------------------------------------+
|                        VIEWS (Consumers)                        |
|  PublishedCardPlayerView | MontagePreviewView | ClipPreviewSheet|
|  VideoPreviewView                                               |
|  (All use TOYVideoPlayerView for rendering)                     |
+-----------------------------------------------------------------+
          |                    |                    |
          v                    v                    v
+-----------------------------------------------------------------+
|                    VideoPlaybackService                          |
|  @Observable, @MainActor                                        |
|  - Player lifecycle (create, configure, teardown)               |
|  - Playback state (loading, ready, error, progress)             |
|  - Looping configuration                                        |
|  - Buffer progress tracking                                     |
+-----------------------------------------------------------------+
          |
          v
+-----------------------------------------------------------------+
|                     VideoURLResolver                             |
|  actor (thread-safe)                                            |
|  - Signed URL resolution with TTL-aware cache                   |
|  - Disk cache management for video data                         |
|  - Integrates with existing StorageService                      |
+-----------------------------------------------------------------+
          |
          v
+-----------------------------------------------------------------+
|                     StorageService (existing)                    |
|  actor                                                          |
|  - createSignedURL(path:) -> URL                                |
|  - createSignedVideoURL(path:) -> URL                           |
+-----------------------------------------------------------------+
```

### Component 1: TOYVideoPlayerView (Unified UIViewRepresentable)

**Purpose:** Single reusable SwiftUI view that wraps AVPlayerLayer. Replaces all 4 existing UIViewRepresentable implementations.

**What it replaces:** `PlayerLayerView`/`PlayerUIView`, `QueueVideoPlayer`/`QueuePlayerUIView`, `ClipVideoPlayer`/`ClipPlayerUIView`, `LoopingVideoPlayer`/`PlayerUIView`

**Type:** NEW component

```
TOYVideoPlayerView
  Input: AVPlayer (or AVQueuePlayer -- AVQueuePlayer is a subclass of AVPlayer)
  Input: videoGravity (default .resizeAspectFill)
  Output: onReadyForDisplay callback
  Output: onPlaybackFinished callback (optional)

  Internal:
    - UIView subclass with layerClass = AVPlayerLayer
    - KVO on playerLayer.isReadyForDisplay
    - Handles both AVPlayer and AVQueuePlayer uniformly
```

**Key design decision:** This view takes an `AVPlayer` instance, not a URL. The view is purely a rendering surface. All player creation, configuration, and URL resolution happens in the service layer. This separation means the view can be used for both remote (signed URL) and local file playback without modification.

### Component 2: VideoURLResolver (New Actor)

**Purpose:** Centralized signed URL resolution with two-tier caching (URL cache + optional disk cache for video data). Replaces the ad hoc signed URL caching in `HomeView`, `CardDetailViewModel`, and individual views.

**Type:** NEW component in `TOYShared/Sources/TOYShared/Services/`

```
actor VideoURLResolver

  Dependencies:
    - StorageService (existing, injected or created internally)

  URL Cache Layer:
    - Dictionary: [String: CachedURL]  // storage path -> (url, fetchedAt)
    - struct CachedURL { url: URL, fetchedAt: Date }
    - TTL: 50 minutes (conservative vs 60-min Supabase expiry)
    - resolveURL(path:, bucket:) async throws -> URL
      1. Check URL cache -- if present and not expired, return
      2. Call StorageService to get fresh signed URL
      3. Cache and return

  Disk Cache Layer (Phase 2):
    - Directory: FileManager.cachesDirectory/video-cache/
    - Key: SHA256 hash of storage path (stable across URL rotations)
    - resolveLocalURL(path:, bucket:) async throws -> URL
      1. Check disk cache -- if file exists, return local file URL
      2. Resolve signed URL via URL cache
      3. Download to disk cache
      4. Return local file URL
    - Cache eviction: LRU, max 500MB (configurable)
    - Files in cachesDirectory can be purged by OS under storage pressure

  Bucket Routing:
    - "clips" bucket -> StorageService.createSignedURL()
    - "videos" bucket -> StorageService.createSignedVideoURL()
    - Matches existing StorageService two-bucket design
```

**Why actor, not class:** Matches the existing `StorageService` and `CardService` pattern in the codebase. Multiple views may request URLs concurrently (e.g., MontagePreviewView resolving 5 clip URLs in parallel). Actor isolation prevents data races on the cache dictionary without manual locking.

**Why 50-minute TTL, not 60:** Supabase signed URLs expire after 3600 seconds (1 hour). A 50-minute TTL provides a 10-minute buffer so a URL fetched from cache is never served with less than 10 minutes of validity remaining. This matters because AVPlayer may not start downloading immediately -- the user could get a URL, background the app, return 8 minutes later, and the URL still needs to work.

### Component 3: VideoPlaybackService (New @Observable Service)

**Purpose:** Manages AVPlayer lifecycle, configuration, and observable state for any video playback scenario. Each view creates its own instance (not a singleton) because playback state is per-view.

**Type:** NEW component

```
@MainActor
@Observable
final class VideoPlaybackService

  Dependencies:
    - VideoURLResolver (shared singleton instance)

  Published State:
    - player: AVPlayer?
    - playbackState: PlaybackState
        // .idle, .loading(progress), .ready, .playing, .paused, .error(String)
    - loadingProgress: Double  // 0.0 to 1.0
    - isReadyForDisplay: Bool

  Configuration:
    - loopMode: LoopMode  // .none, .loop, .loopQueue
    - autoPlay: Bool
    - preferredForwardBufferDuration: TimeInterval

  Core Methods:
    - loadRemoteVideo(storagePath: String, bucket: Bucket) async
        1. Set state to .loading(0)
        2. Resolve URL via VideoURLResolver
        3. Create AVPlayerItem
        4. Create or reuse AVPlayer
        5. Observe buffering progress
        6. Play if autoPlay

    - loadLocalVideo(fileURL: URL)
        1. Create AVPlayerItem from local URL
        2. Create AVPlayer
        3. Play if autoPlay

    - loadQueue(storagePaths: [String], bucket: Bucket) async
        1. Resolve all URLs via VideoURLResolver (concurrent)
        2. Create AVPlayerItems with preferredForwardBufferDuration
        3. Create AVQueuePlayer
        4. Configure actionAtItemEnd

    - cleanup()
        1. Pause player
        2. Remove all observers
        3. Set player to nil

  Internal:
    - KVO observers for loadedTimeRanges (buffer progress)
    - NotificationCenter observer for AVPlayerItemDidPlayToEndTime
    - Handles looping logic internally based on loopMode
```

**Why per-view instances, not a singleton:** Each player view needs independent state (its own AVPlayer, its own loading progress, its own error state). A singleton would conflate state across screens. The shared resource is `VideoURLResolver` (the cache), not the playback service.

**Why @Observable, not ObservableObject:** The existing codebase uses `@Observable` (Swift 5.9 Observation framework) throughout -- `CardDetailViewModel`, `AuthViewModel`, `PublishViewModel` all use this pattern. `@Observable` provides finer-grained updates than `ObservableObject`'s `objectWillChange`.

---

## Integration Points with Existing Components

### Integration Map

```
EXISTING                          NEW                         HOW
-------                          ---                         ---
StorageService (actor)      -->  VideoURLResolver            Wraps, adds caching
CardDetailViewModel         -->  VideoURLResolver            Remove cachedSignedURLs dict,
                                                             remove montagePlayer cache
HomeView                    -->  VideoURLResolver            Remove publishedVideoURLCache dict
PublishedCardPlayerView     -->  VideoPlaybackService        Replace manual AVPlayer + observer code
                            -->  TOYVideoPlayerView          Replace PlayerLayerView
MontagePreviewView          -->  VideoPlaybackService        Replace manual AVQueuePlayer + observer code
                            -->  TOYVideoPlayerView          Replace QueueVideoPlayer
ClipPreviewSheet            -->  VideoPlaybackService        Replace manual AVPlayer + observer code
                            -->  TOYVideoPlayerView          Replace ClipVideoPlayer
VideoPreviewView            -->  VideoPlaybackService        Replace manual AVPlayer code
                            -->  TOYVideoPlayerView          Replace LoopingVideoPlayer
```

### What Gets Removed from Existing Files

**CardDetailViewModel** (MODIFY):
- Remove `cachedSignedURLs: [UUID: URL]` property
- Remove `montagePlayer: AVQueuePlayer?` property
- Remove `montageSignedURLs: [URL]` property
- Remove `isMontageReady: Bool` property
- Remove `getSignedURL(for:)` method
- Remove `prefetchSignedURLs()` method
- Keep all non-video state (participants, clips, profiles, loading, errors)

**HomeView** (MODIFY):
- Remove `publishedVideoURLCache: [UUID: URL]` state
- Remove `onVideoURLLoaded` callback passing
- Remove `cachedVideoURL` parameter passing to PublishedCardPlayerView

**StorageService** (NO CHANGE):
- Remains as-is. VideoURLResolver wraps it; does not modify it.

**CardService** (NO CHANGE):
- No video playback concerns.

### Data Flow: Loading a Published Card Video

```
User taps published card in HomeView
  |
  v
HomeView presents PublishedCardPlayerView(card: card)
  |  (no more cachedVideoURL parameter needed)
  |
  v
PublishedCardPlayerView.task:
  let service = VideoPlaybackService()
  service.loopMode = .loop
  service.autoPlay = true
  await service.loadRemoteVideo(
    storagePath: card.videoUrl!,
    bucket: .videos
  )
  |
  v
VideoPlaybackService.loadRemoteVideo():
  playbackState = .loading(0)
  let url = try await VideoURLResolver.shared.resolveURL(
    path: storagePath,
    bucket: .videos
  )
  |
  v
VideoURLResolver.resolveURL():
  // Check cache: is there a CachedURL for this path with fetchedAt < 50min ago?
  if let cached = urlCache[path], !cached.isExpired { return cached.url }
  // Cache miss: call StorageService
  let url = try await storageService.createSignedVideoURL(path: path)
  urlCache[path] = CachedURL(url: url, fetchedAt: Date())
  return url
  |
  v
VideoPlaybackService (continued):
  let item = AVPlayerItem(url: url)
  // Set up KVO on loadedTimeRanges -> update loadingProgress
  let player = AVPlayer(playerItem: item)
  self.player = player
  player.play()
  // KVO on playerLayer.isReadyForDisplay -> set isReadyForDisplay = true
  // NotificationCenter on .AVPlayerItemDidPlayToEndTime -> seek to zero, replay
```

### Data Flow: Loading a Montage Preview (Multi-Clip Queue)

```
User taps "Preview Full Video" in CardDetailView
  |
  v
MontagePreviewView.task:
  let service = VideoPlaybackService()
  service.loopMode = .none  // plays once, shows replay button
  service.autoPlay = true
  let paths = sortedClips.map(\.videoUrl)
  await service.loadQueue(storagePaths: paths, bucket: .clips)
  |
  v
VideoPlaybackService.loadQueue():
  playbackState = .loading(0)
  // Resolve all URLs concurrently
  let urls = try await withTaskGroup { group in
    for (i, path) in paths.enumerated() {
      group.addTask {
        (i, try await VideoURLResolver.shared.resolveURL(path: path, bucket: .clips))
      }
    }
    // Collect, sort by index, update progress
  }
  // Create AVPlayerItems with preferredForwardBufferDuration = 5
  // Create AVQueuePlayer(items:)
  // actionAtItemEnd = .advance
  // Observe last item for playback end
```

### Data Flow: Loading a Clip Preview

```
User taps clip thumbnail in CardDetailView
  |
  v
ClipPreviewSheet.task:
  let service = VideoPlaybackService()
  service.loopMode = .loop
  service.autoPlay = true
  await service.loadRemoteVideo(
    storagePath: clip.videoUrl,
    bucket: .clips
  )
  // Same flow as published card, just different bucket
```

### Data Flow: Local Video Preview After Recording

```
Recording completes, VideoPreviewView appears
  |
  v
VideoPreviewView.onAppear:
  let service = VideoPlaybackService()
  service.loopMode = .loop
  service.autoPlay = true
  service.loadLocalVideo(fileURL: videoURL)
  // No network, no signed URL, just local file
```

---

## Component Boundaries

| Component | Location | Responsibility | Does NOT Do |
|-----------|----------|---------------|-------------|
| `TOYVideoPlayerView` | `TOYShared/Video/` | Render AVPlayer via AVPlayerLayer, report readyForDisplay | Create players, resolve URLs, manage state |
| `VideoPlaybackService` | `TOYShared/Video/` | Create/configure AVPlayer, manage playback state, handle looping/buffering | Cache URLs, download videos, render UI |
| `VideoURLResolver` | `TOYShared/Services/` | Cache signed URLs with TTL, resolve URLs via StorageService, (future) disk cache | Create players, manage playback state |
| `StorageService` | `TOYShared/Services/` (existing) | Generate signed URLs from Supabase | Cache anything, create players |

### Module Placement Rationale

- `VideoURLResolver` goes in `TOYShared` because it wraps `StorageService` which is already in `TOYShared`, and the App Clip (if it needs video playback) would need URL resolution.
- `TOYVideoPlayerView` and `VideoPlaybackService` go in `TOYShared` -- the App Clip already uses `RecordingView` from TOYShared, so video playback there is a natural extension.

---

## Anti-Patterns to Avoid

### Anti-Pattern 1: Singleton AVPlayer

**What:** Creating a single shared AVPlayer instance for the entire app.
**Why bad:** The app can have multiple video contexts alive simultaneously (e.g., CardDetailView has a cached montage player while ClipPreviewSheet is open as a sheet). A single player would conflict.
**Instead:** Each view gets its own `VideoPlaybackService` instance (which creates its own AVPlayer). The shared resource is the URL cache (`VideoURLResolver.shared`), not the player.

### Anti-Pattern 2: Creating New AVPlayers on Every Appear/Disappear

**What:** The current pattern -- every view creates `AVPlayer(url:)` on appear and sets `player = nil` on disappear.
**Why bad:** AVPlayer creation allocates system playback pipeline resources. iOS limits the number of concurrent pipelines. Rapidly creating/destroying players (e.g., scrolling through a list) can exhaust pipelines and cause silent failures.
**Instead:** `VideoPlaybackService` should use `player.replaceCurrentItem(with:)` when reloading the same view with different content, and only create new AVPlayer instances when a view first appears. The `cleanup()` method should properly tear down by calling `replaceCurrentItem(with: nil)` before setting player to nil, which releases the pipeline.

### Anti-Pattern 3: AVAssetResourceLoaderDelegate for Simple Signed URLs

**What:** Implementing `AVAssetResourceLoaderDelegate` with custom URL schemes to intercept and cache video downloads.
**Why bad:** Extremely complex to implement correctly, requires custom URL scheme registration, handling partial byte-range requests, and managing a download state machine. Overkill for 7-second clips that are small enough to download entirely.
**Instead:** For Phase 1, use the URL cache (signed URL TTL caching). For Phase 2, if disk caching is needed, download the file to disk first via URLSession, then play from the local file URL. This is dramatically simpler than resource loader interception.

### Anti-Pattern 4: Caching AVPlayer/AVPlayerItem Instances

**What:** The current `CardDetailViewModel.montagePlayer` pattern -- caching the entire AVQueuePlayer instance.
**Why bad:** AVPlayer instances hold significant memory (video buffers, decoded frames). Caching them means those buffers persist even when the user is on a different screen. For a montage with 5 clips, this can be tens of MB of video buffer memory sitting idle.
**Instead:** Cache the resolved URLs (cheap, just strings) and re-create the player quickly when needed. With URL caching, the "slow" part (network request for signed URL) is eliminated. AVPlayer creation from a cached/downloaded file is nearly instant.

---

## Scalability Considerations

| Concern | Current (1-5 clips) | 10+ clips | 50+ clips |
|---------|---------------------|-----------|-----------|
| Signed URL fetching | Concurrent TaskGroup, works fine | Still fine, Supabase handles it | May want to batch or throttle |
| Video memory | One player at a time, fine | Queue player buffers ahead, watch memory | Need aggressive buffer limits |
| Disk cache size | N/A (no disk cache) | ~50-100MB for 7s clips | ~500MB+, need eviction |
| URL cache entries | ~10-20 entries, trivial | ~50 entries, trivial | Still trivial, just strings |

For the current app scale (cards with 1-10 clips of 7 seconds each), the architecture is deliberately straightforward. The main scalability lever is the disk cache (Phase 2), which can be added without changing the player views at all -- only `VideoURLResolver` needs to be extended.

---

## Suggested Build Order

### Phase 1: Foundation (builds from bottom of stack up)

Build order matters because of dependencies. Start from the bottom of the stack and work up.

**Step 1: TOYVideoPlayerView**
- Unified UIViewRepresentable
- Supports both AVPlayer and AVQueuePlayer
- `isReadyForDisplay` KVO callback
- No dependencies on new code -- can be tested immediately
- **Why first:** This is the simplest piece, can be verified visually, and unblocks refactoring individual views.

**Step 2: VideoURLResolver**
- Actor wrapping StorageService
- URL cache with 50-minute TTL
- Bucket routing (clips vs videos)
- **Why second:** Depends on nothing new. Can be unit tested with mock StorageService.

**Step 3: VideoPlaybackService**
- @Observable service with player lifecycle management
- Loading progress tracking
- Looping modes
- **Why third:** Depends on VideoURLResolver. Can be tested by wiring to one view at a time.

### Phase 2: View Migration (one view at a time)

Migrate one view at a time, keeping old implementations working until each is replaced.

**Step 4: Migrate VideoPreviewView first**
- Simplest player (local file, no signed URLs)
- Tests that TOYVideoPlayerView + VideoPlaybackService work for the basic case
- Low risk -- this view is already the simplest and "works fine"

**Step 5: Migrate ClipPreviewSheet**
- Adds signed URL resolution (single remote video)
- Tests VideoURLResolver integration
- Medium complexity

**Step 6: Migrate PublishedCardPlayerView**
- Uses videos bucket (not clips bucket) -- tests bucket routing
- Has the most complex loading overlay (thumbnail + progress)
- Remove HomeView's `publishedVideoURLCache`

**Step 7: Migrate MontagePreviewView**
- Most complex: AVQueuePlayer, multi-clip, replay logic
- Remove CardDetailViewModel's montage player caching
- Tests loadQueue() flow end-to-end

### Phase 3: Disk Cache (Optional, later milestone)

**Step 8: Add disk caching to VideoURLResolver**
- Download-to-cache-then-play flow
- LRU eviction with configurable max size
- Only needed if video load times are still too slow after URL caching

### Dependency Graph

```
TOYVideoPlayerView (no dependencies)
       |
       v
VideoURLResolver (depends on StorageService -- existing)
       |
       v
VideoPlaybackService (depends on VideoURLResolver, uses TOYVideoPlayerView indirectly)
       |
       v
View Migrations (depend on all three above)
  VideoPreviewView -> ClipPreviewSheet -> PublishedCardPlayerView -> MontagePreviewView
```

---

## File Structure

```
TOYShared/Sources/TOYShared/
  Services/
    StorageService.swift          (existing, no changes)
    VideoURLResolver.swift        (NEW)
  Video/
    TOYVideoPlayerView.swift      (NEW)
    VideoPlaybackService.swift    (NEW)

TOY/Features/
  PublishedCard/
    PublishedCardPlayerView.swift  (MODIFY - use new infrastructure)
  Publishing/
    MontagePreviewView.swift      (MODIFY - use new infrastructure)
  CardManagement/
    ClipPreviewSheet.swift        (MODIFY - use new infrastructure)
    CardDetailViewModel.swift     (MODIFY - remove video caching state)
  Home/
    HomeView.swift                (MODIFY - remove publishedVideoURLCache)

TOYShared/Sources/TOYShared/Recording/UI/
    VideoPreviewView.swift        (MODIFY - use new infrastructure)
```

**Total new files:** 3
**Total modified files:** 6
**Total deleted files:** 0 (old UIViewRepresentable types are private to their files, removed as part of modification)

---

## Cache Invalidation Strategy for Signed URL Expiry

This is the trickiest aspect of the architecture and deserves explicit treatment.

### The Problem

Supabase signed URLs expire after 1 hour. The app caches these URLs to avoid redundant network requests. If a cached URL is served to AVPlayer after it has expired, playback will fail with an HTTP 400/403 error.

### The Strategy: Conservative TTL + Refresh-on-Error

**Layer 1: Conservative TTL (primary defense)**
- Cache entries expire after 50 minutes (not 60)
- 10-minute buffer accounts for: time between URL fetch and playback start, user backgrounding the app, slow network conditions
- When `VideoURLResolver.resolveURL()` finds a cached entry older than 50 minutes, it treats it as a cache miss and fetches fresh

**Layer 2: Refresh-on-Error (fallback defense)**
- `VideoPlaybackService` observes `AVPlayerItem.status` via KVO
- If status becomes `.failed` and the error indicates an HTTP auth/expiry error (status 400/403), it:
  1. Evicts the cached URL from VideoURLResolver
  2. Re-resolves the URL (getting a fresh signed URL)
  3. Creates a new AVPlayerItem with the fresh URL
  4. Replaces the current item on the player
  5. Resumes playback
- This handles edge cases where even the 50-minute TTL is not enough (e.g., app was suspended for 15 minutes)

**Layer 3: Proactive refresh (future enhancement)**
- If the app returns from background and the player is visible, proactively check if the current URL's cached entry is close to expiry (>45 minutes old) and refresh preemptively
- Not needed for Phase 1 -- the refresh-on-error fallback handles this adequately

### How This Replaces Current Ad Hoc Caching

Currently, `HomeView.publishedVideoURLCache` and `CardDetailViewModel.cachedSignedURLs` cache URLs indefinitely with no expiry tracking. If the user keeps the app open for more than an hour, these cached URLs silently expire and playback fails. The new architecture fixes this systematically.

---

## Sources

- [Apple AVPlayer Documentation](https://developer.apple.com/documentation/avfoundation/avplayer)
- [Apple AVAssetResourceLoaderDelegate Documentation](https://developer.apple.com/documentation/avfoundation/avassetresourceloaderdelegate)
- [Apple replaceCurrentItem(with:) Documentation](https://developer.apple.com/documentation/avfoundation/avplayer/1390806-replacecurrentitem)
- [iOS Performance -- AVPlayer edition (Medium)](https://medium.com/tech-romance/ios-performance-avplayer-edition-257c9575e3ea)
- [Mastering Multilayer Caching in Swift (Medium)](https://medium.com/@khachatur.hakobyan2023/mastering-multilayer-caching-in-ios-nscache-urlcache-filemanager-cdn-beyond-6b5e70d9fb3e)
- [Caching in Swift (Swift by Sundell)](https://www.swiftbysundell.com/articles/caching-in-swift/)
- [VIMVideoPlayer replaceCurrentItem performance discussion](https://github.com/vimeo/VIMVideoPlayer/issues/56)
- [CachingPlayerItem (GitHub)](https://github.com/sukov/CachingPlayerItem)
- [Too Many AVPlayers? (Becky Hansmeyer)](https://www.beckyhansmeyer.com/2017/08/30/too-many-avplayers/)
- Direct codebase analysis of all 4 player implementations, StorageService, CardDetailViewModel, and HomeView
