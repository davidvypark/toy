# Domain Pitfalls: iOS Video Playback Quality

**Domain:** iOS video caching, preloading, and playback optimization for SwiftUI app
**Researched:** 2026-02-06
**Applies to:** TOY - group video greeting card app (SwiftUI, iOS 18.2+)

---

## Critical Pitfalls

Mistakes that cause crashes, data loss, or require significant rework.

### Pitfall 1: Signed URL Expiry Breaks Cached AVPlayerItems

**What goes wrong:** Videos are cached (either as AVPlayerItem references or disk files keyed by URL) with signed URLs that expire after 1 hour. When the user re-opens the app or returns to a previously-viewed card, the cached player item or URL is stale. AVPlayer silently fails or shows a black screen -- the `AVPlayerItem.status` transitions to `.failed` but if you are not observing it, the user sees nothing.

**Why it happens:** The current TOY codebase caches signed URLs in `CardDetailViewModel.cachedSignedURLs` (a `[UUID: URL]` dictionary) and `HomeView.publishedVideoURLCache` with no expiry tracking. The `StorageService.createSignedURL` generates URLs valid for 3600 seconds (1 hour). If the user backgrounds the app for 61 minutes and returns, every cached URL is dead.

**Consequences:**
- Black screen on video playback with no error shown to user
- `PublishedCardPlayerView` passes `cachedVideoURL` that is expired, AVPlayer fails silently
- `MontagePreviewView` re-uses `cardViewModel?.montagePlayer` which holds expired AVPlayerItems
- User must force-quit and relaunch to recover

**Warning signs:**
- QA reports of "video worked earlier but now shows black screen"
- Intermittent playback failures that resolve after app restart
- `AVPlayerItem.status == .failed` with HTTP 403 in error domain

**Prevention:**
- Store the URL generation timestamp alongside every cached URL. Before using a cached URL, check `Date().timeIntervalSince(cachedAt) < (expiresIn - safetyMargin)` where safetyMargin is 300 seconds (5 minutes)
- For disk-cached video files, key the cache by the stable storage path (e.g., `clips/{clipId}.mov`), NOT by the signed URL. The signed URL is a transport mechanism, not an identity
- When building a video cache layer, separate the concepts: (1) "Do I have the bytes on disk?" keyed by storage path, and (2) "Do I have a valid URL to fetch the bytes?" keyed by storage path + timestamp
- Implement a `SignedURLCache` actor that wraps `StorageService` and automatically refreshes URLs that are within 5 minutes of expiry

**Detection:** Add an `AVPlayerItem.status` observer that checks for `.failed` and inspects the error's `underlyingError` for HTTP 400/403 status codes. Log these as "signed URL likely expired" events.

**Confidence:** HIGH -- directly observable in the current codebase. The `cachedSignedURLs` dictionary in `CardDetailViewModel` has zero expiry logic.

**Which phase should address it:** Phase 1 (foundation) -- this must be solved before any caching layer is built on top, because the caching layer's invalidation strategy depends on understanding URL vs. content identity.

---

### Pitfall 2: AVPlayer Render Pipeline Exhaustion (4-16 Player Limit)

**What goes wrong:** iOS has a hard limit on the number of simultaneous hardware video decode pipelines. The commonly cited limit is 4 concurrent AVPlayer-AVPlayerItem associations on older devices, up to 16 on newer devices. Exceeding this limit causes `AVPlayerItem.status` to become `.failed` with a "Cannot decode" error. No new videos will play until existing pipelines are released.

**Why it happens:** Each time you associate an `AVPlayerItem` with an `AVPlayer` (including via `init(playerItem:)` or `replaceCurrentItem(with:)`), iOS allocates a hardware decode pipeline. Setting the player to `nil` does NOT reliably release the pipeline -- you must explicitly call `replaceCurrentItem(with: nil)` or let the AVPlayer fully deallocate. In SwiftUI, view re-creation can silently allocate new players without properly releasing old ones.

**Consequences:**
- After navigating between several video screens, new videos refuse to play
- Error is cryptic ("Cannot decode") and does not suggest the root cause
- The problem is invisible during development with 1-2 test videos but surfaces when users have 5+ cards

**Warning signs:**
- "Cannot decode" errors in AVPlayerItem status observer
- Videos that played fine earlier suddenly fail to play in the same session
- Problem worsens as user navigates between more card views

**Prevention:**
- Always call `player.replaceCurrentItem(with: nil)` before setting `player = nil` in cleanup (the current `PublishedCardPlayerView.onDisappear` does this correctly, but `ClipPreviewSheet.cleanupPlayer` only sets `player = nil` without calling `replaceCurrentItem(with: nil)` first)
- Maintain a maximum of 1-2 active AVPlayer instances app-wide. Use a singleton player manager that reuses a single AVPlayer by swapping items rather than creating new player instances
- In `MontagePreviewView`, the pattern of caching `montagePlayer` in the view model is dangerous because it keeps a decode pipeline allocated even when the view is not visible. Consider caching the signed URLs (or local file paths) and re-creating the player on re-open instead
- Never pre-create AVPlayerItems for "preloading" unless you are about to play them. AVPlayerItem begins buffering immediately upon creation and consumes a decode slot when associated with a player

**Detection:** Add a counter or logging around AVPlayer creation and destruction. If the count of live AVPlayer instances exceeds 3 at any point, log a warning.

**Confidence:** HIGH -- documented Apple Developer Forums constraint, multiple independent sources confirm the pipeline limit.

**Which phase should address it:** Phase 1 (foundation) -- the player management architecture must enforce this limit from the start. Retrofitting pipeline management onto an architecture that freely creates players is a rewrite.

---

### Pitfall 3: iOS 18 Swift Concurrency Actor Isolation Crash

**What goes wrong:** On iOS 18+ with Swift 6 language mode, calling `AVPlayer.replaceCurrentItem(with:)` from within an actor-isolated context (including `@MainActor` tasks or actor wrappers) can crash with "Incorrect actor executor assumption." This is a runtime crash, not a compile-time error.

**Why it happens:** Swift 6 enforces stricter actor isolation rules. AVPlayer's internal implementation makes assumptions about which executor it runs on. When you pass an AVPlayer between actors or call its methods from a `Task { @MainActor in }` block, the runtime assertion can fail.

**Consequences:**
- App crashes during video playback, specifically when swapping video items
- Crash is not reproducible under Swift 5 language mode, making it hard to diagnose
- Affects any code path that replaces the current player item

**Warning signs:**
- Crash logs mentioning "Incorrect actor executor assumption" in AVFoundation frames
- Crashes that only reproduce on iOS 18+ devices
- Crashes that appear after migrating to Swift 6 language mode

**Prevention:**
- Keep AVPlayer creation, configuration, and item replacement on the main thread using synchronous main-thread calls, not `Task { @MainActor in }`
- Do not wrap AVPlayer in a custom actor. AVPlayer is inherently main-thread-bound
- If using Swift 6 strict concurrency, ensure AVPlayer property access goes through `MainActor.assumeIsolated { }` rather than actor-hopping tasks
- The current codebase uses `await MainActor.run { }` in `PublishedCardPlayerView.loadVideo()` which should be verified against this crash pattern on iOS 18.2+
- As a fallback, Swift 5 language mode avoids this entirely

**Detection:** Test all video playback code paths on an iOS 18.2+ device with Swift 6 strict concurrency enabled. Crash will be immediate and obvious.

**Confidence:** MEDIUM -- reported on Apple Developer Forums (thread/764133) for iOS 18; the current codebase targets iOS 18.2+ so this is directly relevant, but the current code uses `await MainActor.run { }` which may or may not trigger the issue depending on the calling context.

**Which phase should address it:** Phase 1 (foundation) -- must be validated before building any new player management code.

---

### Pitfall 4: KVO Observer Crash on AVPlayer/AVPlayerItem Deallocation

**What goes wrong:** AVPlayer and AVPlayerItem use KVO (Key-Value Observing) extensively. If an observer is still registered when the observed object deallocates, the app crashes with `NSInternalInconsistencyException`. The crash message is "An instance of AVPlayer was deallocated while key value observers were still registered with it."

**Why it happens:** The current codebase uses `NSKeyValueObservation` (block-based Swift KVO) in `PlayerUIView`, `QueuePlayerUIView`, `ClipPlayerUIView`, and in the buffer observer patterns. The block-based API is safer than the old `addObserver` API because `NSKeyValueObservation` auto-invalidates on its own dealloc. However, the risk surfaces when:
1. The observation's closure captures `self` strongly, preventing deallocation of the observation
2. The observed object (AVPlayerItem) is replaced or removed from the player while still being observed
3. SwiftUI view re-creation creates a new observation without invalidating the old one

**Consequences:**
- Crash during navigation (dismissing a video view while video is still loading)
- Crash when backgrounding the app during video playback
- Memory leak if the crash is avoided by retain cycle (observer and observed object both stay alive)

**Warning signs:**
- Crash reports with "KVO" or "NSKeyValueObservation" in the stack trace
- Memory growth that correlates with video view open/close cycles
- The current `observeBuffering` method in `PublishedCardPlayerView` captures `[self]` (explicit strong capture) in the KVO closure, and dispatches to main queue -- if the view is dismissed between the KVO fire and the main queue dispatch, references may be stale

**Prevention:**
- Always invalidate `NSKeyValueObservation` in `onDisappear` AND in `deinit` of UIView subclasses (the current `PlayerUIView.deinit` does invalidate, which is correct)
- For `@State` observations in SwiftUI views (like `bufferObserver` in `PublishedCardPlayerView`), invalidate in `.onDisappear` before setting player to nil (the current code does this correctly)
- Never use `DispatchQueue.main.async` in KVO callbacks for AVPlayer properties -- use `Task { @MainActor in }` instead, and guard against the observed object being nil
- When the observer closure captures `[self]`, use `[weak self]` instead. The current `observeBuffering` in `MontagePreviewView` uses `[self]` in `DispatchQueue.main.async` which is a retain risk
- With the `NSKeyValueObservation` API, storing the observation in a `@State` property means it lives as long as the view's state -- but SwiftUI may recreate view bodies without calling `onDisappear`, so rely on the observation's own lifecycle, not the view's

**Detection:** Run the app with Instruments' Zombies template. Navigate rapidly between video views. Watch for zombie access or KVO deregistration warnings.

**Confidence:** HIGH -- well-documented iOS development pitfall. The current codebase has several KVO observation patterns that are mostly correct but have subtle risks with strong captures.

**Which phase should address it:** Phase 1 (foundation) -- the unified player wrapper must get KVO lifecycle right from the start.

---

## Moderate Pitfalls

Mistakes that cause poor performance, degraded UX, or accumulating technical debt.

### Pitfall 5: Disk Cache Growing Without Bounds

**What goes wrong:** When implementing video file caching to disk (downloading signed URL content to the Caches directory), the cache grows indefinitely. iOS can reclaim the Caches directory under storage pressure, but this happens unpredictably and often not soon enough. On a 64GB iPhone with 5GB free, a video cache that grows to 2GB triggers low-storage warnings for the user, who then blames your app.

**Why it happens:** Each 7-second 720p H.264 clip is roughly 2-5MB. A montage of 10 clips is 20-50MB. If the user has 20 published cards, cached montages alone could be 400MB-1GB. Without active cache management, every video ever viewed stays on disk.

**Consequences:**
- Users see "Storage Almost Full" warnings and investigate per-app storage usage
- App appears bloated in Settings > iPhone Storage, leading to deletion
- iOS may reclaim the cache directory at inopportune times (mid-session), causing playback failures for "cached" content that is no longer there

**Prevention:**
- Set a hard cache size limit (e.g., 200MB for video files). Implement LRU (Least Recently Used) eviction
- Track cache entries with metadata: file size, last access time, storage path
- On app launch and on `applicationDidReceiveMemoryWarning`, evict the oldest/least-used entries
- Use the `Caches` directory (not `Documents` or `Application Support`) so iOS CAN reclaim space if needed
- Consider a two-tier strategy: keep the most recent 3-5 video files on disk, and let older ones re-download on demand (for 7-second clips over WiFi, re-download is < 1 second)
- Log cache size periodically in debug builds so you can catch unbounded growth during development

**Detection:** Check app size in Settings > iPhone Storage after extended use. Add a debug menu showing current cache size.

**Confidence:** HIGH -- universal mobile caching pitfall, well-documented across platforms.

**Which phase should address it:** Phase 2 (caching implementation) -- the cache manager must enforce size limits from day one.

---

### Pitfall 6: Duplicate Downloads (Stream + Cache)

**What goes wrong:** AVPlayer starts buffering a video from the network immediately when you create an `AVPlayerItem(url:)`. If you also start a parallel download to cache the video to disk, you download the same bytes twice. For a 5MB clip, that is 10MB of bandwidth and doubled latency.

**Why it happens:** AVPlayer's internal buffering is opaque -- you cannot access the bytes it downloads. When you then use `URLSession.shared.download(from:)` to cache the file, it creates a completely separate network request. The two downloads race each other and neither benefits from the other's progress.

**Consequences:**
- Doubled bandwidth usage (significant on cellular)
- Slower apparent load time because network is contended
- Battery drain from redundant network activity

**Prevention:**
- **Option A (Recommended for TOY's use case):** Download-then-play. For 7-second clips, download the entire file to disk first (< 1 second on decent connection), then play from the local file URL. AVPlayer plays local files instantly with no buffering delay
- **Option B:** Use `AVAssetResourceLoaderDelegate` with a custom URL scheme to intercept AVPlayer's data requests, serve them from your own download pipeline, and cache the bytes as they flow through. This is more complex but enables simultaneous streaming and caching
- **Option C:** Accept the double download for the currently-playing video and only cache on subsequent views. Simpler but wastes bandwidth on first view
- For TOY's 7-second clips at 720p, Option A is strongly recommended. The files are small enough that download-first adds negligible delay (100-500ms) while eliminating all caching complexity. The `AVAssetResourceLoaderDelegate` approach (Option B) requires custom URL schemes, delegating all data loading manually, and is overkill for files under 10MB

**Detection:** Monitor network traffic with Charles Proxy or Instruments Network template. Look for duplicate requests to the same signed URL.

**Confidence:** HIGH -- documented issue across Apple Developer Forums and community resources.

**Which phase should address it:** Phase 2 (caching implementation) -- the caching strategy must be decided before implementation begins because it fundamentally affects the player architecture.

---

### Pitfall 7: Memory Pressure from In-Memory Video Data

**What goes wrong:** Loading video file `Data` into memory (e.g., `Data(contentsOf: fileURL)`) for caching or processing consumes significant RAM. A 5MB video held as a `Data` object is 5MB of heap allocation. If you hold 10 videos in memory simultaneously (e.g., a prefetch queue), that is 50MB+ of memory pressure that can trigger `didReceiveMemoryWarning` or jetsam (process termination).

**Why it happens:** The current `StorageService.uploadVideo` reads entire file data into memory with `Data(contentsOf: fileURL)`. If a similar pattern is used for caching (downloading to `Data` then writing to disk), the memory spike during the download/write can be significant. Additionally, any attempt to hold decoded video frames in memory (e.g., for thumbnail generation or frame preview) multiplies the problem: a single 720p frame is approximately 2.7MB uncompressed (1280 x 720 x 4 bytes).

**Consequences:**
- App terminated by iOS jetsam on low-memory devices (iPhone with 3GB RAM)
- Stutter and frame drops as system reclaims memory
- `didReceiveMemoryWarning` triggers cache eviction at the worst possible time (during playback)

**Prevention:**
- Never hold video file `Data` in memory longer than necessary. Use streaming downloads (`URLSession.download`) that write directly to disk, not `URLSession.data` that loads into memory
- For disk caching, use `FileManager.moveItem` from the temporary download location to the cache directory -- never read the file into `Data` and then write it back
- Limit the number of concurrent download tasks (2-3 max) to bound peak memory usage
- For thumbnail generation, use `AVAssetImageGenerator` with `maximumSize` set to the display size (e.g., 100x133 for the current 50x66pt thumbnail at 2x) to avoid generating full-resolution frames
- Monitor memory usage in Instruments during cache population to establish a baseline

**Detection:** Profile with Instruments Memory Allocations. Filter for `Data` objects > 1MB. Watch for memory spikes during video list loading.

**Confidence:** HIGH -- standard iOS memory management concern, directly applicable given the current `Data(contentsOf:)` patterns in the codebase.

**Which phase should address it:** Phase 2 (caching implementation) -- download pipeline must use streaming I/O from the start.

---

### Pitfall 8: AVQueuePlayer Items Consumed After Playback

**What goes wrong:** `AVQueuePlayer` removes items from its queue after they finish playing. If you want to replay the sequence, you cannot simply call `seek(to: .zero)` -- the items are gone. You must re-create all `AVPlayerItem` instances and re-insert them.

**Why it happens:** This is by design in AVFoundation. An `AVPlayerItem` can only be associated with one player at a time and is consumed (removed from the queue) after playback completes. The current `MontagePreviewView` already handles this in `replayVideo()` by removing all items and re-inserting new ones, but the pattern is fragile.

**Consequences:**
- Black screen when attempting to replay a montage
- Re-creating AVPlayerItems from signed URLs triggers new network buffering (not instant replay)
- If the signed URLs have expired between first play and replay, the replay fails silently

**Warning signs:**
- `queuePlayer.items()` returns empty array after first playback
- Replay shows loading spinner instead of instant playback

**Prevention:**
- For TOY's use case (7-second clips), cache the video files to disk first. Create new AVPlayerItems from local file URLs for replay -- playback from local files is instant with no network buffering
- Keep an array of the source URLs (or local file paths) separate from the AVPlayerItems, and re-create items from that source array for replay
- The current approach in `MontagePreviewView.replayVideo()` is correct in concept but will be slow because it re-creates items from remote signed URLs. Once caching is implemented, this switches to local URLs and becomes instant

**Detection:** Test the replay flow. Measure time from tap-replay to first frame displayed.

**Confidence:** HIGH -- documented AVFoundation behavior, already partially handled in the current codebase.

**Which phase should address it:** Phase 2 (caching) -- once videos are cached to disk, replay becomes instant.

---

### Pitfall 9: SwiftUI View Lifecycle vs. AVPlayer Lifecycle Mismatch

**What goes wrong:** SwiftUI may call `onAppear` and `onDisappear` multiple times for the same logical view presentation. It may also re-create view bodies (and thus UIViewRepresentable instances) without triggering `onDisappear`. This means AVPlayer setup/teardown code in lifecycle hooks can run out of order or multiple times, creating duplicate players or orphaned players.

**Why it happens:**
- `onAppear` can fire multiple times when a view is inside a `TabView`, `NavigationStack`, or `ScrollView`
- `.task` modifier cancels and restarts when the view's identity changes
- `UIViewRepresentable.updateUIView` is called on every view re-evaluation, which in the current `PlayerLayerView` re-sets the player on the layer every time (via the `player` property setter)
- Sheet/fullScreenCover presentations have their own lifecycle that does not always pair `onAppear`/`onDisappear` cleanly

**Consequences:**
- Multiple AVPlayer instances created for the same video
- Player starts playing before the view is visible (audio leaks)
- Player not cleaned up when view is dismissed via gesture (partial swipe-to-dismiss on sheets)

**Warning signs:**
- Audio continues playing after dismissing a video view
- Memory growth with each video view open/close cycle
- Debug logs showing duplicate "Loading video..." messages

**Prevention:**
- Use `@State` to hold the AVPlayer instance (the current code does this correctly). `@State` is stable across view body re-evaluations
- In `UIViewRepresentable.updateUIView`, check if the player has actually changed before re-assigning: `if uiView.playerLayer.player !== newValue { uiView.player = newValue }`
- Use `.task(id:)` with a stable identifier rather than bare `.task` for video loading, so it only re-runs when the video identity changes
- For cleanup, prefer `.onDisappear` for pausing and a separate mechanism (view model `deinit` or explicit cleanup method) for full teardown
- Consider using `@State` with a reference-type player controller object that manages its own lifecycle independent of view body re-evaluation

**Detection:** Add logging to AVPlayer init and deinit. Navigate to a video view and back 10 times. Count how many players were created vs. destroyed.

**Confidence:** HIGH -- well-documented SwiftUI behavior. Directly relevant to the three UIViewRepresentable player wrappers in the current codebase.

**Which phase should address it:** Phase 1 (foundation) -- the unified player wrapper must handle this correctly. Every video view inherits this behavior.

---

### Pitfall 10: NotificationCenter Observer Leaks

**What goes wrong:** `NotificationCenter.default.addObserver(forName:object:queue:)` returns an opaque observer object. If you do not store this object and later call `removeObserver`, the observer remains active forever. In the current codebase, `PublishedCardPlayerView.loadVideo()` (line 253) and `ClipPreviewSheet.setupPlayer()` (line 192) call `addObserver` for `.AVPlayerItemDidPlayToEndTime` but never store the returned observer or call `removeObserver`.

**Why it happens:** The block-based `addObserver` API is convenient but does not auto-remove when the caller is deallocated (unlike the older `Selector`-based API which was auto-removed in iOS 9+). If the view is dismissed and re-presented, a new observer is added each time, but the old one is still active -- causing the callback to fire multiple times.

**Consequences:**
- Seek-to-beginning-and-replay fires multiple times per play-through (visible as a stutter at the loop point)
- Closures in the observer capture `avPlayer` strongly, preventing deallocation
- Memory leak accumulates with each view presentation

**Warning signs:**
- Video loops multiple times at the end point (rapid seek-back-play cycles)
- Memory growth correlates with number of times video view has been opened

**Prevention:**
- Store the observer token returned by `addObserver` in a `@State` or instance property
- Remove the observer in `onDisappear` using `NotificationCenter.default.removeObserver(token)`
- Alternatively, use the Combine-based `NotificationCenter.default.publisher(for:object:)` with `.onReceive` in SwiftUI, which automatically manages the subscription lifetime
- Or use `for await notification in NotificationCenter.default.notifications(named:object:)` inside a `.task` modifier, which auto-cancels when the task is cancelled (i.e., view disappears)

**Detection:** Set a breakpoint in the `AVPlayerItemDidPlayToEndTime` handler. Open and close a video view 5 times, then play the video. The breakpoint should fire once per loop, not 5 times.

**Confidence:** HIGH -- directly observable in the current codebase. `PublishedCardPlayerView` line 253 and `ClipPreviewSheet` line 192 both call `addObserver` without storing the return value.

**Which phase should address it:** Phase 1 (foundation) -- must be fixed in the unified player wrapper.

---

## Minor Pitfalls

Mistakes that cause annoyance or minor UX issues but are straightforward to fix.

### Pitfall 11: preferredForwardBufferDuration Ignored for Progressive Downloads

**What goes wrong:** Setting `AVPlayerItem.preferredForwardBufferDuration` to limit buffering only works reliably for HLS (HTTP Live Streaming) content. For progressive download files (like the `.mov` files served by Supabase), AVPlayer may buffer the entire file regardless of this setting.

**Why it happens:** Progressive download files do not have segment boundaries like HLS. AVPlayer's buffer management is optimized for HLS's chunk-based delivery. With a single progressive file, the player's buffer strategy is "download as fast as possible."

**Consequences:**
- Setting `preferredForwardBufferDuration = 5` in `MontagePreviewView` (lines 169, 339) may have no effect
- Bandwidth usage is higher than expected (full file downloaded even if user only watches first 2 seconds)
- For TOY's 7-second clips this is mostly harmless, but for longer montages it wastes bandwidth

**Prevention:**
- For short clips (< 15 seconds), accept that the full file will be buffered -- it is small enough that this is actually a feature, not a bug (enables instant replay)
- If bandwidth optimization matters for longer content, serve video as HLS (requires server-side segmentation) -- but this is overkill for TOY's use case
- For the download-then-play approach (recommended in Pitfall 6), this is entirely irrelevant because the file is already local

**Detection:** Monitor network transfer size in Instruments. Compare to the expected partial buffer size.

**Confidence:** MEDIUM -- reported on Apple Developer Forums but behavior may vary by iOS version.

**Which phase should address it:** Phase 3 (optimization) -- low priority, only relevant if bandwidth is a concern.

---

### Pitfall 12: Thumbnail Generation Blocking the Main Thread

**What goes wrong:** Using `AVAssetImageGenerator.copyCGImage(at:actualTime:)` or even the async variant on the main thread causes UI freezes. Even the async variant can block briefly during asset inspection.

**Why it happens:** `AVAssetImageGenerator` needs to open the video file, seek to the target time, and decode a frame. For remote URLs, this includes a network request. Even for local files, the decode step takes 10-50ms per frame.

**Consequences:**
- Scroll jank in the card list if thumbnails are generated inline
- Delayed view appearance if thumbnail generation blocks `.task`

**Prevention:**
- Always generate thumbnails on a background thread/actor
- Pre-generate thumbnails at upload time (TOY already does this correctly -- `StorageService.uploadThumbnail` stores pre-generated JPEG thumbnails)
- Use Kingfisher for thumbnail display with stable cache keys (the current code does this correctly with `cacheKey: thumbnailPath`)
- If generating thumbnails client-side for preview, use `maximumSize` to limit output resolution

**Detection:** Profile with Instruments Time Profiler. Look for `AVAssetImageGenerator` calls on the main thread.

**Confidence:** HIGH -- standard AVFoundation concern, though the current codebase mostly avoids this by using pre-generated server-side thumbnails.

**Which phase should address it:** Not currently needed -- the existing pre-generated thumbnail pattern is correct. Maintain this pattern.

---

### Pitfall 13: automaticallyWaitsToMinimizeStalling Causes Slow Startup

**What goes wrong:** `AVPlayer.automaticallyWaitsToMinimizeStalling` defaults to `true`. This causes the player to wait until it has buffered "enough" data before starting playback, which can add 1-5 seconds to startup time depending on network conditions.

**Why it happens:** Apple designed this feature for long-form content where a 2-second initial buffer prevents mid-playback stalls. For short clips (7 seconds), the buffer threshold can exceed the clip duration, causing the player to buffer the entire clip before starting playback.

**Consequences:**
- User sees loading spinner for 2-5 seconds for a 7-second clip
- Feels sluggish compared to TikTok/Instagram which start playback in < 500ms

**Warning signs:**
- Loading percentage jumps from 30% to 100% all at once (buffering completed before playback started)
- Time-to-first-frame consistently > 1 second even on fast connections

**Prevention:**
- Set `automaticallyWaitsToMinimizeStalling = false` for short clips (< 15 seconds). The current `ClipPreviewSheet.setupPlayer()` (line 181) does set this to `false`, but `PublishedCardPlayerView.loadVideo()` does NOT set it, leaving the default `true`
- When set to `false`, you take responsibility for stall recovery. Monitor `playbackBufferEmpty` and `playbackLikelyToKeepUp` to manually resume playback after a stall
- For the download-then-play approach, this is irrelevant (local file playback never stalls)

**Detection:** Measure time from `AVPlayer.play()` call to `AVPlayerLayer.isReadyForDisplay` becoming `true`. Compare with and without the setting.

**Confidence:** HIGH -- documented Apple recommendation, inconsistently applied in the current codebase.

**Which phase should address it:** Phase 1 (foundation) -- configure this correctly in the unified player wrapper.

---

## Phase-Specific Warnings

| Phase Topic | Likely Pitfall | Mitigation |
|---|---|---|
| Phase 1: Unified Player Wrapper | KVO crash on dealloc (Pitfall 4), Observer leaks (Pitfall 10), iOS 18 actor crash (Pitfall 3), View lifecycle mismatch (Pitfall 9) | Build comprehensive test for open/close/background/foreground cycles. Validate on iOS 18.2+ device. |
| Phase 1: Signed URL Management | URL expiry breaking playback (Pitfall 1) | Build SignedURLCache with expiry tracking before any video caching work begins |
| Phase 1: Player Pool | Render pipeline exhaustion (Pitfall 2) | Enforce max 2 active players via centralized player manager |
| Phase 2: Video File Caching | Unbounded disk cache (Pitfall 5), Duplicate downloads (Pitfall 6), Memory pressure from Data loading (Pitfall 7) | Use download-then-play pattern with LRU disk cache capped at 200MB |
| Phase 2: Preloading | Pipeline exhaustion if preloading creates AVPlayers (Pitfall 2), Memory pressure if preloading holds Data (Pitfall 7) | Preload = download to disk only. Do NOT create AVPlayerItems for preloaded content until playback |
| Phase 3: Montage Playback | AVQueuePlayer item consumption (Pitfall 8), Buffer duration ignored for progressive download (Pitfall 11) | Cache montage segments to disk, re-create items from local URLs for replay |
| Phase 3: Polish | Startup latency (Pitfall 13) | Set automaticallyWaitsToMinimizeStalling = false consistently, or move entirely to local-file playback |

---

## Existing Codebase Issues to Address During Implementation

These are not hypothetical pitfalls -- they are concrete issues observed in the current code that will compound if not addressed alongside the playback quality improvements.

| File | Line(s) | Issue | Severity |
|---|---|---|---|
| `PublishedCardPlayerView.swift` | 253 | `NotificationCenter.addObserver` return value not stored; observer never removed | Moderate (memory leak) |
| `ClipPreviewSheet.swift` | 192 | Same `addObserver` leak pattern | Moderate (memory leak) |
| `MontagePreviewView.swift` | 272, 410, 428 | `[self]` capture in `DispatchQueue.main.async` inside KVO closure | Low (potential retain cycle) |
| `PublishedCardPlayerView.swift` | 272 | `[self]` capture in KVO observation closure | Low (potential retain cycle) |
| `CardDetailViewModel.swift` | 21 | `cachedSignedURLs` dictionary has no expiry tracking | High (stale URLs after 1 hour) |
| `HomeView.swift` | 33 | `publishedVideoURLCache` dictionary has no expiry tracking | High (stale URLs after 1 hour) |
| `MontagePreviewView.swift` | 196 | Caching `montagePlayer` in view model keeps hardware decode pipeline allocated off-screen | Moderate (pipeline exhaustion risk) |
| `PublishedCardPlayerView.swift` | 244 | Does not set `automaticallyWaitsToMinimizeStalling = false` | Low (unnecessarily slow startup) |
| All PlayerUIView classes | Multiple files | Three nearly identical UIViewRepresentable wrappers (PlayerUIView, QueuePlayerUIView, ClipPlayerUIView) | Low (maintenance burden; should be unified into one) |

---

## Sources

- [Apple Developer Forums: AVPlayer.replaceCurrentItem crash on iOS 18](https://developer.apple.com/forums/thread/764133) -- iOS 18 actor isolation crash
- [Apple Developer Forums: How many AVPlayers allowed simultaneously](https://developer.apple.com/forums/thread/67382) -- render pipeline limits
- [Apple Developer Forums: AVPlayerItem buffer duration not respected](https://developer.apple.com/forums/thread/63435) -- preferredForwardBufferDuration for progressive downloads
- [Apple Developer Forums: SwiftUI onAppear/onDisappear called multiple times](https://developer.apple.com/forums/thread/666345) -- view lifecycle issues
- [Apple Developer Forums: HLS caching while playing](https://developer.apple.com/forums/thread/649810) -- dual download problem
- [Apple Developer Forums: Use data cached by AVAssetDownloadTask](https://developer.apple.com/forums/thread/657540) -- cache reuse limitations
- [Apple Developer Forums: AVPlayerViewController memory leaks](https://developer.apple.com/forums/thread/121780) -- lifecycle leaks
- [Apple Developer Forums: AVPlayer KVO crashes at replaceCurrentItem iOS 16](https://developer.apple.com/forums/thread/719494) -- KVO crash patterns
- [Apple Developer Forums: Crash in iOS 18 regarding AVPlayer](https://developer.apple.com/forums/thread/767379) -- iOS 18 KVO crash from internal SDK
- [Hacking with Swift: SwiftUI VideoPlayer leaking](https://www.hackingwithswift.com/forums/swiftui/swiftui-videoplayer-leaking-atstate-management-issue/25070) -- @State management issues
- [Becky Hansmeyer: Too Many AVPlayers?](https://www.beckyhansmeyer.com/2017/08/30/too-many-avplayers/) -- practical pipeline limit testing
- [iOS Performance - AVPlayer Edition (Medium)](https://medium.com/tech-romance/ios-performance-avplayer-edition-257c9575e3ea) -- performance optimization guide
- [AVPlayer Video Optimization Part 1 (Medium)](https://medium.com/@sojik/avplayer-video-optimization-part-1-2a45ea002ea2) -- buffer management strategies
- [CachingPlayerItem (GitHub)](https://github.com/neekeetab/CachingPlayerItem) -- reference implementation for AVAssetResourceLoaderDelegate caching
- [VIMediaCache (GitHub)](https://github.com/vitoziv/VIMediaCache) -- AVAssetResourceLoader-based caching library
- [How to cache AVURLAsset data (Medium)](https://medium.com/@vdugnist/how-to-cache-avurlasset-data-downloaded-by-avplayer-5400677b8b9e) -- cache implementation patterns
- [Implementing AVAssetResourceLoaderDelegate (Jared Sinclair)](https://jaredsinclair.com/2016/09/03/implementing-avassetresourceload.html) -- comprehensive delegate implementation guide
- [SwiftUI Lab: UIViewControllerRepresentable Memory Leak](https://swiftui-lab.com/uiviewcontrollerrepresentable-memory-leak/) -- representable lifecycle issues
- [Debugging a spurious AVPlayer KVO Crash (Scientific Witchery)](https://www.jackyoustra.com/blog/live-text-kvo) -- iOS 16 Live Text KVO interaction
