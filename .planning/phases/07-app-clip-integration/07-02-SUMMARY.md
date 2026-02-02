# Summary: 07-02 App Clip Target Setup

## What Was Done

1. **Created App Clip configuration files**
   - Created TOYClip/TOYClip.entitlements with appclips:sendtoycard.com domain
   - Created TOYClip/Info.plist with NSAppClip configuration and privacy descriptions

2. **App Clip target created in Xcode** (human action)
   - User added TOYClip target via File > New > Target > App Clip
   - Bundle ID: com.kindauseful.TOY.Clip
   - TOYShared linked as framework dependency
   - Scheme activated and build verified

3. **Fixed entitlements to include appclips: domain**
   - Added `appclips:sendtoycard.com` to associated domains
   - Uses production domain (sendtoycard.com) instead of placeholder

## Artifacts

| File | Change |
|------|--------|
| TOYClip/TOYClip.entitlements | App Clip associated domains and parent app reference |
| TOYClip/Info.plist | NSAppClip config, camera/mic privacy descriptions |
| TOY.xcodeproj/project.pbxproj | App Clip target added (Xcode) |
| TOYClip/ContentView.swift | Placeholder view (Xcode template) |
| TOYClip/TOYClipApp.swift | Placeholder app entry (Xcode template) |

## Decisions

| ID | Decision | Rationale |
|----|----------|-----------|
| CLIP-001 | Use sendtoycard.com for App Clip domain | Production domain, consistent with URL-001 |
| CLIP-002 | Bundle ID com.kindauseful.TOY.Clip | Matches main app bundle ID + .Clip suffix (required) |

## Verification

- [x] TOYClip scheme exists in xcodebuild -list
- [x] TOYClip target builds successfully
- [x] Entitlements include appclips:sendtoycard.com
- [x] TOYShared linked to App Clip target
- [x] Info.plist includes NSAppClip and privacy descriptions

## Duration

~5 minutes (includes human action)

## Notes

- Xcode generates placeholder ContentView.swift and TOYClipApp.swift
- These will be replaced in Plan 07-03 with actual App Clip entry point
- The appclips: domain is different from applinks: (used in main app)
