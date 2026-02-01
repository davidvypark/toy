# Requirements: TOY (Thinking Of You)

**Defined:** 2026-02-01
**Core Value:** Anyone can create a heartfelt group video message in minutes

## v1 Requirements

Requirements for initial release. Each maps to roadmap phases.

### Host Flow

- [ ] **HOST-01**: Host can create a new card
- [ ] **HOST-02**: Host can record their own video clip (appears first in montage)
- [ ] **HOST-03**: Host can generate shareable invite link
- [ ] **HOST-04**: Host can view all invitees and their submission status
- [ ] **HOST-05**: Host can preview each submitted clip
- [ ] **HOST-06**: Host can delete unwanted clips
- [ ] **HOST-07**: Host can preview the full stitched montage
- [ ] **HOST-08**: Host can finalize and publish the card
- [ ] **HOST-09**: Host receives shareable link to send to recipient

### Participant Flow

- [ ] **PART-01**: Participant can open invite link via App Clip (no app install required)
- [ ] **PART-02**: Participant can record video Vine-style (hold to record, release to pause)
- [ ] **PART-03**: Participant recording limited to 7 seconds total
- [ ] **PART-04**: Participant can start over (delete all and re-record)
- [ ] **PART-05**: Participant can preview their recording before submitting
- [ ] **PART-06**: Participant can submit their clip
- [ ] **PART-07**: Participant sees upload progress indicator during submission

### Recipient Flow

- [ ] **RCPT-01**: Recipient can open link and view final montage
- [ ] **RCPT-02**: Video auto-plays when recipient opens link
- [ ] **RCPT-03**: Video displays with subtle TOY branding
- [ ] **RCPT-04**: Recipient can reshare video to social media

### Technical

- [ ] **TECH-01**: Supabase backend for authentication
- [ ] **TECH-02**: Supabase database for cards, clips, invites data
- [ ] **TECH-03**: Supabase storage for video clips (clips bucket)
- [ ] **TECH-04**: Supabase storage for final videos (videos bucket)
- [ ] **TECH-05**: Deep linking for invite flow (Universal Links)
- [ ] **TECH-06**: App Clip target for participant recording flow
- [ ] **TECH-07**: Server-side video stitching (host first, then chronological)
- [ ] **TECH-08**: Signed URLs for secure video access
- [ ] **TECH-09**: Analytics/tracking for user behavior

### Monetization

- [ ] **MNTZ-01**: One-time purchase per card via RevenueCat
- [ ] **MNTZ-02**: Free tier for small groups (8 or fewer participants)

### Architecture

- [ ] **ARCH-01**: Clean architecture with MVVM pattern
- [ ] **ARCH-02**: Reusable UI component library (buttons, labels, inputs)
- [ ] **ARCH-03**: Theme system supporting future dark/light mode
- [ ] **ARCH-04**: Shared Swift package for code reuse between app and App Clip

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

### Platform

- **PLAT-V2-01**: Android version

## Out of Scope

Explicitly excluded. Documented to prevent scope creep.

| Feature | Reason |
|---------|--------|
| Android version | iOS-first for MVP, evaluate after v1 launch |
| Clip reordering by host | Auto-order (host first, chronological) is sufficient for MVP |
| Trimming/editing clips | Keep recording simple, Vine-style constraints work |
| Video filters/effects | Post-MVP feature, adds complexity to recording flow |
| Text overlays | Video-only for MVP, keeps focus on the message |
| OAuth/social login | Simple email auth for MVP |
| Subscription model | One-time purchase aligns with event-based usage |
| Real-time collaboration | Adds significant complexity, async flow works |
| Multi-recipient cards | One recipient per card for MVP |

## Traceability

Which phases cover which requirements. Updated during roadmap creation.

| Requirement | Phase | Status |
|-------------|-------|--------|
| ARCH-01 | Phase 1 | Pending |
| ARCH-02 | Phase 1 | Pending |
| ARCH-03 | Phase 1 | Pending |
| ARCH-04 | Phase 1 | Pending |
| TECH-01 | Phase 1 | Pending |
| TECH-02 | Phase 1 | Pending |
| PART-02 | Phase 2 | Pending |
| PART-03 | Phase 2 | Pending |
| PART-04 | Phase 2 | Pending |
| PART-05 | Phase 2 | Pending |
| TECH-03 | Phase 3 | Pending |
| TECH-05 | Phase 3 | Pending |
| TECH-08 | Phase 3 | Pending |
| PART-06 | Phase 3 | Pending |
| PART-07 | Phase 3 | Pending |
| HOST-01 | Phase 4 | Pending |
| HOST-02 | Phase 4 | Pending |
| HOST-03 | Phase 4 | Pending |
| HOST-04 | Phase 5 | Pending |
| HOST-05 | Phase 5 | Pending |
| HOST-06 | Phase 5 | Pending |
| HOST-07 | Phase 6 | Pending |
| HOST-08 | Phase 6 | Pending |
| HOST-09 | Phase 6 | Pending |
| TECH-04 | Phase 6 | Pending |
| TECH-07 | Phase 6 | Pending |
| TECH-06 | Phase 7 | Pending |
| PART-01 | Phase 7 | Pending |
| RCPT-01 | Phase 8 | Pending |
| RCPT-02 | Phase 8 | Pending |
| RCPT-03 | Phase 8 | Pending |
| RCPT-04 | Phase 8 | Pending |
| MNTZ-01 | Phase 8 | Pending |
| MNTZ-02 | Phase 8 | Pending |
| TECH-09 | Phase 8 | Pending |

**Coverage:**
- v1 requirements: 35 total
- Mapped to phases: 35
- Unmapped: 0

---
*Requirements defined: 2026-02-01*
*Last updated: 2026-02-01 after roadmap creation*
