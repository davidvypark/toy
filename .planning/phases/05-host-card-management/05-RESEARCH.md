# Phase 5: Host Card Management - Research

**Researched:** 2026-02-02
**Domain:** SwiftUI List/Detail views, video preview from signed URLs, Supabase delete operations
**Confidence:** HIGH

## Summary

Phase 5 enables hosts to manage their created cards: viewing all participants and their submission status, previewing submitted clips, and deleting unwanted clips. This phase builds on the existing CardService, StorageService, and models (Card, Clip, Participant) from Phase 4, adding query methods for fetching participants and clips, and delete operations for clip removal.

The implementation requires three main components: (1) a card detail view showing participants list with status indicators, (2) video preview using signed URLs from StorageService (reusing the existing `LoopingVideoPlayer` pattern from VideoPreviewView), and (3) clip deletion with confirmation dialog and cascade delete from storage. The existing RLS policies already support hosts reading/deleting clips on their cards via the `is_host_of_card()` helper function.

**Primary recommendation:** Extend CardService with `fetchParticipantsForCard`, `fetchClipsForCard`, and `deleteClip` methods. Create CardDetailView with participant list and clip preview. Use SwiftUI's native `.confirmationDialog` for delete confirmation and `.refreshable` for pull-to-refresh.

## Standard Stack

The established libraries/tools for this domain:

### Core
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| SwiftUI List | iOS 18.2+ | Participant/clip listing | Native, handles dynamic content |
| AVPlayer | iOS 18.2+ | Video preview playback | Already used in VideoPreviewView |
| Supabase Swift | 2.x | Fetch/delete operations | Already integrated, type-safe |
| confirmationDialog | iOS 15+ | Delete confirmation | Native SwiftUI, no wrapper needed |

### Supporting
| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| AVAssetImageGenerator | Built-in | Video thumbnails | Clip list previews |
| refreshable | iOS 15+ | Pull to refresh | Updating participant status |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| List | LazyVStack in ScrollView | List provides swipe actions and better performance |
| AVAssetImageGenerator | First frame from AVPlayer | Generator is async and more efficient for lists |
| confirmationDialog | Custom alert | Dialog is standard pattern for destructive actions |

**No additional packages required.** All capabilities exist in current dependencies.

## Architecture Patterns

### Recommended Project Structure
```
TOY/Features/
├── CardManagement/
│   ├── CardDetailView.swift          # Main management view
│   ├── CardDetailViewModel.swift     # Data loading and actions
│   ├── ParticipantRow.swift          # Individual participant with status
│   ├── ClipPreviewView.swift         # Video preview modal/sheet
│   └── ClipThumbnail.swift           # Thumbnail generation helper
├── Home/
│   └── HomeView.swift                # Add navigation to CardDetailView
TOYShared/Sources/TOYShared/
└── Services/
    └── CardService.swift             # Add fetch/delete methods
```

### Pattern 1: Card Detail ViewModel with @Observable
**What:** MainActor-isolated Observable class managing card detail state
**When to use:** Any view needing async data loading with refresh capability
**Example:**
```swift
// Source: Existing CreateCardViewModel pattern in codebase
@MainActor
@Observable
final class CardDetailViewModel {
    // State
    var participants: [Participant] = []
    var clips: [Clip] = []
    var isLoading = false
    var errorMessage: String?

    private let cardService = CardService()
    private let storageService = StorageService()

    func loadData(for cardId: UUID) async {
        isLoading = true
        do {
            async let fetchedParticipants = cardService.fetchParticipantsForCard(cardId: cardId)
            async let fetchedClips = cardService.fetchClipsForCard(cardId: cardId)
            participants = try await fetchedParticipants
            clips = try await fetchedClips
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }
}
```

### Pattern 2: Supabase Query with Foreign Key Join
**What:** Fetching related data in a single query using select with relationships
**When to use:** When you need participant info alongside clips
**Example:**
```swift
// Source: Supabase Swift SDK docs - select with nested relations
// Clips with participant info (if needed for display names)
let clips: [Clip] = try await supabase
    .from("clips")
    .select()
    .eq("card_id", value: cardId)
    .order("order_position", ascending: true)
    .execute()
    .value
```

### Pattern 3: Signed URL Video Preview
**What:** Generate time-limited signed URL before playback
**When to use:** Previewing clips from private storage bucket
**Example:**
```swift
// Source: Existing StorageService pattern
func previewClip(_ clip: Clip) async throws -> URL {
    // clip.videoUrl is the storage path (e.g., "{clipId}.mov")
    return try await storageService.createSignedURL(
        path: clip.videoUrl,
        expiresIn: 3600  // 1 hour validity
    )
}
```

### Pattern 4: Confirmation Dialog for Delete
**What:** Native SwiftUI confirmation before destructive action
**When to use:** Before deleting clips or participants
**Example:**
```swift
// Source: https://swiftwithmajid.com/2021/07/28/confirmation-dialogs-in-swiftui/
@State private var clipToDelete: Clip?
@State private var showDeleteConfirmation = false

.confirmationDialog(
    "Delete Clip",
    isPresented: $showDeleteConfirmation,
    titleVisibility: .visible,
    presenting: clipToDelete
) { clip in
    Button("Delete", role: .destructive) {
        Task { await deleteClip(clip) }
    }
    // Cancel button is added automatically by SwiftUI
} message: { clip in
    Text("This will permanently remove this clip from the card.")
}
```

### Pattern 5: Async Thumbnail Generation
**What:** Generate video thumbnails without blocking UI
**When to use:** Displaying clip list with preview images
**Example:**
```swift
// Source: Apple Developer docs - AVAssetImageGenerator
actor ThumbnailGenerator {
    func generateThumbnail(from url: URL, maxSize: CGSize = CGSize(width: 200, height: 200)) async throws -> UIImage {
        let asset = AVURLAsset(url: url)
        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        generator.maximumSize = maxSize  // Prevents full-size images in memory

        let time = CMTime(seconds: 0.5, preferredTimescale: 600)
        let cgImage = try await generator.image(at: time).image
        return UIImage(cgImage: cgImage)
    }
}
```

### Anti-Patterns to Avoid
- **Fetching signed URLs for all clips at once:** Signed URLs expire; generate on-demand when user taps to preview
- **Storing AVPlayer instances in list data:** Memory-heavy; create player only for active preview
- **Deleting clip record without storage cleanup:** Delete from storage first, then database (or use cascade)
- **Blocking main thread during thumbnail generation:** Use async/await and cache thumbnails
- **Showing raw storage paths to users:** Display participant names or generic labels instead

## Don't Hand-Roll

Problems that look simple but have existing solutions:

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Video preview player | New video player component | Existing LoopingVideoPlayer from VideoPreviewView | Already styled, handles looping |
| Signed URL generation | Manual HTTP request building | StorageService.createSignedURL | Handles auth, expiry correctly |
| Delete confirmation | Custom modal/alert | SwiftUI .confirmationDialog | Native UX, auto-cancel button |
| Pull to refresh | Manual refresh button | .refreshable modifier | Native UX, auto spinner management |
| Participant status display | Custom status logic | Map Participant.status to UI | Database enum is source of truth |

**Key insight:** Most UI patterns already exist in iOS native SwiftUI. Focus on data layer methods in CardService and composing existing components.

## Common Pitfalls

### Pitfall 1: Signed URL Expiration During Preview
**What goes wrong:** User opens preview, leaves app, returns - video fails to load
**Why it happens:** Signed URLs have 1-hour expiry; stale URLs throw errors
**How to avoid:** Generate fresh signed URL each time preview is opened, not on list load
**Warning signs:** Video previews work initially but fail after idle time

### Pitfall 2: Delete Not Appearing to Work (RLS Silent Failure)
**What goes wrong:** Delete operation completes without error but row still exists
**Why it happens:** RLS delete policy requires SELECT visibility; if user loses access, delete silently fails
**How to avoid:** Verify user is still card host before delete; refresh data after delete to confirm
**Warning signs:** Clips reappear after "successful" delete

### Pitfall 3: Memory Pressure from Multiple Video Previews
**What goes wrong:** App crashes or slows when scrolling through many clips
**Why it happens:** AVPlayer and video buffers consume significant memory
**How to avoid:** Use thumbnails in list; only instantiate AVPlayer for active preview; nil player on dismiss
**Warning signs:** Memory warnings, slow scrolling, app termination

### Pitfall 4: Participant Status Not Updating
**What goes wrong:** Participant shows "invited" even after they submitted
**Why it happens:** No real-time sync; local cache is stale
**How to avoid:** Implement pull-to-refresh; consider Supabase Realtime for future (Phase N)
**Warning signs:** Status mismatches between host view and reality

### Pitfall 5: Storage Orphans After Database Delete
**What goes wrong:** Clip deleted from database but video file remains in storage, wasting space
**Why it happens:** Database ON DELETE CASCADE doesn't affect storage
**How to avoid:** Delete from storage FIRST, then delete clip record; or use storage trigger (advanced)
**Warning signs:** Storage usage keeps growing even as clips are deleted

### Pitfall 6: Order Position Gaps After Delete
**What goes wrong:** order_position has gaps (0, 1, 3, 5) after deletes, causing rendering issues
**Why it happens:** Delete removes row without re-indexing others
**How to avoid:** Either re-index after delete (extra query) or accept gaps (simpler, order by still works)
**Warning signs:** Visual gaps in clip ordering, confusion during stitching phase

## Code Examples

Verified patterns from official sources and existing codebase:

### CardService: Fetch Participants for Card
```swift
// Source: Existing CardService pattern + Supabase docs
public func fetchParticipantsForCard(cardId: UUID) async throws -> [Participant] {
    do {
        let participants: [Participant] = try await supabase
            .from("participants")
            .select()
            .eq("card_id", value: cardId)
            .order("invited_at", ascending: true)
            .execute()
            .value

        #if DEBUG
        print("👥 Fetched \(participants.count) participants for card \(cardId)")
        #endif

        return participants
    } catch {
        throw CardError.fetchFailed(error.localizedDescription)
    }
}
```

### CardService: Fetch Clips for Card
```swift
// Source: Existing CardService pattern + Supabase docs
public func fetchClipsForCard(cardId: UUID) async throws -> [Clip] {
    do {
        let clips: [Clip] = try await supabase
            .from("clips")
            .select()
            .eq("card_id", value: cardId)
            .order("order_position", ascending: true)
            .execute()
            .value

        #if DEBUG
        print("🎬 Fetched \(clips.count) clips for card \(cardId)")
        #endif

        return clips
    } catch {
        throw CardError.fetchFailed(error.localizedDescription)
    }
}
```

### CardService: Delete Clip (with storage cleanup)
```swift
// Source: https://supabase.com/docs/reference/swift/delete + existing StorageService
public func deleteClip(clipId: UUID, storagePath: String) async throws {
    // 1. Delete from storage first
    let bucket = supabase.storage.from("clips")
    do {
        try await bucket.remove(paths: [storagePath])
        #if DEBUG
        print("🗑️ Deleted from storage: \(storagePath)")
        #endif
    } catch {
        // Log but continue - storage may already be deleted
        #if DEBUG
        print("⚠️ Storage delete failed (may not exist): \(error)")
        #endif
    }

    // 2. Delete from database
    do {
        try await supabase
            .from("clips")
            .delete()
            .eq("id", value: clipId)
            .execute()

        #if DEBUG
        print("🗑️ Deleted clip record: \(clipId)")
        #endif
    } catch {
        throw CardError.updateFailed("Failed to delete clip: \(error.localizedDescription)")
    }
}
```

### SwiftUI: Participant Row with Status
```swift
// Source: Existing TOYLabel, Color patterns in codebase
struct ParticipantRow: View {
    let participant: Participant

    var body: some View {
        HStack {
            // Avatar placeholder
            Circle()
                .fill(Color.toySurface)
                .frame(width: 40, height: 40)
                .overlay {
                    Image(systemName: "person.fill")
                        .foregroundColor(.toyTextSecondary)
                }

            VStack(alignment: .leading, spacing: 2) {
                TOYLabel(participant.email ?? "Invited Guest", style: .body)
                TOYLabel(statusText, style: .caption, color: statusColor)
            }

            Spacer()

            if participant.status == "submitted" {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
            }
        }
        .padding(.vertical, 4)
    }

    private var statusText: String {
        switch participant.status {
        case "invited": return "Waiting for response"
        case "viewed": return "Viewed invitation"
        case "recording": return "Recording in progress"
        case "submitted": return "Clip submitted"
        default: return participant.status
        }
    }

    private var statusColor: Color {
        switch participant.status {
        case "submitted": return .green
        case "recording": return .toyPrimary
        default: return .toyTextSecondary
        }
    }
}
```

### SwiftUI: Clip Preview with Signed URL
```swift
// Source: Existing VideoPreviewView + StorageService patterns
struct ClipPreviewSheet: View {
    let clip: Clip
    let storageService: StorageService
    let onDelete: () async -> Void

    @State private var signedURL: URL?
    @State private var isLoading = true
    @State private var showDeleteConfirmation = false
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack {
            if let url = signedURL {
                // Reuse existing looping player pattern
                VideoPreviewContent(videoURL: url)
            } else if isLoading {
                ProgressView()
            } else {
                Text("Failed to load video")
            }

            // Delete button
            TOYButton("Delete Clip", style: .destructive, size: .large) {
                showDeleteConfirmation = true
            }
            .padding()
        }
        .task {
            await loadSignedURL()
        }
        .confirmationDialog("Delete Clip", isPresented: $showDeleteConfirmation) {
            Button("Delete", role: .destructive) {
                Task {
                    await onDelete()
                    dismiss()
                }
            }
        } message: {
            Text("This clip will be permanently removed from the card.")
        }
    }

    private func loadSignedURL() async {
        do {
            signedURL = try await storageService.createSignedURL(path: clip.videoUrl)
        } catch {
            #if DEBUG
            print("❌ Failed to get signed URL: \(error)")
            #endif
        }
        isLoading = false
    }
}
```

### SwiftUI: Pull to Refresh with List
```swift
// Source: https://sarunw.com/posts/pull-to-refresh-in-swiftui/
struct CardDetailView: View {
    @State private var viewModel = CardDetailViewModel()
    let card: Card

    var body: some View {
        List {
            Section("Participants") {
                ForEach(viewModel.participants) { participant in
                    ParticipantRow(participant: participant)
                }
            }

            Section("Submitted Clips") {
                ForEach(viewModel.clips) { clip in
                    ClipRow(clip: clip)
                }
            }
        }
        .refreshable {
            await viewModel.loadData(for: card.id)
        }
        .task {
            await viewModel.loadData(for: card.id)
        }
        .navigationTitle(card.title)
    }
}
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| UIActivityIndicatorView | SwiftUI ProgressView | iOS 14 (2020) | Declarative loading states |
| Manual refresh button | .refreshable modifier | iOS 15 (2021) | Native pull-to-refresh |
| ActionSheet | .confirmationDialog | iOS 15 (2021) | Better semantics, auto cancel |
| Callback-based AVAssetImageGenerator | async/await generator | iOS 15+ | Cleaner async code |
| @StateObject | @State + @Observable | iOS 17 (2023) | Simpler state management |

**Deprecated/outdated:**
- UIAlertController for confirmations: Use .confirmationDialog in SwiftUI
- Manual KVO for player state: Use async/await and Combine publishers
- Storing player in ForEach model: Memory-heavy; create on-demand

## Open Questions

Things that couldn't be fully resolved:

1. **Real-time participant status updates**
   - What we know: Supabase Realtime can push database changes
   - What's unclear: Whether to implement in this phase or defer
   - Recommendation: Use pull-to-refresh for MVP; add Realtime in future phase

2. **Thumbnail caching strategy**
   - What we know: Generating thumbnails from signed URLs is expensive
   - What's unclear: Best caching approach (memory, disk, skip thumbnails)
   - Recommendation: Start with on-demand generation; cache in memory with NSCache if needed

3. **Bulk clip deletion**
   - What we know: Host might want to delete multiple clips at once
   - What's unclear: UI pattern for multi-select in SwiftUI List
   - Recommendation: Start with single-clip delete; add bulk in future iteration

4. **Order position re-indexing after delete**
   - What we know: Deleting clips leaves gaps in order_position
   - What's unclear: Whether gaps cause issues for stitching phase
   - Recommendation: Keep gaps for simplicity; ORDER BY still works correctly

## Sources

### Primary (HIGH confidence)
- [Supabase Swift SDK - Delete](https://supabase.com/docs/reference/swift/delete) - Delete operation patterns
- Existing codebase: CardService, StorageService, VideoPreviewView patterns
- Database schema: supabase/migrations/001_initial_schema.sql, 003_fix_rls_recursion.sql

### Secondary (MEDIUM confidence)
- [SwiftUI confirmationDialog](https://swiftwithmajid.com/2021/07/28/confirmation-dialogs-in-swiftui/) - Confirmation dialog patterns
- [Pull to Refresh in SwiftUI](https://sarunw.com/posts/pull-to-refresh-in-swiftui/) - Refreshable modifier usage
- [Hacking with Swift - Swipe to Delete](https://www.hackingwithswift.com/quick-start/swiftui/how-to-let-users-delete-rows-from-a-list) - List deletion patterns
- [Apple - AVAssetImageGenerator](https://developer.apple.com/documentation/avfoundation/avassetimagegenerator) - Thumbnail generation

### Tertiary (LOW confidence)
- Web search results for video caching patterns - general guidance only, not iOS-specific

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH - Using existing SDK and native SwiftUI
- Architecture: HIGH - Following established patterns in codebase
- Pitfalls: HIGH - Based on documented Supabase/RLS behaviors and existing codebase patterns

**Research date:** 2026-02-02
**Valid until:** 2026-03-02 (30 days - stable domain)
