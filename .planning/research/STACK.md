# TOY - Technology Stack Research

> **Research Type:** Project Research - Stack Dimension
> **Milestone:** Greenfield iOS App
> **Last Updated:** 2026-02-01
> **Confidence Levels:** HIGH (90%+) | MEDIUM (70-89%) | LOW (<70%)

---

## Executive Summary

This document defines the recommended 2025/2026 technology stack for TOY, a group video greeting card iOS app. The stack prioritizes native SwiftUI, Apple's first-party frameworks for video handling, and Supabase for backend services.

**Core Architecture:** Native iOS (SwiftUI) + Supabase BaaS + Server-side video processing

---

## 1. iOS Application Layer

### 1.1 UI Framework

| Component | Recommendation | Version | Confidence |
|-----------|---------------|---------|------------|
| **UI Framework** | SwiftUI | iOS 17+ (target iOS 17.0 minimum) | HIGH |
| **Swift Version** | Swift 5.10+ | Xcode 15.3+ | HIGH |
| **Minimum iOS** | iOS 17.0 | - | HIGH |

**Rationale:**
- SwiftUI is Apple's declarative UI framework and has reached production maturity as of iOS 17
- iOS 17+ provides stable SwiftUI lifecycle, improved animations, and better camera/video APIs
- iOS 17 adoption is ~85%+ by early 2026, making it a safe minimum target
- Swift 5.10 includes improved concurrency and type safety features

**What NOT to use:**
- UIKit as primary framework: SwiftUI handles all TOY's UI requirements; UIKit wrappers only where SwiftUI lacks capability (camera preview)
- Storyboards/XIBs: Entirely deprecated for new projects; SwiftUI is declarative and more maintainable
- iOS 16 or lower: Missing critical SwiftUI improvements and camera APIs

### 1.2 Architecture Pattern

| Component | Recommendation | Confidence |
|-----------|---------------|------------|
| **Architecture** | MVVM with SwiftUI | HIGH |
| **State Management** | @Observable (Observation framework) | HIGH |
| **Dependency Injection** | Swift native (Environment/EnvironmentObject) | HIGH |
| **Navigation** | NavigationStack (iOS 16+) | HIGH |

**Rationale:**
- @Observable (iOS 17+) replaces @ObservableObject with better performance and simpler syntax
- MVVM maps naturally to SwiftUI's declarative model
- NavigationStack provides type-safe, programmatic navigation superior to NavigationView

**What NOT to use:**
- @ObservableObject/@StateObject: Deprecated pattern; @Observable is the modern replacement
- Combine for simple state: @Observable handles most cases; Combine only for complex async streams
- Third-party DI frameworks (Swinject, etc.): Unnecessary complexity for this app size
- NavigationView: Deprecated; use NavigationStack

---

## 2. Video Recording & Processing

### 2.1 Video Capture (Vine-style hold-to-record)

| Component | Recommendation | Version | Confidence |
|-----------|---------------|---------|------------|
| **Camera Framework** | AVFoundation | Native (iOS 17+) | HIGH |
| **Video Format** | H.264/HEVC | - | HIGH |
| **Resolution** | 1080p (1920x1080) | - | HIGH |
| **Max Duration** | 7 seconds | - | HIGH |
| **Frame Rate** | 30 fps | - | HIGH |

**Implementation Approach:**
```swift
// Core components needed:
- AVCaptureSession for camera pipeline
- AVCaptureMovieFileOutput for recording
- Custom SwiftUI wrapper using UIViewControllerRepresentable
- Long-press gesture recognizer for hold-to-record
```

**Rationale:**
- AVFoundation is Apple's mature, full-featured video framework
- Native framework ensures best performance and battery efficiency
- H.264 for compatibility, HEVC for smaller file sizes (device-dependent)
- 1080p balances quality with file size for mobile upload
- 7 seconds at 1080p/30fps = ~15-25MB depending on content

**What NOT to use:**
- PhotosUI/ImagePicker for video: Limited control over recording experience
- Third-party camera SDKs (e.g., CameraKit): Unnecessary dependency for basic capture
- 4K video: Overkill for greeting cards; increases storage costs significantly
- ReplayKit: Designed for screen recording, not camera capture

### 2.2 Video Stitching/Concatenation

| Component | Recommendation | Location | Confidence |
|-----------|---------------|----------|------------|
| **Primary Processing** | Server-side (FFmpeg) | Supabase Edge Functions / External Service | HIGH |
| **Fallback/Preview** | AVFoundation (on-device) | iOS Client | MEDIUM |

**Server-side Approach (Recommended):**
```
Pipeline:
1. Upload individual clips to Supabase Storage
2. Trigger Edge Function on "finalize" action
3. FFmpeg processes clips server-side
4. Store final video in Supabase Storage
5. Return CDN URL to client
```

**Rationale - Server-side preferred:**
- Consistent output quality across all device types
- Reduces client battery and processing load
- Enables transitions, overlays, watermarks without app updates
- Better error handling and retry logic
- Device-independent (older iPhones won't struggle)

**On-device (secondary use case):**
- Use AVMutableComposition for preview/draft rendering only
- Useful for showing host a rough preview before final server render

**What NOT to use:**
- On-device as primary stitching: Battery drain, inconsistent quality across devices, long processing times
- GPUImage/Metal for stitching: Over-engineered for simple concatenation
- Third-party video editing SDKs (VideoEditor SDK, etc.): Expensive licensing, unnecessary features

### 2.3 Video Processing Service Options

| Option | Recommendation | Confidence |
|--------|---------------|------------|
| **Option A** | Supabase Edge Functions + FFmpeg WASM | MEDIUM |
| **Option B** | Dedicated video processing service (Mux, Cloudflare Stream) | HIGH |
| **Option C** | Self-hosted FFmpeg on Railway/Fly.io | MEDIUM |

**Detailed Analysis:**

**Option B - Mux (Recommended for MVP):**
- Pricing: ~$0.015/min stored + $0.0015/min delivered
- Handles transcoding, stitching via Assembly API, CDN delivery
- Eliminates video infrastructure complexity
- Confidence: HIGH

**Option A - FFmpeg in Edge Functions:**
- Supabase Edge Functions have 150s timeout, 150MB memory
- FFmpeg WASM works but has limitations for longer videos
- Better for post-MVP when optimizing costs
- Confidence: MEDIUM

---

## 3. Backend Services (Supabase)

### 3.1 Supabase Core

| Component | Recommendation | Version | Confidence |
|-----------|---------------|---------|------------|
| **Supabase Swift SDK** | supabase-swift | 2.x (latest: ~2.5.x) | HIGH |
| **Database** | PostgreSQL (via Supabase) | 15+ | HIGH |
| **Auth** | Supabase Auth | - | HIGH |
| **Storage** | Supabase Storage | - | HIGH |
| **Realtime** | Supabase Realtime (optional) | - | MEDIUM |
| **Edge Functions** | Deno-based | - | HIGH |

**Package Manager:**
```swift
// Package.swift or SPM in Xcode
.package(url: "https://github.com/supabase-community/supabase-swift", from: "2.0.0")
```

**Rationale:**
- supabase-swift 2.x has full Swift Concurrency (async/await) support
- Single SDK provides Auth, Database, Storage, Realtime
- PostgreSQL offers robust relational data model for cards/participants
- Edge Functions enable server-side logic without managing servers

**What NOT to use:**
- Firebase: Google ecosystem lock-in, less developer-friendly than Supabase
- AWS Amplify: Complex setup, overkill for this app scale
- Custom backend: Unnecessary development time for MVP
- Parse Server: Aging technology, smaller community

### 3.2 Database Schema (High-level)

```sql
-- Core tables
cards (
  id, host_user_id, recipient_name, occasion, status,
  invite_code, final_video_url, created_at, published_at
)

participants (
  id, card_id, user_id, display_name, status, invited_at
)

clips (
  id, card_id, participant_id, video_url, duration_ms,
  order_index, status, uploaded_at
)

users (
  id, auth_id, display_name, email, created_at
)

purchases (
  id, user_id, card_id, product_id, transaction_id,
  purchased_at, status
)
```

### 3.3 Storage Configuration

| Bucket | Purpose | Access | Confidence |
|--------|---------|--------|------------|
| `clips` | Individual participant videos | Private (signed URLs) | HIGH |
| `final-videos` | Stitched final videos | Private or Public | HIGH |
| `thumbnails` | Video thumbnails | Public | HIGH |

**Rationale:**
- Separate buckets for access control and lifecycle policies
- Signed URLs for clips prevent unauthorized access
- Final videos can be public for easy sharing or private with auth

---

## 4. App Clips

### 4.1 App Clip Configuration

| Component | Recommendation | Confidence |
|-----------|---------------|------------|
| **Size Limit** | <15MB (Apple requirement) | HIGH |
| **Minimum iOS** | iOS 17.0 | HIGH |
| **Shared Code** | Swift Package for shared models/logic | HIGH |
| **Invocation** | QR Code, NFC, Safari Smart Banner, Deep Link | HIGH |

**App Clip Scope (Participant Flow Only):**
1. Open via invite link/QR
2. Display card info and recording UI
3. Record 7-sec clip (hold-to-record)
4. Upload to Supabase
5. Prompt to download full app (optional)

**Rationale:**
- App Clips remove friction for participants (no App Store download)
- 15MB limit is tight; exclude host features, complex animations
- Shared Swift Package prevents code duplication
- iOS 17+ ensures modern SwiftUI and camera APIs work

**What NOT to use:**
- Web-based recording: iOS Safari has limited camera API access, inconsistent quality
- Full app features in App Clip: Violates size limit and purpose
- Third-party frameworks in App Clip: Bloats binary size

### 4.2 Code Sharing Strategy

```
TOY/
  TOYApp/           # Full iOS app target
  TOYAppClip/       # App Clip target
  TOYShared/        # Swift Package (shared code)
    - Models/
    - Services/
    - VideoCapture/
    - SupabaseClient/
```

---

## 5. Deep Linking & Invites

### 5.1 Deep Link Strategy

| Component | Recommendation | Confidence |
|-----------|---------------|------------|
| **Primary** | Universal Links | HIGH |
| **Fallback** | Custom URL Scheme | HIGH |
| **Format** | `https://toy.app/card/{inviteCode}` | HIGH |

**Universal Links Setup:**
- Host `apple-app-site-association` file on domain
- Configure Associated Domains entitlement
- Handle in `onOpenURL` modifier (SwiftUI)

**Rationale:**
- Universal Links work with App Clips out of the box
- Provide seamless web-to-app handoff
- Custom scheme as fallback for older integrations

**What NOT to use:**
- Firebase Dynamic Links: Deprecated by Google (sunsetting 2025)
- Branch.io for MVP: Adds complexity; consider post-MVP for analytics
- Custom URL scheme only: Doesn't trigger App Clip invocation

---

## 6. In-App Purchases

### 6.1 StoreKit Configuration

| Component | Recommendation | Version | Confidence |
|-----------|---------------|---------|------------|
| **Framework** | StoreKit 2 | iOS 15+ | HIGH |
| **Product Type** | Non-consumable | - | HIGH |
| **Pricing Model** | Per-card purchase | - | HIGH |

**Implementation Approach:**
```swift
// StoreKit 2 async API
let products = try await Product.products(for: ["toy.card.single"])
let result = try await product.purchase()
// Handle result, verify transaction, unlock card finalization
```

**Rationale:**
- StoreKit 2 has modern async/await API, simpler than StoreKit 1
- Non-consumable fits "one purchase per card" model
- Native verification reduces server-side receipt validation complexity

**Server-side Verification (Recommended):**
- Use App Store Server API for transaction verification
- Store purchase records in Supabase for access control
- Supabase Edge Function can validate with Apple servers

**What NOT to use:**
- StoreKit 1 (original): Legacy API, callback-based, harder to maintain
- RevenueCat for MVP: Adds dependency and cost; consider post-MVP for analytics
- Consumables: Doesn't match "unlock card" use case

---

## 7. Additional Dependencies

### 7.1 Recommended Swift Packages

| Package | Purpose | Version | Confidence |
|---------|---------|---------|------------|
| supabase-swift | Backend SDK | 2.x | HIGH |
| swift-collections | Ordered collections (OrderedDictionary) | 1.x | MEDIUM |
| swift-algorithms | Sequence algorithms | 1.x | LOW |

**Minimal dependency philosophy:**
- Apple first-party frameworks cover 95% of needs
- Only add third-party packages when significant time savings

### 7.2 Development Tools

| Tool | Purpose | Confidence |
|------|---------|------------|
| Xcode 15.3+ | IDE | HIGH |
| Swift Package Manager | Dependency management | HIGH |
| Supabase CLI | Local development, migrations | HIGH |
| Xcode Cloud / Fastlane | CI/CD | MEDIUM |

---

## 8. What NOT to Use (Summary)

| Category | Avoid | Reason |
|----------|-------|--------|
| **UI** | UIKit (as primary), Storyboards | SwiftUI is mature, declarative, less code |
| **State** | Combine (for simple state), RxSwift | @Observable handles most cases |
| **DI** | Swinject, Resolver | Swift Environment is sufficient |
| **Backend** | Firebase, AWS Amplify, Parse | Supabase is simpler, more cost-effective |
| **Video** | Third-party camera SDKs | AVFoundation is capable and performant |
| **Video Processing** | On-device as primary | Inconsistent, battery-draining |
| **Links** | Firebase Dynamic Links | Deprecated; use Universal Links |
| **IAP** | StoreKit 1, RevenueCat (MVP) | StoreKit 2 is simpler; add analytics later |
| **Navigation** | NavigationView | Deprecated; use NavigationStack |

---

## 9. Risk Assessment

| Risk | Mitigation | Confidence |
|------|------------|------------|
| App Clip size limit (15MB) | Aggressive code splitting, minimal deps | MEDIUM |
| Video upload on poor networks | Chunked uploads, background URLSession | HIGH |
| Supabase Swift SDK maturity | Active community, falling back to REST if needed | HIGH |
| Video stitching latency | Async processing, webhook notifications | HIGH |
| StoreKit 2 edge cases | Comprehensive testing, transaction observer | MEDIUM |

---

## 10. Version Matrix

| Component | Minimum | Recommended | Latest Verified |
|-----------|---------|-------------|-----------------|
| iOS | 17.0 | 17.4+ | 18.x |
| Swift | 5.9 | 5.10 | 5.10 |
| Xcode | 15.0 | 15.3+ | 16.x |
| supabase-swift | 2.0.0 | 2.5.x | 2.5.x |
| PostgreSQL (Supabase) | 15 | 15 | 15 |

---

## 11. Decision Log

| Decision | Date | Rationale |
|----------|------|-----------|
| iOS 17.0 minimum | 2026-02-01 | @Observable, stable SwiftUI, ~85% adoption |
| Supabase over Firebase | 2026-02-01 | Open-source, simpler DX, PostgreSQL flexibility |
| Server-side video stitching | 2026-02-01 | Consistency, performance, device-independence |
| StoreKit 2 only | 2026-02-01 | Modern API, no legacy support needed for new app |
| Universal Links primary | 2026-02-01 | App Clip compatibility, no third-party dependency |

---

## Appendix A: Quick Start Commands

```bash
# Create new Xcode project with App Clip target
# Xcode > File > New > Project > App > Include App Clip

# Add Supabase Swift SDK
# In Xcode: File > Add Package Dependencies
# URL: https://github.com/supabase-community/supabase-swift
# Version: 2.0.0 - Next Major

# Install Supabase CLI (for local dev)
brew install supabase/tap/supabase

# Initialize Supabase project
supabase init
supabase start
```

---

## Appendix B: Estimated Costs (Monthly)

| Service | Usage Assumption | Estimated Cost |
|---------|------------------|----------------|
| Supabase (Pro) | 100GB storage, 10GB bandwidth | $25-50/mo |
| Mux (if used) | 100 hrs stored, 1000 hrs streamed | $30-50/mo |
| Apple Developer | Annual | $8.25/mo ($99/yr) |
| **Total MVP** | - | **~$65-110/mo** |

---

*This document serves as the canonical stack reference for TOY development. Update version numbers as dependencies are updated.*
