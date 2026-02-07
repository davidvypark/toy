# Milestones: TOY (Thinking Of You)

## Completed Milestones

### v1.0 — Core MVP (2026-02-01 to 2026-02-02)

**Goal:** Build complete end-to-end group video card experience

**Phases:** 1-8 (38 plans)

**Delivered:**
- iOS app with Apple Sign-In
- Vine-style video recording (7 seconds, hold-to-record)
- Card creation, participant invites, clip management
- Video stitching and publishing
- App Clip for zero-install participant recording
- Web viewer at sendtoycard.com
- RevenueCat integration (upgrade UI ready)

**Key Decisions:**
- SwiftUI + AVFoundation native stack
- Supabase backend (auth, database, storage)
- sendtoycard.com domain for all links
- PostHog removed (use DB timestamps for analytics)

**Requirements completed:** 35/35 v1 requirements

---

### v1.1 — Video Playback Quality & UI Polish (2026-02-06 to 2026-02-07)

**Goal:** Improve video playback smoothness and polish the app UI for launch readiness

**Phases:** 9-12 (partially completed via GSD, rest done manually)

**Delivered:**
- Removed percentage text from loading overlays (spinner-only)
- Thumbnail generation at 1.5s (natural pose) instead of 0.5s
- Audio plays correctly in silent mode (.playback audio session)
- AVPlayerLooper for seamless video loops
- Tap-to-pause/play across all video surfaces
- Videos resume after app backgrounding
- Published video layout improvements (title above video, details caret)
- Onboarding slideshow (3 value prop slides + sign-in)
- URL consolidation (/card + /watch)

**Key Decisions:**
- Download-first-then-play over streaming (7s clips are 2-5MB)
- AVPlayerLooper over manual seek-to-zero
- Simplified onboarding architecture (TabView + fullScreenCover for sign-in)

**Requirements completed:** v1.1 playback quality improvements + UI polish

---
*Last updated: 2026-02-07*
