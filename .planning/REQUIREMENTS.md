# Requirements: TOY (Thinking Of You)

**Defined:** 2026-02-01
**Core Value:** Anyone can create a heartfelt group video message in minutes

## v1 Requirements

Requirements for initial release (v1.0). All delivered.

### Host Flow

- [x] **HOST-01**: Host can create a new card
- [x] **HOST-02**: Host can record their own video clip (appears first in montage)
- [x] **HOST-03**: Host can generate shareable invite link
- [x] **HOST-04**: Host can view all invitees and their submission status
- [x] **HOST-05**: Host can preview each submitted clip
- [x] **HOST-06**: Host can delete unwanted clips
- [x] **HOST-07**: Host can preview the full stitched montage
- [x] **HOST-08**: Host can finalize and publish the card
- [x] **HOST-09**: Host receives shareable link to send to recipient

### Participant Flow

- [x] **PART-01**: Participant can open invite link via App Clip (no app install required)
- [x] **PART-02**: Participant can record video Vine-style (hold to record, release to pause)
- [x] **PART-03**: Participant recording limited to 7 seconds total
- [x] **PART-04**: Participant can start over (delete all and re-record)
- [x] **PART-05**: Participant can preview their recording before submitting
- [x] **PART-06**: Participant can submit their clip
- [x] **PART-07**: Participant sees upload progress indicator during submission

### Recipient Flow

- [x] **RCPT-01**: Recipient can open link and view final montage
- [x] **RCPT-02**: Video auto-plays when recipient opens link
- [x] **RCPT-03**: Video displays with subtle TOY branding
- [x] **RCPT-04**: Recipient can reshare video to social media

### Technical

- [x] **TECH-01**: Supabase backend for authentication
- [x] **TECH-02**: Supabase database for cards, clips, invites data
- [x] **TECH-03**: Supabase storage for video clips (clips bucket)
- [x] **TECH-04**: Supabase storage for final videos (videos bucket)
- [x] **TECH-05**: Deep linking for invite flow (Universal Links)
- [x] **TECH-06**: App Clip target for participant recording flow
- [x] **TECH-07**: Server-side video stitching (host first, then chronological)
- [x] **TECH-08**: Signed URLs for secure video access
- [x] **TECH-09**: Analytics/tracking for user behavior

### Monetization

- [x] **MNTZ-01**: One-time purchase per card via RevenueCat
- [x] **MNTZ-02**: Free tier for small groups (8 or fewer participants)

### Architecture

- [x] **ARCH-01**: Clean architecture with MVVM pattern
- [x] **ARCH-02**: Reusable UI component library (buttons, labels, inputs)
- [x] **ARCH-03**: Theme system supporting future dark/light mode
- [x] **ARCH-04**: Shared Swift package for code reuse between app and App Clip

## v1.1 Requirements

Requirements for Video Playback Quality milestone. Each maps to roadmap phases.

### Playback Infrastructure

- [ ] **PLAY-01**: Unified video player component replaces all 4 separate player implementations
- [ ] **PLAY-02**: Videos cached to disk with LRU eviction for instant replay on re-visit
- [ ] **PLAY-03**: Signed URLs managed with TTL tracking and auto-refresh before expiry
- [ ] **PLAY-04**: Published card videos preloaded in background when card list loads
- [ ] **PLAY-05**: Montage clips downloaded to disk before queue playback begins

### Loading UX

- [ ] **LOAD-01**: Thumbnail displays as full-bleed placeholder with seamless crossfade to video
- [ ] **LOAD-02**: No percentage text shown during video loading
- [ ] **LOAD-03**: Zero black frames between thumbnail and video playback
- [ ] **LOAD-04**: Video playback starts immediately without waiting for full buffer
- [ ] **LOAD-05**: Shimmer animation shown over thumbnail during video loading

### Playback Quality

- [ ] **QUAL-01**: Thumbnails generated at 1.5s into clip instead of 0.5s
- [ ] **QUAL-02**: Video loops seamlessly with no visible gap at loop point
- [ ] **QUAL-03**: Video audio plays correctly when device is in silent mode

## v2 Requirements

Deferred to future release. Tracked but not in current roadmap.

### Host Enhancements

- **HOST-V2-01**: Real-time dashboard updates (see submissions arrive live)
- **HOST-V2-02**: Card templates/themes (pre-designed visual styles)
- **HOST-V2-03**: Clip reordering (manual arrangement of clips)

### Recipient Enhancements

- **RCPT-V2-01**: Download video to camera roll
- **RCPT-V2-02**: Thank you response card (recipient creates response back)

### Visual Enhancements

- **VIS-V2-01**: Filters/ambience effects for clips
- **VIS-V2-02**: Text overlays on videos
- **VIS-V2-03**: Transition effects between clips

### Video Quality

- **VID-V2-01**: Adaptive thumbnail generation (multiple candidates with face detection scoring)

### Platform

- **PLAT-V2-01**: Android version

## Out of Scope

Explicitly excluded. Documented to prevent scope creep.

| Feature | Reason |
|---------|--------|
| Android version | iOS-first, evaluate after v1 launch |
| Clip reordering by host | Auto-order (host first, chronological) is sufficient |
| Trimming/editing clips | Keep recording simple, Vine-style constraints work |
| Video filters/effects | Post-MVP feature, adds complexity to recording flow |
| Text overlays | Video-only, keeps focus on the message |
| OAuth/social login | Simple auth is sufficient |
| Subscription model | One-time purchase aligns with event-based usage |
| Real-time collaboration | Adds significant complexity, async flow works |
| Multi-recipient cards | One recipient per card |
| HLS / adaptive bitrate streaming | Videos are 2-5MB; download-first is better than streaming optimization |
| Custom video player controls | 7-second auto-play clips don't need scrub bars |
| CDN / video transcoding service | TOY's scale doesn't justify Mux/Cloudflare Stream complexity |
| Third-party video caching libraries | Custom URL scheme requirement and signed URL rotation make them actively harmful |

## Traceability

Which phases cover which requirements. Updated during roadmap creation.

### v1.0 (Complete)

| Requirement | Phase | Status |
|-------------|-------|--------|
| ARCH-01 | Phase 1 | Complete |
| ARCH-02 | Phase 1 | Complete |
| ARCH-03 | Phase 1 | Complete |
| ARCH-04 | Phase 1 | Complete |
| TECH-01 | Phase 1 | Complete |
| TECH-02 | Phase 1 | Complete |
| PART-02 | Phase 2 | Complete |
| PART-03 | Phase 2 | Complete |
| PART-04 | Phase 2 | Complete |
| PART-05 | Phase 2 | Complete |
| TECH-03 | Phase 3 | Complete |
| TECH-05 | Phase 3 | Complete |
| TECH-08 | Phase 3 | Complete |
| PART-06 | Phase 3 | Complete |
| PART-07 | Phase 3 | Complete |
| HOST-01 | Phase 4 | Complete |
| HOST-02 | Phase 4 | Complete |
| HOST-03 | Phase 4 | Complete |
| HOST-04 | Phase 5 | Complete |
| HOST-05 | Phase 5 | Complete |
| HOST-06 | Phase 5 | Complete |
| HOST-07 | Phase 6 | Complete |
| HOST-08 | Phase 6 | Complete |
| HOST-09 | Phase 6 | Complete |
| TECH-04 | Phase 6 | Complete |
| TECH-07 | Phase 6 | Complete |
| TECH-06 | Phase 7 | Complete |
| PART-01 | Phase 7 | Complete |
| RCPT-01 | Phase 8 | Complete |
| RCPT-02 | Phase 8 | Complete |
| RCPT-03 | Phase 8 | Complete |
| RCPT-04 | Phase 8 | Complete |
| MNTZ-01 | Phase 8 | Complete |
| MNTZ-02 | Phase 8 | Complete |
| TECH-09 | Phase 8 | Complete |

### v1.1 (In Progress)

| Requirement | Phase | Status |
|-------------|-------|--------|
| LOAD-02 | Phase 9 | Pending |
| LOAD-04 | Phase 9 | Pending |
| QUAL-01 | Phase 9 | Pending |
| QUAL-02 | Phase 9 | Pending |
| QUAL-03 | Phase 9 | Pending |
| PLAY-01 | Phase 10 | Pending |
| LOAD-01 | Phase 10 | Pending |
| LOAD-03 | Phase 10 | Pending |
| LOAD-05 | Phase 10 | Pending |
| PLAY-02 | Phase 11 | Pending |
| PLAY-03 | Phase 11 | Pending |
| PLAY-04 | Phase 12 | Pending |
| PLAY-05 | Phase 12 | Pending |

**Coverage:**
- v1.0 requirements: 35 total (all complete)
- v1.1 requirements: 13 total
- Mapped to phases: 13/13
- Unmapped: 0

---
*Requirements defined: 2026-02-01*
*Last updated: 2026-02-06 after v1.1 roadmap creation*
