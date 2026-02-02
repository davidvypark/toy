---
phase: 08-recipient-flow-monetization
plan: 04
subsystem: payments
tags: [revenucat, iap, swift, swiftui, monetization, freemium]

# Dependency graph
requires:
  - phase: 08-03
    provides: PurchaseService with RevenueCat SDK integration
provides:
  - UpgradeViewModel for card upgrade purchase flow
  - CardUpgradeView UI for host upgrade prompts
  - CardService.updateCardMaxParticipants method
  - CardDetailView integration with upgrade banner
affects: [card-management, participant-limits, monetization-flow]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - UpgradeViewModel state machine (idle, loading, ready, purchasing, success, error)
    - Best-effort database updates after RevenueCat purchase

key-files:
  created:
    - TOY/Features/Monetization/UpgradeViewModel.swift
    - TOY/Features/Monetization/CardUpgradeView.swift
  modified:
    - TOY/TOYShared/Sources/TOYShared/Services/CardService.swift
    - TOY/Features/CardManagement/CardDetailView.swift

key-decisions:
  - "UPGRADE-001: maxParticipants = 999 represents unlimited (avoids schema change)"
  - "UPGRADE-002: Best-effort database update after purchase (RevenueCat is source of truth)"
  - "UPGRADE-003: needsUpgrade checks participants >= maxParticipants && maxParticipants < 999"

patterns-established:
  - "Per-card upgrade flow: load offering -> purchase -> record upgrade"
  - "Upgrade banner pattern: conditional section in List with highlighted background"

# Metrics
duration: 3min
completed: 2026-02-02
---

# Phase 8 Plan 4: Upgrade UI and Free Tier Enforcement Summary

**Card upgrade purchase flow with RevenueCat integration and host upgrade prompts when participant limit reached**

## Performance

- **Duration:** ~3 min
- **Started:** 2026-02-02T13:44:24Z
- **Completed:** 2026-02-02T13:47:12Z
- **Tasks:** 3
- **Files modified:** 4

## Accomplishments
- UpgradeViewModel manages complete purchase flow with state machine pattern
- CardUpgradeView displays benefits, price from RevenueCat, and purchase button
- CardDetailView shows upgrade banner when card reaches participant limit
- Free tier cards (< 8 participants) work without any upgrade prompts

## Task Commits

Each task was committed atomically:

1. **Task 1: Create UpgradeViewModel** - `8d1812e` (feat)
2. **Task 2: Add CardService method and CardUpgradeView** - `20b361c` (feat)
3. **Task 3: Integrate upgrade prompt into CardDetailView** - `e98b488` (feat)

## Files Created/Modified

- `TOY/Features/Monetization/UpgradeViewModel.swift` - Purchase flow state machine with RevenueCat integration
- `TOY/Features/Monetization/CardUpgradeView.swift` - Upgrade UI with benefits list, price display, restore button
- `TOY/TOYShared/Sources/TOYShared/Services/CardService.swift` - Added updateCardMaxParticipants method
- `TOY/Features/CardManagement/CardDetailView.swift` - Added upgrade banner and sheet presentation

## Decisions Made

| ID | Decision | Rationale |
|----|----------|-----------|
| UPGRADE-001 | maxParticipants = 999 for unlimited | Simple flag without schema migration; 999 is effectively unlimited |
| UPGRADE-002 | Best-effort DB update after purchase | RevenueCat is authoritative; local record is convenience only |
| UPGRADE-003 | Check both count >= max AND max < 999 | Prevents showing upgrade to already-upgraded cards |

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered

None.

## User Setup Required

RevenueCat configuration required (from 08-03):
- RevenueCat dashboard product/offering setup
- API key configured in Configuration.swift
- App Store Connect IAP products created

## Next Phase Readiness

- Upgrade flow complete and integrated into card management
- Ready for Phase 8 completion (recipient web viewer in 08-02)
- Host can upgrade cards when reaching free tier limit

---
*Phase: 08-recipient-flow-monetization*
*Completed: 2026-02-02*
