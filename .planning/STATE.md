# Project State

## Project Reference

See: .planning/PROJECT.md (updated 2026-02-08)

**Core value:** Anyone can create a heartfelt group video message in minutes
**Current focus:** Phase 15 -- Checkout & Purchase Flow (v1.2 Seat-Based Monetization)

## Current Position

Phase: 15 of 16 (Checkout & Purchase Flow)
Plan: 2 of 2 in current phase
Status: Phase complete
Last activity: 2026-02-08 -- Completed 15-02 CheckoutSheet + MontagePreviewView tier gate

Progress: [=========████████░] 82% (45/55 estimated plans)

## Performance Metrics

**Velocity:**
- Total plans completed: 44
- Average duration: ~3.2 minutes
- Total execution time: ~140 minutes

**By Phase:**

| Phase | Plans | Total | Avg/Plan |
|-------|-------|-------|----------|
| 1 | 7/7 | ~56min | ~8min |
| 2 | 6/6 | ~19min | ~3.2min |
| 3 | 4/4 | ~11min | ~2.75min |
| 4 | 4/4 | ~22min | ~5.5min |
| 5 | 3/3 | ~8min | ~2.7min |
| 6 | 4/4 | ~22min | ~5.5min |
| 7 | 4/4 | ~24min | ~6min |
| 8 | 6/6 | ~26min | ~4.3min |
| 9 | 3/3 | ~2min | ~0.7min |
| 10-12 | 7/7 | manual | manual |
| 13 | 2/2 | ~4min | ~2min |
| 14 | 2/2 | ~6min | ~3min |
| 15 | 2/2 | ~6min | ~3min |

*Updated after each plan completion*

## Accumulated Context

### Decisions

Decisions are logged in PROJECT.md Key Decisions table.
Recent decisions affecting current work:

- [v1.2]: Consumable IAPs (not non-consumable) -- hosts buy same tier for different cards
- [v1.2]: CardTier enum in TOYShared for pure tier logic, no service dependency
- [v1.2]: Gate at publish time, not at clip submission
- [v1.2]: Supabase card.maxParticipants is source of truth (not RevenueCat entitlements)
- [v1.2]: New cards default to maxParticipants = 5; existing cards with 8 are grandfathered
- [v1.2]: Static tier visualization at checkout (not interactive carousel)
- [v1.2]: Client-side purchase recording for MVP (no Edge Function webhook)
- [v1.2]: Tier indicator visibility uses card.maxParticipants threshold (not CardTier.free.clipLimit) for grandfathering
- [v1.2]: TierIndicatorView is stateless -- receives all data as parameters, no network calls
- [v1.2]: TierSelectionSheet is browse-only -- no purchase button (Phase 15 adds purchase CTA)
- [v1.2]: Price fetching isolated to TierSelectionSheet, not in CardDetailViewModel
- [v1.2]: AnyJSON for mixed-type Supabase update dictionaries (Int + String in one call)
- [v1.2]: purchaseWithTransaction re-throws PurchaseError to preserve cancellation, wraps others as purchaseFailed
- [v1.2]: Publish gate uses card.maxParticipants directly (not CardTier enum) for grandfathering safety
- [v1.2]: Separate CheckoutTierRow from TierRowView -- checkout rows are selectable, browse rows are static

### Pending Todos

None.

### Blockers/Concerns

- App Store Connect products need to be created (consumable IAPs) -- external dependency
- RevenueCat offering needs dashboard configuration for multi-tier packages
- TOYProducts.storekit must be added to Xcode project and scheme manually
- Supabase migration: purchase_transaction_id TEXT column must be added to cards table before Plan 02 testing

## Session Continuity

Last session: 2026-02-08
Stopped at: Completed 15-02 (CheckoutSheet + Tier Gate) -- Phase 15 complete, Phase 16 next
Resume file: .planning/phases/16-cleanup/16-01-PLAN.md
