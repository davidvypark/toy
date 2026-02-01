# Architecture Research: TOY Group Video Greeting Card App

**Research Date:** 2026-02-01
**Dimension:** Architecture
**Milestone:** Greenfield - System Structure Analysis

---

## Executive Summary

TOY requires a modular architecture that supports three distinct user journeys (Host, Participant, Recipient) across two deployment targets (main app, App Clip). The recommended approach is **MVVM with a shared Core module**, prioritizing simplicity over framework overhead while enabling the critical App Clip code-sharing requirement.

**Key Architectural Decisions:**
1. MVVM over TCA (simpler, sufficient for scope, faster iteration)
2. Shared Swift Package for App Clip code reuse
3. Hybrid video stitching (client-side with server fallback)
4. Deep link-driven navigation architecture
5. Repository pattern for Supabase integration

---

## 1. SwiftUI App Structure

### Recommendation: MVVM with Coordinator Pattern

**Why MVVM over TCA:**
- **Complexity match:** TCA adds ceremony (reducers, effects, stores) that benefits apps with complex state interactions. TOY has relatively isolated flows (Host creates, Participant records, Recipient views).
- **Learning curve:** MVVM is native to SwiftUI ecosystem; TCA requires team buy-in and additional dependencies.
- **App Clip size:** TCA dependency adds ~2-3MB to binary; App Clips have 15MB limit including assets.
- **Iteration speed:** MVVM allows faster prototyping for MVP; can migrate to TCA post-launch if needed.

**Why Not Pure MVC or Simpler:**
- Video recording state management is complex (recording segments, permissions, camera state).
- Need clear separation for testability of business logic.
- Coordinator pattern needed for deep link handling across flows.

### Proposed Layer Structure

```
TOY/
├── App/
│   ├── TOYApp.swift              # Main app entry
│   ├── TOYAppClipApp.swift       # App Clip entry (separate target)
│   └── AppCoordinator.swift      # Navigation + deep link handling
├── Core/                         # Shared Swift Package
│   ├── Models/
│   ├── Services/
│   ├── ViewModels/
│   └── Utilities/
├── Features/
│   ├── Host/
│   │   ├── Views/
│   │   ├── ViewModels/
│   │   └── Coordinator/
│   ├── Participant/
│   │   ├── Views/
│   │   ├── ViewModels/
│   │   └── Coordinator/
│   └── Recipient/
│       ├── Views/
│       └── ViewModels/
├── Recording/                    # Shared recording infrastructure
│   ├── CameraService.swift
│   ├── RecordingViewModel.swift
│   └── Views/
└── Shared/
    ├── Components/              # Reusable UI components
    ├── Extensions/
    └── Resources/
```

### State Management Strategy

| State Type | Pattern | Location |
|------------|---------|----------|
| View-local UI state | `@State` | View |
| Feature-level state | `@StateObject` + ViewModel | ViewModel |
| App-wide state (auth, user) | `@EnvironmentObject` | AppState |
| Recording segments | Observable class | RecordingViewModel |
| Navigation state | Coordinator | AppCoordinator |

---

## 2. App Clip Integration Architecture

### Code Sharing Strategy: Swift Package

**Structure:**
```
TOYCore/                          # Swift Package
├── Package.swift
├── Sources/
│   └── TOYCore/
│       ├── Models/
│       │   ├── Card.swift
│       │   ├── Clip.swift
│       │   └── Participant.swift
│       ├── Services/
│       │   ├── SupabaseService.swift
│       │   ├── CameraService.swift
│       │   └── VideoExportService.swift
│       ├── ViewModels/
│       │   └── RecordingViewModel.swift
│       └── Utilities/
│           ├── DeepLinkParser.swift
│           └── VideoUtilities.swift
└── Tests/
```

**Target Configuration:**

| Component | Main App | App Clip |
|-----------|----------|----------|
| TOYCore package | Yes | Yes |
| Host flow | Yes | No |
| Participant flow | Yes | Yes |
| Recipient flow | Yes | Yes (view-only) |
| Video stitching | Yes | No |
| Full settings | Yes | No |

### App Clip Constraints

**15MB Binary Limit Strategies:**
1. **Asset optimization:** Use SF Symbols over custom icons
2. **Conditional compilation:** `#if !APPCLIP` for main-app-only features
3. **On-demand resources:** Keep non-critical assets out of App Clip
4. **Video quality:** Lower resolution in App Clip (720p vs 1080p)

**Shared Configuration:**
```swift
// TOYCore/Configuration.swift
public struct AppConfiguration {
    public static var isAppClip: Bool {
        #if APPCLIP
        return true
        #else
        return false
        #endif
    }

    public static var maxVideoResolution: CGSize {
        isAppClip ? CGSize(width: 720, height: 1280) : CGSize(width: 1080, height: 1920)
    }
}
```

### App Clip Entry Points

```swift
// App Clip URL handling
// toy://card/{cardId}/record
// toy://card/{cardId}/view

@main
struct TOYAppClipApp: App {
    @StateObject private var coordinator = AppClipCoordinator()

    var body: some Scene {
        WindowGroup {
            AppClipRootView()
                .environmentObject(coordinator)
                .onContinueUserActivity(NSUserActivityTypeBrowsingWeb) { activity in
                    coordinator.handleDeepLink(activity.webpageURL)
                }
        }
    }
}
```

---

## 3. Video Recording Pipeline

### AVFoundation Architecture

**Component Hierarchy:**
```
CameraService (singleton)
├── AVCaptureSession
│   ├── AVCaptureDeviceInput (camera)
│   ├── AVCaptureDeviceInput (microphone)
│   ├── AVCaptureVideoPreviewLayer
│   └── AVCaptureMovieFileOutput
└── RecordingSessionManager
    ├── Segment tracking
    ├── File management
    └── Duration enforcement
```

### Recording ViewModel Design

```swift
@MainActor
class RecordingViewModel: ObservableObject {
    // State
    @Published var recordingState: RecordingState = .idle
    @Published var segments: [RecordingSegment] = []
    @Published var totalDuration: TimeInterval = 0
    @Published var cameraPermission: PermissionStatus = .undetermined
    @Published var microphonePermission: PermissionStatus = .undetermined

    // Constants
    let maxDuration: TimeInterval = 7.0

    // Dependencies
    private let cameraService: CameraServiceProtocol
    private let exportService: VideoExportServiceProtocol

    enum RecordingState {
        case idle
        case previewing
        case recording
        case paused
        case reviewing
        case exporting
        case complete
    }
}
```

### Vine-Style Recording State Machine

```
                    ┌─────────────┐
                    │    IDLE     │
                    └──────┬──────┘
                           │ camera ready
                           ▼
                    ┌─────────────┐
          ┌────────│  PREVIEWING │◄────────┐
          │        └──────┬──────┘         │
          │               │ touch down     │ delete segment
          │               ▼                │
          │        ┌─────────────┐         │
          │        │  RECORDING  │─────────┤
          │        └──────┬──────┘         │
          │               │ touch up       │
          │               ▼                │
          │        ┌─────────────┐         │
          │        │   PAUSED    │─────────┘
          │        └──────┬──────┘
          │               │ tap done (or max reached)
          │               ▼
          │        ┌─────────────┐
          │        │  REVIEWING  │
          │        └──────┬──────┘
          │               │ confirm
          │               ▼
          │        ┌─────────────┐
          │        │  EXPORTING  │
          │        └──────┬──────┘
          │               │ success
          │               ▼
          └───────►┌─────────────┐
     (re-record)   │  COMPLETE   │
                   └─────────────┘
```

### Segment Management

```swift
struct RecordingSegment: Identifiable {
    let id: UUID
    let localURL: URL
    let duration: TimeInterval
    let timestamp: Date
}

// File naming: {sessionId}_{segmentIndex}.mov
// Temp directory: FileManager.default.temporaryDirectory/toy_recording/
```

---

## 4. Video Stitching Architecture

### Recommendation: Hybrid Approach (Client-First)

**Decision Matrix:**

| Factor | On-Device | Server-Side |
|--------|-----------|-------------|
| Latency | Immediate | 30s-5min |
| Cost | Free | Compute costs |
| Quality control | Limited | Full |
| Offline capability | Yes | No |
| Complex transitions | Limited | Full |
| Battery impact | High | Low |

**Recommended Strategy:**
1. **Primary:** Client-side stitching using AVFoundation for simple concatenation
2. **Fallback:** Server-side for failures or premium features (future)

### Client-Side Stitching Pipeline

```swift
class VideoStitchingService {
    func stitchClips(_ clips: [VideoClip]) async throws -> URL {
        // 1. Create composition
        let composition = AVMutableComposition()

        // 2. Add video tracks
        guard let videoTrack = composition.addMutableTrack(
            withMediaType: .video,
            preferredTrackID: kCMPersistentTrackID_Invalid
        ) else { throw StitchingError.trackCreationFailed }

        // 3. Add audio tracks
        guard let audioTrack = composition.addMutableTrack(
            withMediaType: .audio,
            preferredTrackID: kCMPersistentTrackID_Invalid
        ) else { throw StitchingError.trackCreationFailed }

        // 4. Insert clips sequentially
        var currentTime = CMTime.zero
        for clip in clips {
            let asset = AVURLAsset(url: clip.localURL)
            // ... insert at currentTime
            currentTime = CMTimeAdd(currentTime, asset.duration)
        }

        // 5. Apply video composition (orientation fixes)
        let videoComposition = AVMutableVideoComposition()
        // ... configure transforms

        // 6. Export
        let exporter = AVAssetExportSession(
            asset: composition,
            presetName: AVAssetExportPresetHighestQuality
        )
        // ... configure and export

        return outputURL
    }
}
```

### Stitching Order Logic

```swift
func orderedClips(for card: Card) -> [VideoClip] {
    // Host clip always first
    let hostClip = card.clips.first { $0.participantId == card.hostId }

    // Remaining clips sorted by submission time
    let participantClips = card.clips
        .filter { $0.participantId != card.hostId }
        .sorted { $0.submittedAt < $1.submittedAt }

    return [hostClip].compactMap { $0 } + participantClips
}
```

---

## 5. Supabase Integration Architecture

### Service Layer Design

```
SupabaseManager (singleton)
├── AuthService
│   ├── signInAnonymously()
│   ├── signUp(email:password:)
│   └── currentUser
├── DatabaseService
│   ├── CardRepository
│   ├── ClipRepository
│   └── ParticipantRepository
├── StorageService
│   ├── uploadVideo(data:path:)
│   ├── downloadVideo(path:)
│   └── getSignedURL(path:)
└── RealtimeService
    └── subscribeToCard(cardId:)
```

### Repository Pattern

```swift
protocol CardRepositoryProtocol {
    func create(_ card: Card) async throws -> Card
    func fetch(id: String) async throws -> Card
    func update(_ card: Card) async throws
    func delete(id: String) async throws
    func observeCard(id: String) -> AsyncStream<Card>
}

class SupabaseCardRepository: CardRepositoryProtocol {
    private let client: SupabaseClient

    func observeCard(id: String) -> AsyncStream<Card> {
        AsyncStream { continuation in
            let channel = client.realtime
                .channel("card:\(id)")
                .on("postgres_changes",
                    filter: .eq("id", id)) { payload in
                    // Parse and yield updated card
                }
            // ... setup and cleanup
        }
    }
}
```

### Database Schema (Supabase Tables)

```sql
-- Cards table
CREATE TABLE cards (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    host_id UUID REFERENCES auth.users(id),
    title TEXT,
    recipient_name TEXT,
    status TEXT CHECK (status IN ('draft', 'collecting', 'finalizing', 'published')),
    created_at TIMESTAMPTZ DEFAULT now(),
    published_at TIMESTAMPTZ,
    final_video_url TEXT
);

-- Clips table
CREATE TABLE clips (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    card_id UUID REFERENCES cards(id) ON DELETE CASCADE,
    participant_id UUID REFERENCES auth.users(id),
    participant_name TEXT,
    video_url TEXT,
    duration_seconds DECIMAL(4,2),
    order_index INTEGER,
    status TEXT CHECK (status IN ('pending', 'uploaded', 'approved', 'rejected')),
    created_at TIMESTAMPTZ DEFAULT now()
);

-- Storage buckets
-- videos/cards/{card_id}/clips/{clip_id}.mp4
-- videos/cards/{card_id}/final.mp4
```

### Realtime Subscriptions

**Host Dashboard Updates:**
```swift
// Subscribe to new clip submissions
func observeCardClips(cardId: String) -> AsyncStream<[Clip]> {
    // Realtime subscription to clips table
    // Fires when participant uploads new clip
}
```

**Use Cases:**
1. Host sees new participant submissions in real-time
2. Participant sees confirmation when upload completes
3. Recipient gets notified when video is ready (optional)

---

## 6. Deep Linking Architecture

### URL Schema

```
# Universal Links (production)
https://toy.app/card/{cardId}/record     # Participant recording
https://toy.app/card/{cardId}/view       # Recipient viewing
https://toy.app/card/{cardId}/manage     # Host management

# Custom URL Scheme (development/fallback)
toy://card/{cardId}/record
toy://card/{cardId}/view
```

### Deep Link Coordinator

```swift
@MainActor
class DeepLinkCoordinator: ObservableObject {
    @Published var destination: Destination?

    enum Destination: Hashable {
        case participantRecording(cardId: String)
        case recipientViewing(cardId: String)
        case hostManagement(cardId: String)
    }

    func handle(url: URL) -> Bool {
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: true),
              let pathComponents = parsePathComponents(components.path) else {
            return false
        }

        switch (pathComponents.action, pathComponents.cardId) {
        case ("record", let cardId?):
            destination = .participantRecording(cardId: cardId)
        case ("view", let cardId?):
            destination = .recipientViewing(cardId: cardId)
        case ("manage", let cardId?):
            destination = .hostManagement(cardId: cardId)
        default:
            return false
        }
        return true
    }
}
```

### Navigation Architecture

```swift
struct ContentView: View {
    @EnvironmentObject var deepLinkCoordinator: DeepLinkCoordinator
    @EnvironmentObject var authState: AuthState

    var body: some View {
        Group {
            if let destination = deepLinkCoordinator.destination {
                destinationView(for: destination)
            } else if authState.isAuthenticated {
                HostDashboardView()
            } else {
                OnboardingView()
            }
        }
    }

    @ViewBuilder
    func destinationView(for destination: DeepLinkCoordinator.Destination) -> some View {
        switch destination {
        case .participantRecording(let cardId):
            ParticipantRecordingFlow(cardId: cardId)
        case .recipientViewing(let cardId):
            RecipientViewingFlow(cardId: cardId)
        case .hostManagement(let cardId):
            HostManagementFlow(cardId: cardId)
        }
    }
}
```

---

## 7. State Management for Recording Flow

### Recording Flow State Machine

```swift
enum RecordingFlowState: Equatable {
    case loading                          // Fetching card info
    case permissionRequired([Permission]) // Need camera/mic
    case ready                            // Can start recording
    case recording(RecordingState)        // Active recording
    case reviewing(previewURL: URL)       // Watching playback
    case uploading(progress: Double)      // Sending to Supabase
    case success                          // Upload complete
    case error(RecordingFlowError)        // Recoverable error

    enum Permission {
        case camera, microphone
    }
}
```

### Flow ViewModel

```swift
@MainActor
class ParticipantRecordingFlowViewModel: ObservableObject {
    // Flow state
    @Published var flowState: RecordingFlowState = .loading

    // Sub-states
    @Published var card: Card?
    @Published var recordingViewModel: RecordingViewModel?

    // Dependencies
    private let cardRepository: CardRepositoryProtocol
    private let clipRepository: ClipRepositoryProtocol
    private let storageService: StorageServiceProtocol

    func loadCard(id: String) async {
        flowState = .loading
        do {
            card = try await cardRepository.fetch(id: id)
            await checkPermissions()
        } catch {
            flowState = .error(.cardNotFound)
        }
    }

    func submitRecording() async {
        guard let previewURL = recordingViewModel?.finalVideoURL else { return }

        flowState = .uploading(progress: 0)

        do {
            // 1. Upload video
            let videoData = try Data(contentsOf: previewURL)
            let remotePath = try await storageService.uploadVideo(
                data: videoData,
                path: "cards/\(card!.id)/clips/\(UUID().uuidString).mp4"
            ) { progress in
                Task { @MainActor in
                    self.flowState = .uploading(progress: progress)
                }
            }

            // 2. Create clip record
            let clip = Clip(
                cardId: card!.id,
                videoURL: remotePath,
                duration: recordingViewModel!.totalDuration
            )
            try await clipRepository.create(clip)

            flowState = .success
        } catch {
            flowState = .error(.uploadFailed(error))
        }
    }
}
```

---

## Component Boundaries

### Boundary Diagram

```
┌─────────────────────────────────────────────────────────────────┐
│                         iOS App / App Clip                       │
├─────────────────────────────────────────────────────────────────┤
│  Presentation Layer                                              │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐          │
│  │  Host Views  │  │ Participant  │  │  Recipient   │          │
│  │              │  │    Views     │  │    Views     │          │
│  └──────┬───────┘  └──────┬───────┘  └──────┬───────┘          │
│         │                  │                  │                  │
├─────────┴──────────────────┴──────────────────┴─────────────────┤
│  ViewModel Layer (Feature-specific)                              │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐          │
│  │HostDashboard │  │  Recording   │  │   Viewing    │          │
│  │  ViewModel   │  │  ViewModel   │  │  ViewModel   │          │
│  └──────┬───────┘  └──────┬───────┘  └──────┬───────┘          │
│         │                  │                  │                  │
├─────────┴──────────────────┴──────────────────┴─────────────────┤
│  Service Layer (Shared via TOYCore package)                      │
│  ┌────────────┐ ┌────────────┐ ┌────────────┐ ┌────────────┐   │
│  │  Camera    │ │  Storage   │ │  Database  │ │  Realtime  │   │
│  │  Service   │ │  Service   │ │  Repos     │ │  Service   │   │
│  └─────┬──────┘ └─────┬──────┘ └─────┬──────┘ └─────┬──────┘   │
│        │              │              │              │            │
├────────┴──────────────┴──────────────┴──────────────┴───────────┤
│  External Dependencies                                           │
│  ┌────────────┐ ┌────────────────────────────────────────────┐  │
│  │AVFoundation│ │              Supabase                       │  │
│  │            │ │  ┌────────┐ ┌─────────┐ ┌─────────────┐    │  │
│  │            │ │  │  Auth  │ │Database │ │   Storage   │    │  │
│  │            │ │  │        │ │(Postgres)│ │   (S3)      │    │  │
│  └────────────┘ │  └────────┘ └─────────┘ └─────────────┘    │  │
│                 └────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────────┘
```

### Component Communication Rules

| From | To | Method | Data Format |
|------|-----|--------|-------------|
| View | ViewModel | Direct method calls | Swift types |
| ViewModel | Service | Async/await | Domain models |
| Service | Supabase | SDK calls | JSON/Binary |
| ViewModel | ViewModel | NotificationCenter / Combine | Events |
| App Clip | Main App | Shared Keychain | Tokens |

---

## Data Flow

### Host Creates Card Flow

```
User Action: Tap "Create Card"
     │
     ▼
┌─────────────────┐
│HostDashboardVM  │ createCard()
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│ CardRepository  │ create(card)
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│  SupabaseDB     │ INSERT INTO cards
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│ Generate Link   │ "https://toy.app/card/{id}/record"
└────────┬────────┘
         │
         ▼
UI: Show share sheet with link
```

### Participant Records Clip Flow

```
Deep Link: toy://card/{cardId}/record
     │
     ▼
┌─────────────────┐
│DeepLinkCoord    │ destination = .participantRecording
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│ParticipantFlow  │ loadCard() -> checkPermissions()
│    ViewModel    │
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│ RecordingVM     │ Vine-style recording loop
└────────┬────────┘
         │ (touch to record segments)
         ▼
┌─────────────────┐
│ CameraService   │ AVCaptureSession -> file segments
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│VideoExportSvc   │ Merge segments -> single file
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│ StorageService  │ Upload to Supabase Storage
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│ ClipRepository  │ Create clip record
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│ RealtimeService │ Notify host of new submission
└─────────────────┘
```

### Host Finalizes Card Flow

```
User Action: Tap "Finalize Card"
     │
     ▼
┌─────────────────┐
│HostManagementVM │ finalizeCard()
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│ ClipRepository  │ Fetch all approved clips
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│ StorageService  │ Download all clip videos
└────────┬────────┘
         │
         ▼
┌─────────────────────┐
│VideoStitchingService│ Concatenate clips (host first)
└────────┬────────────┘
         │
         ▼
┌─────────────────┐
│ StorageService  │ Upload final video
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│ CardRepository  │ Update card status = 'published'
└────────┬────────┘
         │
         ▼
UI: Show share link for recipient
```

---

## Suggested Build Order

### Phase 1: Foundation (Week 1-2)
**Dependencies: None**

1. **TOYCore Swift Package setup**
   - Create package structure
   - Define domain models (Card, Clip, Participant)
   - No external dependencies yet

2. **Supabase integration skeleton**
   - SupabaseManager singleton
   - Basic auth (anonymous for App Clip)
   - Configuration handling

3. **Deep link infrastructure**
   - URL parsing
   - DeepLinkCoordinator
   - Basic navigation structure

### Phase 2: Recording Pipeline (Week 2-3)
**Dependencies: Foundation complete**

1. **Camera service**
   - AVCaptureSession setup
   - Permission handling
   - Preview layer integration

2. **Recording ViewModel**
   - State machine implementation
   - Segment management
   - Duration enforcement

3. **Recording UI**
   - Camera preview view
   - Record button (hold to record)
   - Segment indicators
   - Review playback

### Phase 3: Data Layer (Week 3-4)
**Dependencies: Recording pipeline for testing**

1. **Supabase repositories**
   - CardRepository implementation
   - ClipRepository implementation
   - Error handling

2. **Storage service**
   - Video upload with progress
   - Signed URL generation
   - Download for playback

3. **Realtime subscriptions**
   - Card updates channel
   - Clip submission notifications

### Phase 4: Host Flow (Week 4-5)
**Dependencies: Data layer complete**

1. **Host dashboard**
   - Card list view
   - Create card flow
   - Share invite link

2. **Card management**
   - View submissions
   - Preview clips
   - Delete clips

3. **Video stitching**
   - AVFoundation composition
   - Export pipeline
   - Progress feedback

### Phase 5: App Clip (Week 5-6)
**Dependencies: Recording + Data layers**

1. **App Clip target setup**
   - Xcode configuration
   - Shared code via TOYCore
   - Size optimization

2. **Participant flow**
   - Deep link handling
   - Streamlined recording
   - Upload and confirmation

3. **Testing & optimization**
   - Binary size verification
   - Performance testing
   - Edge case handling

### Phase 6: Recipient Flow + Polish (Week 6-7)
**Dependencies: All flows complete**

1. **Recipient viewing**
   - Video player
   - Branding overlay
   - Share functionality

2. **End-to-end testing**
   - Full flow testing
   - Error handling
   - Edge cases

3. **Performance optimization**
   - Video compression tuning
   - Memory management
   - Battery impact

---

## Build Order Dependency Graph

```
                    ┌─────────────────┐
                    │   Foundation    │
                    │  (TOYCore pkg)  │
                    └────────┬────────┘
                             │
              ┌──────────────┼──────────────┐
              │              │              │
              ▼              ▼              ▼
       ┌────────────┐ ┌────────────┐ ┌────────────┐
       │  Recording │ │ Deep Link  │ │  Supabase  │
       │  Pipeline  │ │ Navigation │ │   Setup    │
       └──────┬─────┘ └──────┬─────┘ └──────┬─────┘
              │              │              │
              └──────────────┴──────────────┘
                             │
                             ▼
                    ┌─────────────────┐
                    │   Data Layer    │
                    │  (Repositories) │
                    └────────┬────────┘
                             │
              ┌──────────────┴──────────────┐
              │                             │
              ▼                             ▼
       ┌────────────┐                ┌────────────┐
       │  Host Flow │                │  App Clip  │
       │            │                │ (Participant)│
       └──────┬─────┘                └──────┬─────┘
              │                             │
              └──────────────┬──────────────┘
                             │
                             ▼
                    ┌─────────────────┐
                    │ Recipient Flow  │
                    │    + Polish     │
                    └─────────────────┘
```

---

## Technical Risks & Mitigations

| Risk | Impact | Mitigation |
|------|--------|------------|
| App Clip exceeds 15MB | Cannot publish | Aggressive asset optimization; lower resolution; monitor size in CI |
| Video stitching OOM on device | Crashes on large cards | Stream processing; limit participant count; server fallback |
| Supabase storage costs | Budget overrun | Compress videos aggressively; set file size limits; monitor usage |
| AVFoundation complexity | Development delays | Start with simple capture; iterate on quality |
| Deep link fragility | Broken participant links | Comprehensive URL parsing tests; fallback handling |

---

## Open Questions for Implementation

1. **Anonymous vs registered participants?** Can participants record without creating an account? (Likely yes for App Clip friction reduction)

2. **Offline recording?** Should participant be able to record offline and upload later? (Adds complexity but improves UX)

3. **Video quality presets?** Should we offer quality options or auto-detect based on network/device?

4. **Retry logic?** How aggressively should we retry failed uploads? Background upload support?

5. **Clip approval workflow?** Does host explicitly approve each clip or are all auto-approved?

---

*Architecture research complete: 2026-02-01*
