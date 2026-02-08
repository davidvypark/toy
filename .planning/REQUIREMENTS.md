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

## v1.1 Requirements (Complete)

Requirements for Video Playback Quality milestone. Delivered manually outside GSD.

### Playback Infrastructure

- [x] **PLAY-01**: Unified video player component replaces all 4 separate player implementations
- [x] **PLAY-02**: Videos cached to disk with LRU eviction for instant replay on re-visit
- [x] **PLAY-03**: Signed URLs managed with TTL tracking and auto-refresh before expiry
- [x] **PLAY-04**: Published card videos preloaded in background when card list loads
- [x] **PLAY-05**: Montage clips downloaded to disk before queue playback begins

### Loading UX

- [x] **LOAD-01**: Thumbnail displays as full-bleed placeholder with seamless crossfade to video
- [x] **LOAD-02**: No percentage text shown during video loading
- [x] **LOAD-03**: Zero black frames between thumbnail and video playback
- [x] **LOAD-04**: Video playback starts immediately without waiting for full buffer
- [x] **LOAD-05**: Shimmer animation shown over thumbnail during video loading

### Playback Quality

- [x] **QUAL-01**: Thumbnails generated at 1.5s into clip instead of 0.5s
- [x] **QUAL-02**: Video loops seamlessly with no visible gap at loop point
- [x] **QUAL-03**: Video audio plays correctly when device is in silent mode

## v1.2 Requirements

Requirements for Seat-Based Monetization milestone. Each maps to roadmap phases.

### Pricing (PRICE)

- [ ] **PRICE-01**: Cards with 5 or fewer clips can be published for free with no payment interaction
- [ ] **PRICE-02**: Participants can always record and submit clips regardless of how many clips exist on the card
- [ ] **PRICE-03**: Host is prompted to select a tier and pay only when they tap "Publish" and clip count exceeds the free tier
- [ ] **PRICE-04**: Host explicitly chooses their tier — no auto-charges, no surprise billing
- [ ] **PRICE-05**: Tier products are consumable IAPs so the same host can purchase the same tier for different cards

### Tier Awareness (TIER)

- [ ] **TIER-01**: Card detail view shows a tier indicator with clip count, current tier status, and cost to publish when over free limit
- [ ] **TIER-02**: Host can tap the tier indicator to proactively upgrade their card's tier before publish time
- [ ] **TIER-03**: At publish checkout, a static tier visualization shows where the host falls in the tier range (not an interactive carousel)
- [ ] **TIER-04**: Checkout auto-selects the cheapest tier that fits the current clip count

### Purchase Flow (PURCH)

- [ ] **PURCH-01**: Purchase records the transaction ID and tier to the card record in Supabase
- [ ] **PURCH-02**: Card's `maxParticipants` is updated to the purchased tier's clip limit after successful purchase
- [ ] **PURCH-03**: If publish fails after payment, host can retry publish without re-purchasing
- [ ] **PURCH-04**: Existing cards with `maxParticipants = 8` are grandfathered (treated as free with 8-clip allowance)

### Cleanup (CLEAN)

- [ ] **CLEAN-01**: Old single-product `CardUpgradeView` and binary upgrade flow are removed and replaced by the new tier system

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
| Subscription model | Per-card consumable purchases align with event-based usage |
| Interactive checkout carousel | Static tier visualization is cleaner; swipeable carousel adds complexity without value |
| Celebratory publish animation | Deferred to future polish milestone |
| Per-participant cost framing | Nice-to-have but not essential for v1.2 |
| Server-side purchase verification (Edge Function) | Client-side tracking sufficient for MVP; add when fraud is a concern |
| RevenueCat webhooks | Not needed for MVP; client-side purchase recording is sufficient |
| A/B testing pricing | Need baseline conversion data first |
| Group gifting / cost-splitting | Future consideration |
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

### v1.1 (Complete)

| Requirement | Phase | Status |
|-------------|-------|--------|
| LOAD-02 | Phase 9 | Complete |
| LOAD-04 | Phase 9 | Complete |
| QUAL-01 | Phase 9 | Complete |
| QUAL-02 | Phase 9 | Complete |
| QUAL-03 | Phase 9 | Complete |
| PLAY-01 | Phase 10 | Complete |
| LOAD-01 | Phase 10 | Complete |
| LOAD-03 | Phase 10 | Complete |
| LOAD-05 | Phase 10 | Complete |
| PLAY-02 | Phase 11 | Complete |
| PLAY-03 | Phase 11 | Complete |
| PLAY-04 | Phase 12 | Complete |
| PLAY-05 | Phase 12 | Complete |

### v1.2 (In Progress)

| Requirement | Phase | Status |
|-------------|-------|--------|
| — | — | Pending roadmap |

**Coverage:**
- v1.0 requirements: 35 total (all complete)
- v1.1 requirements: 13 total (all complete)
- v1.2 requirements: 14 total
- Mapped to phases: 0/14 (pending roadmap)
- Unmapped: 14

---
*Requirements defined: 2026-02-01*
*Last updated: 2026-02-08 after v1.2 requirements definition*
