# Phase 7: App Clip Integration - Research

**Researched:** 2026-02-02
**Domain:** iOS App Clips, Universal Links, StoreKit
**Confidence:** HIGH

## Summary

This phase implements an App Clip target that allows participants to record video clips via invite links without installing the full app. The existing codebase is well-positioned for this: TOYShared Swift Package already contains all recording infrastructure, DeepLinkService handles URL parsing, and the recording flow supports card context parameters.

The standard approach is to add an App Clip target in Xcode using the built-in template, share the TOYShared package between both targets, and use conditional compilation (`#if APPCLIP`) for App Clip-specific behavior. The App Clip will handle invocation URLs via `onContinueUserActivity(_:perform:)`, launch directly into the recording flow, and present an SKOverlay after successful upload to prompt full app installation.

**Primary recommendation:** Add an App Clip target that embeds TOYShared, implements minimal SwiftUI App lifecycle with URL handling, and presents recording flow immediately upon launch.

## Standard Stack

### Core (Platform APIs)

| Component | Version | Purpose | Why Standard |
|-----------|---------|---------|--------------|
| App Clip Target | Xcode 15+ | Separate lightweight binary | Apple's official approach for instant app experiences |
| `onContinueUserActivity` | SwiftUI | Handle invocation URLs | SwiftUI lifecycle's standard URL handling mechanism |
| `NSUserActivityTypeBrowsingWeb` | iOS 14+ | URL activity type | Required activity type for App Clip invocation URLs |
| SKOverlay | StoreKit | Full app install prompt | Apple's official mechanism for App Clip-to-app conversion |
| Associated Domains | iOS 14+ | Link App Clip to domain | Required capability for App Clip URL handling |

### Supporting

| Component | Version | Purpose | When to Use |
|-----------|---------|---------|-------------|
| TOYShared | Local Package | Shared recording, services | All recording and upload functionality |
| Active Compilation Conditions | Xcode | Conditional code paths | Exclude main-app-only code from App Clip |
| App Groups | iOS 14+ | Shared data container | If data needs to persist to full app (optional) |
| Keychain Sharing | iOS 15.4+ | Secure data transfer | Auth tokens transfer to full app on install |

### Alternatives Considered

| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| Shared Swift Package | Target Membership | Package approach cleaner, already in use |
| SKOverlay | Manual App Store link | SKOverlay is native, supports in-app install |
| onContinueUserActivity | onOpenURL | onContinueUserActivity required for App Clips |

**Installation:**
No additional dependencies required. TOYShared already includes Supabase for backend operations.

## Architecture Patterns

### Recommended Project Structure

```
TOY/
├── TOY/                          # Main app target
│   ├── TOYApp.swift              # Main app entry point
│   ├── Features/
│   │   └── Recording/            # RecordingView, RecordingViewModel
│   └── TOY.entitlements
├── TOYClip/                      # App Clip target (NEW)
│   ├── TOYClipApp.swift          # App Clip entry point
│   ├── ParticipantRecordingFlow.swift  # Recording coordinator
│   ├── TOYClip.entitlements      # App Clip entitlements
│   └── Info.plist
├── TOYShared/                    # Shared Swift Package (EXISTING)
│   └── Sources/TOYShared/
│       ├── Recording/            # VideoRecorder, etc.
│       ├── Services/             # CardService, StorageService
│       └── Models/               # Card, Clip, Participant
└── TOY.xcodeproj
```

### Pattern 1: App Clip App Lifecycle with URL Handling

**What:** SwiftUI App struct with `onContinueUserActivity` for invocation URL handling
**When to use:** App Clip entry point - always

**Example:**
```swift
// Source: Apple WWDC20 Configure and link your App Clips
import SwiftUI
import TOYShared

@main
struct TOYClipApp: App {
    @State private var cardShareToken: String?
    @State private var isLoading = true

    var body: some Scene {
        WindowGroup {
            Group {
                if isLoading {
                    LoadingView()
                } else if let shareToken = cardShareToken {
                    ParticipantRecordingFlow(shareToken: shareToken)
                } else {
                    InvalidLinkView()
                }
            }
            .onContinueUserActivity(NSUserActivityTypeBrowsingWeb) { activity in
                handleInvocation(activity)
            }
        }
    }

    private func handleInvocation(_ activity: NSUserActivity) {
        guard let url = activity.webpageURL else {
            isLoading = false
            return
        }

        let destination = DeepLinkService.parse(url)
        switch destination {
        case .card(let shareToken):
            cardShareToken = shareToken
        case .unknown:
            cardShareToken = nil
        }
        isLoading = false
    }
}
```

### Pattern 2: SKOverlay for Full App Prompt

**What:** Present App Store overlay after successful clip upload
**When to use:** After participant successfully submits their recording

**Example:**
```swift
// Source: Apple Developer Documentation - SKOverlay.AppClipConfiguration
import StoreKit
import SwiftUI

struct UploadSuccessView: View {
    @State private var showOverlay = false

    var body: some View {
        VStack {
            Text("Your clip was submitted!")
            Text("Get the full app to create your own cards")
                .padding()
        }
        .onAppear {
            // Slight delay before showing overlay
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                showOverlay = true
            }
        }
        .appStoreOverlay(isPresented: $showOverlay) {
            SKOverlay.AppClipConfiguration(position: .bottom)
        }
    }
}
```

### Pattern 3: Conditional Compilation for Target Differences

**What:** Use `#if APPCLIP` to conditionally include/exclude code
**When to use:** When code behavior must differ between main app and App Clip

**Example:**
```swift
// In shared code or views that need conditional behavior
#if APPCLIP
    // App Clip specific: no tab bar, straight to recording
    ParticipantRecordingFlow(shareToken: shareToken)
#else
    // Main app: full navigation with tab bar
    MainTabView()
#endif
```

### Anti-Patterns to Avoid

- **Duplicating TOYShared code:** Never copy recording/service code into App Clip target. Use the shared package.
- **Using onOpenURL for App Clips:** Must use `onContinueUserActivity(NSUserActivityTypeBrowsingWeb)` for App Clip invocation URLs.
- **Omitting Parent Application Identifiers:** App Clip won't build/deploy without proper entitlement configuration.
- **Testing only in Debug:** Size limits differ dramatically between Debug and Release builds.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Full app install prompt | Custom App Store link button | SKOverlay.AppClipConfiguration | Native UX, supports in-context install |
| URL parsing | New URL parser | Existing DeepLinkService | Already handles /card/{shareToken} |
| Recording infrastructure | New recorder | TOYShared VideoRecorder | Complete, tested implementation |
| Video upload | New upload code | TOYShared StorageService | Already works with Supabase |
| Clip database records | New service | TOYShared CardService | createClip already exists |

**Key insight:** The existing TOYShared package already contains everything needed for the App Clip's core functionality. The App Clip is essentially a minimal wrapper around existing shared code.

## Common Pitfalls

### Pitfall 1: App Clip Size Exceeds Limit

**What goes wrong:** App Clip binary exceeds 15MB (iOS 16+) or 10MB (iOS 15) limit after thinning
**Why it happens:** Debug builds are larger, or Supabase SDK adds too much weight
**How to avoid:**
  - Test with Release archive, not Debug builds
  - Use Xcode's App Thinning Size Report to measure actual variant sizes
  - Import only required Supabase modules if size is an issue
  - Verify size early in development, not just before submission
**Warning signs:** Archive build takes longer than expected; TestFlight shows size warning

### Pitfall 2: Associated Domains Not Configured for App Clips

**What goes wrong:** Tapping invite link doesn't trigger App Clip, goes to Safari instead
**Why it happens:** Missing `appclips:` domain in entitlements or AASA file not configured
**How to avoid:**
  - Add `appclips:toy.app` to App Clip entitlements (in addition to main app's `applinks:toy.app`)
  - Update AASA file to include `appclips` section with App Clip bundle ID
  - Use `?mode=developer` suffix during development to bypass CDN caching
**Warning signs:** Links work in main app but not for App Clip; App Store Connect shows domain validation errors

### Pitfall 3: Parent Application Identifiers Mismatch

**What goes wrong:** Archive fails with entitlement validation error
**Why it happens:** App Clip bundle ID doesn't use main app bundle ID as prefix
**How to avoid:**
  - App Clip bundle ID must be: `$(MAIN_APP_BUNDLE_ID).Clip`
  - Example: If main app is `com.toy.TOY`, App Clip must be `com.toy.TOY.Clip`
  - Xcode template sets this automatically, but verify manually
**Warning signs:** Build succeeds but archive fails; "parent-application-identifiers does not match" error

### Pitfall 4: SKOverlay Crash in Simulator

**What goes wrong:** App crashes when presenting SKOverlay
**Why it happens:** SKOverlay only works on physical devices
**How to avoid:**
  - Wrap SKOverlay presentation in `#if !targetEnvironment(simulator)` check
  - Or use @Environment(\.horizontalSizeClass) to detect simulator
  - Test SKOverlay on real device only
**Warning signs:** "dyld: Library not loaded: _StoreKit_SwiftUI.framework" crash

### Pitfall 5: URL Not Received in App Clip

**What goes wrong:** App Clip launches but cardShareToken is nil
**Why it happens:** Using wrong activity handler or URL format mismatch
**How to avoid:**
  - Use `onContinueUserActivity(NSUserActivityTypeBrowsingWeb)` - not `onOpenURL`
  - Ensure invocation URL matches path patterns in AASA file
  - Test with `_XCAppClipURL` environment variable in scheme
**Warning signs:** App Clip opens to "invalid link" screen; works in simulator with env var but not on device

## Code Examples

### App Clip Entry Point

```swift
// TOYClip/TOYClipApp.swift
// Source: Apple WWDC20 "Configure and link your App Clips"

import SwiftUI
import TOYShared

@main
struct TOYClipApp: App {
    @State private var shareToken: String?
    @State private var loadState: LoadState = .loading

    enum LoadState {
        case loading
        case ready
        case invalidLink
    }

    var body: some Scene {
        WindowGroup {
            Group {
                switch loadState {
                case .loading:
                    ProgressView("Loading...")
                case .ready:
                    if let token = shareToken {
                        ParticipantRecordingFlow(shareToken: token)
                    }
                case .invalidLink:
                    InvalidLinkView()
                }
            }
            .onContinueUserActivity(NSUserActivityTypeBrowsingWeb, perform: handleActivity)
        }
    }

    private func handleActivity(_ activity: NSUserActivity) {
        guard let url = activity.webpageURL else {
            loadState = .invalidLink
            return
        }

        let destination = DeepLinkService.parse(url)
        switch destination {
        case .card(let token):
            shareToken = token
            loadState = .ready
        case .unknown:
            loadState = .invalidLink
        }
    }
}
```

### App Clip Entitlements

```xml
<!-- TOYClip/TOYClip.entitlements -->
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>com.apple.developer.associated-domains</key>
    <array>
        <string>appclips:toy.app</string>
    </array>
    <key>com.apple.developer.parent-application-identifiers</key>
    <array>
        <string>$(AppIdentifierPrefix)$(PARENT_BUNDLE_IDENTIFIER)</string>
    </array>
</dict>
</plist>
```

### AASA File Update

```json
// .well-known/apple-app-site-association (on toy.app server)
{
  "applinks": {
    "apps": [],
    "details": [
      {
        "appID": "TEAMID.com.toy.TOY",
        "paths": ["/card/*"]
      }
    ]
  },
  "appclips": {
    "apps": ["TEAMID.com.toy.TOY.Clip"]
  }
}
```

### SKOverlay After Upload Success

```swift
// TOYClip/UploadSuccessView.swift
import SwiftUI
import StoreKit

struct UploadSuccessView: View {
    @State private var showAppStoreOverlay = false
    let onDismiss: () -> Void

    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 60))
                .foregroundStyle(.green)

            Text("Clip Submitted!")
                .font(.title)
                .fontWeight(.bold)

            Text("Your video message has been sent.")
                .foregroundStyle(.secondary)

            Spacer()
        }
        .padding()
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                showAppStoreOverlay = true
            }
        }
        #if !targetEnvironment(simulator)
        .appStoreOverlay(isPresented: $showAppStoreOverlay) {
            SKOverlay.AppClipConfiguration(position: .bottom)
        }
        #endif
    }
}
```

### Testing with Environment Variable

```
// Xcode Scheme > Run > Arguments > Environment Variables
// Add: _XCAppClipURL = https://toy.app/card/abc123-share-token
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| 10MB App Clip limit | 15MB (iOS 16+), 100MB digital-only (iOS 17+) | WWDC 2022, 2023 | More room for SDK dependencies |
| App Groups for secure data | Keychain transfer to full app | iOS 15.4 | Simpler secure credential migration |
| Complex AASA setup | Xcode auto-generates template | Xcode 14+ | Less manual configuration |

**Current size limits (as of iOS 17):**
- iOS 15 and earlier: 10MB
- iOS 16+: 15MB (all invocations)
- iOS 17+ (digital only, no NFC/QR): 100MB

For this app, targeting iOS 16+ minimum with 15MB limit is recommended.

**Deprecated/outdated:**
- 10MB limit: Only applies to iOS 15 and earlier deployment targets
- App Groups for credentials: Keychain sharing (iOS 15.4+) is now preferred

## Open Questions

1. **Supabase SDK size impact**
   - What we know: The SDK is modular; can import only needed components
   - What's unclear: Exact binary size contribution after thinning
   - Recommendation: Test with archive early; if size exceeds 15MB, import only `Supabase.Auth`, `Supabase.Storage`, `Supabase.PostgREST` individually

2. **Participant lookup without auth**
   - What we know: App Clip users are not signed in; need to look up card by shareToken
   - What's unclear: Whether current CardService supports unauthenticated requests
   - Recommendation: Add `fetchCardByShareToken(shareToken:)` method if not present; may need Supabase RLS policy for public card lookup

3. **Domain configuration timing**
   - What we know: toy.app is placeholder; real domain needed for production
   - What's unclear: When domain will be finalized
   - Recommendation: Use `?mode=developer` suffix during development; document domain update process for launch

## Sources

### Primary (HIGH confidence)
- Apple Developer Documentation: Creating an App Clip with Xcode
- Apple Developer Documentation: SKOverlay.AppClipConfiguration
- Apple Developer Documentation: Maximum build file sizes
- Apple WWDC20: Configure and link your App Clips
- Apple WWDC21: Build light and fast App Clips
- Apple Fruta Sample App (GitHub)

### Secondary (MEDIUM confidence)
- [Kodeco: App Clips for iOS Getting Started](https://www.kodeco.com/14455571-app-clips-for-ios-getting-started) - comprehensive tutorial
- [tanaschita.com: Developer guide on App Clips for iOS](https://tanaschita.com/20230424-app-clips/) - concise implementation guide
- [Hacking with Swift: appStoreOverlay](https://www.hackingwithswift.com/quick-start/swiftui/how-to-recommend-another-app-using-appstoreoverlay) - SKOverlay SwiftUI usage

### Tertiary (LOW confidence)
- [VGS Blog: Optimizing App Clip Size in iOS](https://www.verygoodsecurity.com/blog/posts/optimizing-appclip-size-in-ios) - size optimization techniques
- Various Apple Developer Forum threads on entitlement configuration

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH - Apple's approach is well-documented, no third-party dependencies beyond existing
- Architecture: HIGH - Pattern matches Apple's Fruta sample and existing codebase structure
- Pitfalls: MEDIUM - Based on community experiences and forum discussions
- Size limits: HIGH - Official Apple documentation verified

**Research date:** 2026-02-02
**Valid until:** 2026-03-02 (30 days - App Clip APIs are stable)
