# Pitfalls Analysis: TOY Group Video Greeting Card App

> Common mistakes and critical issues to avoid when building a group video greeting card app for iOS with App Clip integration.

---

## 1. Video Recording Issues

### 1.1 Memory Exhaustion During Recording

**The Pitfall:** Recording video directly to memory (using `AVCaptureMovieFileOutput` without proper configuration) can exhaust device memory on older iPhones, causing crashes mid-recording.

**Warning Signs:**
- App crashes during recording on iPhone SE or older devices
- Memory warnings in console during video capture
- Users reporting "recording stopped unexpectedly"

**Prevention Strategy:**
- Use `AVAssetWriter` with `AVAssetWriterInput` configured for fragmented movie output
- Write directly to disk, not memory buffers
- Implement `AVCaptureSession` with lower preset (`AVCaptureSession.Preset.medium`) for App Clip
- Set maximum recording duration in code (7 seconds) with hard stop

**Phase:** Phase 1 (Core Recording) - Must be correct from start; retrofitting is expensive

```swift
// Good: Stream to disk
let outputURL = FileManager.default.temporaryDirectory.appendingPathComponent("clip.mov")
let assetWriter = try AVAssetWriter(outputURL: outputURL, fileType: .mov)
// Configure for real-time writing
assetWriter.movieFragmentInterval = CMTime(seconds: 1, preferredTimescale: 600)
```

---

### 1.2 Camera Permission Denial Without Recovery Path

**The Pitfall:** App Clip users who deny camera permission have no way to record. Many apps fail silently or show an unhelpful error.

**Warning Signs:**
- Analytics showing high drop-off at camera screen
- Support requests: "camera screen is blank"
- App Store reviews mentioning camera not working

**Prevention Strategy:**
- Pre-flight permission check before showing camera UI
- Clear, friendly explanation BEFORE requesting permission
- If denied: Show specific instructions with "Open Settings" deep link (`UIApplication.openSettingsURLString`)
- Never show camera preview until permission confirmed

**Phase:** Phase 1 (Core Recording) - Critical for first-run experience

---

### 1.3 Video Compression Producing Incompatible Files

**The Pitfall:** Different iOS versions and devices produce videos with different codecs. HEVC videos from newer iPhones may not stitch properly with H.264 from older devices.

**Warning Signs:**
- Final montage has visual glitches at clip transitions
- Some clips appear as black screens in final video
- Different video dimensions causing letterboxing

**Prevention Strategy:**
- Force consistent output format at recording time:
  - Codec: H.264 (not HEVC) for maximum compatibility
  - Resolution: 720p fixed (not native camera resolution)
  - Frame rate: 30fps fixed
  - Orientation: Portrait locked
- Validate every uploaded clip server-side before accepting
- Re-encode non-compliant clips during upload

**Phase:** Phase 1 (Core Recording) + Phase 3 (Stitching)

```swift
// Enforce consistent recording settings
let videoSettings: [String: Any] = [
    AVVideoCodecKey: AVVideoCodecType.h264,
    AVVideoWidthKey: 720,
    AVVideoHeightKey: 1280,
    AVVideoCompressionPropertiesKey: [
        AVVideoAverageBitRateKey: 2_000_000, // 2 Mbps
        AVVideoProfileLevelKey: AVVideoProfileLevelH264HighAutoLevel
    ]
]
```

---

## 2. App Clip Limitations

### 2.1 Binary Size Exceeding 15MB (Now 50MB for iOS 16+)

**The Pitfall:** App Clips have strict size limits. Including video processing libraries, large assets, or frameworks can easily exceed limits, causing App Store rejection.

**Warning Signs:**
- Archive build exceeds size limit
- "App Clip too large" App Store Connect error
- Xcode build warnings about binary size

**Prevention Strategy:**
- Measure thinned binary size regularly (not universal binary)
- Use `xcrun --sdk iphoneos -v clang` to check per-architecture sizes
- Avoid bundling:
  - Large video processing frameworks (use AVFoundation only)
  - Image assets (use SF Symbols, system colors)
  - Third-party analytics SDKs in App Clip target
- Share code via framework but exclude from App Clip target
- Use asset catalogs with App Clip-specific assets (smaller)

**Phase:** Phase 1 - Must be designed for from start; impossible to fix later

```bash
# Check thinned binary size for App Clip
xcodebuild -exportArchive -archivePath MyApp.xcarchive \
  -exportPath export -exportOptionsPlist ExportOptions.plist
# Check: export/AppClips/TOYClip.app should be < 15MB (or 50MB for iOS 16+)
```

---

### 2.2 Limited API Availability in App Clips

**The Pitfall:** Many iOS APIs are unavailable or restricted in App Clips: HealthKit, CallKit, background modes, and limited local storage.

**Warning Signs:**
- Runtime crashes in App Clip that work in main app
- Features mysteriously not working in App Clip
- "Capability not available" errors

**Prevention Strategy:**
- Consult Apple's App Clip API availability documentation
- Create shared code with `#if APPCLIP` compiler directives
- Test every feature in App Clip target separately
- Do NOT rely on:
  - Persistent local storage (use server)
  - Background tasks
  - Push notifications (App Clips get ephemeral notifications only)
  - Keychain (data deleted after inactivity)

**Phase:** Phase 1 - Architecture decision

```swift
#if APPCLIP
// Minimal analytics, no persistent storage
Analytics.shared.useEphemeralMode()
#else
// Full analytics with persistent storage
Analytics.shared.useFullMode()
#endif
```

---

### 2.3 App Clip Session Expiration

**The Pitfall:** App Clips and their data are automatically deleted after a period of inactivity (varies, typically 30 days). Users returning to complete a recording may find their progress gone.

**Warning Signs:**
- Users report "my recording disappeared"
- Return visitors can't find their previous clip
- Confusion about App Clip vs full app

**Prevention Strategy:**
- Upload videos immediately after recording (don't store locally)
- Show clear "uploaded successfully" confirmation
- Provide card URL/code so users can return via link, not app icon
- Prompt to download full app for host/frequent users
- Never rely on App Clip local storage for important data

**Phase:** Phase 1 (Core Recording) + Phase 2 (Upload)

---

## 3. Video Stitching Challenges

### 3.1 Memory Crash During Multi-Clip Composition

**The Pitfall:** Loading 10+ video clips into memory simultaneously for `AVMutableComposition` causes out-of-memory crashes, especially on devices with 2-3GB RAM.

**Warning Signs:**
- Crash reports showing memory pressure
- "Jetsam" terminations in device logs
- Stitching fails only with many clips

**Prevention Strategy:**
- Use `AVAssetExportSession` with `.presetPassthrough` when possible
- Process clips sequentially, not all at once
- Use `AVURLAsset` with `AVURLAssetPreferPreciseDurationAndTimingKey: false` for faster loading
- Implement progressive composition (stitch 2-3 clips at a time, then combine)
- Consider server-side stitching for reliability (FFmpeg on cloud function)

**Phase:** Phase 3 (Montage Creation)

```swift
// Bad: Load all assets into memory
let assets = clipURLs.map { AVURLAsset(url: $0) } // Memory explosion

// Good: Process sequentially with autorelease
for clipURL in clipURLs {
    autoreleasepool {
        let asset = AVURLAsset(url: clipURL, options: [
            AVURLAssetPreferPreciseDurationAndTimingKey: false
        ])
        // Process and release
    }
}
```

---

### 3.2 Audio/Video Sync Drift in Final Montage

**The Pitfall:** When stitching clips with different audio sample rates or timing, audio can drift out of sync with video, especially noticeable in longer montages.

**Warning Signs:**
- Lip sync issues in final video
- Audio "jumps" at clip transitions
- Different audio levels between clips

**Prevention Strategy:**
- Normalize all clips to same audio format before stitching:
  - Sample rate: 44.1kHz
  - Channels: Stereo
  - Bit depth: 16-bit
- Use `AVMutableAudioMix` to handle transitions
- Apply crossfade transitions (0.3s) to mask audio discontinuities
- Test on long montages (10+ clips, 70+ seconds)

**Phase:** Phase 3 (Montage Creation)

---

### 3.3 Export Takes Too Long / Appears Frozen

**The Pitfall:** `AVAssetExportSession` can take 30+ seconds for a 70-second montage on older devices. Users think the app is frozen and force-quit.

**Warning Signs:**
- Support requests: "app froze during export"
- Incomplete montages in database
- Low task completion rates

**Prevention Strategy:**
- Show indeterminate progress (animated), not percentage
- Use `AVAssetExportSession.progress` to show real progress
- Add "This may take a moment" messaging
- Implement background task for export (`beginBackgroundTask`)
- Consider server-side stitching for complex montages

**Phase:** Phase 3 (Montage Creation)

```swift
// Enable background processing
var backgroundTask: UIBackgroundTaskIdentifier = .invalid
backgroundTask = UIApplication.shared.beginBackgroundTask {
    // Handle expiration
    exportSession.cancelExport()
    UIApplication.shared.endBackgroundTask(backgroundTask)
}
```

---

## 4. Supabase Storage Costs and Limitations

### 4.1 Storage Costs Spiraling with Uncompressed Video

**The Pitfall:** Users uploading videos at full camera resolution (4K) will quickly exhaust storage quotas. A single 4K 7-second clip can be 30-50MB.

**Warning Signs:**
- Storage costs exceeding projections by 5-10x
- Free tier limits hit during beta testing
- Slow uploads reported by users

**Prevention Strategy:**
- Compress before upload (720p, 2Mbps target = ~2MB per 7-sec clip)
- Calculate expected storage: (clips_per_card * avg_clip_size * cards_per_month)
- Implement client-side compression, not server-side
- Set maximum file size limit in Supabase storage policies
- Implement retention policy (delete raw clips after final video generated)

**Phase:** Phase 2 (Upload) - Critical cost control

```sql
-- Supabase storage policy: reject files > 10MB
create policy "Limit upload size"
on storage.objects for insert
with check (
  (metadata->>'size')::int < 10485760  -- 10MB
);
```

---

### 4.2 Supabase Free Tier Rate Limits

**The Pitfall:** Supabase free tier has API rate limits (500 requests/minute) and bandwidth limits. Viral cards can easily exceed these.

**Warning Signs:**
- 429 errors in production
- "too many requests" errors during card viewing
- Videos failing to load during high traffic

**Prevention Strategy:**
- Use signed URLs with long expiration for video delivery
- Implement CDN caching in front of Supabase storage
- Cache video URLs client-side
- Consider moving to Pro tier ($25/mo) before launch
- Implement exponential backoff for failed requests

**Phase:** Phase 2 (Upload) + Phase 4 (Viewing)

---

### 4.3 Large Video Upload Failures

**The Pitfall:** Uploading 5-10MB files on mobile networks frequently times out or fails silently. Supabase has upload size limits per request.

**Warning Signs:**
- Uploads succeeding on WiFi but failing on cellular
- Partial uploads corrupting database state
- Users reporting "upload seems stuck"

**Prevention Strategy:**
- Use Supabase `uploadToSignedUrl` for resumable uploads (>6MB files)
- Implement chunked upload with progress tracking
- Add retry logic with exponential backoff
- Compress aggressively to keep uploads under 5MB
- Show upload progress UI (not indeterminate spinner)

**Phase:** Phase 2 (Upload)

```swift
// Resumable upload for large files
let signedUrl = try await supabase.storage
    .from("clips")
    .createSignedUploadUrl(path: "cards/\(cardId)/\(clipId).mp4")

// Upload with URLSession for progress tracking
```

---

## 5. Deep Linking Gotchas on iOS

### 5.1 Universal Links Not Working Reliably

**The Pitfall:** Universal Links (for App Clip invocation) fail silently if AASA file is misconfigured, CDN-cached incorrectly, or DNS isn't propagated.

**Warning Signs:**
- App Clip card opens Safari instead of App Clip
- Works on some devices but not others
- Works on WiFi but not cellular (DNS caching)

**Prevention Strategy:**
- Validate AASA file: `https://app-site-association.cdn-apple.com/a/v1/yourdomain.com`
- Use Apple's AASA validator tool
- Ensure AASA served with `Content-Type: application/json`
- No redirects on AASA URL
- Test with fresh device (no cached links)
- Host AASA at root `.well-known/apple-app-site-association`

**Phase:** Phase 1 - Must be configured correctly before any testing

```json
// .well-known/apple-app-site-association
{
  "appclips": {
    "apps": ["TEAMID.com.yourcompany.toy.Clip"]
  },
  "applinks": {
    "apps": [],
    "details": [{
      "appID": "TEAMID.com.yourcompany.toy",
      "paths": ["/card/*", "/c/*"]
    }]
  }
}
```

---

### 5.2 App Clip Card URL Length Limits

**The Pitfall:** App Clip URLs have a practical limit around 2000 characters. Embedding data in URL params can exceed this and break scanning.

**Warning Signs:**
- QR codes become unscannable (too dense)
- NFC tags fail to write
- iMessage link previews break

**Prevention Strategy:**
- Use short card IDs (8-10 characters, base62 encoded)
- Never embed user data in URL
- Use URL structure: `https://toy.app/c/{shortId}`
- Store all card data server-side
- Test QR codes at all error correction levels

**Phase:** Phase 1 - URL scheme decision

---

### 5.3 Deep Link State Restoration Failures

**The Pitfall:** When a user opens an App Clip link, records a video, and the app is terminated, reopening loses context of which card they were contributing to.

**Warning Signs:**
- Users complete recording but video appears on wrong card
- "How do I get back to my card?" support requests
- Orphaned clips in database

**Prevention Strategy:**
- Store current card context immediately on App Clip launch
- Use `NSUserActivity` for state restoration
- Include card ID in all API calls (not relying on local state)
- Show card info prominently during recording flow
- Implement "recent cards" list for recovery

**Phase:** Phase 1 (Recording Flow)

---

## 6. User Experience Anti-Patterns

### 6.1 Requiring Account Creation to Contribute

**The Pitfall:** Requiring sign-up before recording a clip has 60-80% drop-off rate. Most people will abandon rather than create an account for a one-time action.

**Warning Signs:**
- High drop-off at sign-up screen
- Low clip-per-card ratios
- Feedback: "I just want to record a quick video"

**Prevention Strategy:**
- Allow anonymous contributions via App Clip (no sign-up)
- Assign temporary anonymous ID for clip ownership
- Only require account for host features (creating/managing cards)
- Offer "save your contribution" prompt AFTER recording complete

**Phase:** Phase 1 - Core UX decision

---

### 6.2 No Clip Preview/Retake Flow

**The Pitfall:** Users record their 7-second clip, mess up, and have no way to retake. They abandon the flow frustrated.

**Warning Signs:**
- Single-take clips with awkward endings
- Users recording same card multiple times (creating duplicates)
- Feedback: "I want to redo my video"

**Prevention Strategy:**
- Always show preview after recording
- "Retake" and "Use This Clip" buttons equally prominent
- Allow 3-5 retakes before upload (auto-delete unused)
- Consider saving last 2 takes locally for comparison

**Phase:** Phase 1 (Recording Flow)

---

### 6.3 Confusing App Clip vs Full App Experience

**The Pitfall:** Users don't understand the difference between App Clip and full app. They download the full app expecting their App Clip data, but it's not there.

**Warning Signs:**
- Support requests: "my videos are gone"
- App Store reviews: "app lost my recordings"
- Users creating duplicate cards

**Prevention Strategy:**
- Show clear banner in App Clip: "You're using TOY Instant"
- After successful contribution, prompt: "Get the full app to [benefit]"
- Ensure URL-based access works in both App Clip and full app identically
- Implement Keychain sharing between App Clip and full app targets
- Transfer App Clip data to full app on install

**Phase:** Phase 1 + Phase 4

---

### 6.4 Poor Non-Technical User Experience

**The Pitfall:** The target audience includes non-tech-savvy users (elderly relatives, etc.). Jargon, complex flows, or unclear CTAs will lose them.

**Warning Signs:**
- Older users unable to complete flow in testing
- Questions: "What is an App Clip?"
- Users screenshots asking for help

**Prevention Strategy:**
- Use plain language: "Record a Video" not "Capture Clip"
- Large tap targets (minimum 44pt)
- Single action per screen
- Show example/demo video before asking to record
- Test with actual target users (not just developers)

**Phase:** All phases - Continuous UX testing

---

## 7. In-App Purchase Implementation Issues

### 7.1 StoreKit 2 Transaction Verification Failures

**The Pitfall:** StoreKit 2's transaction verification can fail intermittently, causing users to pay but not receive their purchase.

**Warning Signs:**
- Purchases charged but not delivered
- `VerificationResult.unverified` errors in logs
- Support requests: "I paid but didn't get it"

**Prevention Strategy:**
- Always handle both `.verified` and `.unverified` cases
- Implement server-side receipt validation as fallback
- Store transaction IDs in your backend
- Provide manual restore mechanism
- Log all transaction states for debugging

**Phase:** Phase 5 (Monetization)

```swift
for await result in Transaction.updates {
    switch result {
    case .verified(let transaction):
        await deliverPurchase(transaction)
        await transaction.finish()
    case .unverified(let transaction, let error):
        // Log for investigation but don't block
        logger.error("Unverified: \(error)")
        // Consider delivering anyway for small purchases
    }
}
```

---

### 7.2 Subscription State Not Updating

**The Pitfall:** StoreKit 2's `currentEntitlements` can be stale. Users cancel or change subscription but app still shows old state.

**Warning Signs:**
- Cancelled users still have premium access
- Premium users lose access incorrectly
- Subscription state desyncs between devices

**Prevention Strategy:**
- Always verify subscription status with App Store on launch
- Implement server-side subscription status webhook
- Cache subscription state with short TTL (1 hour)
- Handle `Transaction.updates` for real-time changes
- Force refresh on key actions (creating premium card)

**Phase:** Phase 5 (Monetization)

---

### 7.3 App Store Review Rejection for IAP Issues

**The Pitfall:** Apple rejects apps for unclear IAP flows, missing restore button, or non-functional purchase buttons.

**Warning Signs:**
- "Guideline 3.1.1 - Business - Payments" rejection
- Rejection: "Unable to complete purchase"
- Sandbox testing works but review fails

**Prevention Strategy:**
- Include visible "Restore Purchases" button
- Handle all purchase states (success, cancel, pending, failed)
- Test in Sandbox environment extensively
- Ensure purchase flows work without network
- Add "Demo/Preview" mode for unpurchased features
- Clear pricing display before purchase

**Phase:** Phase 5 (Monetization)

---

## 8. Performance and Reliability

### 8.1 Video Playback Stuttering

**The Pitfall:** Playing final montage video stutters on first load because the entire file downloads before playback starts.

**Warning Signs:**
- Long delay before video starts
- Playback pauses/buffers mid-video
- Works on WiFi, terrible on cellular

**Prevention Strategy:**
- Use HLS streaming for final videos (not direct mp4)
- Enable progressive download (`AVURLAsset.preferredForwardBufferDuration`)
- Preload video when card is opened, before user presses play
- Show loading state while buffering (not blank screen)

**Phase:** Phase 4 (Viewing Experience)

---

### 8.2 No Offline Handling

**The Pitfall:** App crashes or behaves unexpectedly when network is unavailable. Users in basements or airplanes can't use the app.

**Warning Signs:**
- Crashes when network drops mid-recording
- Infinite spinners on poor connections
- Lost recordings due to upload failures

**Prevention Strategy:**
- Queue uploads for retry when offline
- Save recordings locally until confirmed uploaded
- Show clear offline messaging
- Timeout API calls (10s max) with retry
- Test with Network Link Conditioner

**Phase:** All phases - Core architecture

---

## Phase Mapping Summary

| Pitfall Category | Phase 1 | Phase 2 | Phase 3 | Phase 4 | Phase 5 |
|-----------------|---------|---------|---------|---------|---------|
| Video Recording | Core | - | - | - | - |
| App Clip Limits | Core | - | - | - | - |
| Video Stitching | - | - | Core | - | - |
| Supabase Storage | - | Core | - | Consider | - |
| Deep Linking | Core | - | - | - | - |
| UX Anti-Patterns | Core | - | - | Core | - |
| In-App Purchase | - | - | - | - | Core |
| Performance | - | - | - | Core | - |

---

## Critical Pre-Development Checklist

Before writing any code, verify:

- [ ] App Clip size budget calculated (track with every build)
- [ ] Video format spec locked (720p, H.264, 30fps, stereo 44.1kHz)
- [ ] Universal Links AASA file configured and validated
- [ ] URL scheme designed (short IDs, no user data in URL)
- [ ] Supabase storage tier selected with cost projections
- [ ] Anonymous contribution flow designed
- [ ] Error recovery flows documented for every user action

---

*Last Updated: 2026-02-01*
*Research Type: Pitfalls Dimension*
*Project: TOY (Thinking Of You) - Group Video Greeting Card App*
