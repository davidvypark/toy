# Features Research: Group Video Greeting Card Apps

## Research Summary

**Apps Analyzed**: Tribute, Kudoboard, VidDay, Memento, GroupGreeting, Punchbowl
**Focus**: iOS group video greeting card app (TOY - Thinking Of You)
**Date**: 2026-02-01

### Key Insight

The group video greeting card market splits into two camps:
1. **Video-first** (Tribute, VidDay, Memento): Focus on video montage creation with professional editing
2. **Card-first** (Kudoboard, GroupGreeting): Focus on digital cards with video as one media type among many

TOY's positioning (simple, fast, Vine-style clips) is closest to video-first but with radical simplification.

---

## Table Stakes Features

*Must have or users leave. Users expect these based on competitor products.*

### Host Features

| Feature | Complexity | Dependencies | Notes |
|---------|------------|--------------|-------|
| **Create card/project** | Low | Auth, DB | Basic CRUD. Every competitor has this. |
| **Add occasion/event type** | Low | Create card | Birthday, wedding, retirement, etc. Templates optional. |
| **Invite via shareable link** | Medium | Deep linking | Universal links required. SMS/email sharing. |
| **View participant list** | Low | Invites | Who's invited, who submitted. |
| **Preview individual clips** | Low | Video storage | Must see what participants sent. |
| **Delete/remove clips** | Low | Preview clips | Remove inappropriate content. |
| **Preview final montage** | Medium | Video stitching | See before publishing. |
| **Publish/finalize card** | Low | Preview montage | Lock edits, generate recipient link. |
| **Share with recipient** | Low | Publish | Generate link/QR code for recipient. |

### Participant Features

| Feature | Complexity | Dependencies | Notes |
|---------|------------|--------------|-------|
| **Open invite without app install** | High | App Clip or web | Critical for conversion. App Clip ideal for iOS. |
| **Record video** | Medium | Camera permissions | Core functionality. |
| **Preview before submit** | Low | Record video | See what you're sending. |
| **Re-record option** | Low | Preview | Fix mistakes before submitting. |
| **Submit clip** | Low | Video upload | Upload to host's card. |
| **Confirmation of submission** | Low | Submit clip | Know it worked. |

### Recipient Features

| Feature | Complexity | Dependencies | Notes |
|---------|------------|--------------|-------|
| **View final video** | Medium | Video playback | Core delivery. Web or app. |
| **Full-screen playback** | Low | Video player | Standard expectation. |
| **Replay/scrub video** | Low | Video player | Basic video controls. |

### Technical Table Stakes

| Feature | Complexity | Dependencies | Notes |
|---------|------------|--------------|-------|
| **Video compression** | Medium | Upload flow | Keep file sizes manageable. |
| **Progress indicators** | Low | Upload/download | Show upload/download progress. |
| **Error handling** | Medium | All flows | Graceful failures, retry options. |
| **Offline detection** | Low | Network layer | Alert user when offline. |
| **Basic video stitching** | High | All clips uploaded | Combine clips into single video. |

---

## Differentiators

*Competitive advantages that set apps apart.*

### Category A: Experience Differentiators

| Feature | Complexity | Dependencies | TOY Relevance | Notes |
|---------|------------|--------------|---------------|-------|
| **Vine-style recording** | Medium | Camera | **Core differentiator** | Hold-to-record is more intuitive than tap start/stop. |
| **7-second limit per clip** | Low | Recording | **Core differentiator** | Forces concise, watchable content. VidDay allows 3+ minutes. |
| **Auto-ordering** | Low | Multiple clips | **Core differentiator** | Host first, then chronological. Removes complexity. |
| **No editing required** | — | — | **Core differentiator** | Deliberate omission. Competitors offer trim, filters, music. |
| **App Clip for participants** | High | iOS ecosystem | **Core differentiator** | Zero friction recording. Most competitors require web or app. |

### Category B: Engagement Differentiators

| Feature | Complexity | Dependencies | TOY Relevance | Notes |
|---------|------------|--------------|---------------|-------|
| **Reminder notifications** | Medium | Push infrastructure | Post-MVP | Nudge non-submitters. Tribute does this well. |
| **Deadline countdown** | Low | Card settings | Post-MVP | Creates urgency for participants. |
| **Live preview for host** | Medium | Real-time updates | Post-MVP | See montage build as clips arrive. |
| **Participant analytics** | Low | Tracking | Post-MVP | Who opened link, who viewed, who submitted. |

### Category C: Content Enhancement (Competitors)

| Feature | Complexity | Dependencies | TOY Relevance | Notes |
|---------|------------|--------------|---------------|-------|
| **Music/soundtrack overlay** | High | Audio library, licensing | Post-MVP | Tribute, VidDay prominent feature. |
| **Transitions between clips** | Medium | Video processing | Post-MVP | Professional feel. Most competitors have. |
| **Photo slideshow option** | Medium | Image processing | Not for MVP | Kudoboard strength. Video-only for TOY. |
| **Text/GIF cards** | Medium | Content types | Not for MVP | Kudoboard/GroupGreeting. TOY is video-only. |
| **Themes/templates** | Medium | Design system | Post-MVP | Visual customization per occasion. |

### Category D: Distribution Differentiators

| Feature | Complexity | Dependencies | TOY Relevance | Notes |
|---------|------------|--------------|---------------|-------|
| **QR code generation** | Low | Publish | Consider | Easy physical sharing (e.g., at event). |
| **Download final video** | Low | Video storage | Consider | Let recipient keep forever. |
| **Physical product option** | High | Fulfillment | Not for MVP | Tribute offers USB/DVD. Niche but memorable. |
| **Social sharing** | Low | Share sheet | Consider | Share to Instagram, TikTok, etc. |

---

## Anti-Features

*Things to deliberately NOT build. Complexity traps or user experience killers.*

### Complexity Traps

| Anti-Feature | Why Avoid | Competitors Who Have It | Notes |
|--------------|-----------|------------------------|-------|
| **Video trimming/editing** | Scope creep, complexity for non-tech users | VidDay, Tribute | If users need to trim, the 7-sec limit failed. |
| **Clip reordering by host** | Decision fatigue, rarely used | Tribute, VidDay | Auto-order is sufficient. |
| **Filters/effects on recording** | App size bloat, distraction | Snapchat-style apps | Keep recording simple and authentic. |
| **Multi-recipient cards** | Complex permissions, confusing UX | None prominently | One card = one recipient. |
| **Collaborative host permissions** | Auth complexity, edge cases | Kudoboard (premium) | Single host is simpler. |
| **Comment/reaction systems** | Social features creep | Kudoboard | This isn't social media. |
| **Draft auto-save complexity** | Sync conflicts, confusion | Various | Simple: recorded or not recorded. |

### UX Killers

| Anti-Feature | Why Avoid | Competitors Who Have It | Notes |
|--------------|-----------|------------------------|-------|
| **Required account for participants** | Conversion killer | Older apps | App Clip = no account needed. |
| **Long onboarding flows** | Drop-off | Various | Get to recording in < 30 seconds. |
| **Mandatory tutorials** | Frustrating | Legacy apps | Interface should be self-evident. |
| **Upsell interruptions** | Trust-breaking | Freemium apps | Price clear upfront, no surprises. |
| **Watermarks on free tier** | Cheap feeling | Some competitors | Undermines the gift. |

### Premature Optimization

| Anti-Feature | Why Avoid | Notes |
|--------------|-----------|-------|
| **Android version** | Split focus | iOS-first for MVP. |
| **Real-time collaboration** | Unnecessary complexity | Video contributions are async by nature. |
| **AI-powered editing** | Trend-chasing | Simple is the feature. |
| **Enterprise/team features** | Different market | Consumer-focused only. |
| **Subscription model** | Doesn't match usage | Per-card purchase fits better. |

---

## Feature Dependencies Map

```
Card Creation
    └── Invite Generation (deep links)
            └── Participant Recording (App Clip)
                    └── Video Upload
                            └── Host Preview
                                    └── Video Stitching
                                            └── Final Preview
                                                    └── Publish
                                                            └── Recipient View
```

**Critical Path**: Every feature depends on the previous. No shortcuts.

**Parallel Development Possible**:
- Recording UI (App Clip) can be developed alongside backend
- Recipient view can be developed alongside stitching
- Host dashboard can be developed alongside participant flow

---

## Competitive Positioning Matrix

| Feature | Tribute | Kudoboard | VidDay | Memento | TOY (Target) |
|---------|---------|-----------|--------|---------|--------------|
| **Primary Medium** | Video | Mixed | Video | Video | Video |
| **Recording Style** | Standard | Web-based | Standard | Standard | Vine-style |
| **Clip Length** | 3 min | Varies | 3 min | Varies | 7 sec |
| **Editing Required** | Yes | No | Yes | Yes | No |
| **Music Library** | Yes | No | Yes | Yes | No (MVP) |
| **Participant Friction** | Medium | Low | Medium | High | Very Low |
| **Price Model** | Per video | Tiered | Per video | Per video | Per card |
| **Physical Products** | Yes | No | No | Yes | No |

### TOY's Unique Position

**"The Vine of group greeting cards"** — Fast, fun, frictionless.

- Shortest clips in market = most watchable montages
- Lowest participant friction = highest completion rates
- No editing = accessible to everyone
- App Clip = zero install barrier

---

## Recommendations for TOY MVP

### Must Build (Table Stakes)
1. Card creation with occasion selection
2. Shareable invite links (universal links)
3. App Clip participant recording
4. Vine-style hold-to-record (7 sec max)
5. Host preview of all clips
6. Host delete capability
7. Basic video stitching (host first, then chronological)
8. Final montage preview
9. Publish and share to recipient
10. Recipient web/app playback

### Should Build (Differentiators)
1. Progress indicator for host (X of Y clips received)
2. Simple transitions between clips (crossfade)
3. Download option for recipient
4. QR code for physical sharing

### Defer to Post-MVP
1. Reminder notifications
2. Music overlay
3. Themes/templates
4. Participant analytics
5. Social sharing integrations

### Never Build
1. Video trimming/editing
2. Clip reordering
3. Filters/effects
4. Multi-recipient cards
5. Collaborative hosting
6. Comment/reaction features
7. Watermarks

---

## Open Questions

1. **Transition style**: Should clips hard-cut or crossfade? (Recommend: subtle crossfade)
2. **Branding placement**: How prominent should TOY branding be on final video? (Recommend: small watermark at end only)
3. **Clip audio**: Should clips have audio by default or muted? (Recommend: audio on, user's voice is the content)
4. **Expiration**: Should cards expire? (Recommend: no expiration, but warn about storage costs)
5. **Re-submission**: Can participants re-submit after initial submission? (Recommend: yes, until host finalizes)

---

*Research based on market analysis of Tribute, Kudoboard, VidDay, Memento, GroupGreeting, and Punchbowl. Last updated: 2026-02-01*
