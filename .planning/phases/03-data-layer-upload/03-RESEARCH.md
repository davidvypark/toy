# Phase 3: Data Layer & Upload - Research

**Researched:** 2026-02-02
**Domain:** Supabase Storage, iOS Universal Links, Video Upload with Progress
**Confidence:** MEDIUM

## Summary

This phase requires implementing video upload to Supabase Storage with progress tracking, secure signed URL generation for video playback, and Universal Links for deep linking into the app. The project already uses supabase-swift v2.41.0 which provides storage APIs, but **does not yet support native progress tracking or resumable uploads** - this is the key constraint.

The standard approach involves:
1. Using Supabase Storage standard upload API for files under 6MB, or implementing TUSKit separately for larger files with progress
2. Creating RLS policies that allow authenticated uploads but use signed URLs for secure read access
3. Configuring Universal Links via AASA file on web server + Associated Domains entitlement in Xcode
4. Using SwiftUI's `onOpenURL` modifier for handling incoming deep links

**Primary recommendation:** Use standard Supabase upload with custom URLSession wrapper for progress tracking, store clips in a private bucket with RLS, and generate time-limited signed URLs for playback. For Universal Links, host AASA file on Supabase Edge Functions or your domain.

## Standard Stack

### Core
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| supabase-swift | 2.41.0 | Storage upload, signed URLs | Already integrated, official SDK |
| URLSession | iOS 17+ | Upload with progress delegate | Native iOS, no dependencies |
| Associated Domains | - | Universal Links entitlement | Apple's official deep linking |

### Supporting
| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| TUSKit | latest | Resumable uploads with progress | If videos exceed 6MB frequently or need resume-on-failure |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| Custom URLSession wrapper | TUSKit | TUSKit adds dependency but gives auto-retry, background upload; URLSession is simpler for our ~30s clips |
| Supabase standard upload | Supabase resumable upload | Swift SDK doesn't support resumable yet (planned for v3), would need TUSKit directly |
| Private bucket + signed URLs | Public bucket | Public bucket exposes all videos; signed URLs provide time-limited secure access |

**Note:** No additional Swift packages needed - supabase-swift is already integrated.

## Architecture Patterns

### Recommended Project Structure
```
TOY/
├── TOYShared/Sources/TOYShared/
│   └── Services/
│       ├── SupabaseClient.swift     # Existing
│       ├── StorageService.swift     # NEW: Upload + signed URLs
│       └── DeepLinkService.swift    # NEW: URL parsing
├── TOY/
│   └── Features/
│       └── Recording/
│           ├── RecordingViewModel.swift  # Wire upload to confirmVideo()
│           └── UploadProgressView.swift  # NEW: Progress indicator
└── TOY.entitlements                      # Add Associated Domains
```

### Pattern 1: Upload Service with Progress
**What:** Wrap Supabase upload in a service that provides progress via AsyncStream
**When to use:** For all video uploads
**Example:**
```swift
// Source: Supabase docs + URLSession delegate pattern
actor StorageService {
    func uploadVideo(
        fileURL: URL,
        clipId: UUID,
        onProgress: @escaping (Double) -> Void
    ) async throws -> String {
        let bucket = supabase.storage.from("clips")
        let path = "\(clipId).mov"
        let fileData = try Data(contentsOf: fileURL)

        // For simple implementation without custom progress:
        try await bucket.upload(
            path: path,
            file: fileData,
            options: FileOptions(
                cacheControl: "3600",
                contentType: "video/quicktime",
                upsert: false
            )
        )

        return path
    }

    func createSignedURL(path: String, expiresIn: Int = 3600) async throws -> URL {
        try await supabase.storage
            .from("clips")
            .createSignedURL(path: path, expiresIn: expiresIn)
    }
}
```

### Pattern 2: Custom Progress Tracking with URLSession
**What:** Use URLSession delegate for byte-level progress on large uploads
**When to use:** If supabase-swift's standard upload doesn't provide progress
**Example:**
```swift
// Source: Apple URLSession documentation
class UploadDelegate: NSObject, URLSessionTaskDelegate {
    var onProgress: ((Double) -> Void)?

    func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        didSendBodyData bytesSent: Int64,
        totalBytesSent: Int64,
        totalBytesExpectedToSend: Int64
    ) {
        let progress = Double(totalBytesSent) / Double(totalBytesExpectedToSend)
        onProgress?(progress)
    }
}
```

### Pattern 3: Deep Link Handling with onOpenURL
**What:** SwiftUI modifier to handle Universal Links
**When to use:** At app root level
**Example:**
```swift
// Source: SwiftUI documentation
@main
struct TOYApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                .onOpenURL { url in
                    handleDeepLink(url)
                }
        }
    }

    private func handleDeepLink(_ url: URL) {
        // URL format: https://yourdomain.com/card/{shareToken}
        guard let host = url.host,
              host == "yourdomain.com",
              url.pathComponents.count >= 3,
              url.pathComponents[1] == "card" else { return }

        let shareToken = url.pathComponents[2]
        // Navigate to card view with shareToken
    }
}
```

### Anti-Patterns to Avoid
- **Storing videos in public bucket without signed URLs:** Exposes all content; use private bucket + signed URLs
- **Uploading from Data instead of file for background uploads:** Background uploads require file reference, not Data
- **Hardcoding signed URL expiry too long:** 24+ hour URLs are security risk; use 1 hour default
- **Not handling upload failure:** Always implement retry logic for network failures

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Video upload to cloud | Custom S3 integration | Supabase Storage API | Already configured, RLS policies, signed URLs |
| Progress tracking | Timer-based polling | URLSession delegate or TUSKit | Native progress callbacks are accurate |
| Retry logic | Custom retry counter | Exponential backoff or TUSKit | Edge cases (partial uploads, timeouts) are complex |
| Deep link URL parsing | Manual string parsing | URLComponents | Handles encoding, edge cases |
| AASA file hosting | Manual server setup | Supabase Edge Functions or CDN | Must be exact format, no redirects |

**Key insight:** Supabase handles storage complexity (bucket permissions, CDN, signed URLs). URLSession handles upload progress natively. Don't build infrastructure.

## Common Pitfalls

### Pitfall 1: RLS Policy Blocking Uploads
**What goes wrong:** Upload fails with 403 or "new row violates row-level security policy"
**Why it happens:** Missing INSERT policy on storage.objects table
**How to avoid:** Create explicit RLS policy:
```sql
CREATE POLICY "authenticated_upload_clips"
ON storage.objects FOR INSERT
TO authenticated
WITH CHECK (bucket_id = 'clips');
```
**Warning signs:** Upload works with service key but fails with anon/authenticated

### Pitfall 2: Signed URLs Not Working
**What goes wrong:** 403 when accessing signed URL, or URL expires immediately
**Why it happens:** Missing SELECT policy, or bucket is public (signed URLs bypass)
**How to avoid:** Private bucket + SELECT policy for signed URL generation:
```sql
CREATE POLICY "authenticated_select_clips"
ON storage.objects FOR SELECT
TO authenticated
USING (bucket_id = 'clips');
```
**Warning signs:** Can upload but can't generate working signed URLs

### Pitfall 3: Universal Links Not Opening App
**What goes wrong:** Link opens in Safari instead of app
**Why it happens:** AASA file not found, wrong format, or cached
**How to avoid:**
1. File must be at `/.well-known/apple-app-site-association` (no .json extension)
2. Content-Type: application/json header required
3. No redirects allowed
4. Delete and reinstall app to refresh iOS cache
**Warning signs:** Works on some devices not others; worked yesterday but not today

### Pitfall 4: Upload Progress Shows 0% Then 100%
**What goes wrong:** No intermediate progress values
**Why it happens:** Using completion handler API instead of delegate
**How to avoid:** Use URLSession with delegate, not completion handler
**Warning signs:** Progress jumps directly to complete

### Pitfall 5: Large Video Upload Timeout
**What goes wrong:** Upload fails after ~60 seconds on slow connection
**Why it happens:** Default timeout, video larger than expected
**How to avoid:**
1. Verify video size (~30s at 720p H.264 should be 5-15MB)
2. Set longer timeout on URLRequest
3. Consider TUSKit for resumable uploads
**Warning signs:** Upload succeeds on WiFi, fails on cellular

## Code Examples

### Supabase Storage Upload (Verified)
```swift
// Source: https://supabase.com/docs/reference/swift/storage-from-upload
let fileName = "clip-\(UUID()).mov"
let fileData = try Data(contentsOf: localVideoURL)

try await supabase.storage
    .from("clips")
    .upload(
        path: fileName,
        file: fileData,
        options: FileOptions(
            cacheControl: "3600",
            contentType: "video/quicktime",
            upsert: false
        )
    )
```

### Create Signed URL (Verified)
```swift
// Source: https://supabase.com/docs/reference/swift/storage-from-createsignedurl
let signedURL = try await supabase.storage
    .from("clips")
    .createSignedURL(path: "clip-abc123.mov", expiresIn: 3600)
// Returns URL valid for 1 hour
```

### RLS Policies for Clips Bucket
```sql
-- Source: https://supabase.com/docs/guides/storage/security/access-control

-- Allow authenticated users to upload
CREATE POLICY "authenticated_insert_clips"
ON storage.objects FOR INSERT
TO authenticated
WITH CHECK (bucket_id = 'clips');

-- Allow authenticated users to generate signed URLs
CREATE POLICY "authenticated_select_clips"
ON storage.objects FOR SELECT
TO authenticated
USING (bucket_id = 'clips');

-- For upsert (overwrite), also need UPDATE
CREATE POLICY "authenticated_update_clips"
ON storage.objects FOR UPDATE
TO authenticated
USING (bucket_id = 'clips');
```

### AASA File Format (Verified)
```json
{
    "applinks": {
        "details": [{
            "appIDs": ["TEAMID.com.yourcompany.TOY"],
            "components": [
                {
                    "/": "/card/*",
                    "comment": "Matches card deep links"
                }
            ]
        }]
    }
}
```

### SwiftUI Universal Link Handler (Verified)
```swift
// Source: https://fatbobman.com/en/posts/howto-swiftui-onopenurl/
@main
struct TOYApp: App {
    @State private var deepLinkCardToken: String?

    var body: some Scene {
        WindowGroup {
            ContentView()
                .onOpenURL { url in
                    if let token = parseCardToken(from: url) {
                        deepLinkCardToken = token
                    }
                }
        }
    }

    private func parseCardToken(from url: URL) -> String? {
        guard url.pathComponents.count >= 3,
              url.pathComponents[1] == "card" else { return nil }
        return url.pathComponents[2]
    }
}
```

### URLSession Upload with Progress
```swift
// Source: Apple URLSession documentation
func uploadWithProgress(
    fileURL: URL,
    to uploadURL: URL,
    headers: [String: String],
    onProgress: @escaping (Double) -> Void
) async throws {
    let delegate = UploadProgressDelegate(onProgress: onProgress)
    let session = URLSession(
        configuration: .default,
        delegate: delegate,
        delegateQueue: nil
    )

    var request = URLRequest(url: uploadURL)
    request.httpMethod = "POST"
    headers.forEach { request.setValue($1, forHTTPHeaderField: $0) }

    let (_, response) = try await session.upload(for: request, fromFile: fileURL)
    guard let httpResponse = response as? HTTPURLResponse,
          (200...299).contains(httpResponse.statusCode) else {
        throw UploadError.serverError
    }
}

class UploadProgressDelegate: NSObject, URLSessionTaskDelegate {
    let onProgress: (Double) -> Void

    init(onProgress: @escaping (Double) -> Void) {
        self.onProgress = onProgress
    }

    func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        didSendBodyData bytesSent: Int64,
        totalBytesSent: Int64,
        totalBytesExpectedToSend: Int64
    ) {
        let progress = Double(totalBytesSent) / Double(totalBytesExpectedToSend)
        DispatchQueue.main.async {
            self.onProgress(progress)
        }
    }
}
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| AppDelegate `continue userActivity` | SwiftUI `onOpenURL` modifier | iOS 14 / SwiftUI 2.0 | Declarative, view-scoped handling |
| Data-based upload | File-based upload | Background session req | Required for background uploads |
| Public bucket URLs | Signed URLs | Always recommended | Time-limited secure access |
| Custom TUS implementation | TUSKit library | 2023+ | Standardized resumable uploads |

**Deprecated/outdated:**
- `application(_:open:options:)` for URL schemes - use `onOpenURL` for SwiftUI apps
- AASA v1 format with `appID` (singular) - use v2 format with `appIDs` (array) and `components`

## Open Questions

1. **Progress tracking without TUSKit**
   - What we know: supabase-swift v2.41.0 upload() returns after completion, no progress callback
   - What's unclear: Whether we can intercept the underlying URLSession for progress
   - Recommendation: Start with completion-only upload; add custom URLSession wrapper if UX demands progress bar

2. **Exact video file sizes**
   - What we know: 30s 720p H.264 typically 5-15MB depending on content
   - What's unclear: Actual sizes from the recording pipeline in this app
   - Recommendation: Log actual file sizes in testing; if regularly >6MB, prioritize TUSKit

3. **AASA hosting location**
   - What we know: Needs HTTPS, no redirects, specific Content-Type
   - What's unclear: Where the project's web domain is hosted
   - Recommendation: Can use Supabase Edge Functions to serve AASA, or any static hosting

4. **Retry strategy details**
   - What we know: Need retry on failure
   - What's unclear: How many retries, exponential backoff timing, user feedback
   - Recommendation: 3 retries with 2s/4s/8s delays; show "Retrying..." state

## Sources

### Primary (HIGH confidence)
- [Supabase Swift Storage Upload](https://supabase.com/docs/reference/swift/storage-from-upload) - upload API syntax
- [Supabase Swift Signed URLs](https://supabase.com/docs/reference/swift/storage-from-createsignedurl) - createSignedURL API
- [Supabase Storage Access Control](https://supabase.com/docs/guides/storage/security/access-control) - RLS policy patterns
- [SwiftUI onOpenURL](https://fatbobman.com/en/posts/howto-swiftui-onopenurl/) - Universal Link handling in SwiftUI

### Secondary (MEDIUM confidence)
- [SwiftLee Universal Links](https://www.avanderlee.com/swiftui/universal-links-ios/) - AASA format, entitlements
- [TUSKit GitHub](https://github.com/tus/TUSKit) - resumable upload API
- [Supabase Resumable Uploads](https://supabase.com/docs/guides/storage/uploads/resumable-uploads) - TUS protocol support
- [URLSession Background Uploads](https://www.avanderlee.com/swift/urlsession-common-pitfalls-with-background-download-upload-tasks/) - background session pitfalls

### Tertiary (LOW confidence)
- [supabase-swift issue #171](https://github.com/supabase/supabase-swift/issues/171) - resumable upload status (v3 planned)
- WebSearch results for iOS upload patterns - community practices

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH - supabase-swift is documented, URLSession is Apple API
- Architecture: MEDIUM - upload service pattern is standard, but progress tracking approach needs validation
- Pitfalls: MEDIUM - RLS policies verified in docs, Universal Links pitfalls from multiple sources
- Deep linking: HIGH - SwiftUI onOpenURL is well-documented

**Research date:** 2026-02-02
**Valid until:** 2026-03-02 (30 days - stable domain, supabase-swift actively maintained)
