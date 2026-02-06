# Phase 9: Quick Playback Wins - Research

**Researched:** 2026-02-06
**Domain:** iOS AVFoundation video playback behavioral fixes (no new infrastructure)
**Confidence:** HIGH

## Summary

Phase 9 targets five specific, scoped behavioral fixes to the existing video playback code. Unlike the broader video infrastructure recommendations in the project-level research (unified player, disk cache, preloading), this phase is purely about **quick wins** -- changes that require modifying existing code at specific lines, with no new services, actors, or architectural patterns.

All five requirements (LOAD-02, LOAD-04, QUAL-01, QUAL-02, QUAL-03) have been mapped to exact files and line numbers in the current codebase. Each change is small (1-20 lines modified per file), low-risk, and independently testable. The audio session fix (QUAL-03) is already implemented in `TOYApp.swift` but needs verification on a physical device with the silent switch engaged.

**Primary recommendation:** Implement these five fixes as independent, sequential tasks. Each can be tested in isolation. The order should be: LOAD-02 (remove % text) first since it is pure removal, then LOAD-04 (autoWait), QUAL-01 (thumbnail time), QUAL-03 (audio session verification), and QUAL-02 (AVPlayerLooper) last since it is the most behavioral change.

## Standard Stack

No new libraries or dependencies are needed for Phase 9. All changes use existing AVFoundation APIs.

### Core (Already in Project)
| Library | Version | Purpose | Role in Phase 9 |
|---------|---------|---------|-----------------|
| AVFoundation | Native (iOS 18.2+) | Video playback, thumbnail generation | All requirements |
| AVKit | Native (iOS 18.2+) | AVPlayer, AVQueuePlayer, AVPlayerLooper | LOAD-04, QUAL-02 |
| Kingfisher | 8.x (already installed) | Thumbnail image caching | Unaffected by changes |

### New Dependencies
None. Phase 9 adds zero new dependencies.

## Architecture Patterns

### Pattern: Targeted In-Place Fixes (No Refactoring)

Phase 9 does NOT unify the four player implementations or introduce new services. That is future work. Each fix is applied directly to the existing file where the problem lives. This keeps the blast radius small and makes each change independently revertable.

### File Map

```
Files to MODIFY:
  TOY/Features/PublishedCard/PublishedCardPlayerView.swift   -- LOAD-02, LOAD-04, QUAL-02
  TOY/Features/Publishing/MontagePreviewView.swift           -- LOAD-02
  TOY/Features/CardManagement/ClipPreviewSheet.swift         -- QUAL-02
  TOY/TOYShared/Sources/TOYShared/Recording/UI/
    VideoPreviewView.swift                                    -- QUAL-02
    RecordingViewModel.swift                                  -- QUAL-01
  TOY/TOYApp.swift                                            -- QUAL-03 (verify only)

Files NOT modified:
  HomeView.swift                 -- No playback code changes needed
  CardDetailViewModel.swift      -- No playback code changes needed
  StorageService.swift           -- No changes
  CardService.swift              -- No changes
```

## Requirement-by-Requirement Analysis

### LOAD-02: Remove Percentage Text from Loading Overlays

**Goal:** No percentage text appears anywhere during video loading.

**Current state -- exactly what to remove:**

**File 1: `PublishedCardPlayerView.swift` (lines 78-85)**
```swift
// CURRENT -- lines 78-85
VStack(spacing: TOYSpacing.sm) {
    Text("Loading video...")
        .font(.toyBodyMedium())
        .foregroundColor(.warmCream)
    Text("\(Int(loadingProgress * 100))% complete")  // <-- REMOVE THIS
        .font(.toyCaption())
        .foregroundColor(.warmCream.opacity(0.8))
}
```

**What to change:** Remove the `Text("\(Int(loadingProgress * 100))% complete")` line and its modifiers. Keep "Loading video..." text OR replace the entire VStack with a simple spinner:
```swift
// REPLACEMENT -- subtle spinner over thumbnail
ProgressView()
    .tint(.warmCream)
    .scaleEffect(1.2)
```

**Also clean up:** The `loadingProgress` state variable (line 24), the `observeBuffering(item:)` method (lines 271-297), and the `bufferObserver` state (line 30) can all be removed since they only existed to drive the percentage display. However, `loadingProgress` is also used in the `isPlayerReady` transition logic (line 48 sets it to 1.0 in `onReadyToDisplay`). Evaluate whether to keep or remove based on whether any other logic depends on it.

**Recommendation:** Remove the percentage text but keep `loadingProgress` and `observeBuffering` for now -- they are harmless and could be useful for future loading indicators. Only remove the visible `Text` element.

**File 2: `MontagePreviewView.swift` (lines 112-119)**
```swift
// CURRENT -- lines 112-119
VStack(spacing: TOYSpacing.sm) {
    Text("Stitching videos...")
        .font(.toyBodyMedium())
        .foregroundColor(.warmCream)
    Text("\(Int(loadingProgress * 100))% complete")  // <-- REMOVE THIS
        .font(.toyCaption())
        .foregroundColor(.warmCream.opacity(0.8))
}
```

**What to change:** Same pattern -- remove the percentage text line. Keep "Stitching videos..." or replace with spinner.

**What NOT to change:**
- Do NOT remove the `loadingProgress` tracking in MontagePreviewView -- it is used for the `isPlayerReady` state transition and for disabling the Publish button (`isLoadingURLs`)
- Do NOT change `observeBuffering` in MontagePreviewView -- it still drives internal state
- Do NOT modify ClipPreviewSheet -- it already shows only a spinner with "Loading..." text, no percentage

**Testing strategy:**
1. Open a published card -- should see thumbnail + spinner (or "Loading video..."), no percentage
2. Open montage preview -- should see "Stitching videos..." + spinner, no percentage
3. Open clip preview -- should see spinner (unchanged, already correct)

**Confidence:** HIGH -- Pure UI removal, zero behavioral risk.

---

### LOAD-04: Video Playback Starts Without Waiting for Full Buffer

**Goal:** Video playback begins within ~500ms without waiting for full buffer.

**Current state:**

**File: `PublishedCardPlayerView.swift` (lines 244-251)**
```swift
// CURRENT -- lines 244-251
await MainActor.run {
    let playerItem = AVPlayerItem(url: signedURL)
    let avPlayer = AVPlayer(playerItem: playerItem)

    // Observe buffering progress
    observeBuffering(item: playerItem)

    avPlayer.play()
    // NOTE: automaticallyWaitsToMinimizeStalling is NOT set -- defaults to true
```

**What to change:** Add one line after creating the AVPlayer:
```swift
let avPlayer = AVPlayer(playerItem: playerItem)
avPlayer.automaticallyWaitsToMinimizeStalling = false  // ADD THIS LINE
```

**Why this works:** When `automaticallyWaitsToMinimizeStalling` is `true` (the default), AVPlayer waits until it has buffered "enough" data to guarantee stall-free playback before starting. For 7-second clips, the buffer threshold can be close to the entire clip duration, causing a 1-3 second delay. Setting to `false` tells AVPlayer to start playback as soon as any buffered data is available.

**What NOT to change:**
- Do NOT change `MontagePreviewView` -- it intentionally sets `automaticallyWaitsToMinimizeStalling = true` (line 354) because the queue player benefits from buffering ahead to prevent black flashes between clips. This is correct for multi-clip queue playback.
- Do NOT change `ClipPreviewSheet` -- it already sets `automaticallyWaitsToMinimizeStalling = false` (line 181). Already correct.
- Do NOT change `VideoPreviewView` -- plays from local file URL, buffering is irrelevant.

**Stall recovery consideration:** When `automaticallyWaitsToMinimizeStalling = false`, AVPlayer will start playing and may stall if the network is slow. For 7-second clips on modern connections, this is extremely unlikely. If stalling is observed in testing, add a `playbackBufferEmpty` observer to pause and show a spinner, then resume when `playbackLikelyToKeepUp` becomes true. But do NOT add this preemptively -- only if testing reveals actual stalling.

**Testing strategy:**
1. Clear app from memory (force quit), open a published card on WiFi -- playback should begin within ~500ms
2. Throttle network to 3G (Network Link Conditioner) -- playback should still start quickly, may stall mid-playback (acceptable)
3. Verify montage preview still behaves correctly (should NOT have changed)

**Confidence:** HIGH -- One-line change, well-documented Apple API. ClipPreviewSheet already does this successfully.

---

### QUAL-01: Thumbnails Generated at 1.5s Instead of 0.5s

**Goal:** Newly recorded clips generate thumbnails at ~1.5s where the person is composed.

**Current state:**

**File: `RecordingViewModel.swift` (line 309)**
```swift
// CURRENT -- line 309
let time = CMTime(seconds: 0.5, preferredTimescale: 600)
```

**What to change:** Change `0.5` to `1.5`:
```swift
let time = CMTime(seconds: 1.5, preferredTimescale: 600)
```

**Why 1.5s:** For a 7-second greeting card clip where someone is speaking to camera, 0.5 seconds is typically before the person has settled into a natural expression (they are still adjusting after pressing record). At 1.5 seconds, the person is typically composed, making eye contact, and often smiling -- a much better thumbnail frame.

**What NOT to change:**
- Do NOT change the `maximumSize` (line 307: `CGSize(width: 150, height: 200)`) -- this is appropriate for thumbnail resolution
- Do NOT change `appliesPreferredTrackTransform = true` (line 306) -- this ensures correct orientation
- Do NOT change `compressionQuality: 0.7` (line 314) -- appropriate for thumbnails

**Impact on existing thumbnails:** This change only affects NEW clips recorded after the code change. Existing clips in the database already have thumbnails generated at 0.5s and stored in Supabase Storage. Those will remain unchanged. A backfill migration to regenerate thumbnails for existing clips is NOT in scope for Phase 9 -- it would require downloading every clip video, regenerating the thumbnail, and re-uploading. This could be a future enhancement.

**Edge case:** If a clip is shorter than 1.5 seconds, `AVAssetImageGenerator.image(at:)` will return the nearest available frame. Since TOY clips are 7 seconds, this is not a concern.

**Testing strategy:**
1. Record a new 7-second clip
2. Verify the generated thumbnail shows the person in a composed pose (not mid-gesture from pressing record)
3. Compare with a thumbnail from a clip recorded before the change -- the new thumbnail should look more natural
4. Verify the thumbnail uploads correctly and displays in the card detail view

**Confidence:** HIGH -- One constant change, no behavioral risk.

---

### QUAL-02: Seamless Video Looping (No Visible Gap)

**Goal:** Videos loop seamlessly with no visible pause, stutter, or black flash at loop point.

**Current state:** Three views use the NotificationCenter `AVPlayerItemDidPlayToEndTime` + `seek(to: .zero)` + `play()` pattern for looping, which causes a visible gap (typically 100-300ms of black or frozen frame) at the loop point.

**File 1: `PublishedCardPlayerView.swift` (lines 253-260)**
```swift
// CURRENT -- lines 253-260
NotificationCenter.default.addObserver(
    forName: .AVPlayerItemDidPlayToEndTime,
    object: playerItem,
    queue: .main
) { _ in
    avPlayer.seek(to: .zero)
    avPlayer.play()
}
```

**What to change:** Replace `AVPlayer` with `AVQueuePlayer` + `AVPlayerLooper`:
```swift
// REPLACEMENT for PublishedCardPlayerView.loadVideo()
let playerItem = AVPlayerItem(url: signedURL)
let queuePlayer = AVQueuePlayer()
queuePlayer.automaticallyWaitsToMinimizeStalling = false

// AVPlayerLooper handles seamless looping internally
let looper = AVPlayerLooper(player: queuePlayer, templateItem: playerItem)

queuePlayer.play()

self.player = queuePlayer     // AVQueuePlayer is a subclass of AVPlayer
self.playerLooper = looper     // Must retain -- looper stops if deallocated
```

**Required state additions to PublishedCardPlayerView:**
```swift
@State private var playerLooper: AVPlayerLooper?  // ADD to state declarations
```

**Required cleanup changes (onDisappear, around line 213-219):**
```swift
.onDisappear {
    playerLooper?.disableLooping()   // ADD -- cleanly stop looper
    playerLooper = nil                // ADD -- release looper
    player?.pause()
    player?.replaceCurrentItem(with: nil)
    player = nil
    bufferObserver?.invalidate()
    bufferObserver = nil
}
```

**Also remove:** The `NotificationCenter.default.addObserver` block (lines 253-260) since AVPlayerLooper replaces it entirely.

**Important:** The existing `PlayerUIView` / `PlayerLayerView` UIViewRepresentable works with AVQueuePlayer without changes because AVQueuePlayer is a subclass of AVPlayer. The `playerLayer.player = newValue` assignment on line 387 accepts any AVPlayer subclass.

**File 2: `ClipPreviewSheet.swift` (lines 192-199)**
```swift
// CURRENT -- lines 192-199
NotificationCenter.default.addObserver(
    forName: .AVPlayerItemDidPlayToEndTime,
    object: newPlayer.currentItem,
    queue: .main
) { _ in
    newPlayer.seek(to: .zero)
    newPlayer.play()
}
```

**What to change:** Same pattern -- replace AVPlayer with AVQueuePlayer + AVPlayerLooper:
```swift
// REPLACEMENT for ClipPreviewSheet.setupPlayer()
let playerItem = AVPlayerItem(url: url)
let queuePlayer = AVQueuePlayer()
queuePlayer.automaticallyWaitsToMinimizeStalling = false

let looper = AVPlayerLooper(player: queuePlayer, templateItem: playerItem)
queuePlayer.play()

// Status observer on the template item (same as before)
playerStatusObserver = playerItem.observe(\.status, options: [.new]) { item, _ in
    DispatchQueue.main.async {
        if case .failed = item.status {
            loadError = item.error?.localizedDescription ?? "Failed to load video"
        }
    }
}

player = queuePlayer
playerLooper = looper
```

**Required state addition:**
```swift
@State private var playerLooper: AVPlayerLooper?
```

**Required cleanup update (`cleanupPlayer()`):**
```swift
private func cleanupPlayer() {
    playerStatusObserver?.invalidate()
    playerStatusObserver = nil
    playerLooper?.disableLooping()
    playerLooper = nil
    player?.pause()
    player?.replaceCurrentItem(with: nil)  // ADD -- proper pipeline release
    player = nil
    isPlayerReady = false
}
```

**File 3: `VideoPreviewView.swift` (lines 95-102)**
```swift
// CURRENT -- lines 95-102
NotificationCenter.default.addObserver(
    forName: .AVPlayerItemDidPlayToEndTime,
    object: newPlayer.currentItem,
    queue: .main
) { _ in
    newPlayer.seek(to: .zero)
    newPlayer.play()
}
```

**What to change:** Same AVPlayerLooper pattern. VideoPreviewView plays local files so looping is even more seamless (no network involvement).

**Required state addition:**
```swift
@State private var playerLooper: AVPlayerLooper?
```

**Updated setupPlayer():**
```swift
private func setupPlayer() {
    let playerItem = AVPlayerItem(url: videoURL)
    let queuePlayer = AVQueuePlayer()
    let looper = AVPlayerLooper(player: queuePlayer, templateItem: playerItem)
    queuePlayer.play()

    player = queuePlayer
    playerLooper = looper
}
```

**Updated onDisappear:**
```swift
.onDisappear {
    playerLooper?.disableLooping()
    playerLooper = nil
    player?.pause()
    player?.replaceCurrentItem(with: nil)
    player = nil
}
```

**What NOT to change:**
- Do NOT change `MontagePreviewView` -- it uses `AVQueuePlayer` for sequential multi-clip playback (play once, then show replay button), NOT for looping. The current behavior is intentionally non-looping. AVPlayerLooper is not appropriate for queue playback of different clips.

**Important AVPlayerLooper caveats:**
1. The `AVPlayerLooper` instance MUST be retained (stored in a `@State` property). If it deallocates, looping stops.
2. `AVPlayerLooper` requires an `AVQueuePlayer`, not a plain `AVPlayer`. This is because it internally manages a queue of items.
3. The `templateItem` passed to `AVPlayerLooper` must not already be associated with a player. Create a fresh `AVPlayerItem` for the template.
4. Call `looper.disableLooping()` before cleanup to ensure clean teardown.

**Testing strategy:**
1. Open a published card video -- watch through at least 3 complete loops. There should be zero visible pause, black flash, or stutter at the loop point.
2. Open a clip preview -- same test, 3+ loops seamless.
3. Record a video and preview it -- same test, 3+ loops seamless.
4. Open montage preview -- verify it still plays once and shows replay button (NOT looping). This is the non-regression test.
5. Test dismissing each view mid-loop -- should not crash (tests cleanup).

**Confidence:** HIGH -- AVPlayerLooper is a stable API (available since iOS 10), designed specifically for this use case. Multiple official Apple sample projects demonstrate this pattern.

---

### QUAL-03: Audio Plays Correctly in Silent Mode

**Goal:** Video audio plays correctly even when the device ringer/silent switch is set to silent mode.

**Current state:**

**File: `TOYApp.swift` (lines 111-119)**
```swift
// CURRENT -- already implemented!
init() {
    // Configure audio session to play sound even when silent switch is on
    do {
        try AVAudioSession.sharedInstance().setCategory(.playback, mode: .moviePlayback)
        try AVAudioSession.sharedInstance().setActive(true)
    } catch {
        #if DEBUG
        print("Failed to configure audio session: \(error)")
        #endif
    }
}
```

**Analysis:** This is already correctly implemented.

- `.playback` category: Tells iOS that audio is a core feature. Ignores the silent switch.
- `.moviePlayback` mode: Optimized for video playback scenarios (appropriate for TOY).
- `setActive(true)`: Activates the session at app launch.
- Placement in `TOYApp.init()`: Runs once at app startup, before any video playback occurs.

**What to verify (but NOT change):**
1. The audio session is set BEFORE any AVPlayer is created. Since it is in `TOYApp.init()`, this is guaranteed.
2. The `.playback` category correctly overrides the silent switch. This is documented Apple behavior.
3. No other code in the app resets the audio session category to `.ambient` or `.soloAmbient` (which would re-enable the silent switch). A grep for `AVAudioSession` confirms no other code touches it.

**Potential issue:** If another app's audio session interrupts (e.g., a phone call), TOY's audio session may be deactivated. When the interruption ends, audio should resume automatically because `.playback` category is set. However, if issues are observed, adding an interruption handler may be needed -- but this is out of scope for Phase 9.

**What NOT to change:**
- Do NOT add `.mixWithOthers` option -- TOY's video audio should properly take over from background audio
- Do NOT change to `.ambient` category -- that would respect the silent switch (opposite of what we want)
- Do NOT move the audio session configuration to individual views -- app-level is correct

**Testing strategy (physical device REQUIRED -- Simulator does not have silent switch):**
1. Toggle iPhone silent switch to ON (orange visible)
2. Open a published card video -- audio should play through the speaker
3. Open a clip preview -- audio should play
4. Record and preview a video -- audio should play
5. Toggle silent switch to OFF -- audio should still play (verify no double-audio or other issues)

**Confidence:** HIGH -- Already implemented. Just needs physical device verification.

---

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Seamless looping | `NotificationCenter` + `seek(.zero)` + `play()` | `AVPlayerLooper` | Apple's API pre-buffers the loop transition, eliminating the visible gap. The manual pattern cannot achieve frame-accurate looping. |
| Audio in silent mode | Per-view audio session management | Single `AVAudioSession.setCategory(.playback)` at app init | Audio category is a global app setting, not per-view. Setting it once at launch is correct. |
| Thumbnail frame selection | Complex multi-frame scoring/ML | Hardcoded 1.5s time constant | For 7-second greeting cards, 1.5s is empirically the right moment. Adaptive selection is over-engineering for this use case. |

## Common Pitfalls

### Pitfall 1: AVPlayerLooper Deallocates and Looping Stops
**What goes wrong:** The `AVPlayerLooper` instance is stored in a local variable instead of a `@State` property. It deallocates at the end of the scope, and looping silently stops after the first play-through.
**Why it happens:** `AVPlayerLooper` does not retain itself. Unlike NotificationCenter observers (which the system retains), the looper must be explicitly kept alive.
**How to avoid:** Always store the looper in `@State private var playerLooper: AVPlayerLooper?` and clean it up in `onDisappear`.
**Warning signs:** Video plays once but does not loop. No error is logged.

### Pitfall 2: Creating AVPlayerLooper with an Already-Associated Item
**What goes wrong:** Passing an `AVPlayerItem` that is already associated with a player to `AVPlayerLooper(player:templateItem:)` causes undefined behavior or a crash.
**Why it happens:** AVPlayerItem can only be associated with one player at a time. If you create it with `AVPlayer(playerItem:)` first, then try to use the same item as a looper template, it fails.
**How to avoid:** Create the `AVPlayerItem`, pass it directly to `AVPlayerLooper` as the template, do NOT associate it with a player first. Let the looper manage the item-player association internally.

### Pitfall 3: Forgetting replaceCurrentItem(with: nil) on Cleanup
**What goes wrong:** Setting `player = nil` without first calling `player?.replaceCurrentItem(with: nil)` may not fully release the hardware decode pipeline. Over multiple view open/close cycles, this can exhaust the system's pipeline limit (4-16 depending on device).
**Why it happens:** AVPlayer's deallocation does not guarantee immediate pipeline release.
**How to avoid:** Always call `player?.replaceCurrentItem(with: nil)` before setting `player = nil`. The current `PublishedCardPlayerView.onDisappear` does this correctly, but `ClipPreviewSheet.cleanupPlayer()` does NOT (line 208 sets `player = nil` without `replaceCurrentItem(with: nil)` first). Fix this as part of the QUAL-02 changes.

### Pitfall 4: NotificationCenter Observer Leak (Existing Bug)
**What goes wrong:** The current code in `PublishedCardPlayerView` (line 253) and `ClipPreviewSheet` (line 192) calls `NotificationCenter.default.addObserver(forName:object:queue:)` but never stores the return value or removes the observer. If the view is presented multiple times, observers accumulate, causing the seek-to-zero callback to fire multiple times per loop.
**Why it happens:** The block-based `addObserver` API returns an opaque observer token that must be stored and later removed. Not storing it leaks the observer.
**How to avoid:** The QUAL-02 fix (switching to AVPlayerLooper) eliminates this code entirely, solving the leak as a side effect. No separate fix needed.

### Pitfall 5: Stall Recovery After Disabling automaticallyWaitsToMinimizeStalling
**What goes wrong:** After setting `automaticallyWaitsToMinimizeStalling = false`, AVPlayer may stall on slow connections. Without the automatic wait behavior, the player will not resume on its own.
**Why it happens:** When automatic waiting is disabled, AVPlayer starts immediately but does not pause proactively when the buffer runs low. If the buffer empties, playback stalls.
**How to avoid:** For 7-second clips, stalling is extremely unlikely on any reasonable connection (2-5MB downloads in under a second). Do NOT add stall recovery logic preemptively. Only add it if testing reveals actual stalling on real networks.
**Warning signs:** Video freezes mid-playback (different from the startup delay this fix addresses).

## Code Examples

### AVPlayerLooper Pattern (used in QUAL-02)
```swift
// Source: Apple AVPlayerLooper documentation + Apple avloopplayer sample project
// https://developer.apple.com/documentation/avfoundation/avplayerlooper

// 1. Create the player item
let playerItem = AVPlayerItem(url: videoURL)

// 2. Create an AVQueuePlayer (required by AVPlayerLooper)
let queuePlayer = AVQueuePlayer()
queuePlayer.automaticallyWaitsToMinimizeStalling = false

// 3. Create the looper -- it manages the queue internally
let looper = AVPlayerLooper(player: queuePlayer, templateItem: playerItem)

// 4. Start playback
queuePlayer.play()

// 5. Store both -- looper MUST be retained
self.player = queuePlayer
self.playerLooper = looper

// 6. Cleanup
func cleanup() {
    playerLooper?.disableLooping()
    playerLooper = nil
    player?.pause()
    player?.replaceCurrentItem(with: nil)
    player = nil
}
```

### Thumbnail Generation at 1.5s (used in QUAL-01)
```swift
// Source: Apple AVAssetImageGenerator documentation
// https://developer.apple.com/documentation/avfoundation/avassetimagegenerator

let asset = AVAsset(url: videoURL)
let generator = AVAssetImageGenerator(asset: asset)
generator.appliesPreferredTrackTransform = true
generator.maximumSize = CGSize(width: 150, height: 200)

let time = CMTime(seconds: 1.5, preferredTimescale: 600)  // Changed from 0.5

let cgImage = try await generator.image(at: time).image
let uiImage = UIImage(cgImage: cgImage)
return uiImage.jpegData(compressionQuality: 0.7)
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| `seek(.zero)` + `play()` for looping | `AVPlayerLooper` for seamless loops | iOS 10 (2016) | Eliminates visible gap at loop point |
| `automaticallyWaitsToMinimizeStalling = true` (default) | Set to `false` for short clips | WWDC 2016 Session 503 | Faster startup for short-form content |
| Fixed thumbnail at 0.0s | Content-aware time selection | Industry best practice | Better representative thumbnails |

## Open Questions

1. **AVPlayerLooper + isReadyForDisplay observation**
   - What we know: The current `PlayerUIView` observes `playerLayer.isReadyForDisplay` to trigger the thumbnail-to-video crossfade. When switching from `AVPlayer` to `AVQueuePlayer` (for AVPlayerLooper), this observation should continue to work since `AVQueuePlayer` is a subclass of `AVPlayer`.
   - What's unclear: Whether `isReadyForDisplay` fires at the same timing with AVPlayerLooper as with a plain AVPlayer. It should, since the player layer renders the same way regardless.
   - Recommendation: Test this during implementation. If the crossfade timing changes, the `onReadyToDisplay` callback in `PlayerUIView` may need adjustment.

2. **Buffer progress observation with AVPlayerLooper**
   - What we know: `PublishedCardPlayerView.observeBuffering()` observes `loadedTimeRanges` on the `AVPlayerItem`. With AVPlayerLooper, the looper creates internal copies of the template item.
   - What's unclear: Whether the buffer observation on the original template item still fires correctly, or whether it needs to be placed on the looper's internal items.
   - Recommendation: Since we are removing the percentage text display (LOAD-02), the buffer observation is less critical. If it is still needed for internal state, observe the `queuePlayer.currentItem` instead of the template item.

3. **Audio session interruption recovery**
   - What we know: The `.playback` audio session category in `TOYApp.init()` correctly ignores the silent switch.
   - What's unclear: Whether audio resumes correctly after a phone call or other audio interruption.
   - Recommendation: Out of scope for Phase 9. Document as future work if testing reveals issues.

## Sources

### Primary (HIGH confidence)
- [Apple AVPlayerLooper Documentation](https://developer.apple.com/documentation/avfoundation/avplayerlooper) -- seamless looping API
- [Apple AVFoundation Looping Player Sample Code](https://developer.apple.com/library/archive/samplecode/avloopplayer/Introduction/Intro.html) -- official sample project
- [Apple AVPlayer.automaticallyWaitsToMinimizeStalling](https://developer.apple.com/documentation/avfoundation/avplayer/automaticallywaitstominimizestalling) -- buffer behavior
- [Apple AVAssetImageGenerator](https://developer.apple.com/documentation/avfoundation/avassetimagegenerator) -- thumbnail generation
- [Apple AVAudioSession.Category.playback](https://developer.apple.com/documentation/avfaudio/avaudiosession/category/1616509-playback) -- silent switch override
- [WWDC 2016 Session 503: Advances in AVFoundation Playback](https://asciiwwdc.com/2016/sessions/503) -- autoWait recommendation

### Secondary (MEDIUM confidence)
- [Bitmovin: How to let audio play in silent mode](https://developer.bitmovin.com/playback/docs/ios-how-to-let-audio-play-when-the-ios-device-is-in-silent-mode) -- audio session patterns
- [GitHub Gist: AVPlayerLooper example](https://gist.github.com/lanserxt/33fd8c479185cba181497315299e0e31) -- community implementation reference

### Codebase Analysis (HIGH confidence)
- Direct reading of all 4 player view implementations
- Direct reading of RecordingViewModel.generateThumbnail()
- Direct reading of TOYApp.init() audio session configuration
- Line-number-level mapping of all changes

## Metadata

**Confidence breakdown:**
- LOAD-02 (remove % text): HIGH -- Pure UI removal, zero risk
- LOAD-04 (autoWait): HIGH -- One-line change, documented API, already used in ClipPreviewSheet
- QUAL-01 (thumbnail time): HIGH -- One constant change, isolated impact
- QUAL-02 (AVPlayerLooper): HIGH -- Stable API since iOS 10, well-documented, but involves more code changes across 3 files
- QUAL-03 (audio session): HIGH -- Already implemented, needs device verification only

**Research date:** 2026-02-06
**Valid until:** 2026-04-06 (stable -- AVFoundation APIs do not change rapidly)
