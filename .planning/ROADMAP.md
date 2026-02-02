# Roadmap: TOY (Thinking Of You)

## Overview

TOY enables anyone to create heartfelt group video messages in minutes. The roadmap progresses from foundational architecture through the recording pipeline, data layer, host flows, video stitching, App Clip integration, and finally recipient viewing with monetization. Each phase delivers a coherent, verifiable capability that builds toward the complete end-to-end experience of creating, contributing to, and viewing group video cards.

## Phases

**Phase Numbering:**
- Integer phases (1, 2, 3): Planned milestone work
- Decimal phases (2.1, 2.2): Urgent insertions (marked with INSERTED)

Decimal phases appear between their surrounding integers in numeric order.

- [x] **Phase 1: Foundation & Architecture** - Project structure, Supabase setup, theme system ✓
- [x] **Phase 2: Recording Pipeline** - Vine-style video capture with preview and re-record ✓
- [x] **Phase 3: Data Layer & Upload** - Storage, deep linking, video upload with progress ✓
- [x] **Phase 4: Host Card Creation** - Create cards, record host clip, generate invites ✓
- [x] **Phase 5: Host Card Management** - View participants, preview clips, manage submissions ✓
- [x] **Phase 6: Video Stitching & Publishing** - Montage generation, preview, publish to recipient ✓
- [x] **Phase 7: App Clip Integration** - Zero-friction participant recording without app install ✓
- [x] **Phase 8: Recipient Flow & Monetization** - Video viewing, sharing, payments ✓

## Phase Details

### Phase 1: Foundation & Architecture
**Goal**: Establish the technical foundation with clean architecture, reusable components, and backend connectivity
**Depends on**: Nothing (first phase)
**Requirements**: ARCH-01, ARCH-02, ARCH-03, ARCH-04, TECH-01, TECH-02
**Success Criteria** (what must be TRUE):
  1. App launches with themed UI matching brand guidelines (DM Serif Display, modern aesthetic)
  2. Supabase authentication flow works (sign up, sign in, sign out)
  3. Database schema exists for cards, clips, and participants
  4. Shared TOYShared Swift Package compiles for both app and App Clip targets
  5. Reusable button, label, and input components render correctly
**Plans**: 7 plans in 4 waves

Plans:
- [x] 01-01-PLAN.md — Create TOYShared Swift Package (Wave 1)
- [x] 01-02-PLAN.md — Database Schema Design (Wave 1)
- [x] 01-03-PLAN.md — Theme System & Typography (Wave 2)
- [x] 01-04-PLAN.md — Supabase Client & Configuration (Wave 2)
- [x] 01-05-PLAN.md — Reusable UI Components (Wave 3)
- [x] 01-06-PLAN.md — Auth Service Layer (Wave 3)
- [x] 01-07-PLAN.md — Wire & Verify Foundation (Wave 4)

### Phase 2: Recording Pipeline
**Goal**: Users can record 7-second Vine-style video clips with preview and re-record capability
**Depends on**: Phase 1
**Requirements**: PART-02, PART-03, PART-04, PART-05
**Success Criteria** (what must be TRUE):
  1. User can hold to record and release to pause (Vine-style)
  2. Recording automatically stops at 7 seconds total
  3. User can start over and re-record from scratch
  4. User can preview their complete recording before any action
  5. Video outputs as H.264, 720p, 30fps (consistent format)
**Plans**: 6 plans in 4 waves

Plans:
- [x] 02-01-PLAN.md — Core Capture Infrastructure (Wave 1)
- [x] 02-02-PLAN.md — Video Merging & Preview Playback (Wave 1)
- [x] 02-03-PLAN.md — Camera Preview & Permission Config (Wave 2)
- [x] 02-04-PLAN.md — Recording Coordinator (Wave 2)
- [x] 02-05-PLAN.md — Recording UI & ViewModel (Wave 3)
- [x] 02-06-PLAN.md — Wire & Verify Recording Flow (Wave 4)

### Phase 3: Data Layer & Upload
**Goal**: Recorded clips can be uploaded to Supabase storage with progress tracking and deep link support
**Depends on**: Phase 2
**Requirements**: TECH-03, TECH-05, TECH-08, PART-06, PART-07
**Success Criteria** (what must be TRUE):
  1. User can submit their recorded clip and see upload progress indicator
  2. Video files are stored in Supabase storage (clips bucket)
  3. Deep links (Universal Links) open the app to the correct card context
  4. Videos are accessible only via signed URLs (secure access)
  5. Upload completes reliably with retry on failure
**Plans**: 4 plans in 3 waves

Plans:
- [x] 03-01-PLAN.md — Storage Service & Supabase Bucket Setup (Wave 1)
- [x] 03-02-PLAN.md — Deep Link Infrastructure (Wave 1)
- [x] 03-03-PLAN.md — Upload UI & Integration (Wave 2)
- [x] 03-04-PLAN.md — Verify & Human Test (Wave 3)

### Phase 4: Host Card Creation
**Goal**: Hosts can create new cards, record their own clip, and invite participants
**Depends on**: Phase 3
**Requirements**: HOST-01, HOST-02, HOST-03
**Success Criteria** (what must be TRUE):
  1. Host can create a new card from the dashboard
  2. Host can record their own video clip (using Phase 2 recording flow)
  3. Host's clip is marked to appear first in the final montage
  4. Host can generate a shareable invite link for participants
  5. Invite link contains card context for participant routing
**Plans**: 4 plans in 3 waves

Plans:
- [x] 04-01-PLAN.md — Models & CardService (Wave 1)
- [x] 04-02-PLAN.md — Card Creation Form (Wave 2)
- [x] 04-03-PLAN.md — Recording with Card Context (Wave 2)
- [x] 04-04-PLAN.md — Wire Flow & ShareLink (Wave 3)

### Phase 5: Host Card Management
**Goal**: Hosts can view all participants, preview submitted clips, and manage their card
**Depends on**: Phase 4
**Requirements**: HOST-04, HOST-05, HOST-06
**Success Criteria** (what must be TRUE):
  1. Host can view list of all invitees and their submission status
  2. Host can preview each submitted clip individually
  3. Host can delete unwanted clips from the card
  4. Participant list updates to reflect current submissions
**Plans**: 3 plans in 3 waves

Plans:
- [x] 05-01-PLAN.md — CardService Extensions & ParticipantRow (Wave 1)
- [x] 05-02-PLAN.md — CardDetailView & ClipPreviewSheet (Wave 2)
- [x] 05-03-PLAN.md — Wire Navigation & Human Verify (Wave 3)

### Phase 6: Video Stitching & Publishing
**Goal**: Hosts can preview the full stitched montage and publish the final card for recipients
**Depends on**: Phase 5
**Requirements**: HOST-07, HOST-08, HOST-09, TECH-04, TECH-07
**Success Criteria** (what must be TRUE):
  1. Host can preview the full stitched montage (host first, then chronological)
  2. Video stitching produces seamless output with consistent quality
  3. Host can finalize and publish the card
  4. Host receives shareable link to send to the recipient
  5. Final montage is stored in Supabase storage (videos bucket)
**Plans**: 4 plans in 3 waves

Plans:
- [x] 06-01-PLAN.md — Videos Bucket & Service Extensions (Wave 1)
- [x] 06-02-PLAN.md — MontageService & VideoMerger Progress (Wave 1)
- [x] 06-03-PLAN.md — Publishing UI (Wave 2)
- [x] 06-04-PLAN.md — Wire Navigation & Human Verify (Wave 3)

### Phase 7: App Clip Integration
**Goal**: Participants can open invite links and record clips without installing the full app
**Depends on**: Phase 3 (recording + upload must work)
**Requirements**: TECH-06, PART-01
**Success Criteria** (what must be TRUE):
  1. Participant can open invite link via App Clip (no app install required)
  2. App Clip binary is under 15MB (iOS 16+)
  3. Recording flow works identically in App Clip as in main app
  4. Uploaded clips from App Clip appear in host's card management view
  5. App Clip prompts user to get full app after submission
**Plans**: 4 plans in 3 waves

Plans:
- [x] 07-01-PLAN.md — Backend support for unauthenticated card lookup (Wave 1)
- [x] 07-02-PLAN.md — App Clip target setup (Wave 1)
- [x] 07-03-PLAN.md — App Clip entry point and recording flow (Wave 2)
- [x] 07-04-PLAN.md — Upload success view and human verification (Wave 3)

### Phase 8: Recipient Flow & Monetization
**Goal**: Recipients can view final videos and hosts can purchase card upgrades
**Depends on**: Phase 6
**Requirements**: RCPT-01, RCPT-02, RCPT-03, RCPT-04, MNTZ-01, MNTZ-02, TECH-09
**Success Criteria** (what must be TRUE):
  1. Recipient can open link and view the final montage
  2. Video auto-plays when recipient opens the link
  3. Video displays with subtle TOY branding
  4. Recipient can reshare video to social media
  5. Host can purchase per-card upgrades via RevenueCat
  6. Free tier works for cards with 8 or fewer participants
**Plans**: 6 plans in 3 waves

Plans:
- [x] 08-01-PLAN.md — Next.js web project setup with Supabase (Wave 1)
- [x] 08-02-PLAN.md — Video viewer page with branding and social sharing (Wave 2)
- [x] 08-03-PLAN.md — RevenueCat SDK setup and PurchaseService (Wave 1)
- [x] 08-04-PLAN.md — Upgrade UI and free tier enforcement (Wave 2)
- [x] 08-05-PLAN.md — PostHog analytics integration (Wave 1) — removed, using DB timestamps
- [x] 08-06-PLAN.md — Human verification of recipient flow and monetization (Wave 3)

## Progress

**Execution Order:**
Phases execute in numeric order: 1 -> 2 -> 3 -> 4 -> 5 -> 6 -> 7 -> 8

| Phase | Plans Complete | Status | Completed |
|-------|----------------|--------|-----------|
| 1. Foundation & Architecture | 7/7 | Complete | 2026-02-01 |
| 2. Recording Pipeline | 6/6 | Complete | 2026-02-02 |
| 3. Data Layer & Upload | 4/4 | Complete | 2026-02-02 |
| 4. Host Card Creation | 4/4 | Complete | 2026-02-02 |
| 5. Host Card Management | 3/3 | Complete | 2026-02-02 |
| 6. Video Stitching & Publishing | 4/4 | Complete | 2026-02-02 |
| 7. App Clip Integration | 4/4 | Complete | 2026-02-02 |
| 8. Recipient Flow & Monetization | 6/6 | Complete | 2026-02-02 |

---
*Roadmap created: 2026-02-01*
*Depth: comprehensive (8 phases)*
*Coverage: 35/35 v1 requirements mapped*
