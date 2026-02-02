# Phase 4: Host Card Creation - Research

**Researched:** 2026-02-02
**Domain:** SwiftUI forms, Supabase CRUD operations, share link generation
**Confidence:** HIGH

## Summary

Phase 4 enables hosts to create video greeting cards, record their own clip (which appears first in the final montage), and generate shareable invite links for participants. This phase builds on existing infrastructure: the recording pipeline from Phase 2, storage service from Phase 3, and the database schema with cards/clips/participants tables already created in Phase 1.

The implementation requires three main components: (1) a card creation form with validation, (2) integration with the existing RecordingView for host clip recording, and (3) share link generation using the deep link infrastructure already in place. The Supabase Swift SDK provides straightforward CRUD operations with Codable models, and SwiftUI's native `ShareLink` view (iOS 16+) handles share sheet presentation.

**Primary recommendation:** Create Card/Clip/Participant Swift models matching the database schema, build a CardService actor for Supabase operations, and compose existing RecordingView into a host-specific flow that creates the card record before recording.

## Standard Stack

The established libraries/tools for this domain:

### Core
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| SwiftUI Form | iOS 18.2+ | Card creation UI | Native, declarative form handling |
| Supabase Swift | 2.x | Database CRUD | Already integrated, type-safe with Codable |
| ShareLink | iOS 16+ | Share sheet | Native SwiftUI, no wrapper needed |

### Supporting
| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| Foundation UUID | Built-in | Token generation | Share tokens, clip IDs |
| Combine | Built-in | Form validation | Reactive validation state |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| ShareLink | UIActivityViewController wrapper | Only needed for iOS < 16, app targets 18.2+ |
| Form validation library | SwiftUIFormValidator | Unnecessary complexity for simple forms |
| Custom share tokens | Short URL service | UUID-based tokens sufficient for MVP |

**No additional packages required.** All capabilities exist in current dependencies.

## Architecture Patterns

### Recommended Project Structure
```
TOY/Features/
├── CardCreation/
│   ├── CreateCardView.swift          # Form for card details
│   ├── CreateCardViewModel.swift     # Form state and validation
│   └── HostRecordingView.swift       # Wraps RecordingView with card context
├── Home/
│   └── HomeView.swift                # Add navigation to CreateCardView
TOYShared/Sources/TOYShared/
├── Models/
│   ├── Card.swift                    # Card model
│   ├── Clip.swift                    # Clip model
│   └── Participant.swift             # Participant model
└── Services/
    └── CardService.swift             # Supabase CRUD operations
```

### Pattern 1: Codable Models for Supabase
**What:** Swift structs matching database tables with Codable conformance
**When to use:** All Supabase table interactions
**Example:**
```swift
// Source: Supabase Swift SDK docs
struct Card: Codable, Identifiable {
    let id: UUID
    let hostId: UUID
    var title: String
    var recipientName: String
    var occasion: String?
    var status: String
    var shareToken: String?
    var maxParticipants: Int
    let createdAt: Date
    var updatedAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case hostId = "host_id"
        case title
        case recipientName = "recipient_name"
        case occasion
        case status
        case shareToken = "share_token"
        case maxParticipants = "max_participants"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}
```

### Pattern 2: Actor-based Service
**What:** Actor isolation for thread-safe async database operations
**When to use:** Any service making Supabase calls from multiple contexts
**Example:**
```swift
// Source: Existing StorageService pattern in codebase
public actor CardService {
    public init() {}

    public func createCard(title: String, recipientName: String, occasion: String?, hostId: UUID) async throws -> Card {
        let newCard = NewCard(
            hostId: hostId,
            title: title,
            recipientName: recipientName,
            occasion: occasion,
            shareToken: UUID().uuidString.lowercased()
        )

        let card: Card = try await supabase
            .from("cards")
            .insert(newCard)
            .select()
            .single()
            .execute()
            .value

        return card
    }
}
```

### Pattern 3: Host Clip with order_position = 0
**What:** Mark host's clip to always appear first in montage
**When to use:** When host records their clip
**Example:**
```swift
// After successful upload, create clip record with order_position = 0
let clip = NewClip(
    cardId: cardId,
    participantId: hostId,
    videoUrl: storagePath,
    durationSeconds: duration,
    orderPosition: 0,  // Host clip always first
    status: "uploaded"
)
try await supabase.from("clips").insert(clip).execute()
```

### Pattern 4: Share Link Generation
**What:** Generate invite URL from card's share_token
**When to use:** After card creation, in share UI
**Example:**
```swift
// Source: DeepLinkService pattern in codebase
struct ShareLinkGenerator {
    static let baseURL = "https://toy.app"  // Placeholder per LINK-001

    static func inviteURL(for card: Card) -> URL? {
        guard let token = card.shareToken else { return nil }
        return URL(string: "\(baseURL)/card/\(token)")
    }
}
```

### Anti-Patterns to Avoid
- **Creating card after recording:** Create the card record FIRST, then record. This ensures the clip has a card_id to reference.
- **Storing video URL before upload:** Only create clip record after successful storage upload.
- **Using share_token for card lookup during creation:** Use card.id (UUID) for internal references; share_token is for external sharing only.
- **Blocking main thread during Supabase calls:** All database operations must be async with proper actor isolation.

## Don't Hand-Roll

Problems that look simple but have existing solutions:

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Share token generation | Custom random string | `UUID().uuidString` | 122 bits randomness, guaranteed unique |
| Share sheet | UIActivityViewController wrapper | SwiftUI `ShareLink` | Native iOS 16+, app targets 18.2+ |
| Form validation | Custom state machine | Computed properties + disabled() | SwiftUI pattern, simpler |
| Video upload | Custom HTTP calls | Existing StorageService | Already built, tested in Phase 3 |
| Recording flow | New recording views | Existing RecordingView | Phase 2 is complete, reuse it |

**Key insight:** Most of Phase 4 is composition of existing components. The card creation form and CardService are the only truly new code. Recording, upload, and deep link parsing are already built.

## Common Pitfalls

### Pitfall 1: Creating Clip Record Before Upload Completes
**What goes wrong:** Clip record in database has no valid video_url, or references a failed upload
**Why it happens:** Eager record creation without waiting for storage confirmation
**How to avoid:** Only insert clip record AFTER StorageService.uploadVideo returns successfully
**Warning signs:** Clips table has NULL video_url or dead storage paths

### Pitfall 2: Missing CodingKeys for snake_case
**What goes wrong:** Supabase queries fail with decoding errors
**Why it happens:** Swift uses camelCase, Postgres uses snake_case
**How to avoid:** Always define CodingKeys enum mapping camelCase to snake_case
**Warning signs:** "keyNotFound" errors in Supabase responses

### Pitfall 3: Share Token Collision
**What goes wrong:** Two cards have same share_token (DB constraint violation)
**Why it happens:** Unlikely with UUID, but possible if using shorter tokens
**How to avoid:** Use full UUID string (36 chars); database has UNIQUE constraint as safety net
**Warning signs:** Insert fails with unique constraint error

### Pitfall 4: Not Handling RLS Policy Restrictions
**What goes wrong:** Queries return empty results or fail silently
**Why it happens:** RLS policies require auth.uid() to match host_id
**How to avoid:** Ensure user is authenticated before card operations; verify host_id matches current user
**Warning signs:** Card creation "succeeds" but card doesn't appear in list

### Pitfall 5: Recording Without Card Context
**What goes wrong:** Host records video but can't associate it with a card
**Why it happens:** Navigating to RecordingView without passing card ID
**How to avoid:** Create card first, pass card ID to recording flow, create clip record after upload
**Warning signs:** Orphaned videos in storage bucket with no clip record

## Code Examples

Verified patterns from official sources and existing codebase:

### Supabase Insert with Return
```swift
// Source: https://supabase.com/docs/reference/swift/insert
struct NewCard: Encodable {
    let hostId: UUID
    let title: String
    let recipientName: String
    let occasion: String?
    let shareToken: String

    enum CodingKeys: String, CodingKey {
        case hostId = "host_id"
        case title
        case recipientName = "recipient_name"
        case occasion
        case shareToken = "share_token"
    }
}

let card: Card = try await supabase
    .from("cards")
    .insert(newCard)
    .select()
    .single()
    .execute()
    .value
```

### Supabase Update
```swift
// Source: https://supabase.com/docs/reference/swift/update
try await supabase
    .from("cards")
    .update(["status": "collecting"])
    .eq("id", value: cardId)
    .execute()
```

### Supabase Select with Filter
```swift
// Source: https://supabase.com/docs/reference/swift/select
let cards: [Card] = try await supabase
    .from("cards")
    .select()
    .eq("host_id", value: userId)
    .execute()
    .value
```

### SwiftUI ShareLink
```swift
// Source: https://www.hackingwithswift.com/books/ios-swiftui/how-to-let-the-user-share-content-with-sharelink
if let inviteURL = ShareLinkGenerator.inviteURL(for: card) {
    ShareLink(
        item: inviteURL,
        subject: Text("Join my TOY card"),
        message: Text("Record a video message for \(card.recipientName)!")
    ) {
        Label("Share Invite", systemImage: "square.and.arrow.up")
    }
}
```

### Form Validation Pattern
```swift
// Source: https://www.hackingwithswift.com/books/ios-swiftui/validating-and-disabling-forms
struct CreateCardView: View {
    @State private var title = ""
    @State private var recipientName = ""

    private var isFormValid: Bool {
        !title.trimmingCharacters(in: .whitespaces).isEmpty &&
        !recipientName.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var body: some View {
        Form {
            TextField("Card Title", text: $title)
            TextField("Recipient Name", text: $recipientName)
        }
        TOYButton("Continue", style: .primary) {
            // Create card
        }
        .disabled(!isFormValid)
    }
}
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| UIActivityViewController | SwiftUI ShareLink | iOS 16 (2022) | Native declarative sharing |
| Combine for form state | @Observable macro | iOS 17 (2023) | Simpler state management |
| Manual JSON encoding | Codable with CodingKeys | Swift 4+ (standard) | Type-safe Supabase operations |

**Deprecated/outdated:**
- UIActivityViewController wrapper: Only needed for iOS 15 and earlier; app targets 18.2+
- @StateObject for view models: @State with @Observable is preferred pattern in iOS 17+

## Open Questions

Things that couldn't be fully resolved:

1. **Video duration calculation for clip record**
   - What we know: AVAsset can provide duration; clips table has duration_seconds column
   - What's unclear: Whether to calculate from merged video or sum of clip durations
   - Recommendation: Use AVAsset.duration on the final merged video before upload

2. **Card status transitions**
   - What we know: Status enum is draft -> collecting -> stitching -> published
   - What's unclear: When exactly to transition from draft to collecting
   - Recommendation: Set to "collecting" after host records their clip

3. **Error handling for partial failures**
   - What we know: Card creation, recording, and upload are separate steps
   - What's unclear: What to do if card created but recording fails
   - Recommendation: Card remains in "draft" until host clip is uploaded; allow retry

## Sources

### Primary (HIGH confidence)
- Supabase Swift SDK official docs - insert, update, select operations
  - https://supabase.com/docs/reference/swift/insert
  - https://supabase.com/docs/reference/swift/update
  - https://supabase.com/docs/reference/swift/select
- Existing codebase: StorageService, DeepLinkService, RecordingView patterns
- Database schema: supabase/migrations/001_initial_schema.sql

### Secondary (MEDIUM confidence)
- [Hacking with Swift - SwiftUI ShareLink](https://www.hackingwithswift.com/books/ios-swiftui/how-to-let-the-user-share-content-with-sharelink)
- [Hacking with Swift - Form Validation](https://www.hackingwithswift.com/books/ios-swiftui/validating-and-disabling-forms)
- [AzamSharp - Validation Patterns](https://azamsharp.com/2024/12/18/the-ultimate-guide-to-validation-patterns-in-swiftui.html)

### Tertiary (LOW confidence)
- Web search results for Universal Links patterns - general guidance only

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH - Using existing SDK and native SwiftUI
- Architecture: HIGH - Following established patterns in codebase
- Pitfalls: HIGH - Based on documented Supabase behaviors and RLS policies

**Research date:** 2026-02-02
**Valid until:** 2026-03-02 (30 days - stable domain)
