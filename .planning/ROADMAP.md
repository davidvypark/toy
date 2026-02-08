# Roadmap: TOY (Thinking Of You)

## Milestones

- v1.0 MVP - Phases 1-8 (shipped 2026-02-02)
- v1.1 Video Playback Quality - Phases 9-12 (shipped 2026-02-07)
- v1.2 Seat-Based Monetization - Phases 13-16 (in progress)

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

<details>
<summary>v1.1 Video Playback Quality (Phases 9-12) - SHIPPED 2026-02-07</summary>

### Phase 9: Quick Playback Wins
**Goal**: Users experience noticeably faster, smoother video playback through targeted behavioral fixes across all existing player views
**Requirements**: LOAD-02, LOAD-04, QUAL-01, QUAL-02, QUAL-03
**Plans**: 3/3 complete

Plans:
- [x] 09-01: Remove percentage text from loading overlays and enable immediate playback start
- [x] 09-02: Change thumbnail generation time to 1.5s and verify audio session
- [x] 09-03: Replace looping pattern with AVPlayerLooper for seamless video loops

### Phase 10: Unified Player & Loading UX
**Goal**: All 4 separate video player implementations are replaced by a single TOYVideoPlayerView with a polished loading experience
**Requirements**: PLAY-01, LOAD-01, LOAD-03, LOAD-05
**Plans**: 3/3 complete

Plans:
- [x] 10-01: Unified TOYVideoPlayerView component
- [x] 10-02: Thumbnail-to-video crossfade transitions
- [x] 10-03: Shimmer loading animation

### Phase 11: Cache Infrastructure
**Goal**: Videos play instantly from disk on re-visit and signed URLs are managed transparently
**Requirements**: PLAY-02, PLAY-03
**Plans**: 2/2 complete

Plans:
- [x] 11-01: Disk video cache with LRU eviction
- [x] 11-02: Signed URL manager with TTL tracking

### Phase 12: Preloading Pipeline
**Goal**: Videos are downloaded in the background before the user navigates to them
**Requirements**: PLAY-04, PLAY-05
**Plans**: 2/2 complete

Plans:
- [x] 12-01: Published card video preloading from home screen
- [x] 12-02: Montage clip pre-download for queue playback

</details>

### v1.2 Seat-Based Monetization (In Progress)

**Milestone Goal:** Implement transparent, GitHub-style seat-based pricing where hosts start free (5 clips) and upgrade based on participant count at publish time -- never blocking participant submissions, never auto-charging

- [x] **Phase 13: Pricing Infrastructure** - CardTier model, RevenueCat multi-product setup, free tier default change, grandfathering
- [x] **Phase 14: Tier Awareness UI** - Tier indicator on card detail showing clip count, tier status, and upgrade path
- [ ] **Phase 15: Checkout & Purchase Flow** - Publish-time tier gate, static tier visualization, purchase recording to Supabase
- [ ] **Phase 16: Cleanup & Verification** - Remove old binary upgrade flow, end-to-end verification of all tier paths

## Phase Details

### Phase 13: Pricing Infrastructure
**Goal**: The app has a complete tier data model and multi-product purchase capability so that all downstream UI can compute tiers and initiate purchases
**Depends on**: Phase 12 (v1.1 complete)
**Requirements**: PRICE-01, PRICE-02, PRICE-05, PURCH-04
**Success Criteria** (what must be TRUE):
  1. A card with 5 or fewer clips shows no pricing UI and can reach the publish flow without any payment interaction
  2. Participants can submit clips to any card regardless of how many clips already exist -- no submission blocking at any count
  3. New cards are created with maxParticipants = 5 (new free tier default)
  4. Existing cards with maxParticipants = 8 continue to function with their original 8-clip free allowance (grandfathered)
  5. PurchaseService can fetch all tier packages from a single RevenueCat offering and each tier product is configured as a consumable IAP
**Plans**: 2 plans

Plans:
- [x] 13-01-PLAN.md — CardTier enum + Card default change + Supabase migration
- [x] 13-02-PLAN.md — PurchaseService multi-tier fetch + deprecation + StoreKit config

### Phase 14: Tier Awareness UI
**Goal**: Hosts always know where their card stands in the tier system -- how many clips they have, what tier that requires, and what it will cost to publish
**Depends on**: Phase 13
**Requirements**: TIER-01, TIER-02
**Success Criteria** (what must be TRUE):
  1. Card detail view shows a tier indicator displaying clip count, current tier status, and cost to publish when the card exceeds the free limit
  2. When a card is within the free tier (5 or fewer clips), no pricing or tier information appears on the card detail view
  3. Host can tap the tier indicator to open a tier selection view and proactively upgrade their card before publish time
**Plans**: 2 plans

Plans:
- [x] 14-01-PLAN.md — TierIndicatorView + ViewModel tier properties + CardDetailView wiring (replace upgrade banner)
- [x] 14-02-PLAN.md — TierSelectionSheet with price display + wire sheet presentation

### Phase 15: Checkout & Purchase Flow
**Goal**: Hosts can publish any card -- free cards publish instantly, paid cards present a clear tier selection with one-tap purchase that records the transaction and proceeds to publish
**Depends on**: Phase 14
**Requirements**: PRICE-03, PRICE-04, TIER-03, TIER-04, PURCH-01, PURCH-02, PURCH-03
**Success Criteria** (what must be TRUE):
  1. When a host taps "Publish" on a card with more clips than their free/purchased tier allows, a checkout sheet appears showing a static tier visualization with their position in the tier range
  2. The checkout auto-selects the cheapest tier that fits the current clip count, and the host can select a higher tier but cannot select one below their clip count
  3. The host explicitly confirms the purchase -- no auto-charges happen at any point in the flow
  4. After successful purchase, the transaction ID and tier are recorded to the card in Supabase, and maxParticipants is updated to the purchased tier's limit
  5. If the publish process fails after payment succeeds, the host can retry publishing without being charged again -- the card retains its purchased tier
**Plans**: 2 plans

Plans:
- [ ] 15-01-PLAN.md — PurchaseService transaction ID exposure + CardService recordTierPurchase method
- [ ] 15-02-PLAN.md — CheckoutSheet view + MontagePreviewView tier gate wiring

### Phase 16: Cleanup & Verification
**Goal**: The old binary upgrade system is fully removed and the new tier system works correctly across all edge cases
**Depends on**: Phase 15
**Requirements**: CLEAN-01
**Success Criteria** (what must be TRUE):
  1. The old CardUpgradeView, binary "upgrade for unlimited" banner, and single-product upgrade flow are completely removed from the codebase
  2. A card with 3 clips publishes for free with no payment interaction
  3. A card with 12 clips presents the checkout, auto-selects the correct tier, completes purchase, and publishes successfully
  4. A card with maxParticipants = 8 (legacy) and 6 clips publishes for free (grandfathered)
  5. A card where publish fails after payment can retry publishing without re-purchasing
**Plans**: TBD

Plans:
- [ ] 16-01: TBD
- [ ] 16-02: TBD

## Progress

**Execution Order:**
Phases execute in numeric order: 13 -> 14 -> 15 -> 16

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
| 9. Quick Playback Wins | v1.1 | 3/3 | Complete | 2026-02-06 |
| 10. Unified Player & Loading UX | v1.1 | 3/3 | Complete | 2026-02-07 |
| 11. Cache Infrastructure | v1.1 | 2/2 | Complete | 2026-02-07 |
| 12. Preloading Pipeline | v1.1 | 2/2 | Complete | 2026-02-07 |
| 13. Pricing Infrastructure | v1.2 | 2/2 | Complete | 2026-02-08 |
| 14. Tier Awareness UI | v1.2 | 2/2 | Complete | 2026-02-08 |
| 15. Checkout & Purchase Flow | v1.2 | 0/2 | Not started | - |
| 16. Cleanup & Verification | v1.2 | 0/TBD | Not started | - |

---
*Roadmap created: 2026-02-01*
*v1.1 roadmap added: 2026-02-06*
*v1.2 roadmap added: 2026-02-08*
*Depth: comprehensive (4 phases for v1.2, 16 total)*
*Coverage: 35/35 v1.0 + 13/13 v1.1 + 14/14 v1.2 requirements mapped*
