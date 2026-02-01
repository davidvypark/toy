# Project Research Summary

**Project:** TOY - Group Video Greeting Card App
**Domain:** iOS Mobile Application (Social/Video)
**Researched:** 2026-02-01
**Confidence:** HIGH

## Executive Summary

TOY is a group video greeting card iOS app positioned as "the Vine of greeting cards" - fast, fun, and frictionless. The research reveals a clear technical path: native iOS with SwiftUI, Supabase backend, and App Clip integration for zero-friction participant recording. The market is divided between video-first apps (Tribute, VidDay) that offer complex editing and card-first apps (Kudoboard) with mixed media. TOY's unique positioning is radical simplification: 7-second Vine-style clips, zero editing, and App Clip-based recording that eliminates the install barrier.

The recommended architecture is MVVM with a shared Swift Package for code reuse between the main app and App Clip. Server-side video stitching (using Mux or FFmpeg) is preferred over client-side to ensure consistent quality and reduce battery drain. The tech stack centers on iOS 17+ (for @Observable and modern SwiftUI), AVFoundation for video capture, and Supabase for backend services (auth, database, storage, realtime). StoreKit 2 handles monetization via per-card purchases.

Critical risks include App Clip binary size limits (15MB on iOS 15, 50MB on iOS 16+), video format inconsistencies causing stitching failures, and memory exhaustion during recording or composition. Mitigation strategies are well-documented: aggressive asset optimization for App Clips, enforcing consistent H.264 720p output, and sequential clip processing with autorelease pools. The research provides high confidence in both the technical approach and the ability to avoid common pitfalls through careful implementation.

## Key Findings

### Recommended Stack

The stack prioritizes Apple's native frameworks and Supabase as the backend-as-a-service platform. This combination minimizes dependencies, reduces complexity, and leverages mature, well-documented technologies. The decision to use iOS 17.0 as the minimum target (85%+ market adoption) enables modern SwiftUI features like @Observable and improved camera APIs while maintaining broad compatibility.

**Core technologies:**
- **SwiftUI (iOS 17+)**: Declarative UI with @Observable state management - Apple's first-party framework has reached production maturity and eliminates the boilerplate of UIKit/Storyboards
- **AVFoundation**: Video capture and processing - Native framework ensures best performance, battery efficiency, and full control over recording configuration (critical for consistent output)
- **Supabase (Swift SDK 2.x)**: Backend services (auth, database, storage, realtime) - Open-source alternative to Firebase with better developer experience, PostgreSQL flexibility, and simpler pricing
- **StoreKit 2**: In-app purchases - Modern async/await API for per-card monetization, eliminating the complexity of StoreKit 1's callback-based approach
- **App Clips**: Zero-install participant recording - Removes the largest friction point in group video card creation by enabling instant contributions without App Store downloads

**Critical version requirements:**
- iOS 17.0 minimum (for @Observable, stable SwiftUI, modern camera APIs)
- Swift 5.10+ (improved concurrency, type safety)
- supabase-swift 2.x (Swift Concurrency support)

### Expected Features

TOY's feature set is deliberately minimal compared to competitors, focusing on speed and simplicity over comprehensive editing capabilities. The "7-second Vine-style clip" is the core differentiator that drives all other feature decisions.

**Must have (table stakes):**
- Card creation with occasion selection - Basic CRUD that every competitor offers
- Shareable invite links (Universal Links) - Enable participants to join without app install
- App Clip participant recording - Zero-friction contribution (critical competitive advantage)
- Vine-style hold-to-record (7 sec max) - Intuitive recording with automatic duration enforcement
- Host preview and delete capability - Review all submissions and remove inappropriate content
- Basic video stitching (host first, chronological) - Combine clips into single montage with simple ordering
- Publish and share to recipient - Generate final video and shareable link
- Recipient video playback - Full-screen viewing with standard controls

**Should have (differentiators):**
- Progress indicator for host (X of Y clips received) - Visibility into card completion status
- Simple transitions between clips (crossfade) - Professional feel without complexity
- Download option for recipient - Let recipients keep the video forever
- QR code generation for physical sharing - Enable in-person distribution (e.g., at events)

**Defer (v2+):**
- Reminder notifications for non-submitters - Increases completion rates but adds complexity
- Music overlay on final video - Common in competitors but requires licensing infrastructure
- Themes/templates per occasion - Visual customization that can wait for product-market fit
- Participant analytics (who opened, who viewed) - Useful data but not essential for core flow
- Social sharing integrations - Nice-to-have once core experience is solid

**Anti-features (never build):**
- Video trimming/editing - If users need to trim, the 7-second limit failed; adds unwanted complexity
- Clip reordering by host - Decision fatigue; auto-ordering (host first, then chronological) is simpler
- Filters/effects on recording - Bloats App Clip binary; keep recording authentic and simple
- Required account for participants - Conversion killer; App Clip enables anonymous contributions

### Architecture Approach

MVVM over The Composable Architecture (TCA) is the right choice for TOY's scope. TCA's ceremony (reducers, effects, stores) benefits apps with complex state interactions, but TOY has relatively isolated flows (Host creates, Participant records, Recipient views). MVVM maps naturally to SwiftUI, has no additional dependencies, and enables faster iteration for MVP. The critical architectural decision is the shared Swift Package strategy for App Clip code reuse.

**Major components:**
1. **TOYCore Swift Package** - Shared models, services, and utilities between main app and App Clip; keeps business logic DRY while enabling independent targets
2. **Recording Pipeline (AVFoundation)** - CameraService manages AVCaptureSession; RecordingViewModel implements Vine-style state machine; segments written directly to disk (not memory) to prevent crashes
3. **Supabase Integration Layer** - Repository pattern for Cards, Clips, Participants; StorageService for video upload/download with signed URLs; RealtimeService for live updates to host dashboard
4. **Deep Link Coordinator** - Handles Universal Links and custom URL schemes; routes to correct flow (participant record, host manage, recipient view); critical for App Clip invocation
5. **Video Stitching Service** - Client-side concatenation using AVMutableComposition for simple cases; server-side fallback (Mux or FFmpeg) for reliability and advanced features

**Key architectural patterns:**
- State management: @Observable for feature-level state, @State for view-local UI, @EnvironmentObject for app-wide state (auth, user)
- Navigation: Deep link-driven with NavigationStack; coordinator pattern handles URL parsing and routing
- Data flow: View → ViewModel → Service → Supabase; async/await throughout
- Code sharing: Swift Package linked to both main app and App Clip targets; conditional compilation with `#if APPCLIP` for target-specific code

### Critical Pitfalls

Research identified 8 major pitfall categories; the top 5 are critical for MVP success.

1. **Memory exhaustion during recording** - Recording video directly to memory crashes older iPhones; use AVAssetWriter configured for fragmented movie output, write to disk, and implement hard 7-second duration limit; failure to address this causes "recording stopped unexpectedly" reports and App Store reviews about instability

2. **App Clip binary size exceeding 15MB** - App Clips have strict size limits (15MB on iOS 15, 50MB on iOS 16+); use SF Symbols instead of custom icons, conditional compilation to exclude main-app-only features, asset catalogs with App Clip-specific assets; measure thinned binary size with every build; exceeding the limit means App Store rejection and no App Clip functionality

3. **Video format inconsistencies causing stitching failures** - Different iOS versions produce different codecs (HEVC vs H.264) and resolutions; enforce consistent output at recording time (H.264, 720p, 30fps, portrait) and validate uploads server-side; ignoring this results in black screens, glitches at transitions, and letterboxing in final videos

4. **Supabase storage costs spiraling** - Uncompressed 4K video quickly exhausts storage quotas (a single 7-second 4K clip is 30-50MB); compress before upload (720p, 2Mbps target = ~2MB per clip), set maximum file size limits in storage policies, implement retention policies to delete raw clips after final video generation; failure to control this causes budget overruns

5. **Universal Links not working reliably** - App Clip invocation fails silently if AASA file is misconfigured or DNS isn't propagated; validate with Apple's AASA validator, ensure correct Content-Type, no redirects, and host at `.well-known/apple-app-site-association`; broken links mean participants can't join, defeating the core value proposition

**Additional critical pitfalls:**
- Camera permission denial without recovery path - Pre-flight checks and "Open Settings" deep link required
- Memory crash during multi-clip composition - Process clips sequentially with autorelease pools, not all at once
- Large video upload failures - Implement chunked upload with retry logic and progress tracking
- No clip preview/retake flow - Users need to review before submitting; always offer retakes

## Implications for Roadmap

Based on research, the suggested phase structure prioritizes establishing the full end-to-end flow before adding complexity. The architecture reveals clear dependencies: recording must work before uploading, data layer must exist before host management, and App Clip requires solid recording + data layers.

### Phase 1: Foundation & Recording Pipeline
**Rationale:** Recording is the core mechanic and most technically complex component. Building this first validates feasibility and establishes the quality baseline for all videos. The Vine-style hold-to-record state machine is unique to TOY and requires careful tuning. Foundation (TOYCore package, Supabase setup, deep linking) must be in place to support all future work.

**Delivers:**
- TOYCore Swift Package structure
- Supabase integration (auth, database schema)
- AVFoundation recording pipeline with Vine-style controls
- Camera permissions handling
- Video preview and retake flow
- Consistent video output (H.264, 720p, 30fps)

**Addresses features:**
- Record video (table stakes)
- Preview before submit (table stakes)
- Re-record option (table stakes)
- Vine-style recording (core differentiator)
- 7-second limit per clip (core differentiator)

**Avoids pitfalls:**
- Memory exhaustion during recording (write to disk, not memory)
- Camera permission denial (pre-flight checks)
- Video format inconsistencies (enforce consistent settings)

**Research flag:** Standard patterns for AVFoundation; well-documented APIs; skip additional research

---

### Phase 2: Data Layer & Upload
**Rationale:** Once recording works, participants need to upload clips to cards. This phase implements the Supabase repositories, storage service, and upload flow. Deep link handling is required for App Clip invocation. This phase establishes the data model and backend integration that all future features depend on.

**Delivers:**
- CardRepository, ClipRepository implementations
- StorageService with chunked upload and progress tracking
- Deep link URL parsing and routing
- Universal Links AASA file configuration
- Video compression before upload
- Upload retry logic and offline queueing

**Addresses features:**
- Submit clip (table stakes)
- Confirmation of submission (table stakes)
- Shareable invite links (table stakes)
- Progress indicators (technical table stakes)

**Avoids pitfalls:**
- Large video upload failures (chunked upload, retry logic)
- Supabase storage costs (compress to ~2MB per clip)
- Universal Links not working (AASA validation)
- Deep link state restoration failures (store card context immediately)

**Research flag:** Standard REST/SDK patterns; skip additional research

---

### Phase 3: Host Flow & Card Management
**Rationale:** With recording and upload working, hosts need to create cards, invite participants, and manage submissions. This phase completes the creation side of the marketplace. Video stitching is introduced here to enable final montage generation.

**Delivers:**
- Host dashboard (card list, create card)
- Invite generation with shareable links
- Card management (view submissions, preview clips, delete clips)
- Video stitching service (client-side with AVMutableComposition)
- Final montage preview
- Publish/finalize card

**Addresses features:**
- Create card/project (table stakes)
- Add occasion/event type (table stakes)
- Invite via shareable link (table stakes)
- View participant list (table stakes)
- Preview individual clips (table stakes)
- Delete/remove clips (table stakes)
- Preview final montage (table stakes)
- Publish/finalize card (table stakes)
- Auto-ordering (core differentiator)
- No editing required (core differentiator)

**Avoids pitfalls:**
- Memory crash during multi-clip composition (sequential processing, autorelease pools)
- Audio/video sync drift (normalize audio format)
- Export appears frozen (progress UI, background task)

**Research flag:** AVFoundation composition is complex; may need `/gsd:research-phase` for advanced stitching techniques if simple concatenation has issues

---

### Phase 4: App Clip Integration
**Rationale:** App Clip is the key differentiator (zero-friction participant recording) but requires phases 1-2 to be solid. Building the App Clip target involves code extraction to TOYCore package, binary size optimization, and testing the participant flow in isolation.

**Delivers:**
- App Clip target configuration
- Shared code via TOYCore package
- Streamlined participant recording flow
- Binary size optimization (SF Symbols, conditional compilation)
- Universal Link handling in App Clip
- Anonymous contribution support
- "Get the full app" prompt post-submission

**Addresses features:**
- Open invite without app install (table stakes, critical differentiator)
- App Clip for participants (core differentiator)

**Avoids pitfalls:**
- App Clip binary size exceeding 15MB (aggressive optimization, measure every build)
- Limited API availability in App Clips (conditional compilation)
- App Clip session expiration (upload immediately, no local storage reliance)
- Confusing App Clip vs full app (clear banner, data transfer on install)

**Research flag:** App Clip best practices and size optimization may need additional research if approaching limits

---

### Phase 5: Recipient Flow & Polish
**Rationale:** With the creation and contribution flows complete, recipients need a great viewing experience. This phase adds the final video playback, sharing, and optional monetization via StoreKit 2.

**Delivers:**
- Recipient video player (full-screen, scrubbing, replay)
- Share functionality (link, QR code)
- Download option for recipient
- StoreKit 2 integration for per-card purchases
- Transaction verification and restore
- Performance optimization (video compression tuning, memory management)

**Addresses features:**
- View final video (table stakes)
- Full-screen playback (table stakes)
- Replay/scrub video (table stakes)
- Share with recipient (table stakes)
- QR code generation (should have)
- Download final video (should have)

**Avoids pitfalls:**
- Video playback stuttering (HLS streaming or progressive download)
- StoreKit 2 transaction verification failures (handle both verified and unverified)
- No offline handling (queue uploads, local storage until confirmed)

**Research flag:** Standard AVPlayer and StoreKit 2 patterns; skip additional research

---

### Phase 6: Realtime Updates & Engagement (Optional for MVP)
**Rationale:** After core functionality is stable, realtime updates improve the host experience by showing new submissions as they arrive. This phase is optional for MVP and can be deferred if timeline is tight.

**Delivers:**
- Supabase Realtime subscriptions for card updates
- Host dashboard live updates (new clip notifications)
- Participant analytics (who opened link, who viewed, who submitted)
- Progress indicator for host (X of Y clips received)

**Addresses features:**
- Progress indicator for host (should have)
- Participant analytics (post-MVP)

**Research flag:** Supabase Realtime API is straightforward; skip additional research

---

### Phase Ordering Rationale

The phase order follows a clear dependency graph:
- **Phase 1 (Foundation & Recording)** establishes the core mechanic and technical foundation; everything depends on this working reliably
- **Phase 2 (Data Layer & Upload)** connects recording to backend; enables participants to contribute
- **Phase 3 (Host Flow)** completes the creation side; enables hosts to orchestrate cards
- **Phase 4 (App Clip)** is the key differentiator but requires solid recording and upload flows
- **Phase 5 (Recipient Flow)** completes the full user journey; adds monetization
- **Phase 6 (Realtime)** is polish that can be deferred if needed

This ordering avoids premature optimization (App Clip before recording works), prevents rework (data model before upload logic), and maintains focus on critical path (end-to-end flow before engagement features).

### Research Flags

**Phases likely needing deeper research during planning:**
- **Phase 3 (Video Stitching):** AVFoundation composition for multi-clip montages can be complex; if simple concatenation has audio sync or transition issues, may need `/gsd:research-phase` to investigate advanced techniques
- **Phase 4 (App Clip Optimization):** If binary size approaches limits, may need research on aggressive size reduction techniques beyond standard practices

**Phases with standard patterns (skip research-phase):**
- **Phase 1 (Recording):** AVFoundation capture is well-documented; standard Vine-style state machine
- **Phase 2 (Data Layer):** Repository pattern and Supabase SDK are straightforward
- **Phase 5 (Recipient Flow):** AVPlayer and StoreKit 2 have mature APIs and extensive documentation
- **Phase 6 (Realtime):** Supabase Realtime API is simple for basic subscriptions

## Confidence Assessment

| Area | Confidence | Notes |
|------|------------|-------|
| Stack | HIGH | Native iOS frameworks (SwiftUI, AVFoundation) are mature and well-documented; Supabase Swift SDK 2.x has strong community support; all recommendations verified against official docs |
| Features | HIGH | Analyzed 6 competitors (Tribute, Kudoboard, VidDay, Memento, GroupGreeting, Punchbowl); feature set is deliberately minimal and well-scoped; table stakes clearly identified |
| Architecture | HIGH | MVVM is the standard pattern for SwiftUI; App Clip code-sharing strategy is documented by Apple; repository pattern for Supabase is common practice |
| Pitfalls | HIGH | Pitfalls derived from known iOS limitations (App Clip size, AVFoundation memory usage), Supabase constraints, and competitor analysis; mitigation strategies are concrete and testable |

**Overall confidence:** HIGH

The research combines official Apple documentation (SwiftUI, AVFoundation, App Clips, StoreKit 2), Supabase official docs and community best practices, and competitive analysis of established products. The recommended approach is conservative (proven technologies) while the differentiation is clear (Vine-style recording, App Clip, radical simplification). There are no experimental dependencies or untested patterns.

### Gaps to Address

While confidence is high, several areas need validation during implementation:

- **App Clip binary size:** Theory says 15MB (iOS 15) or 50MB (iOS 16+) is achievable, but real-world measurement required with every build; asset optimization is iterative
- **Video stitching quality:** Simple AVMutableComposition may have edge cases (different device codecs, orientation issues); server-side fallback provides insurance
- **Supabase Swift SDK maturity:** 2.x is production-ready but newer than Firebase; community smaller; monitor for edge cases and be prepared to use REST API fallback
- **Realtime subscription scalability:** Unclear how Supabase Realtime performs with many concurrent card creations; may need throttling or polling fallback
- **StoreKit 2 transaction verification:** Apple's server-to-server notifications are recommended but add complexity; start with client-side verification, add server validation before launch

**How to handle:**
- Track App Clip binary size in CI; fail builds that exceed 80% of limit
- Implement comprehensive logging for video stitching; build fallback to server-side early
- Create abstraction layer for Supabase calls; enables switching to REST if SDK has issues
- Load test Realtime subscriptions in staging before launch
- Implement both client and server-side receipt validation for production

## Sources

### Primary (HIGH confidence)
- **Apple Developer Documentation** - SwiftUI, AVFoundation, App Clips, StoreKit 2, Universal Links (official APIs and best practices)
- **Supabase Official Docs** - supabase-swift SDK, authentication, storage, realtime, database patterns
- **App Store Connect Guidelines** - App Clip size limits, submission requirements, IAP policies

### Secondary (MEDIUM confidence)
- **Competitor Analysis** - Tribute, Kudoboard, VidDay, Memento, GroupGreeting, Punchbowl (feature analysis via app exploration and public materials)
- **iOS Developer Community** - Stack Overflow, Apple Developer Forums (AVFoundation best practices, App Clip optimization techniques)
- **Supabase Community** - GitHub issues, Discord, blog posts (Swift SDK edge cases, production deployment patterns)

### Tertiary (LOW confidence, needs validation)
- **Estimated costs** - Supabase and Mux pricing projections based on assumed usage; requires actual measurement post-launch
- **Market adoption of iOS 17** - Estimated 85%+ adoption by early 2026; verify with latest Apple stats before finalizing minimum version
- **Video stitching latency** - Server-side processing estimates (30s-5min) based on general FFmpeg benchmarks; actual performance depends on infrastructure choice

---
*Research completed: 2026-02-01*
*Ready for roadmap: yes*
