# Project State

## Project Reference

See: .planning/PROJECT.md (updated 2026-02-01)

**Core value:** Anyone can create a heartfelt group video message in minutes
**Current focus:** Phase 1 - Foundation & Architecture

## Current Position

Phase: 1 of 8 (Foundation & Architecture)
Plan: 6 of 7 in current phase
Status: In progress
Last activity: 2026-02-01 - Completed 01-06-PLAN.md (Authentication Service)

Progress: [######----] 86% (6/7 plans in Phase 1)

## Performance Metrics

**Velocity:**
- Total plans completed: 6
- Average duration: ~6 minutes
- Total execution time: ~36 minutes

**By Phase:**

| Phase | Plans | Total | Avg/Plan |
|-------|-------|-------|----------|
| 1 | 6/7 | ~36min | ~6min |

**Recent Trend:**
- Last 5 plans: 01-02 (~13min), 01-03 (~8min), 01-04 (~5min), 01-05 (~2min), 01-06 (~3min)
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

### Pending Todos

None.

### Blockers/Concerns

None.

## Session Continuity

Last session: 2026-02-01 15:06 UTC
Stopped at: Completed 01-06-PLAN.md
Resume file: None

## What's Available

After 01-06 completion:
- TOYShared Swift Package at /TOYShared/ with supabase-swift dependency
- Package integrated with main app target
- Directory structure ready for Models, Services, Theme, Components
- Main app imports TOYShared successfully
- Supabase project "TOY" created with database schema
- Tables: profiles, cards, clips, participants with RLS policies
- Migration SQL at supabase/migrations/001_initial_schema.sql
- Environment template at .env.example
- .env file with actual Supabase credentials (gitignored)
- **Theme system operational:**
  - ThemeManager with @Observable for reactive theme state (system/light/dark)
  - Semantic colors: toyPrimary, toySecondary, toyBackground, toySurface, toyText, toyTextSecondary
  - Typography: DM Serif Display headings, System Rounded body with Dynamic Type
  - Asset catalog colorsets with light/dark mode variants
  - Custom fonts registered in Info.plist
- **Supabase client configured:**
  - Configuration.swift loads URL and anon key from Info.plist
  - SupabaseClient.swift with global `supabase` singleton
  - Keychain-based auth token storage (KeychainLocalStorage)
  - Debug.xcconfig template for local development
  - Info.plist with SUPABASE_URL and SUPABASE_ANON_KEY placeholders
- **UI Component Library:**
  - TOYButton with primary/secondary/text/destructive styles, small/medium/large sizes, loading state
  - TOYTextField with SF Symbol icons, focus state animations, error message display
  - TOYLabel with 10 typography styles and convenience factory methods
  - All components consume theme colors and typography
- **Authentication Service:**
  - AuthServiceProtocol defining signUp, signIn, signOut, getCurrentUser, observeAuthState
  - SupabaseAuthService implementation using global supabase singleton
  - User model with conversion from Supabase Auth.User
  - AsyncStream-based auth state observation for reactive UI
  - SwiftUI @Entry environment key for dependency injection
