# Project State

## Project Reference

See: .planning/PROJECT.md (updated 2026-02-01)

**Core value:** Anyone can create a heartfelt group video message in minutes
**Current focus:** Phase 4 - Host Card Creation

## Current Position

Phase: 4 of 8 (Host Card Creation)
Plan: 2 of TBD in current phase
Status: In progress
Last activity: 2026-02-02 - Completed 04-02-PLAN.md

Progress: [####------] ~42% (3.2/8 phases complete)

## Performance Metrics

**Velocity:**
- Total plans completed: 19
- Average duration: ~5 minutes
- Total execution time: ~90 minutes

**By Phase:**

| Phase | Plans | Total | Avg/Plan |
|-------|-------|-------|----------|
| 1 | 7/7 | ~56min | ~8min |
| 2 | 6/6 | ~19min | ~3.2min |
| 3 | 4/4 | ~11min | ~2.75min |
| 4 | 2/? | ~4min | ~2min |

**Recent Trend:**
- Last 5 plans: 03-02 (~2min), 03-03 (~2min), 03-04 (~5min verification), 04-01 (~2min), 04-02 (~2min)
- Trend: Phase 4 progressing, execution velocity strong

*Updated after each plan completion*

## Accumulated Context

### Decisions

Decisions are logged in PROJECT.md Key Decisions table.
Recent decisions affecting current work:

| ID | Decision | Rationale | Plan |
|----|----------|-----------|------|
| ARCH-001 | Use local Swift Package for shared code | Enables code sharing between main app and App Clip with proper dependency isolation | 01-01 |
| DB-001 | Auto-create profile on signup via trigger | Ensures profiles table stays in sync with auth.users | 01-02 |
| DB-002 | RLS allows public read of published cards with share_token | Enables recipient viewing without authentication | 01-02 |
| UI-001 | @MainActor for ThemeManager instead of Sendable | AppStorage requires main actor isolation | 01-03 |
| UI-002 | DM Serif Display for headings, System Rounded for body | Elegant editorial headings with friendly readable body text | 01-03 |
| INFRA-001 | Keychain storage for auth tokens | More secure than UserDefaults, prevents token exposure if device compromised | 01-04 |
| INFRA-002 | DEBUG fallback values for credentials | Allows SwiftUI previews and tests to run without configured credentials | 01-04 |
| UI-003 | Component style enums for variants | Enables type-safe styling with computed properties for each variant | 01-05 |
| AUTH-001 | AsyncStream for auth state observation | Native Swift concurrency over Combine for simpler async/await integration | 01-06 |
| AUTH-002 | Profile creation in AuthService | Backup to DB trigger ensures profiles table stays in sync | 01-06 |
| AUTH-003 | Apple Sign-In instead of email/password | Captures user name, no SMS costs, better iOS UX | 01-07 |
| AUTH-004 | Nonce-based security for Apple tokens | Required by Apple/Supabase for token validation | 01-07 |
| REC-001 | AVCaptureVideoDataOutput over MovieFileOutput | Sample buffer access enables seamless multi-clip recording | 02-01 |
| REC-002 | Portrait dimensions with transform | Camera captures landscape; transform handles rotation + front camera mirroring | 02-01 |
| REC-003 | Dedicated sessionQueue for capture operations | startRunning() blocks until hardware ready; must never block main thread | 02-01 |
| REC-004 | Single clip returns without export | Avoids unnecessary export processing when only one clip exists | 02-02 |
| REC-005 | Loop playback in preview | NotificationCenter observer for AVPlayerItemDidPlayToEndTime creates continuous preview | 02-02 |
| REC-006 | Wall clock time for UI updates | Timer uses CACurrentMediaTime() for smooth UI; actual duration from asset | 02-04 |
| REC-007 | 0.5s minimum clip duration | Discards accidental taps to prevent tiny clip fragments | 02-04 |
| UI-004 | DragGesture for hold-to-record | onChanged starts recording, onEnded stops, enables Vine-style interaction | 02-05 |
| REC-008 | Forward nested ObservableObject changes | Combine subscription forwards objectWillChange for proper SwiftUI updates | 02-06 |
| REC-009 | Custom AVPlayerLayer for preview | Removes AVKit controls (AirPlay, speed) for cleaner preview experience | 02-06 |
| REC-010 | Immediate state update on stop | Set state to paused immediately, async work updates if needed; prevents UI stuck | 02-06 |
| STORAGE-001 | Actor isolation for StorageService | Thread safety with async upload operations from multiple contexts | 03-01 |
| STORAGE-002 | Private bucket with signed URLs | Security: videos accessible only via time-limited URLs (1 hour default) | 03-01 |
| LINK-001 | Placeholder domain toy.app for Associated Domains | Will be updated when real domain is finalized | 03-02 |
| UPLOAD-001 | Overlay-based upload progress | Shows progress without navigation change; user stays on preview screen | 03-03 |
| UPLOAD-002 | Exponential backoff retry (2s/4s/8s) with max 3 retries | Standard network retry pattern; prevents hammering server | 03-03 |
| UX-001 | Navigate to home after successful upload | Prevents user confusion and accidental re-upload of same video | 03-04 |
| MODEL-001 | NewCard/NewClip separate structs for inserts | Insert structs include only user-provided fields; read models include all fields | 04-01 |
| SERVICE-001 | Actor isolation for CardService | Thread safety with async CRUD operations, consistent with StorageService | 04-01 |
| UI-005 | Callback pattern for card creation navigation | onCardCreated closure enables parent view to control navigation | 04-02 |
| FORM-001 | Trim whitespace on validation and submission | Prevents accidental empty submissions via trailing spaces | 04-02 |

### Pending Todos

None.

### Blockers/Concerns

None.

## Session Continuity

Last session: 2026-02-02
Stopped at: Completed 04-02-PLAN.md (Card Creation Form)
Resume file: None

## What's Available

After Phase 1 completion:
- TOYShared Swift Package at /TOY/TOYShared/ with supabase-swift dependency
- Package integrated with main app target
- Directory structure ready for Models, Services, Theme, Components
- Main app imports TOYShared successfully
- Supabase project "TOY" created with database schema
- Tables: profiles, cards, clips, participants with RLS policies
- Migration SQL at supabase/migrations/001_initial_schema.sql
- **Theme system operational:**
  - ThemeManager with @Observable for reactive theme state (system/light/dark)
  - Semantic colors: toyPrimary, toySecondary, toyBackground, toySurface, toyText, toyTextSecondary
  - Typography: DM Serif Display headings, System Rounded body with Dynamic Type
  - Asset catalog colorsets with light/dark mode variants
  - Custom fonts registered in Info.plist
- **Supabase client configured:**
  - Configuration.swift with hardcoded URL and anon key
  - SupabaseClient.swift with global `supabase` singleton
  - Keychain-based auth token storage (KeychainLocalStorage)
- **UI Component Library:**
  - TOYButton with primary/secondary/text/destructive styles, small/medium/large sizes, loading state
  - TOYTextField with SF Symbol icons, focus state animations, error message display
  - TOYLabel with 10 typography styles and convenience factory methods
  - All components consume theme colors and typography
- **Authentication (Apple Sign-In):**
  - AuthServiceProtocol defining signInWithApple, signOut, getCurrentUser, observeAuthState
  - SupabaseAuthService implementation using global supabase singleton
  - User model with conversion from Supabase Auth.User and Apple fullName
  - AuthViewModel with nonce generation and SHA256 hashing
  - LoginView with SignInWithAppleButton
  - HomeView with welcome message and sign out
  - ContentView routing based on auth state
  - Apple Developer configured (App ID, Service ID, Key)
  - Supabase Apple provider configured with JWT client secret

After 02-01 (Core Video Capture):
- **Recording infrastructure:**
  - RecordingError enum with 10 error cases covering full pipeline
  - CaptureSession wrapper with 720p preset, front camera, background queue
  - ClipWriter wrapper with H.264 encoding, AAC audio, portrait transform
  - Sample buffer delegate pattern for real-time capture

After 02-02 (Video Merging and Preview):
- **Video utilities:**
  - VideoMerger with AVMutableComposition for combining clips
  - 720p export with orientation preservation via preferredTransform
  - VideoPreviewView with SwiftUI VideoPlayer and loop playback
  - Retake/Confirm actions using TOYButton component
  - Recording directory structure in TOY/Features/Recording/

After 02-03 (Camera Preview and Permissions):
- **Camera preview:**
  - CameraPreview UIViewRepresentable for SwiftUI integration
  - PreviewView with layerClass override for AVCaptureVideoPreviewLayer
  - resizeAspectFill video gravity for full-frame preview
- **Privacy permissions:**
  - NSCameraUsageDescription in Info.plist
  - NSMicrophoneUsageDescription in Info.plist

After 02-04 (Multi-clip Recording Coordinator):
- **Recording coordinator:**
  - RecordingState enum with 6 states (idle, recording, paused, completed, previewing, error)
  - Helper properties: canStartRecording, isRecording, hasContent
  - VideoRecorder @MainActor coordinator with ObservableObject
  - Multi-clip management with 7-second maxDuration
  - Auto-stop when time limit reached
  - startOver functionality to reset and clean up
  - progress and remainingTime computed properties for UI

After 02-05 (Recording UI with Hold-to-Record):
- **Recording UI:**
  - RecordingViewModel bridging VideoRecorder to SwiftUI with permission handling
  - RecordingView with full-screen camera preview
  - DragGesture-based hold-to-record button (Vine-style interaction)
  - Progress ring showing elapsed time toward 7-second limit
  - Start Over button visible when hasContent
  - Done button visible when canFinish
  - Time display with recording indicator
  - Permission denied state with Settings link
  - Transition to VideoPreviewView on completion

After 02-06 (Wire & Verify - Phase 2 Complete):
- **Verified recording pipeline:**
  - Navigation from HomeView to RecordingView
  - Combine subscription forwarding nested ObservableObject changes
  - Custom AVPlayerLayer preview without AirPlay/speed controls
  - Race condition fix with isFinishingClip flag
  - Correct video transform for portrait front camera
  - Record button hides when 7 seconds reached
  - All Phase 2 success criteria human-verified on physical device

After 03-01 (Storage Service):
- **Storage infrastructure:**
  - StorageService actor for thread-safe video upload operations
  - uploadVideo() method for clips bucket upload with FileOptions
  - createSignedURL() method for time-limited secure video access
  - UploadError enum with fileNotFound, uploadFailed, signedURLFailed cases
  - SQL migration at supabase/migrations/002_storage_policies.sql
  - Private clips bucket with INSERT/SELECT/UPDATE/DELETE RLS policies

After 03-02 (Deep Link Infrastructure):
- **Universal Links support:**
  - DeepLinkService with parse() method for URL parsing
  - DeepLinkDestination enum with card(shareToken:) and unknown cases
  - Associated Domains entitlement with applinks:toy.app placeholder
  - onOpenURL handler in TOYApp with pendingDeepLink state
  - Ready for card invite link navigation in Phase 4+

After 03-03 (Upload UI & Integration):
- **Upload progress flow:**
  - UploadProgressView with UploadState enum (uploading, success, failed)
  - Full-screen overlay with semi-transparent background
  - Spinner during upload, checkmark on success, error with retry/cancel buttons
  - RecordingViewModel wired to StorageService with upload lifecycle
  - Exponential backoff retry (2s, 4s, 8s delays, max 3 attempts)
  - Upload overlay integrated into RecordingView flow
  - Complete video submission pipeline: record -> preview -> confirm -> upload -> success

After 03-04 (Verify & Human Test - Phase 3 Complete):
- **Verified complete Phase 3 implementation:**
  - All 5 success criteria human-verified on physical device
  - Upload progress indicator shows during upload
  - Videos stored in Supabase clips bucket
  - Signed URLs work for secure video access
  - Retry logic works on upload failure
  - Deep link infrastructure ready for Phase 4+
  - UX fix: successful upload navigates to home screen

After 04-01 (Data Models & Card Service):
- **Data layer for card creation:**
  - Card, Clip, Participant models with Codable conformance and CodingKeys
  - NewCard, NewClip structs for database inserts
  - CardService actor with createCard, createClip, fetchCardsForHost, updateCardStatus
  - CardError enum with localized error descriptions
  - Pattern: separate insert models (New*) from read models for cleaner API

After 04-02 (Card Creation Form):
- **Card creation UI:**
  - CreateCardViewModel with @Observable form state (title, recipientName, occasion)
  - isFormValid and canSubmit computed properties for validation
  - createCard(hostId:) method with CardService integration
  - CreateCardView with TOYTextField inputs for title and recipient name
  - TOYButton submit with loading state and disabled validation
  - onCardCreated callback for parent navigation control
