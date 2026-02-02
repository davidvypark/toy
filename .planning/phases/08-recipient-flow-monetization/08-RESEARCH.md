# Phase 8: Recipient Flow & Monetization - Research

**Researched:** 2026-02-02
**Domain:** iOS in-app purchases, web video viewing, social sharing, analytics
**Confidence:** MEDIUM (RevenueCat well-documented, web viewer requires custom implementation)

## Summary

Phase 8 encompasses three distinct domains: (1) a web-based recipient video viewer at sendtoycard.com/watch/{token}, (2) social media resharing from the recipient view, and (3) RevenueCat-based monetization for per-card upgrades. The existing infrastructure already supports signed URLs for video access and the card has a `maxParticipants` field (default 8) that can gate the free tier.

**RevenueCat** is the standard solution for iOS in-app purchases, supporting non-consumable one-time purchases alongside subscriptions. The SDK (v5.x) integrates via Swift Package Manager and provides both programmatic purchase APIs and pre-built SwiftUI paywall components via RevenueCatUI.

For the **recipient web viewer**, a simple Next.js page deployed to Vercel can fetch card data via Supabase, generate a signed video URL, and render an HTML5 video player with TOY branding. Mobile Safari autoplay requires `muted`, `playsinline`, and `autoplay` attributes.

**Social sharing** can leverage SwiftUI's native `ShareLink` for URL sharing in iOS 16+, with UIActivityViewController patterns available for video file sharing. Platform-specific SDKs (TikTok Share Kit) enable direct-to-platform sharing but add complexity.

**Primary recommendation:** Use RevenueCat with non-consumable products for one-time card upgrades; build a minimal Next.js video viewer page for recipients; use ShareLink for URL-based social sharing.

## Standard Stack

The established libraries/tools for this domain:

### Core (iOS Monetization)
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| RevenueCat | 5.55.x | In-app purchases | Handles StoreKit complexity, cross-platform, dashboard analytics |
| RevenueCatUI | 5.55.x | Paywall UI | Pre-built SwiftUI paywalls, remotely configurable |

### Core (Web Viewer)
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| Next.js | 14.x | Web framework | Server components, Vercel deployment, API routes |
| @supabase/supabase-js | 2.x | Database client | Native Supabase integration |
| Tailwind CSS | 3.x | Styling | Rapid UI development |

### Core (Analytics)
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| PostHog iOS | 3.38.x | Event analytics | Open source, SwiftUI support, autocapture |

### Supporting
| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| TikTok Share Kit | 5.x | Direct TikTok sharing | If TikTok is high-priority channel |
| Video.js | 8.x | Web video player | If native HTML5 video needs enhancement |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| RevenueCat | Native StoreKit 2 | More control but significant complexity |
| Next.js | Static HTML page | Simpler but no dynamic signed URL generation |
| PostHog | Mixpanel | PostHog is open source; Mixpanel is commercial |

**Installation (iOS):**
```bash
# Swift Package Manager URLs:
# RevenueCat: https://github.com/RevenueCat/purchases-ios-spm.git
# PostHog: https://github.com/PostHog/posthog-ios.git
```

**Installation (Web):**
```bash
npx create-next-app@latest sendtoycard-web --typescript --tailwind
cd sendtoycard-web
npm install @supabase/supabase-js
```

## Architecture Patterns

### Recommended Project Structure (iOS additions)
```
TOY/
├── Features/
│   ├── Monetization/
│   │   ├── PurchaseService.swift      # RevenueCat wrapper
│   │   ├── UpgradeViewModel.swift     # Purchase flow state
│   │   └── CardUpgradeView.swift      # Upgrade prompt UI
│   └── Analytics/
│       └── AnalyticsService.swift     # PostHog wrapper
└── TOYShared/
    └── Services/
        └── CardService.swift          # Add upgrade-related methods
```

### Recommended Project Structure (Web)
```
sendtoycard-web/
├── app/
│   ├── watch/
│   │   └── [token]/
│   │       └── page.tsx               # Video viewer page
│   ├── api/
│   │   └── video/
│   │       └── [token]/
│   │           └── route.ts           # Signed URL API
│   └── layout.tsx
├── components/
│   ├── VideoPlayer.tsx                # HTML5 video with branding
│   └── ShareButtons.tsx               # Social share buttons
└── lib/
    └── supabase.ts                    # Supabase client
```

### Pattern 1: RevenueCat Configuration
**What:** Initialize RevenueCat once at app launch
**When to use:** App startup in AppDelegate or @main App
**Example:**
```swift
// Source: RevenueCat official documentation
import RevenueCat

@main
struct TOYApp: App {
    init() {
        Purchases.logLevel = .debug  // Remove in production
        Purchases.configure(withAPIKey: "appl_your_api_key")
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
```

### Pattern 2: Non-Consumable Purchase Check
**What:** Check if user owns a one-time purchase entitlement
**When to use:** Before showing upgrade prompts, when gating features
**Example:**
```swift
// Source: RevenueCat official documentation
func checkCardUpgradeStatus(cardId: UUID) async -> Bool {
    do {
        let customerInfo = try await Purchases.shared.customerInfo()
        // Entitlement ID configured in RevenueCat dashboard
        let isUpgraded = customerInfo.entitlements["card_\(cardId.uuidString)"]?.isActive == true
        return isUpgraded
    } catch {
        return false
    }
}
```

### Pattern 3: Server-Side Signed URL Generation
**What:** Generate time-limited video URLs on the server
**When to use:** Web viewer API route
**Example:**
```typescript
// Source: Supabase documentation
// app/api/video/[token]/route.ts
import { createClient } from '@supabase/supabase-js'
import { NextResponse } from 'next/server'

export async function GET(
  request: Request,
  { params }: { params: { token: string } }
) {
  const supabase = createClient(
    process.env.SUPABASE_URL!,
    process.env.SUPABASE_SERVICE_KEY!  // Server-side only
  )

  // Fetch card by share token
  const { data: card } = await supabase
    .from('cards')
    .select('*')
    .eq('share_token', params.token)
    .eq('status', 'published')
    .single()

  if (!card?.video_url) {
    return NextResponse.json({ error: 'Not found' }, { status: 404 })
  }

  // Generate signed URL (1 hour expiry)
  const { data: signedUrl } = await supabase.storage
    .from('videos')
    .createSignedUrl(card.video_url, 3600)

  return NextResponse.json({
    title: card.title,
    recipientName: card.recipient_name,
    videoUrl: signedUrl.signedUrl
  })
}
```

### Pattern 4: Mobile-Safe Video Autoplay
**What:** HTML5 video that autoplays on mobile Safari
**When to use:** Recipient video viewer
**Example:**
```html
<!-- Source: WebKit blog, multiple sources -->
<video
  autoplay
  muted
  playsinline
  poster="/poster.jpg"
  class="w-full aspect-video"
>
  <source src="{signedUrl}" type="video/quicktime" />
</video>
<!-- Note: Video starts muted; show unmute button for audio -->
```

### Anti-Patterns to Avoid
- **Direct StoreKit calls:** Don't bypass RevenueCat after configuring it; this causes receipt conflicts
- **Client-side service key:** Never expose Supabase service role key in web client code
- **Relying on autoplay with sound:** Mobile browsers block autoplay with sound; always start muted
- **Hardcoded purchase product IDs:** Use RevenueCat offerings to fetch products dynamically

## Don't Hand-Roll

Problems that look simple but have existing solutions:

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| StoreKit integration | Custom StoreKit wrapper | RevenueCat SDK | Receipt validation, cross-platform, webhooks |
| Paywall UI | Custom paywall screens | RevenueCatUI PaywallView | Remote configuration, A/B testing |
| Purchase analytics | Custom tracking | RevenueCat dashboard | Built-in revenue metrics, cohort analysis |
| Analytics events | Custom backend | PostHog | Autocapture, session replay, feature flags |
| Video player controls | Custom video controls | Native HTML5 or Video.js | Browser-tested, accessibility, mobile compat |

**Key insight:** In-app purchases involve complex edge cases (interrupted purchases, restore, refunds, receipt validation) that RevenueCat handles. Building a custom solution leads to support nightmares and lost revenue.

## Common Pitfalls

### Pitfall 1: RevenueCat API Key Exposure
**What goes wrong:** Public API key used in server-side contexts or vice versa
**Why it happens:** Confusion between public (client) and secret (server) keys
**How to avoid:** iOS uses only public API key; webhooks use server secret
**Warning signs:** RevenueCat dashboard shows unexpected API calls

### Pitfall 2: Non-Consumable Entitlement Tracking
**What goes wrong:** User purchases upgrade but app doesn't recognize it
**Why it happens:** Entitlement not properly configured or not linked to product
**How to avoid:** In RevenueCat dashboard: Products -> Entitlements -> Link product
**Warning signs:** Purchase succeeds but `customerInfo.entitlements` is empty

### Pitfall 3: Per-Card Purchase Identification
**What goes wrong:** Can't determine which card was upgraded
**Why it happens:** RevenueCat entitlements are user-level, not card-level
**How to avoid:** Store card upgrade status in your database; use RevenueCat webhooks to sync
**Warning signs:** User upgrades "a card" but unclear which one

### Pitfall 4: Video Autoplay Fails on Mobile
**What goes wrong:** Video shows but doesn't autoplay on iOS Safari
**Why it happens:** Missing `playsinline` attribute or video has audio track without `muted`
**How to avoid:** Always include `autoplay muted playsinline`; show unmute button
**Warning signs:** Works on desktop, fails on mobile

### Pitfall 5: Signed URL Expiration
**What goes wrong:** Recipient opens link but video fails to load
**Why it happens:** Signed URL generated at page load expired before playback
**How to avoid:** Generate URL on video play attempt, not page load; use 1-hour expiry
**Warning signs:** Videos work initially but fail after sitting on page

### Pitfall 6: Share Sheet Video Format Issues
**What goes wrong:** Video shares to iMessage/Mail but not to Instagram/TikTok
**Why it happens:** Platform-specific video format/size requirements
**How to avoid:** For social apps, share URL (not video file); use platform SDKs for direct share
**Warning signs:** Share works to some apps but silently fails on others

## Code Examples

Verified patterns from official sources:

### RevenueCat Purchase Flow
```swift
// Source: RevenueCat official documentation
import RevenueCat
import RevenueCatUI

struct CardUpgradeView: View {
    let card: Card
    @State private var showPaywall = false
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 20) {
            Text("Upgrade \(card.title)")
                .font(.title)

            Text("Unlock unlimited participants")

            TOYButton("Upgrade Card") {
                showPaywall = true
            }
        }
        .sheet(isPresented: $showPaywall) {
            PaywallView()
                .onPurchaseCompleted { customerInfo in
                    // Record which card was upgraded
                    Task {
                        await recordCardUpgrade(cardId: card.id)
                    }
                    dismiss()
                }
        }
    }
}
```

### PostHog Analytics Setup
```swift
// Source: PostHog official documentation
import PostHog

// In App init or AppDelegate
let config = PostHogConfig(
    apiKey: "phc_your_api_key",
    host: "https://us.i.posthog.com"  // or eu.i.posthog.com
)
config.captureApplicationLifecycleEvents = true
config.captureScreenViews = true
PostHogSDK.shared.setup(config)

// Track custom events
PostHogSDK.shared.capture("card_published", properties: [
    "card_id": card.id.uuidString,
    "participant_count": participantCount
])

// Identify user
PostHogSDK.shared.identify(userId, userProperties: [
    "email": email,
    "cards_created": cardsCreated
])
```

### SwiftUI ShareLink for Recipient URL
```swift
// Source: Apple documentation, SwiftUI
struct RecipientShareView: View {
    let card: Card

    private var recipientURL: URL? {
        guard let token = card.shareToken else { return nil }
        return URL(string: "https://sendtoycard.com/watch/\(token)")
    }

    var body: some View {
        if let url = recipientURL {
            ShareLink(
                item: url,
                subject: Text("A video for \(card.recipientName)"),
                message: Text("Someone made you a special video card!")
            ) {
                Label("Share Video", systemImage: "square.and.arrow.up")
            }
        }
    }
}
```

### Web Video Player with Branding
```tsx
// Source: HTML5 spec, WebKit documentation
// components/VideoPlayer.tsx
'use client'
import { useState, useRef } from 'react'

interface VideoPlayerProps {
  videoUrl: string
  recipientName: string
}

export function VideoPlayer({ videoUrl, recipientName }: VideoPlayerProps) {
  const [isMuted, setIsMuted] = useState(true)
  const videoRef = useRef<HTMLVideoElement>(null)

  const toggleMute = () => {
    if (videoRef.current) {
      videoRef.current.muted = !videoRef.current.muted
      setIsMuted(!isMuted)
    }
  }

  return (
    <div className="relative w-full max-w-2xl mx-auto">
      <video
        ref={videoRef}
        autoPlay
        muted
        playsInline
        loop
        className="w-full rounded-lg shadow-xl"
      >
        <source src={videoUrl} type="video/quicktime" />
      </video>

      {/* Subtle TOY branding - bottom right corner */}
      <div className="absolute bottom-4 right-4 opacity-60">
        <span className="text-white text-sm font-medium drop-shadow">
          Made with TOY
        </span>
      </div>

      {/* Unmute button */}
      <button
        onClick={toggleMute}
        className="absolute bottom-4 left-4 bg-black/50 text-white p-2 rounded-full"
      >
        {isMuted ? '🔇' : '🔊'}
      </button>
    </div>
  )
}
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| StoreKit 1 | StoreKit 2 + RevenueCat | 2021-2022 | RevenueCat abstracts both |
| UIActivityViewController | SwiftUI ShareLink | iOS 16 (2022) | Native SwiftUI sharing |
| Custom analytics | PostHog/Mixpanel SDKs | Ongoing | Autocapture reduces manual work |
| iframe video embeds | HTML5 video element | Years ago | Better mobile support |

**Deprecated/outdated:**
- SLComposeViewController (Social framework): Deprecated iOS 11, removed iOS 13
- StoreKit 1 observers: Still work but StoreKit 2 async/await is preferred

## Open Questions

Things that couldn't be fully resolved:

1. **Per-Card Purchase Tracking**
   - What we know: RevenueCat entitlements are user-level, not per-item
   - What's unclear: Best pattern for tracking which specific card was upgraded
   - Recommendation: Store `upgrade_purchased_at` timestamp on card record; use RevenueCat webhook to sync; alternatively use consumable product with webhook tracking

2. **Free Tier Enforcement**
   - What we know: Card has `maxParticipants` field (default 8)
   - What's unclear: Should enforcement be client-side, server-side, or both?
   - Recommendation: Enforce in UI (disable invite after 8) + RLS policy as backup

3. **Web Hosting Domain**
   - What we know: Decision URL-001 specifies sendtoycard.com
   - What's unclear: Is DNS/Vercel already configured?
   - Recommendation: Verify Vercel project exists or create during Phase 8

4. **Video Format for Social Sharing**
   - What we know: Original videos are .mov (QuickTime)
   - What's unclear: Do social platforms accept .mov or need MP4 conversion?
   - Recommendation: Test .mov sharing; convert to MP4 in montage generation if needed

## Sources

### Primary (HIGH confidence)
- [RevenueCat iOS Installation](https://www.revenuecat.com/docs/getting-started/installation/ios) - SDK setup
- [RevenueCat Non-Subscription Purchases](https://www.revenuecat.com/docs/platform-resources/non-subscriptions) - Non-consumable support
- [RevenueCat Paywalls](https://www.revenuecat.com/docs/tools/paywalls/displaying-paywalls) - PaywallView SwiftUI
- [Supabase Storage Signed URLs](https://supabase.com/docs/reference/javascript/storage-from-createsignedurl) - URL generation
- [WebKit Video Policies](https://webkit.org/blog/6784/new-video-policies-for-ios/) - iOS autoplay rules

### Secondary (MEDIUM confidence)
- [PostHog iOS Docs](https://posthog.com/docs/libraries/ios) - Analytics setup
- [Hacking with Swift - ShareLink](https://www.hackingwithswift.com/books/ios-swiftui/how-to-let-the-user-share-content-with-sharelink) - SwiftUI sharing
- [TikTok Share Kit](https://developers.tiktok.com/doc/share-kit-ios-quickstart-v2) - Direct TikTok sharing

### Tertiary (LOW confidence)
- WebSearch results on video watermarking best practices
- Community discussions on per-purchase tracking patterns

## Metadata

**Confidence breakdown:**
- Standard stack (monetization): HIGH - RevenueCat is the industry standard, well-documented
- Standard stack (web): HIGH - Next.js + Supabase is well-established pattern
- Architecture (purchase flow): MEDIUM - Per-card tracking pattern needs validation
- Architecture (web viewer): HIGH - Standard Next.js server components
- Pitfalls: MEDIUM - Based on official docs + community reports

**Research date:** 2026-02-02
**Valid until:** 2026-03-02 (30 days - stable domain)
