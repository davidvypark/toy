# Phase 16: Cleanup & Verification - Research

**Researched:** 2026-02-08
**Domain:** Dead code removal (old binary upgrade system) + end-to-end verification of new tier-based monetization flow
**Confidence:** HIGH

## Summary

Phase 16 is the final phase of the v1.2 Seat-Based Monetization milestone. Its purpose is twofold: (1) remove all vestiges of the old binary "upgrade for unlimited" system that has been superseded by the 4-tier pricing model built in Phases 13-15, and (2) verify that the complete tier system works correctly across all edge cases including free publish, paid publish, grandfathered cards, and post-payment retry.

The removal scope is well-defined and small. The old system consists of exactly 3 code artifacts to delete (CardUpgradeView.swift, UpgradeViewModel.swift, and the deprecated `isCardUpgraded(cardId:)` method) plus 3 dead references to remove from their call sites (CardDetailView's `showUpgradeSheet` state/sheet, PurchaseService's old `purchase(package:)` method and `fetchOfferings()` method, and CardService's `updateCardMaxParticipants` method used only by UpgradeViewModel). Every one of these was explicitly flagged as "remove in Phase 16" during Phases 13, 14, and 15.

The verification scope is defined by the 5 success criteria in the roadmap. Criteria 2-5 require human testing (real StoreKit transactions, Supabase state verification, network failure simulation), but the code paths can be traced and verified by code inspection. Criterion 1 (removal completeness) can be verified via grep.

**Primary recommendation:** Execute removal first (delete files, remove dead references, clean up imports), verify the project builds, then create a verification checklist for human testing of each success criterion.

## Standard Stack

### Core (No New Dependencies)

| Library | Version | Purpose | Status |
|---------|---------|---------|--------|
| SwiftUI | iOS 17+ | Existing views being cleaned | Already integrated |
| TOYShared CardTier | Phase 13 | Tier computation (unchanged) | Already integrated |
| RevenueCat SDK | 5.57.0 | Purchase service (methods cleaned) | Already integrated |
| Supabase Swift | 2.x | Card service (methods cleaned) | Already integrated |

Phase 16 adds NO new libraries, NO new models, and NO new views. It only removes code.

### What Stays (The New System)

| File | Purpose | Phase Created |
|------|---------|---------------|
| `CardTier.swift` | Pure tier computation enum | Phase 13 |
| `TierIndicatorView.swift` | Clip count + tier status display | Phase 14 |
| `TierSelectionSheet.swift` | Browse-only tier list with prices | Phase 14 |
| `CheckoutSheet.swift` | Publish-time checkout with purchase CTA | Phase 15 |
| `PurchaseService.swift` | Actor-based IAP service (cleaned) | Phase 8, updated Phase 15 |
| `PurchaseError` enum | Purchase error cases | Phase 8, updated Phase 15 |

## Architecture Patterns

### Pattern 1: Delete-First, Then Clean References

**What:** Delete the old files entirely first, then fix all compilation errors from missing references. This is safer than surgically editing each reference because the compiler will find every usage.

**Steps:**
1. Delete `CardUpgradeView.swift` (entire file)
2. Delete `UpgradeViewModel.swift` (entire file)
3. Build -- compiler identifies all broken references
4. Fix each broken reference (remove dead state, dead sheet, dead imports)
5. Clean up PurchaseService (remove deprecated/orphaned methods)
6. Clean up CardService (remove orphaned method)
7. Build -- verify clean compilation

**Why this order:** Deleting files first makes the compiler your search tool. Every `CardUpgradeView`, `UpgradeViewModel`, `isCardUpgraded`, etc. reference becomes a compile error that must be addressed. This ensures nothing is missed.

### Pattern 2: Verification by Code Trace + Human Test

**What:** For each success criterion, trace the code path that satisfies it, document the relevant lines, and then specify a human test to confirm runtime behavior.

**When to use:** For all 5 success criteria. Code tracing catches logic errors; human testing catches integration issues (StoreKit sandbox, Supabase connectivity, network failures).

### Anti-Patterns to Avoid

- **Do NOT remove the new tier system's `needsUpgradeToPublish(for:)` in CardDetailViewModel.** This is the NEW system, not the old one. Only remove references to the OLD binary system.
- **Do NOT remove PurchaseService.purchaseWithTransaction(package:)`. This is the NEW purchase method. Only remove the old `purchase(package:)` method.
- **Do NOT remove CardService.recordTierPurchase().** This is the NEW recording method. Only remove the old `updateCardMaxParticipants()` method.
- **Do NOT remove PurchaseService.fetchTierPackages().** This is used by TierSelectionSheet and CheckoutSheet. Only remove `fetchOfferings()` which is only used by UpgradeViewModel.
- **Do NOT remove PurchaseService.restorePurchases() or getCustomerInfo() or hasEntitlement().** These are general-purpose methods not tied to the old system. They may be needed for future features (e.g., customer support, subscription checks).

## Complete Removal Inventory

### Files to DELETE (entire file)

| File | Lines | Why Remove | Verified No Other Users |
|------|-------|------------|-------------------------|
| `TOY/Features/Monetization/CardUpgradeView.swift` | 178 | Old binary upgrade UI | Only referenced by CardDetailView.showUpgradeSheet sheet |
| `TOY/Features/Monetization/UpgradeViewModel.swift` | 145 | Old binary upgrade VM | Only used by CardUpgradeView |

### Methods to REMOVE from PurchaseService.swift

| Method | Lines | Why Remove | Callers After File Deletion |
|--------|-------|------------|----------------------------|
| `purchase(package:) -> CustomerInfo` | 88-95 | Old method that discards StoreTransaction; superseded by `purchaseWithTransaction(package:)` | None (only UpgradeViewModel called it) |
| `fetchOfferings() -> Offerings` | 56-58 | Generic offerings fetch; only caller was UpgradeViewModel. New system uses `fetchTierPackages()` instead | None (only UpgradeViewModel called it) |
| `isCardUpgraded(cardId:) -> Bool` | 165-178 | Already `@available(*, deprecated)`. Per-card product ID pattern is invalid for tier model | None (no callers even before Phase 16) |

Also update the doc comment at top of PurchaseService (lines 34-40) which references `fetchOfferings()` in the usage example.

### Methods to REMOVE from CardService.swift

| Method | Lines | Why Remove | Callers After File Deletion |
|--------|-------|------------|----------------------------|
| `updateCardMaxParticipants(cardId:maxParticipants:)` | 210-225 | Old method that only updates maxParticipants without transaction ID. Superseded by `recordTierPurchase(cardId:maxParticipants:transactionId:)` | None (only UpgradeViewModel called it) |

### Dead State/References to REMOVE from CardDetailView.swift

| Code | Line(s) | Why Remove |
|------|---------|------------|
| `@State private var showUpgradeSheet = false` | 19 | Triggers old CardUpgradeView sheet. Nothing sets this to `true` anymore (Phase 14 replaced the trigger with `showTierSelection`) |
| `.sheet(isPresented: $showUpgradeSheet) { CardUpgradeView(...) }` | 231-236 | Presents the deleted CardUpgradeView. Dead code since Phase 14 |

### Import Cleanup

After deletion, verify no orphaned imports remain:
- CardDetailView.swift: Should NOT need `import RevenueCat` (it doesn't import it currently -- verified)
- PurchaseService.swift: Still needs `import RevenueCat` for remaining methods

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Finding all dead references | Manual grep/search | Delete files, use Swift compiler errors | Compiler finds EVERY reference; manual search misses indirect usage |
| Verifying tier logic correctness | Manual code review only | Trace each success criterion through actual code paths | Structured trace with line numbers is auditable |
| Testing edge cases | Ad-hoc manual testing | Success criteria checklist with specific test data | Ensures every criterion is tested, not just the obvious paths |

## Common Pitfalls

### Pitfall 1: Removing Too Much from PurchaseService

**What goes wrong:** Removing `restorePurchases()`, `getCustomerInfo()`, or `hasEntitlement()` because they seem related to the old upgrade system.

**Why it happens:** These methods exist on PurchaseService alongside the deprecated methods. They look like part of the old system.

**How to avoid:** Check callers precisely. `restorePurchases()` and `getCustomerInfo()` and `hasEntitlement()` are general-purpose RevenueCat wrappers. They are NOT specific to the old binary upgrade system. They may be needed for future features. Only remove methods whose SOLE caller was UpgradeViewModel or CardUpgradeView.

**Warning signs:** Removing a method that has no `@available(*, deprecated)` marker and has a generic purpose.

### Pitfall 2: Missing the CardDetailView Dead Sheet

**What goes wrong:** Deleting CardUpgradeView.swift but leaving the `.sheet(isPresented: $showUpgradeSheet) { CardUpgradeView(...) }` in CardDetailView. This causes a compile error (reference to deleted type).

**Why it happens:** The delete-first approach catches this via compiler, but if someone tries to manually clean references first, they might miss this sheet modifier buried deep in the view chain.

**How to avoid:** The delete-first pattern naturally catches this. After deleting CardUpgradeView.swift, the compiler will flag CardDetailView.swift line 232.

**Warning signs:** Build failure mentioning `CardUpgradeView` after file deletion.

### Pitfall 3: Forgetting to Remove the showUpgradeSheet State

**What goes wrong:** Removing the `.sheet()` but leaving `@State private var showUpgradeSheet = false`. This is dead code that confuses future developers.

**Why it happens:** The `@State` declaration does not cause a compile error when the sheet is removed (it's just an unused variable). Swift may warn but won't error.

**How to avoid:** After removing the `.sheet()` modifier, also remove the `@State` declaration and any other references to `showUpgradeSheet`.

**Warning signs:** Xcode warning about unused variable `showUpgradeSheet`.

### Pitfall 4: Conflating Verification Criteria with Code Verification

**What goes wrong:** Claiming success criteria 2-5 are "verified" based solely on code reading. These criteria describe runtime behavior (publish succeeds, checkout appears, payment works) that requires actual execution.

**Why it happens:** Code tracing can confirm the logic SHOULD work, but real verification requires StoreKit sandbox, Supabase connectivity, and actual tap interactions.

**How to avoid:** Clearly separate "code trace verification" (confirms logic paths) from "human test verification" (confirms runtime behavior). Both are needed for full verification. Code trace is what the planner can automate; human tests go in a checklist.

**Warning signs:** Marking a success criterion as "verified" without noting it needs human testing.

## Verification Matrix

Each success criterion mapped to the code path that satisfies it:

### Criterion 1: Old system completely removed

| Artifact | Current Location | Action |
|----------|-----------------|--------|
| CardUpgradeView.swift | `TOY/Features/Monetization/` | Delete file |
| UpgradeViewModel.swift | `TOY/Features/Monetization/` | Delete file |
| `showUpgradeSheet` state | CardDetailView.swift line 19 | Remove state |
| `.sheet { CardUpgradeView(...) }` | CardDetailView.swift lines 231-236 | Remove sheet modifier |
| `purchase(package:)` old method | PurchaseService.swift lines 88-95 | Remove method |
| `fetchOfferings()` | PurchaseService.swift lines 56-58 | Remove method |
| `isCardUpgraded(cardId:)` | PurchaseService.swift lines 165-178 | Remove deprecated method |
| `updateCardMaxParticipants()` | CardService.swift lines 210-225 | Remove method |

**Verification:** `grep -rn "CardUpgradeView\|UpgradeViewModel\|showUpgradeSheet\|isCardUpgraded\|card_upgrade" TOY/` returns zero matches in Swift files (excluding comments in planning docs).

### Criterion 2: Free card (3 clips) publishes without payment

**Code path:** MontagePreviewView line 58-59: `needsUpgrade = sortedClips.count > card.maxParticipants`. For 3 clips and maxParticipants=5: `3 > 5 = false`. Line 311-319: when `needsUpgrade` is false, directly calls `publishViewModel.publishWithStitching()`. No checkout shown.

**Human test:** Create card, add 3 clips, tap Publish. Should see montage progress immediately, no checkout sheet.

### Criterion 3: Paid card (12 clips) completes checkout + publish

**Code path:** For 12 clips and maxParticipants=5: `12 > 5 = true`, so `needsUpgrade = true`. Line 312: `showCheckout = true`. CheckoutSheet line 36: `CardTier.requiredTier(for: 12)` returns `.group` (12 <= 25). Auto-selects Group tier. After purchase: CheckoutSheet line 188-192 records to Supabase, line 195-198 triggers onPurchaseComplete. MontagePreviewView line 231: `hasPurchased = true`, line 233: calls `publishWithStitching`.

**Human test:** Create card, add 12 clips, tap Publish. Should see CheckoutSheet with Group auto-selected. Complete StoreKit purchase. Should see publish progress and success.

### Criterion 4: Grandfathered card (maxParticipants=8, 6 clips) publishes free

**Code path:** MontagePreviewView line 58-59: `6 > 8 = false`, so `needsUpgrade = false`. Publishes directly without checkout. The key is using `card.maxParticipants` (8) directly, NOT `CardTier.free.clipLimit` (5).

**Human test:** Set a card's maxParticipants to 8 in Supabase, add 6 clips, tap Publish. Should publish immediately with no checkout.

### Criterion 5: Retry after payment failure without re-purchasing

**Code path:** MontagePreviewView line 25: `@State private var hasPurchased = false`. After successful purchase (line 231): `hasPurchased = true`. On retry, line 311: `!hasPurchased && needsUpgrade` evaluates to `!true && true = false`, so checkout is skipped and `publishWithStitching` runs directly.

**Human test:** Purchase a tier, simulate publish failure (e.g., airplane mode after payment), tap Publish again. Should not see checkout, should attempt publish directly.

## State of the Art

| Old Approach (Being Removed) | New Approach (Staying) | When Changed |
|------------------------------|----------------------|--------------|
| `CardUpgradeView` -- single "Upgrade for Unlimited" sheet | `CheckoutSheet` -- multi-tier selection at publish time | Phase 15 |
| `UpgradeViewModel` -- loads single offering, sets maxParticipants=999 | `CheckoutSheet` inline logic -- loads tier packages, records tier + transactionId | Phase 15 |
| `PurchaseService.purchase(package:)` -- discards StoreTransaction | `PurchaseService.purchaseWithTransaction(package:)` -- returns transactionId | Phase 15 |
| `PurchaseService.fetchOfferings()` -- generic offering loader | `PurchaseService.fetchTierPackages()` -- tier-specific package loader | Phase 13 |
| `PurchaseService.isCardUpgraded(cardId:)` -- per-card product ID check | `card.maxParticipants` as source of truth | Phase 13 (deprecated), Phase 16 (removed) |
| `CardService.updateCardMaxParticipants()` -- maxParticipants only | `CardService.recordTierPurchase()` -- maxParticipants + transactionId atomic write | Phase 15 |
| `showUpgradeSheet` in CardDetailView -- triggers old CardUpgradeView | `showTierSelection` -- triggers TierSelectionSheet (browse), `showCheckout` in MontagePreviewView -- triggers CheckoutSheet (purchase) | Phases 14-15 |

## Open Questions

1. **Should the old `purchase(package:)` method be removed or kept for potential future use?**
   - What we know: The only caller was UpgradeViewModel. The method discards the StoreTransaction which makes it unsuitable for the tier model. `purchaseWithTransaction(package:)` is a strict superset.
   - What's unclear: Whether any future feature might want the simpler method signature.
   - Recommendation: Remove it. Any future caller should use `purchaseWithTransaction(package:)` which provides the same functionality plus transaction tracking. Keeping the old method creates a trap where someone might use it and lose transaction data.

2. **Should `fetchOfferings()` be removed or kept?**
   - What we know: Only UpgradeViewModel calls it. `fetchTierPackages()` is more specific and returns packages keyed by identifier. `fetchOfferings()` returns raw RevenueCat Offerings.
   - What's unclear: Whether future features (e.g., subscriptions) might need raw Offerings access.
   - Recommendation: Remove it. If a future feature needs raw offerings, it can be re-added. YAGNI applies -- keeping dead methods creates maintenance burden and confusion.

3. **Should `updateCardMaxParticipants()` be removed or kept?**
   - What we know: Only UpgradeViewModel calls it. `recordTierPurchase()` writes both maxParticipants and transactionId atomically. There is no use case for updating maxParticipants WITHOUT a transaction ID.
   - What's unclear: Whether admin tooling might need to manually adjust maxParticipants.
   - Recommendation: Remove it. If admin tooling is needed, it can use Supabase Dashboard directly or a new purpose-built method. The old method is a footgun because it updates maxParticipants without recording why.

4. **Should PurchaseService.restorePurchases() stay?**
   - What we know: Only called by UpgradeViewModel. But it's a general-purpose RevenueCat wrapper that could be used by future features (e.g., a settings screen "Restore Purchases" button, which is an App Store requirement for apps with non-consumable purchases).
   - What's unclear: Whether the app needs a "Restore Purchases" button for consumable IAPs. (Apple does not require Restore for consumables, only for non-consumables and subscriptions.)
   - Recommendation: Keep it. Removing it saves 8 lines but creates risk if Apple review asks for a Restore Purchases option. Low cost to keep, moderate risk to remove.

## Sources

### Primary (HIGH confidence)
- Direct codebase inspection of all files in removal inventory:
  - `TOY/Features/Monetization/CardUpgradeView.swift` (178 lines, old binary upgrade UI)
  - `TOY/Features/Monetization/UpgradeViewModel.swift` (145 lines, old binary upgrade VM)
  - `TOY/Features/Monetization/PurchaseService.swift` (179 lines, service with deprecated + current methods)
  - `TOY/Features/Monetization/CheckoutSheet.swift` (259 lines, new checkout -- stays)
  - `TOY/Features/Monetization/TierIndicatorView.swift` (45 lines, new indicator -- stays)
  - `TOY/Features/Monetization/TierSelectionSheet.swift` (163 lines, new browse -- stays)
  - `TOY/Features/CardManagement/CardDetailView.swift` (735 lines, contains dead upgrade references)
  - `TOY/Features/CardManagement/CardDetailViewModel.swift` (258 lines, has new tier methods -- stays)
  - `TOY/Features/Publishing/MontagePreviewView.swift` (541 lines, has new tier gate -- stays)
  - `TOY/Features/Publishing/PublishViewModel.swift` (243 lines, unchanged -- stays)
  - `TOY/TOYShared/Sources/TOYShared/Services/CardService.swift` (contains both old and new methods)
  - `TOY/TOYShared/Sources/TOYShared/Models/CardTier.swift` (106 lines, unchanged -- stays)
- Grep analysis confirming caller relationships for every method in removal inventory
- Phase 13 VERIFICATION.md -- confirmed CardTier infrastructure
- Phase 14 VERIFICATION.md (inline in 14-02-PLAN.md summaries) -- confirmed tier UI
- Phase 15 VERIFICATION.md -- confirmed checkout/purchase flow (7/7 truths)
- ROADMAP.md Phase 16 success criteria (5 criteria)
- REQUIREMENTS.md CLEAN-01 definition

### Secondary (MEDIUM confidence)
- Phase 13 RESEARCH.md -- explicitly flagged `isCardUpgraded` for Phase 16 removal
- Phase 14 RESEARCH.md -- explicitly flagged old upgrade banner for Phase 14 replacement + Phase 16 cleanup
- Phase 15 RESEARCH.md -- explicitly flagged CardUpgradeView, UpgradeViewModel, and old `purchase()` for Phase 16 removal

### Tertiary (LOW confidence)
- None. All findings verified directly from codebase inspection.

## Metadata

**Confidence breakdown:**
- Removal inventory: HIGH -- Every file and method in the removal list was verified by grep and direct reading. Caller relationships confirmed for each method.
- Architecture (what stays): HIGH -- The new system (Phases 13-15) is fully verified by Phase 15 VERIFICATION.md (7/7 truths). No changes to the new system needed.
- Verification criteria: HIGH -- All 5 success criteria have traceable code paths. Human test specifications are clear.

**Research date:** 2026-02-08
**Valid until:** 2026-03-08 (stable -- cleanup phase with no external dependencies)
