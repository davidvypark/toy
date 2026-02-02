# Summary: 07-04 App Clip Verification & Bug Fixes

## What Was Done

1. **Fixed recording crash when camera not ready**
   - Added `guard isSessionReady` in VideoRecorder.startRecording()
   - Added defensive check in ClipWriter.finishWriting() before markAsFinished()
   - Record button now shows loading spinner when session not ready
   - Prevents AVAssetWriter crash (status 0) when capture session isn't running

2. **Updated share URLs to production domain**
   - CardCreatedView: toy.app → sendtoycard.com
   - CardDetailView: toy.app → sendtoycard.com
   - Main app entitlements: applinks:toy.app → applinks:sendtoycard.com

3. **Fixed App Clip Info.plist**
   - Added NSCameraUsageDescription
   - Added NSMicrophoneUsageDescription
   - Prevents crash when accessing camera

4. **Applied RLS policy for anon card lookup**
   - User manually applied 005_public_card_lookup.sql migration
   - Enables App Clip (unauthenticated) to fetch card by share_token

## Artifacts

| File | Change |
|------|--------|
| TOYShared/Recording/VideoRecorder.swift | Guard for isSessionReady in startRecording() |
| TOYShared/Recording/ClipWriter.swift | Defensive check for writer.status before markAsFinished() |
| TOYShared/Recording/UI/RecordingView.swift | Record button loading state when session not ready |
| TOY/Features/CardCreation/CardCreatedView.swift | URL domain: sendtoycard.com |
| TOY/Features/CardManagement/CardDetailView.swift | URL domain: sendtoycard.com |
| TOY/TOY.entitlements | applinks:sendtoycard.com |
| TOYClip/Info.plist | Camera and microphone usage descriptions |

## Decisions

| ID | Decision | Rationale |
|----|----------|-----------|
| CLIP-007 | Guard recording start on isSessionReady | Prevents crash when user taps record before camera starts |
| CLIP-008 | Defensive writer status check | Belt-and-suspenders protection against AVAssetWriter crash |
| URL-002 | Share URL domain: sendtoycard.com | Consistent with production domain across all share links |

## Verification

- [x] App Clip launches from simulated URL
- [x] Card loads successfully from Supabase (anon access)
- [x] Recording view appears with camera permission prompt
- [x] No crash when camera session not ready
- [x] Share links use sendtoycard.com domain

## Duration

~15 minutes (including debugging and human verification)

## Notes

- SKOverlay not tested in simulator (requires device)
- Full recording test requires physical device with camera
- Web viewer at sendtoycard.com not yet built (Phase 8)
