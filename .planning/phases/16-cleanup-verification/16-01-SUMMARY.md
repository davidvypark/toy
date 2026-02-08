---
phase: 16-cleanup-verification
plan: 01
subsystem: payments
tags: [revenuecat, cleanup, dead-code-removal, monetization]

# Dependency graph
requires:
  - phase: 15-checkout-purchase
    provides: New tier purchase system (purchaseWithTransaction, recordTierPurchase, CheckoutSheet)
provides:
  - Clean codebase with zero references to old binary upgrade system
  - PurchaseService with only tier-based methods
  - CardService with only recordTierPurchase (no updateCardMaxParticipants)
affects: [16-02 verification]

# Tech tracking
tech-stack:
  added: []
  patterns: []

key-files:
  created: []
  modified:
    - TOY/Features/Monetization/PurchaseService.swift
    - TOY/TOYShared/Sources/TOYShared/Services/CardService.swift
    - TOY/Features/CardManagement/CardDetailView.swift

key-decisions:
  - "No decisions required -- straightforward removal of dead code"

patterns-established: []

# Metrics
duration: 2min
completed: 2026-02-08
---

# Phase 16 Plan 01: Old Upgrade System Removal Summary

**Removed all old binary upgrade code -- CardUpgradeView, UpgradeViewModel, 4 deprecated service methods, and dead CardDetailView state -- leaving only the new tier-based monetization system**

## Performance

- **Duration:** 2 min
- **Started:** 2026-02-08T12:52:23Z
- **Completed:** 2026-02-08T12:54:53Z
- **Tasks:** 3 (2 with commits, 1 verification-only)
- **Files modified:** 5 (2 deleted, 3 edited)

## Accomplishments
- Deleted CardUpgradeView.swift (178 lines) and UpgradeViewModel.swift (145 lines) -- the entire old binary upgrade UI
- Removed 4 deprecated methods: fetchOfferings(), purchase(package:), isCardUpgraded(cardId:) from PurchaseService, and updateCardMaxParticipants from CardService (72 lines total)
- Cleaned CardDetailView of showUpgradeSheet state and CardUpgradeView sheet presentation
- Verified project builds cleanly with zero references to old upgrade system
- Confirmed all new tier system files intact: CheckoutSheet, TierIndicatorView, TierSelectionSheet, PurchaseService (with purchaseWithTransaction/fetchTierPackages)

## Task Commits

Each task was committed atomically:

1. **Task 1: Delete old upgrade files and remove dead CardDetailView references** - `aa37d26` (chore)
2. **Task 2: Remove deprecated methods from PurchaseService and CardService** - `ccc3327` (refactor)
3. **Task 3: Build verification and final dead code grep** - no commit (verification only, no code changes)

## Files Created/Modified
- `TOY/Features/Monetization/CardUpgradeView.swift` - DELETED (old binary upgrade UI, 178 lines)
- `TOY/Features/Monetization/UpgradeViewModel.swift` - DELETED (old binary upgrade VM, 145 lines)
- `TOY/Features/CardManagement/CardDetailView.swift` - Removed showUpgradeSheet state and .sheet modifier
- `TOY/Features/Monetization/PurchaseService.swift` - Removed fetchOfferings, purchase(package:), isCardUpgraded; updated doc comment
- `TOY/TOYShared/Sources/TOYShared/Services/CardService.swift` - Removed updateCardMaxParticipants

## Decisions Made
None - followed plan as specified.

## Deviations from Plan
None - plan executed exactly as written.

## Issues Encountered
None.

## User Setup Required
None - no external service configuration required.

## Next Phase Readiness
- Old upgrade system completely removed -- zero references remain in project source
- Ready for 16-02 human verification of all tier edge cases
- Build confirmed clean with only a pre-existing unused variable warning in CardDetailView (not introduced by this plan)

## Self-Check: PASSED

All artifacts verified:
- CardUpgradeView.swift: deleted (confirmed not on disk)
- UpgradeViewModel.swift: deleted (confirmed not on disk)
- PurchaseService.swift: exists with new methods intact
- CardService.swift: exists with recordTierPurchase intact
- CardDetailView.swift: exists with no old upgrade references
- Commit aa37d26: found in git log
- Commit ccc3327: found in git log
- SUMMARY.md: exists at expected path

---
*Phase: 16-cleanup-verification*
*Completed: 2026-02-08*
