# Phase 6: Video Stitching & Publishing - Research

**Researched:** 2026-02-02
**Domain:** iOS video composition, Supabase storage, publishing workflow
**Confidence:** HIGH

## Summary

This phase implements video montage stitching and publishing for TOY. Research investigated the key technical question: client-side vs server-side video stitching.

**Key finding:** Server-side video stitching via Supabase Edge Functions is NOT feasible because FFmpeg is not installed in the Deno runtime. Alternative cloud services (Cloudinary, AWS MediaConvert) add significant complexity and cost for an MVP. The existing `VideoMerger` class already successfully merges clips using `AVMutableComposition` - this same approach can be extended to stitch all clips from a card into a final montage.

**Recommendation:** Use client-side stitching with the existing `VideoMerger` infrastructure. This leverages proven code, avoids third-party service dependencies, and keeps the MVP simple. The trade-off (device processing time, battery usage) is acceptable for cards with 8 or fewer participants (the free tier limit).

**Primary recommendation:** Extend `VideoMerger` for montage stitching, download clips from signed URLs, stitch locally, upload final video to new "videos" bucket, update card with video_url and published status.

## Standard Stack

The established libraries/tools for this domain:

### Core
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| AVFoundation | iOS 15+ | Video composition and export | Apple's native framework, already in use |
| AVMutableComposition | iOS 15+ | Combine multiple video assets | Used in existing VideoMerger |
| AVAssetExportSession | iOS 15+ | Export composed video with progress | Standard for video export |
| Supabase Storage | Latest | Store final montage videos | Already integrated for clips |

### Supporting
| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| AVURLAsset | iOS 15+ | Load video from signed URLs | Downloading clips for stitching |
| FileManager | iOS 15+ | Temporary file management | Store downloaded clips before merge |
| Progress/Timer | iOS 15+ | Export progress tracking | UI feedback during long operations |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| Client-side AVFoundation | Cloudinary API | Adds $$ cost, external dependency, async webhook complexity |
| Client-side AVFoundation | AWS MediaConvert | Overkill for MVP, requires AWS account/setup |
| Client-side AVFoundation | Supabase Edge Functions + FFmpeg | NOT POSSIBLE - FFmpeg not available in Deno runtime |
| AVAssetExportSession | Third-party FFmpeg wrapper | Unnecessary complexity, Apple's solution works |

## Architecture Patterns

### Recommended Project Structure
```
TOY/Features/Publishing/
├── MontageService.swift           # Orchestrates download, stitch, upload
├── MontageStitcher.swift          # Extends VideoMerger for multi-clip download+stitch
├── PublishViewModel.swift         # UI state management
├── MontagePreviewView.swift       # Full montage preview before publish
└── PublishedCardView.swift        # Success view with shareable link

TOYShared/Sources/TOYShared/
├── Services/
│   └── CardService.swift          # Add publishCard(), update video_url
└── Services/
    └── StorageService.swift       # Add videos bucket support
```

### Pattern 1: Download-Stitch-Upload Pipeline
**What:** Sequential pipeline that downloads all clips, stitches locally, uploads result
**When to use:** When generating the final montage from multiple remote clips
**Example:**
```swift
// Source: Verified pattern based on existing VideoMerger + StorageService
actor MontageService {
    private let storageService = StorageService()
    private let videoMerger = VideoMerger()

    func generateMontage(for card: Card, clips: [Clip]) async throws -> URL {
        // 1. Download clips to temp directory (host first, then chronological)
        let sortedClips = sortClipsForMontage(clips, hostId: card.hostId)
        let localURLs = try await downloadClips(sortedClips)

        // 2. Stitch using existing VideoMerger
        let montageURL = try await videoMerger.mergeClips(localURLs)

        // 3. Upload to videos bucket
        let storagePath = try await uploadMontage(montageURL, cardId: card.id)

        // 4. Cleanup temp files
        cleanupTempFiles(localURLs)

        return storagePath
    }
}
```

### Pattern 2: Export Progress Tracking
**What:** Timer-based progress monitoring for AVAssetExportSession
**When to use:** During video export to provide UI feedback
**Example:**
```swift
// Source: Apple AVAssetExportSession documentation + community patterns
func exportWithProgress(
    composition: AVComposition,
    to outputURL: URL,
    onProgress: @escaping (Float) -> Void
) async throws {
    guard let exporter = AVAssetExportSession(
        asset: composition,
        presetName: AVAssetExportPreset1280x720
    ) else {
        throw StitchingError.exportFailed
    }

    exporter.outputURL = outputURL
    exporter.outputFileType = .mov
    exporter.shouldOptimizeForNetworkUse = true

    // Progress tracking via timer (iOS 17 compatible approach)
    let progressTask = Task {
        while !Task.isCancelled {
            await MainActor.run {
                onProgress(exporter.progress)
            }
            try? await Task.sleep(nanoseconds: 100_000_000) // 0.1s

            if exporter.status == .completed || exporter.status == .failed {
                break
            }
        }
    }

    await exporter.export()
    progressTask.cancel()

    guard exporter.status == .completed else {
        throw StitchingError.exportFailed(exporter.error)
    }
}
```

### Pattern 3: Clip Ordering for Montage
**What:** Sort clips with host first, then chronologically by upload time
**When to use:** Before stitching to ensure correct montage order
**Example:**
```swift
// Source: REC decision CLIP-002 (host clips orderPosition = 0)
func sortClipsForMontage(_ clips: [Clip], hostId: UUID) -> [Clip] {
    // Host clip first (identified by participantId matching hostId per HOST-001)
    let hostClip = clips.first { $0.participantId == hostId }

    // Remaining clips sorted by orderPosition, then createdAt
    let participantClips = clips
        .filter { $0.participantId != hostId }
        .sorted { clip1, clip2 in
            if let pos1 = clip1.orderPosition, let pos2 = clip2.orderPosition {
                return pos1 < pos2
            }
            return clip1.createdAt < clip2.createdAt
        }

    return [hostClip].compactMap { $0 } + participantClips
}
```

### Anti-Patterns to Avoid
- **Streaming stitching from remote URLs:** AVMutableComposition requires local file access for reliable track insertion. Always download clips first.
- **Blocking main thread during export:** Export operations MUST run on background queue. Use async/await pattern.
- **Ignoring export cancellation on app background:** AVAssetExportSession terminates when app backgrounds. Warn user or implement resume logic.
- **Creating overly large compositions:** Memory pressure from loading many clips simultaneously. Process in batches if needed.

## Don't Hand-Roll

Problems that look simple but have existing solutions:

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Video merging | Custom FFmpeg wrapper | VideoMerger (existing) | Already handles composition, transforms, export |
| Signed URL generation | Manual token generation | StorageService.createSignedURL() | Already handles Supabase auth |
| Progress UI | Custom progress ring | ProgressView with binding | SwiftUI provides standard component |
| Temporary file cleanup | Manual file deletion | FileManager.removeItem in defer | Standard pattern prevents leaks |
| Video thumbnail | Frame extraction | AVAssetImageGenerator | Already used in CardDetailView |

**Key insight:** The existing VideoMerger handles the hard parts of video composition (transform preservation, track insertion, H.264 export). Montage generation is an extension, not a rewrite.

## Common Pitfalls

### Pitfall 1: App Background Kills Export
**What goes wrong:** User backgrounds app during export, AVAssetExportSession terminates
**Why it happens:** iOS suspends the export session when app enters background
**How to avoid:**
- Request background task time with `UIApplication.shared.beginBackgroundTask`
- Show clear warning before starting export about keeping app open
- Consider implementing resume capability for long exports
**Warning signs:** Export progress stuck at partial completion after app foreground

### Pitfall 2: Memory Pressure with Multiple Clips
**What goes wrong:** App crashes or slows dramatically during stitching
**Why it happens:** Loading all video assets into memory simultaneously
**How to avoid:**
- Load assets lazily during composition building
- Use `AVAssetExportPreset1280x720` (720p) not higher presets
- Consider batch processing for cards with many clips
**Warning signs:** Memory warnings in console, choppy UI during export

### Pitfall 3: Inconsistent Video Dimensions
**What goes wrong:** Black bars or cropped video in final montage
**Why it happens:** Clips may have different dimensions if recorded on different devices
**How to avoid:**
- All clips should already be 720p portrait from recording pipeline
- Verify dimensions match before stitching
- Apply scaling transform if dimensions differ
**Warning signs:** Visual artifacts in preview, unexpected aspect ratios

### Pitfall 4: Network Timeout During Clip Download
**What goes wrong:** Montage generation fails partway through
**Why it happens:** Large video files timeout on slow connections
**How to avoid:**
- Use URLSession with extended timeout configuration
- Implement retry logic per-clip
- Show per-clip download progress, not just overall
**Warning signs:** Intermittent failures on cellular networks

### Pitfall 5: Published Card Without Video URL
**What goes wrong:** Card status is "published" but video_url is null
**Why it happens:** Status update succeeds but upload fails, no transaction
**How to avoid:**
- Upload video first, only update card status after confirmed upload
- Validate card has video_url before allowing publish UI
- Use optimistic UI with rollback on failure
**Warning signs:** Recipients see broken video links

## Code Examples

Verified patterns from official sources and existing codebase:

### Download Video from Signed URL
```swift
// Source: Existing StorageService pattern + URLSession
func downloadClip(_ clip: Clip, to directory: URL) async throws -> URL {
    let storageService = StorageService()
    let signedURL = try await storageService.createSignedURL(path: clip.videoUrl)

    let localURL = directory.appendingPathComponent("\(clip.id).mov")

    let (tempURL, response) = try await URLSession.shared.download(from: signedURL)

    guard let httpResponse = response as? HTTPURLResponse,
          httpResponse.statusCode == 200 else {
        throw MontageError.downloadFailed
    }

    try FileManager.default.moveItem(at: tempURL, to: localURL)
    return localURL
}
```

### Create Videos Bucket (SQL Migration)
```sql
-- Source: Pattern from existing 002_storage_policies.sql
INSERT INTO storage.buckets (id, name, public)
VALUES ('videos', 'videos', false)
ON CONFLICT (id) DO NOTHING;

-- RLS policies for videos bucket (same pattern as clips)
CREATE POLICY "authenticated_insert_videos"
ON storage.objects FOR INSERT
TO authenticated
WITH CHECK (bucket_id = 'videos');

CREATE POLICY "authenticated_select_videos"
ON storage.objects FOR SELECT
TO authenticated
USING (bucket_id = 'videos');
```

### Update Card to Published Status
```swift
// Source: Existing CardService.updateCardStatus pattern
public func publishCard(cardId: UUID, videoUrl: String) async throws {
    do {
        try await supabase
            .from("cards")
            .update([
                "status": "published",
                "video_url": videoUrl,
                "published_at": ISO8601DateFormatter().string(from: Date())
            ])
            .eq("id", value: cardId)
            .execute()
    } catch {
        throw CardError.updateFailed(error.localizedDescription)
    }
}
```

### StorageService Extension for Videos Bucket
```swift
// Source: Existing uploadVideo pattern adapted for videos bucket
public func uploadMontage(fileURL: URL, cardId: UUID) async throws -> String {
    guard FileManager.default.fileExists(atPath: fileURL.path) else {
        throw UploadError.fileNotFound
    }

    let fileData = try Data(contentsOf: fileURL)
    let path = "\(cardId).mov"
    let bucket = supabase.storage.from("videos")  // Different bucket

    try await bucket.upload(
        path: path,
        file: fileData,
        options: FileOptions(
            cacheControl: "2592000",
            contentType: "video/quicktime",
            upsert: true  // Allow re-publish
        )
    )

    return path
}
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| Server-side FFmpeg | Client-side AVFoundation | N/A for Supabase | Server-side not viable without external service |
| exportAsynchronously callback | async export() method | iOS 18 | Cleaner code but requires iOS 18 deployment |
| Timer-based progress | Task with sleep | Swift Concurrency | Works with structured concurrency |

**Deprecated/outdated:**
- `AVAssetExportSession.exportAsynchronously(completionHandler:)` - Still works but async `export()` preferred on iOS 18+
- Server-side stitching via Supabase Edge Functions - Not possible, FFmpeg not available

## Open Questions

Things that couldn't be fully resolved:

1. **Background Export Continuation**
   - What we know: Export terminates on app background
   - What's unclear: Best UX for handling this (prevent, warn, resume?)
   - Recommendation: Start with warning + background task request, defer resume to future

2. **Montage Preview Before Upload**
   - What we know: Can preview locally stitched video
   - What's unclear: Should preview use local file or upload first for signed URL?
   - Recommendation: Preview from local file (faster), upload only after confirm

3. **Re-Publishing After Adding Clips**
   - What we know: Card can have clips added after initial publish
   - What's unclear: Should re-stitching replace video or create new version?
   - Recommendation: Replace (upsert) for MVP simplicity, version history deferred

4. **Maximum Clip Count Performance**
   - What we know: Free tier allows 8 participants + host = 9 clips max
   - What's unclear: Exact memory/time limits for stitching 9 x 7-second clips
   - Recommendation: Test on oldest supported device (iPhone 11 / iOS 15)

## Sources

### Primary (HIGH confidence)
- Existing codebase: `VideoMerger.swift` - verified working clip merge implementation
- Existing codebase: `StorageService.swift` - verified signed URL and upload patterns
- Existing codebase: `CardService.swift` - verified card update patterns
- Apple Developer Documentation: AVMutableComposition, AVAssetExportSession

### Secondary (MEDIUM confidence)
- [GitHub Discussion #27280](https://github.com/orgs/supabase/discussions/27280) - FFmpeg not available in Supabase Edge Functions, WASM alternative mentioned but unverified for video
- [Kodeco AVFoundation Tutorial](https://www.kodeco.com/10857372-how-to-play-record-and-merge-videos-in-ios-and-swift) - AVFoundation merge patterns
- [IMG.LY Blog](https://img.ly/blog/combine-video-clips-into-a-new-file-in-ios-with-swift/) - Video composition patterns
- [Cloudinary Documentation](https://cloudinary.com/documentation/video_trimming_and_concatenating) - Alternative server-side option (not recommended for MVP)

### Tertiary (LOW confidence)
- WebSearch results on export progress monitoring - multiple approaches mentioned, timer-based most compatible

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH - Uses existing proven codebase patterns
- Architecture: HIGH - Direct extension of working VideoMerger
- Pitfalls: MEDIUM - Based on general AVFoundation knowledge, some specific edge cases may vary
- Cloud alternatives: HIGH - Supabase limitation confirmed via GitHub discussion

**Research date:** 2026-02-02
**Valid until:** 60 days (AVFoundation is stable, patterns unlikely to change)
