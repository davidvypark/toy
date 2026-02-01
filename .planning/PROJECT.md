# TOY (Thinking Of You)

## What This Is

A group video greeting card app where a host creates a card, invites participants to record short video clips, and publishes a stitched montage for a recipient. Built for iOS in SwiftUI, designed to be simple enough for anyone to use regardless of technical ability.

## Core Value

**Anyone can create a heartfelt group video message in minutes** — no coordination headaches, no editing skills required.

## Requirements

### Validated

- ✓ SwiftUI app structure — existing
- ✓ iOS 18.2+ deployment target — existing
- ✓ Xcode project with test targets — existing

### Active

**Host Flow**
- [ ] Host can create a new card
- [ ] Host can record their own video clip (appears first in montage)
- [ ] Host can invite participants via shareable deep link
- [ ] Host can view all invitees and their submission status
- [ ] Host can preview each submitted clip
- [ ] Host can delete clips from the card
- [ ] Host can preview the full stitched montage
- [ ] Host can finalize and publish the card
- [ ] Host receives shareable link to send to recipient

**Participant Flow**
- [ ] Participant can open invite link (App Clip for low friction)
- [ ] Participant can record video Vine-style (hold to record, release to pause)
- [ ] Participant can record up to 7 seconds total
- [ ] Participant can delete most recent segment
- [ ] Participant can review their recording
- [ ] Participant can submit their clip

**Recipient Flow**
- [ ] Recipient can open link and view final montage
- [ ] Video plays with subtle TOY branding

**Technical**
- [ ] Supabase backend for data and video storage
- [ ] Deep linking for invite flow
- [ ] App Clip for participant recording
- [ ] Video stitching (host first, then chronological by submission)
- [ ] One-time purchase per card
- [ ] Free tier for small groups (~8 participants)

### Out of Scope

- Android version — iOS-first for MVP
- Clip reordering by host — auto-order is sufficient for MVP
- Trimming/editing clips — keep it simple
- Filters/ambience effects — post-MVP feature
- Text overlays on videos — video-only for MVP
- OAuth/social login — simple auth for MVP

## Context

**Existing codebase:** Fresh SwiftUI project with boilerplate structure. No existing functionality beyond app shell.

**Target users:**
- Hosts: People organizing group messages for occasions (birthdays, weddings, get well, congratulations, holidays)
- Participants: Anyone invited, including non-tech-savvy users of all ages
- Recipients: The person receiving the final video message

**Key insight:** The app is event-agnostic. It works for celebrations, sympathy, congratulations, community messages, or anything where multiple people want to say something to one person.

**Branding direction:** Modern, fun, timeless, universal. Not corporate or legacy-feeling. DM Serif Display as primary typeface. Exact terminology for concepts (card, participants, etc.) to be finalized after building.

## Constraints

- **Platform**: iOS only (SwiftUI, iOS 18.2+) — native performance for video recording
- **App Clip size**: 15MB binary limit — may require lower resolution for App Clip recording
- **Video length**: 7 seconds max per clip — keeps montages digestible
- **Storage costs**: Supabase storage pricing — need to monitor and optimize video size/quality
- **Accessibility**: Must work for all ages and technical abilities — simple UX is non-negotiable

## Key Decisions

| Decision | Rationale | Outcome |
|----------|-----------|---------|
| iOS-only MVP | Focus resources, native video recording performance | — Pending |
| Supabase backend | Fast to ship, good Swift SDK, handles storage | — Pending |
| App Clip for participants | Reduces friction for recording | — Pending |
| Auto-order clips (host first, then chronological) | Simplifies host experience | — Pending |
| 7-second max clip length | Keeps montages watchable, reduces storage | — Pending |
| One-time purchase model | Simple, event-based usage pattern | — Pending |
| Free tier ~8 participants | Allows small groups to try before paying | — Pending |

---
*Last updated: 2026-02-01 after initialization*
