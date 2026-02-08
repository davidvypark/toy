---
phase: 15-checkout-purchase-flow
plan: 02
subsystem: payments, ui
tags: [RevenueCat, IAP, checkout, publish-gate, SwiftUI, tier-selection]

# Dependency graph
requires:
  - phase: 15-checkout-purchase-flow (plan 01)
    provides: PurchaseService.purchaseWithTransaction and CardService.recordTierPurchase
provides:
  - CheckoutSheet view with tier selection, purchase CTA, and Supabase recording
  - MontagePreviewView tier gate with grandfathering-safe maxParticipants check
  - hasPurchased retry safety for failed publishes after payment
affects: [16-cleanup]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Direct maxParticipants comparison for publish gate (not CardTier enum) to respect grandfathered cards"
    - "hasPurchased session flag for retry safety after payment"
    - "Pinned CTA button outside ScrollView for consistent bottom placement"

key-files:
  created:
    - TOY/Features/Monetization/CheckoutSheet.swift
  modified:
    - TOY/Features/Publishing/MontagePreviewView.swift

key-decisions:
  - "Used card.maxParticipants direct comparison (not CardTier) for grandfathering safety"
  - "Separate CheckoutTierRow from TierRowView -- checkout rows are selectable, browse rows are static"

patterns-established:
  - "Publish-time tier gate: sortedClips.count > card.maxParticipants"
  - "Session-scoped hasPurchased flag prevents re-gating on publish retry"

# Metrics
duration: 3min
completed: 2026-02-08
---

# Phase 15 Plan 02: Checkout & Publish Gate Summary

**CheckoutSheet with tier selection and purchase CTA, wired into MontagePreviewView with grandfathering-safe tier gate and retry safety**

## Performance

- **Duration:** 3 min
- **Started:** 2026-02-08T10:37:14Z
- **Completed:** 2026-02-08T10:40:11Z
- **Tasks:** 2
- **Files modified:** 2

## Accomplishments
- Created CheckoutSheet with static tier visualization, auto-selected cheapest fitting tier, and explicit purchase CTA with localized pricing
- Wired tier gate into MontagePreviewView using direct maxParticipants comparison (grandfathering-safe)
- Implemented hasPurchased retry safety so failed publishes after payment skip the checkout on retry
- Free cards and grandfathered cards (maxParticipants=8) publish instantly without seeing checkout

## Task Commits

Each task was committed atomically:

1. **Task 1: Create CheckoutSheet with tier selection and purchase CTA** - `e00f229` (feat)
2. **Task 2: Wire tier gate and CheckoutSheet into MontagePreviewView** - `ae11143` (feat)

## Files Created/Modified
- `TOY/Features/Monetization/CheckoutSheet.swift` - Publish-time checkout with tier selection, purchase CTA, RevenueCat integration, and Supabase recording
- `TOY/Features/Publishing/MontagePreviewView.swift` - Tier gate before publish, CheckoutSheet presentation, hasPurchased retry safety

## Decisions Made
- Used `sortedClips.count > card.maxParticipants` for tier gate instead of CardTier enum comparison. CardTier.fromMaxParticipants(8) returns .free which has clipLimit=5, incorrectly gating grandfathered cards with 6-8 clips. Direct comparison respects the actual maxParticipants value.
- Created separate CheckoutTierRow (selectable with checkmark) rather than reusing TierRowView (static display-only). The interaction models are different enough to warrant separate views.

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered
None

## User Setup Required
None - no external service configuration required. (Existing blockers from 15-01 still apply: App Store Connect products and RevenueCat offering configuration needed for runtime testing.)

## Next Phase Readiness
- Phase 15 (Checkout & Purchase Flow) is now complete -- both plans executed
- Phase 16 (Cleanup & Verification) can proceed: remove old CardUpgradeView, binary upgrade flow, and verify tier system across all edge cases
- Runtime testing requires App Store Connect product creation and RevenueCat dashboard configuration (external dependencies)

## Self-Check: PASSED

- FOUND: TOY/Features/Monetization/CheckoutSheet.swift
- FOUND: TOY/Features/Publishing/MontagePreviewView.swift
- FOUND: .planning/phases/15-checkout-purchase-flow/15-02-SUMMARY.md
- FOUND: e00f229 (Task 1 commit)
- FOUND: ae11143 (Task 2 commit)

---
*Phase: 15-checkout-purchase-flow*
*Completed: 2026-02-08*
