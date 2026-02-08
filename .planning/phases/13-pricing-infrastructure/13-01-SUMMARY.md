---
phase: 13-pricing-infrastructure
plan: 01
subsystem: payments
tags: [swift, enum, cardtier, pricing, supabase, migration]

# Dependency graph
requires:
  - phase: 01-foundation
    provides: Card model in TOYShared
provides:
  - CardTier enum as pure value type with 4 tiers (free/starter/group/mega)
  - Tier computation via requiredTier(for:) and fromMaxParticipants(_:)
  - Card.init default maxParticipants changed to 5 (free tier)
  - Supabase column default changed to 5
affects: [13-02, 14-tier-awareness-ui, 15-checkout-purchase-flow, 16-cleanup-verification]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Pure value type enum for tier logic with zero external dependencies"
    - "Grandfathering pattern: fromMaxParticipants maps legacy values to display tier"

key-files:
  created:
    - "TOY/TOYShared/Sources/TOYShared/Models/CardTier.swift"
  modified:
    - "TOY/TOYShared/Sources/TOYShared/Models/Card.swift"

key-decisions:
  - "CardTier lives in TOYShared with zero external dependencies (no RevenueCat, no Supabase)"
  - "Cards with maxParticipants=8 map to .free tier for display (grandfathered)"
  - "Enforcement uses card.maxParticipants directly, not CardTier.clipLimit"
  - "Mega tier uses Int.max for clipLimit (not 999) to avoid ambiguity"

patterns-established:
  - "CardTier.requiredTier(for:) determines minimum tier needed for a clip count"
  - "CardTier.fromMaxParticipants(_:) maps database value to display tier with grandfathering"
  - "maxParticipantsValue stores the Supabase column value for each tier"

# Metrics
duration: 3min
completed: 2026-02-08
---

# Phase 13 Plan 01: CardTier Enum and Card Default Summary

**Pure CardTier enum with 4 pricing tiers (free/starter/group/mega), grandfathering logic for legacy cards, and Card default changed from 8 to 5 clips**

## Performance

- **Duration:** 3 min
- **Started:** 2026-02-08
- **Completed:** 2026-02-08
- **Tasks:** 2
- **Files modified:** 2

## Accomplishments
- Created CardTier enum as pure value type in TOYShared with zero external dependencies
- Defined 4 tiers: free (5 clips), starter (10), group (25), mega (999/unlimited)
- Built grandfathering support so existing cards with maxParticipants=8 display as free tier
- Changed Card.init default from maxParticipants=8 to maxParticipants=5
- Supabase column default changed from 8 to 5 via user-run migration

## Task Commits

Each task was committed atomically:

1. **Task 1: Create CardTier enum and update Card default** - `3de4f05` (feat)
2. **Task 2: Run Supabase migration to change column default** - N/A (manual user action)

## Files Created/Modified
- `TOY/TOYShared/Sources/TOYShared/Models/CardTier.swift` - Pure tier enum with computed properties (clipLimit, displayName, maxParticipantsValue, isPaid, packageIdentifier) and static methods (requiredTier, fromMaxParticipants)
- `TOY/TOYShared/Sources/TOYShared/Models/Card.swift` - Default maxParticipants changed from 8 to 5

## Decisions Made
- CardTier is a pure value type with `import Foundation` only -- no service dependencies ensures it can be used anywhere in TOYShared without coupling
- `fromMaxParticipants(8)` returns `.free` for grandfathered cards -- enforcement uses `card.maxParticipants` directly, not `CardTier.clipLimit`
- Mega tier `clipLimit` uses `Int.max` internally while `maxParticipantsValue` stores 999 for Supabase -- avoids ambiguity between "unlimited" and "database value"
- Comparable conformance via rawValue allows tier comparison with `<` operator

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered
None

## User Setup Required

**Supabase migration (completed):**
- `ALTER TABLE cards ALTER COLUMN max_participants SET DEFAULT 5;` -- run by user in Supabase SQL Editor
- Changes default for new cards only; existing cards with maxParticipants=8 are grandfathered

## Next Phase Readiness
- CardTier enum ready for use in tier-aware UI (Phase 14)
- Combined with Plan 02 (PurchaseService + StoreKit config), Phase 13 is fully complete
- Downstream phases can import CardTier from TOYShared without additional dependencies

---
*Phase: 13-pricing-infrastructure*
*Completed: 2026-02-08*
