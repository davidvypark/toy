# Project State

## Project Reference

See: .planning/PROJECT.md (updated 2026-02-01)

**Core value:** Anyone can create a heartfelt group video message in minutes
**Current focus:** Phase 2 - Recording Pipeline

## Current Position

Phase: 2 of 8 (Recording Pipeline)
Plan: 1 of 6 in current phase
Status: In progress
Last activity: 2026-02-02 - Completed 02-01-PLAN.md (Core Video Capture)

Progress: [##--------] ~16% (1/8 phases + 1/6 plans in Phase 2)

## Performance Metrics

**Velocity:**
- Total plans completed: 8
- Average duration: ~7 minutes
- Total execution time: ~59 minutes

**By Phase:**

| Phase | Plans | Total | Avg/Plan |
|-------|-------|-------|----------|
| 1 | 7/7 | ~56min | ~8min |
| 2 | 1/6 | ~3min | ~3min |

**Recent Trend:**
- Last 5 plans: 01-05 (~2min), 01-06 (~3min), 01-07 (~45min*), 02-01 (~3min)
- *01-07 included Apple Sign-In pivot and backend configuration
- Trend: On track

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

### Pending Todos

None.

### Blockers/Concerns

None.

## Session Continuity

Last session: 2026-02-02
Stopped at: Completed 02-01-PLAN.md
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
