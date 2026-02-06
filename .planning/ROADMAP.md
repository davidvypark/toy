# Roadmap: TOY (Thinking Of You)

## Milestones

- v1.0 MVP - Phases 1-8 (shipped 2026-02-02)
- v1.1 Video Playback Quality - Phases 9-12 (in progress)

## Phases

<details>
<summary>v1.0 MVP (Phases 1-8) - SHIPPED 2026-02-02</summary>

### Phase 1: Foundation & Architecture
**Goal**: Establish the technical foundation with clean architecture, reusable components, and backend connectivity
**Requirements**: ARCH-01, ARCH-02, ARCH-03, ARCH-04, TECH-01, TECH-02
**Plans**: 7/7 complete

Plans:
- [x] 01-01: TOYShared Swift Package
- [x] 01-02: Database Schema Design
- [x] 01-03: Theme System & Typography
- [x] 01-04: Supabase Client & Configuration
- [x] 01-05: Reusable UI Components
- [x] 01-06: Auth Service Layer
- [x] 01-07: Wire & Verify Foundation

### Phase 2: Recording Pipeline
**Goal**: Users can record 7-second Vine-style video clips with preview and re-record capability
**Requirements**: PART-02, PART-03, PART-04, PART-05
**Plans**: 6/6 complete

Plans:
- [x] 02-01: Core Capture Infrastructure
- [x] 02-02: Video Merging & Preview Playback
- [x] 02-03: Camera Preview & Permission Config
- [x] 02-04: Recording Coordinator
- [x] 02-05: Recording UI & ViewModel
- [x] 02-06: Wire & Verify Recording Flow

### Phase 3: Data Layer & Upload
**Goal**: Recorded clips can be uploaded to Supabase storage with progress tracking and deep link support
**Requirements**: TECH-03, TECH-05, TECH-08, PART-06, PART-07
**Plans**: 4/4 complete

Plans:
- [x] 03-01: Storage Service & Supabase Bucket Setup
- [x] 03-02: Deep Link Infrastructure
- [x] 03-03: Upload UI & Integration
- [x] 03-04: Verify & Human Test

### Phase 4: Host Card Creation
**Goal**: Hosts can create new cards, record their own clip, and invite participants
**Requirements**: HOST-01, HOST-02, HOST-03
**Plans**: 4/4 complete

Plans:
- [x] 04-01: Models & CardService
- [x] 04-02: Card Creation Form
- [x] 04-03: Recording with Card Context
- [x] 04-04: Wire Flow & ShareLink

### Phase 5: Host Card Management
**Goal**: Hosts can view all participants, preview submitted clips, and manage their card
**Requirements**: HOST-04, HOST-05, HOST-06
**Plans**: 3/3 complete

Plans:
- [x] 05-01: CardService Extensions & ParticipantRow
- [x] 05-02: CardDetailView & ClipPreviewSheet
- [x] 05-03: Wire Navigation & Human Verify

### Phase 6: Video Stitching & Publishing
**Goal**: Hosts can preview the full stitched montage and publish the final card for recipients
**Requirements**: HOST-07, HOST-08, HOST-09, TECH-04, TECH-07
**Plans**: 4/4 complete

Plans:
- [x] 06-01: Videos Bucket & Service Extensions
- [x] 06-02: MontageService & VideoMerger Progress
- [x] 06-03: Publishing UI
- [x] 06-04: Wire Navigation & Human Verify

### Phase 7: App Clip Integration
**Goal**: Participants can open invite links and record clips without installing the full app
**Requirements**: TECH-06, PART-01
**Plans**: 4/4 complete

Plans:
- [x] 07-01: Backend support for unauthenticated card lookup
- [x] 07-02: App Clip target setup
- [x] 07-03: App Clip entry point and recording flow
- [x] 07-04: Upload success view and human verification

### Phase 8: Recipient Flow & Monetization
**Goal**: Recipients can view final videos and hosts can purchase card upgrades
**Requirements**: RCPT-01, RCPT-02, RCPT-03, RCPT-04, MNTZ-01, MNTZ-02, TECH-09
**Plans**: 6/6 complete

Plans:
- [x] 08-01: Next.js web project setup with Supabase
- [x] 08-02: Video viewer page with branding and social sharing
- [x] 08-03: RevenueCat SDK setup and PurchaseService
- [x] 08-04: Upgrade UI and free tier enforcement
- [x] 08-05: PostHog analytics integration
- [x] 08-06: Human verification of recipient flow and monetization

</details>

### v1.1 Video Playback Quality (In Progress)

**Milestone Goal:** Achieve Instagram/TikTok-level video playback smoothness across all video surfaces -- instant replay on re-visit, seamless loading transitions, no frozen frames or progress jumps

- [ ] **Phase 9: Quick Playback Wins** - Eliminate visible playback annoyances with targeted fixes
- [ ] **Phase 10: Unified Player & Loading UX** - Single player component with polished thumbnail-to-video transitions
- [ ] **Phase 11: Cache Infrastructure** - Disk video cache and signed URL management for instant replay
- [ ] **Phase 12: Preloading Pipeline** - Background video downloads so playback starts instantly on navigation

## Phase Details

### Phase 9: Quick Playback Wins
**Goal**: Users experience noticeably faster, smoother video playback through targeted behavioral fixes across all existing player views
**Depends on**: Phase 8 (v1.0 complete)
**Requirements**: LOAD-02, LOAD-04, QUAL-01, QUAL-02, QUAL-03
**Success Criteria** (what must be TRUE):
  1. No percentage text appears anywhere during video loading -- loading state is communicated visually through thumbnails and transitions only
  2. Video playback begins within ~500ms of player appearing, without waiting for full buffer to fill
  3. Newly recorded clips generate thumbnails at a natural moment (~1.5s) where the person is composed, not mid-setup at 0.5s
  4. Videos loop seamlessly with no visible pause, stutter, or black flash at the loop point
  5. Video audio plays correctly even when the device ringer/silent switch is set to silent mode
**Plans**: TBD

Plans:
- [ ] 09-01: TBD
- [ ] 09-02: TBD

### Phase 10: Unified Player & Loading UX
**Goal**: All 4 separate video player implementations are replaced by a single TOYVideoPlayerView with a polished loading experience that transitions seamlessly from thumbnail to video
**Depends on**: Phase 9
**Requirements**: PLAY-01, LOAD-01, LOAD-03, LOAD-05
**Success Criteria** (what must be TRUE):
  1. A single TOYVideoPlayerView component is used across PublishedCardPlayerView, MontagePreviewView, ClipPreviewSheet, and VideoPreviewView -- no duplicate UIViewRepresentable wrappers remain
  2. When a video is loading, the thumbnail fills the entire frame as a placeholder (no small thumbnail with dark overlay or "Loading video..." text)
  3. The transition from thumbnail to live video is a smooth crossfade with zero black frames visible at any point
  4. A subtle shimmer animation plays over the thumbnail while the video is loading, replacing any static loading indicators
**Plans**: TBD

Plans:
- [ ] 10-01: TBD
- [ ] 10-02: TBD
- [ ] 10-03: TBD

### Phase 11: Cache Infrastructure
**Goal**: Videos play instantly from disk on re-visit and signed URLs are managed transparently so playback never fails due to URL expiry
**Depends on**: Phase 10
**Requirements**: PLAY-02, PLAY-03
**Success Criteria** (what must be TRUE):
  1. Re-visiting a previously watched published card plays the video instantly from disk cache (~100ms) with no loading indicator or network activity
  2. Videos remain cached across app launches -- closing and reopening the app does not require re-downloading previously watched videos
  3. Signed URLs refresh transparently when they approach expiry -- the user never sees a playback error caused by an expired URL, even if the app has been open for hours
  4. Cache respects a size limit (LRU eviction) so disk usage stays bounded even after watching many videos
**Plans**: TBD

Plans:
- [ ] 11-01: TBD
- [ ] 11-02: TBD

### Phase 12: Preloading Pipeline
**Goal**: Videos are downloaded in the background before the user navigates to them, so playback starts instantly on every tap
**Depends on**: Phase 11
**Requirements**: PLAY-04, PLAY-05
**Success Criteria** (what must be TRUE):
  1. When the home screen card list loads, published card videos begin downloading in the background -- by the time the user taps a card, playback starts instantly from cache
  2. When the montage preview opens, all clip videos have been downloaded to disk and the AVQueuePlayer plays from local files with no inter-clip buffering gaps
  3. Preloading respects network conditions and does not visibly degrade app responsiveness or consume excessive bandwidth
**Plans**: TBD

Plans:
- [ ] 12-01: TBD
- [ ] 12-02: TBD

## Progress

**Execution Order:**
Phases execute in numeric order: 9 -> 10 -> 11 -> 12

| Phase | Milestone | Plans Complete | Status | Completed |
|-------|-----------|----------------|--------|-----------|
| 1. Foundation & Architecture | v1.0 | 7/7 | Complete | 2026-02-01 |
| 2. Recording Pipeline | v1.0 | 6/6 | Complete | 2026-02-02 |
| 3. Data Layer & Upload | v1.0 | 4/4 | Complete | 2026-02-02 |
| 4. Host Card Creation | v1.0 | 4/4 | Complete | 2026-02-02 |
| 5. Host Card Management | v1.0 | 3/3 | Complete | 2026-02-02 |
| 6. Video Stitching & Publishing | v1.0 | 4/4 | Complete | 2026-02-02 |
| 7. App Clip Integration | v1.0 | 4/4 | Complete | 2026-02-02 |
| 8. Recipient Flow & Monetization | v1.0 | 6/6 | Complete | 2026-02-02 |
| 9. Quick Playback Wins | v1.1 | 0/TBD | Not started | - |
| 10. Unified Player & Loading UX | v1.1 | 0/TBD | Not started | - |
| 11. Cache Infrastructure | v1.1 | 0/TBD | Not started | - |
| 12. Preloading Pipeline | v1.1 | 0/TBD | Not started | - |

---
*Roadmap created: 2026-02-01*
*v1.1 roadmap added: 2026-02-06*
*Depth: comprehensive (4 phases for v1.1, 12 total)*
*Coverage: 35/35 v1.0 + 13/13 v1.1 requirements mapped*
