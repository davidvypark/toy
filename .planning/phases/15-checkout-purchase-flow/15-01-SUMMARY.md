---
phase: 15-checkout-purchase-flow
plan: 01
subsystem: payments
tags: [revenucat, supabase, iap, storekit, purchase-infrastructure]

# Dependency graph
requires:
  - phase: 13-monetization-foundation
    provides: PurchaseService actor with RevenueCat SDK integration
  - phase: 14-tier-awareness-ui
    provides: TierSelectionSheet browse-only UI and CardTier enum
provides:
  - PurchaseService.purchaseWithTransaction(package:) returning transaction ID
  - PurchaseError.purchaseCancelled for explicit cancellation detection
  - CardService.recordTierPurchase(cardId:maxParticipants:transactionId:) for atomic tier recording
affects: [15-02-checkout-purchase-flow, 16-cleanup]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "AnyJSON for mixed-type Supabase update dictionaries"
    - "Tuple return for multi-value async results (customerInfo + transactionId)"

key-files:
  created: []
  modified:
    - TOY/Features/Monetization/PurchaseService.swift
    - TOY/TOYShared/Sources/TOYShared/Services/CardService.swift

key-decisions:
  - "Used AnyJSON.integer/string for mixed-type Supabase update (Int + String in one call)"
  - "purchaseWithTransaction re-throws PurchaseError to preserve cancellation, wraps others as purchaseFailed"

patterns-established:
  - "purchaseWithTransaction pattern: capture all 3 tuple values from RevenueCat, check userCancelled before returning"
  - "AnyJSON typed dictionaries for Supabase updates with mixed column types"

# Metrics
duration: 3min
completed: 2026-02-08
---

# Phase 15 Plan 01: Purchase Infrastructure Summary

**PurchaseService.purchaseWithTransaction with cancellation detection and CardService.recordTierPurchase for atomic tier+transaction writes to Supabase**

## Performance

- **Duration:** 3 min
- **Started:** 2026-02-08T10:30:41Z
- **Completed:** 2026-02-08T10:33:18Z
- **Tasks:** 2
- **Files modified:** 2

## Accomplishments
- PurchaseService exposes transaction identifier from RevenueCat purchase via purchaseWithTransaction(package:)
- PurchaseService explicitly detects and throws on user cancellation instead of silently proceeding
- CardService can atomically write maxParticipants and transactionId to a card record in a single Supabase update

## Task Commits

Each task was committed atomically:

1. **Task 1: Add purchaseWithTransaction method and cancellation error to PurchaseService** - `9785baa` (feat)
2. **Task 2: Add recordTierPurchase method to CardService** - `c83ff5a` (feat)

## Files Created/Modified
- `TOY/Features/Monetization/PurchaseService.swift` - Added PurchaseError.purchaseCancelled case and purchaseWithTransaction(package:) method returning (CustomerInfo, transactionId)
- `TOY/TOYShared/Sources/TOYShared/Services/CardService.swift` - Added recordTierPurchase(cardId:maxParticipants:transactionId:) method using AnyJSON for mixed-type update

## Decisions Made
- Used AnyJSON.integer/AnyJSON.string for the mixed-type update dictionary (Int maxParticipants + String transactionId) since Supabase update() requires Encodable and [String: Any] is not Encodable
- purchaseWithTransaction catches PurchaseError and re-throws to preserve .purchaseCancelled, while wrapping all other errors as .purchaseFailed

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] Used AnyJSON for mixed-type Supabase update dictionary**
- **Found during:** Task 2 (recordTierPurchase implementation)
- **Issue:** Plan specified `["max_participants": maxParticipants, "purchase_transaction_id": transactionId]` but this creates a `[String: Any]` dictionary which is not `Encodable` -- the Supabase `update()` method requires `some Encodable`
- **Fix:** Used `AnyJSON.integer(maxParticipants)` and `AnyJSON.string(transactionId)` to create a `[String: AnyJSON]` dictionary (aka `JSONObject`) which is `Encodable`
- **Files modified:** TOY/TOYShared/Sources/TOYShared/Services/CardService.swift
- **Verification:** Project builds successfully
- **Committed in:** c83ff5a (Task 2 commit)

---

**Total deviations:** 1 auto-fixed (1 blocking)
**Impact on plan:** AnyJSON usage is the correct Supabase SDK pattern for mixed-type updates. No scope creep.

## Issues Encountered
None

## User Setup Required

**External services require manual configuration.** The `purchase_transaction_id` TEXT column must be added to the Supabase `cards` table before the checkout flow (Plan 02) can record transactions:

```sql
ALTER TABLE cards ADD COLUMN IF NOT EXISTS purchase_transaction_id TEXT;
```

This is documented in the plan's `user_setup` section.

## Next Phase Readiness
- Purchase infrastructure methods ready for Plan 02 (CheckoutSheet)
- Plan 02 can call purchaseWithTransaction to execute purchases and detect cancellation
- Plan 02 can call recordTierPurchase to atomically record tier upgrade + transaction ID
- Supabase column migration (purchase_transaction_id) must be applied before testing

## Self-Check: PASSED

- [x] PurchaseService.swift exists
- [x] CardService.swift exists
- [x] Commit 9785baa exists (Task 1)
- [x] Commit c83ff5a exists (Task 2)
- [x] purchaseWithTransaction method present in PurchaseService
- [x] purchaseCancelled case present in PurchaseService
- [x] recordTierPurchase method present in CardService
- [x] purchase_transaction_id column reference in CardService

---
*Phase: 15-checkout-purchase-flow*
*Completed: 2026-02-08*
