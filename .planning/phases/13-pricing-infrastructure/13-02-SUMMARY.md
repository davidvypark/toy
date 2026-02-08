---
phase: 13-pricing-infrastructure
plan: 02
subsystem: payments
tags: [revenuecat, storekit, iap, consumable, pricing]

# Dependency graph
requires:
  - phase: 08-recipient-flow-monetization
    provides: RevenueCat SDK integration and PurchaseService actor
provides:
  - Multi-tier package fetching via PurchaseService.fetchTierPackages()
  - Deprecated isCardUpgraded(cardId:) with migration guidance
  - StoreKit configuration file for local consumable product testing
affects: [14-tier-awareness-ui, 15-checkout-purchase-flow, 16-cleanup-verification]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Multi-package offering fetch keyed by identifier"
    - "StoreKit configuration file for local consumable testing"

key-files:
  created:
    - "TOY/TOYProducts.storekit"
  modified:
    - "TOY/Features/Monetization/PurchaseService.swift"

key-decisions:
  - "3 consumable products with toy_tier_ prefix for StoreKit config"
  - "Placeholder prices: $1.99/$4.99/$9.99 for starter/group/mega"

patterns-established:
  - "fetchTierPackages returns [String: Package] keyed by RevenueCat package identifier"
  - "StoreKit config products use toy_tier_ prefix; RevenueCat packages use bare identifiers (starter, group, mega)"

# Metrics
duration: 2min
completed: 2026-02-08
---

# Phase 13 Plan 02: PurchaseService Multi-Tier Fetch + StoreKit Config Summary

**Multi-tier package fetching via RevenueCat offerings with deprecated legacy method and local StoreKit testing configuration for 3 consumable tier products**

## Performance

- **Duration:** 2 min
- **Started:** 2026-02-08T08:20:27Z
- **Completed:** 2026-02-08T08:22:20Z
- **Tasks:** 2
- **Files modified:** 2

## Accomplishments
- Added `fetchTierPackages()` to PurchaseService returning packages keyed by identifier from RevenueCat current offering
- Deprecated `isCardUpgraded(cardId:)` with clear migration message pointing to `card.maxParticipants`
- Created StoreKit configuration file with 3 consumable products for local testing

## Task Commits

Each task was committed atomically:

1. **Task 1: Add fetchTierPackages and deprecate isCardUpgraded** - `a08e2b4` (feat)
2. **Task 2: Create StoreKit configuration file** - `2313e53` (chore)

## Files Created/Modified
- `TOY/Features/Monetization/PurchaseService.swift` - Added fetchTierPackages() method, deprecated isCardUpgraded(cardId:)
- `TOY/TOYProducts.storekit` - StoreKit config with 3 consumable products (starter $1.99, group $4.99, mega $9.99)

## Decisions Made
- Used `toy_tier_` prefix for StoreKit product IDs to namespace them clearly
- Set placeholder prices ($1.99/$4.99/$9.99) that can be adjusted in App Store Connect later
- Set `familyShareable: false` for all consumable products (consumables are per-purchase, not shared)

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered
None

## User Setup Required

**Manual Xcode configuration needed** for the StoreKit configuration file:
1. Add `TOY/TOYProducts.storekit` to the Xcode project (drag into project navigator)
2. Edit Scheme -> Run -> Options -> StoreKit Configuration -> select `TOYProducts.storekit`

These steps enable local testing of consumable purchases in the Simulator.

## Next Phase Readiness
- PurchaseService can now fetch tier packages for downstream UI (Phase 14/15)
- StoreKit config enables local purchase testing without App Store Connect products
- Phase 13 Plan 01 (CardTier enum + Card default change) should also be complete for full Phase 13 readiness
- RevenueCat dashboard configuration (creating offering with starter/group/mega packages) needed for real device testing

---
*Phase: 13-pricing-infrastructure*
*Completed: 2026-02-08*
