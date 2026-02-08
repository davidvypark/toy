# Phase 15: Checkout & Purchase Flow - Research

**Researched:** 2026-02-08
**Domain:** Publish-time checkout gate with consumable IAP tier selection, purchase recording, and retry-safe publish flow
**Confidence:** HIGH

## Summary

Phase 15 is the revenue-critical integration that connects the browse-only tier UI (Phase 14) to an actual purchase flow gated at publish time. The infrastructure is almost entirely in place: `CardTier` computes tiers purely, `PurchaseService.fetchTierPackages()` fetches consumable packages, `PurchaseService.purchase(package:)` handles the RevenueCat payment, and `CardService.updateCardMaxParticipants()` writes to Supabase. What is missing is (a) the publish-time gate that intercepts the "Publish" button when clips exceed the purchased tier, (b) a checkout sheet with static tier visualization and purchase CTA, (c) transaction ID recording on the card for audit trail, and (d) retry-safe publish flow that does not re-charge after payment succeeds.

The current `MontagePreviewView` calls `publishViewModel.publishWithStitching(card:, clips:)` directly when the host taps "Publish Card." There is zero tier checking in this flow. The existing `UpgradeViewModel.recordCardUpgrade()` writes `maxParticipants = 999` (hard-coded unlimited) to Supabase after purchase with no transaction ID recorded. Both of these must change.

The key architectural pattern: separate purchase from publish into two sequential steps. Step 1 (purchase) updates `card.maxParticipants` and records the transaction ID. Step 2 (publish) re-checks the tier and proceeds only if the card is now within its paid tier. If Step 2 fails, the host retries Step 2 only -- the card retains its purchased tier from Step 1.

**Primary recommendation:** Build a `CheckoutSheet` as a `.sheet()` from `MontagePreviewView` that presents a static tier visualization, auto-selects the cheapest fitting tier, lets the host select higher tiers, and has a single "Publish -- $X.XX" CTA. On purchase success, record the transaction to Supabase and then trigger publish. On publish failure, persist the purchased state so retry does not re-charge.

## Standard Stack

### Core (Already Integrated -- No New Dependencies)

| Library | Version | Purpose | Status |
|---------|---------|---------|--------|
| RevenueCat SDK | 5.57.0 | IAP payment processing | Already integrated via PurchaseService |
| Supabase Swift | 2.x | Database updates for card tier/transaction | Already integrated via CardService |
| SwiftUI | iOS 17+ | Checkout UI | Already in use |
| TOYShared CardTier | N/A | Tier computation (requiredTier, fromMaxParticipants) | Exists, verified Phase 13 |

### Supporting (Already Integrated)

| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| PurchaseService | Actor singleton | fetchTierPackages(), purchase(package:) | Load tier prices, execute purchase |
| CardService | Actor | updateCardMaxParticipants(cardId:, maxParticipants:) | Record purchase to Supabase |
| TOYButton | SwiftUI component | Primary/secondary/text CTA buttons | Checkout CTA button |

### Alternatives Considered

| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| Custom checkout sheet | RevenueCat PaywallView | PaywallView is designed for subscription paywalls, not consumable tier selection. Custom is required. |
| `.needsUpgrade` state in PublishViewModel | Separate CheckoutViewModel | Separate VM adds complexity. The tier check is a simple condition before publish starts, not a new state machine. Better to gate at the view level in MontagePreviewView. |
| Adding purchase columns to Card model | Keeping Card model unchanged | Card model needs `purchaseTransactionId` for PURCH-01. But for MVP, a separate CardService method can write the transaction ID without changing the Card struct (write-only, no read needed on client). |

## Architecture Patterns

### Current Publish Flow (No Tier Gate)

```
MontagePreviewView
  |-- "Publish Card" button tapped
  |-- calls publishViewModel.publishWithStitching(card:, clips:)
  |-- PublishState: .idle -> .generating -> .uploading -> .publishing -> .success
  |-- On .success: fullScreenCover -> PublishedCardView
  |-- On .failed: alert with retry
```

### Recommended Publish Flow (With Tier Gate)

```
MontagePreviewView
  |-- "Publish Card" button tapped
  |-- CHECK: viewModel.needsUpgradeToPublish(for: card) ?
  |     |
  |     YES -> present CheckoutSheet as .sheet()
  |     |       |-- Shows static tier visualization (all tiers in vertical list)
  |     |       |-- Auto-selects cheapest tier >= clipCount
  |     |       |-- Host can select higher tiers (but not below clipCount)
  |     |       |-- "Publish -- $X.XX" CTA button
  |     |       |-- On purchase success:
  |     |       |     1. PurchaseService.purchase(package:) -> StoreTransaction
  |     |       |     2. CardService write: maxParticipants + transactionId to Supabase
  |     |       |     3. Dismiss sheet with onPurchaseComplete callback
  |     |       |-- MontagePreviewView receives callback
  |     |       |-- Re-triggers publishWithStitching (now passes tier check)
  |     |
  |     NO (free tier or already purchased) -> proceed directly
  |
  |-- publishViewModel.publishWithStitching(card:, clips:)
  |-- PublishState: .idle -> .generating -> .uploading -> .publishing -> .success
```

### Pattern 1: View-Level Tier Gate (Not ViewModel State)

**What:** The tier check happens in MontagePreviewView's action handler, NOT as a PublishViewModel state. Instead of adding `.needsUpgrade` to PublishState, the view checks `viewModel.needsUpgradeToPublish(for: card)` before calling publish.

**When to use:** When the gate is a simple boolean check that presents a sheet, not a complex state transition.

**Why this is better than adding PublishState.needsUpgrade:**
- The PublishState enum is about the publish process itself (generate, upload, publish). Tier checking is a pre-condition, not a step in the process.
- Adding `.needsUpgrade` to PublishState means the checkout sheet dismissal must transition PublishState back to `.idle`, then re-call `publishWithStitching`. This creates a fragile state chain.
- A view-level check with `@State private var showCheckout = false` is simpler and follows the existing pattern (e.g., `showUpgradeSheet`, `showTierSelection` are already `@State` booleans in CardDetailView).

**Example:**
```swift
// In MontagePreviewView actionButtons
TOYButton.primary("Publish Card") {
    if cardDetailViewModel.needsUpgradeToPublish(for: card) {
        showCheckout = true  // Present CheckoutSheet
    } else {
        Task {
            await publishViewModel.publishWithStitching(card: card, clips: sortedClips)
        }
    }
}
```

**Source:** Codebase analysis -- MontagePreviewView already uses multiple `@State` booleans for sheet presentation (line 20: `showPublishedView`). This pattern is consistent.

### Pattern 2: Separate Purchase from Publish (Transaction Safety)

**What:** The purchase step writes to Supabase IMMEDIATELY after RevenueCat confirms payment, BEFORE any video stitching begins. The publish step is independently retriable.

**When to use:** Always. This is the transaction safety pattern.

**Why critical:** RevenueCat's `purchase(package:)` returns `(StoreTransaction?, CustomerInfo, Bool)`. The current code discards the `StoreTransaction` (line 87 in PurchaseService.swift: `let (_, customerInfo, _) = try await...`). The StoreTransaction contains `transactionIdentifier` which MUST be saved to Supabase as proof of purchase. If publish fails after payment, this identifier proves the host already paid.

**Example:**
```swift
// In CheckoutSheet's purchase handler
let (transaction, customerInfo, userCancelled) = try await Purchases.shared.purchase(package: selectedPackage)

guard !userCancelled else { return }  // User dismissed payment sheet

// Step 1: Record purchase to Supabase IMMEDIATELY
let transactionId = transaction?.transactionIdentifier ?? "unknown"
try await cardService.recordTierPurchase(
    cardId: card.id,
    maxParticipants: selectedTier.maxParticipantsValue,
    transactionId: transactionId
)

// Step 2: Dismiss sheet, trigger publish (can fail independently)
onPurchaseComplete()
```

### Pattern 3: Static Tier Visualization (Not Carousel)

**What:** The checkout shows all tiers in a vertical list (not a horizontal carousel). The auto-selected tier is visually highlighted. Tiers below the clip count are dimmed and unselectable.

**When to use:** Per the locked decision: "Static tier visualization at checkout (not interactive carousel)."

**Why:** The FEATURES.md research recommended a horizontal carousel (D3), but the STATE.md records a user decision for "static tier visualization at checkout." This is simpler and avoids the carousel UX pitfalls documented in NNGroup research (swipe ambiguity, hidden content).

**Example structure:**
```swift
// Vertical list of tiers, similar to existing TierSelectionSheet
ForEach(CardTier.allCases, id: \.self) { tier in
    TierCheckoutRow(
        tier: tier,
        priceString: priceString(for: tier),
        isSelected: tier == selectedTier,
        isDisabled: tier.clipLimit < clipCount && tier != .mega,
        clipCount: clipCount
    )
    .onTapGesture {
        if tier.clipLimit >= clipCount || tier == .mega {
            selectedTier = tier
        }
    }
}
```

### Pattern 4: Card Data Refresh After Purchase

**What:** After purchase updates `card.maxParticipants` in Supabase, the local Card object is stale. The publish flow needs the updated card or must bypass the stale check.

**When to use:** After the CheckoutSheet's `onPurchaseComplete` callback fires.

**Options (ranked by simplicity):**
1. **Skip re-check on callback:** The `onPurchaseComplete` callback itself is proof that purchase succeeded. Call `publishWithStitching` without re-checking the tier. The tier was already verified during checkout. (RECOMMENDED for MVP)
2. **Re-fetch card from Supabase:** Call `cardService.fetchCardById(cardId:)` to get the updated card. More correct but adds latency and a network call.
3. **Mutate local card:** Not possible -- `Card` is a struct and is `let` in MontagePreviewView.

**Recommendation:** Option 1. The `onPurchaseComplete` callback only fires after a verified purchase + successful Supabase write. The publish flow can proceed without re-checking. If we need belt-and-suspenders, the `publishCard` Supabase call will work regardless of the local card's `maxParticipants` value.

### Anti-Patterns to Avoid

- **Do NOT add `.needsUpgrade` to PublishState.** Keep the tier check at the view level. PublishState should only represent the publish process itself.
- **Do NOT auto-charge.** The host must explicitly tap a purchase button. No implicit purchases triggered by tapping "Publish."
- **Do NOT discard the StoreTransaction.** The current PurchaseService.purchase(package:) returns it but UpgradeViewModel discards it. The transaction identifier MUST be saved.
- **Do NOT use RevenueCat entitlements for consumables.** Consumable purchases do not create durable entitlements. Card.maxParticipants in Supabase is the source of truth.
- **Do NOT block the publish retry on payment.** PURCH-03 requires that if publish fails after payment, the host retries without re-purchasing. The tier check must see the updated maxParticipants from the earlier purchase.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Payment processing | Custom StoreKit integration | PurchaseService.purchase(package:) via RevenueCat | Receipt validation, refund handling, cross-device sync handled by RevenueCat |
| Localized price strings | Hardcoded "$1.99" | package.localizedPriceString | Handles all currencies and locales automatically |
| Tier computation | Ad-hoc if/else chains | CardTier.requiredTier(for:) / CardTier.fromMaxParticipants() | Already exists, verified, handles grandfathering |
| Transaction retry/recovery | Custom StoreKit Transaction.updates listener | RevenueCat SDK (handles transaction finishing by default) | RevenueCat 5.x uses StoreKit 2 and manages transaction lifecycle |

**Key insight:** The entire purchase infrastructure already exists. Phase 15 is primarily a UI/flow integration task, not an infrastructure task. No new services, no new models (except possibly adding fields to the Card model), no new third-party dependencies.

## Common Pitfalls

### Pitfall 1: Discarding StoreTransaction After Purchase

**What goes wrong:** The current `PurchaseService.purchase(package:)` returns `CustomerInfo` and discards the `StoreTransaction`. Without the transaction identifier, there is no proof-of-purchase stored on the card record. If the Supabase write fails, there is no way to reconcile.

**Why it happens:** The existing UpgradeViewModel only needed to set `maxParticipants = 999`. It didn't need the transaction ID because there was a single binary upgrade. With consumables and per-card tracking, the transaction ID is essential.

**How to avoid:** Modify `PurchaseService.purchase(package:)` to return the full tuple `(StoreTransaction?, CustomerInfo)` or extract the `transactionIdentifier` from the return value. The caller must persist it to Supabase.

**Warning signs:** The line `let (_, customerInfo, _) = try await Purchases.shared.purchase(package: package)` in PurchaseService.swift (line 87) explicitly discards the transaction.

### Pitfall 2: Stale Card Object After Purchase

**What goes wrong:** After the checkout writes `maxParticipants = 25` to Supabase, the local `Card` struct still has `maxParticipants = 5`. If the publish flow re-checks `needsUpgradeToPublish(for: card)`, it will still return `true` and show the checkout again.

**Why it happens:** `Card` is a value type (struct). Updating Supabase does not update the local copy. `MontagePreviewView` receives `card` as `let`.

**How to avoid:** Either (a) skip the tier re-check when resuming publish after checkout (the callback itself is proof), or (b) re-fetch the card from Supabase before re-checking. Option (a) is simpler and recommended.

**Warning signs:** Infinite loop: purchase -> dismiss checkout -> re-check tier -> shows checkout again.

### Pitfall 3: User Cancels Payment Sheet But App Proceeds

**What goes wrong:** RevenueCat's `purchase(package:)` returns `userCancelled: Bool` as part of the tuple. If the code only checks for thrown errors and not the `userCancelled` flag, a cancelled purchase could proceed to the publish step.

**Why it happens:** The current `PurchaseService.purchase(package:)` wraps `Purchases.shared.purchase(package:)` and returns only `CustomerInfo`, swallowing the `userCancelled` flag (line 87: `let (_, customerInfo, _)`).

**How to avoid:** Either return the `userCancelled` flag from `PurchaseService.purchase()` or check it before proceeding. In practice, RevenueCat throws an error on cancellation in some SDK versions, but relying on this is fragile. Explicit handling is safer.

**Warning signs:** User cancels the Apple payment sheet but sees the publish flow start.

### Pitfall 4: Re-Purchase on Publish Retry (Violates PURCH-03)

**What goes wrong:** Host pays $4.99, publish fails (e.g., video stitching error). Host taps "Retry." The app re-checks `needsUpgradeToPublish(for: card)` with the STALE local card object, determines upgrade is still needed, and presents the checkout sheet AGAIN. Host is confused: "I already paid!"

**Why it happens:** Combined effect of Pitfall 2 (stale card) and no local state tracking that purchase already completed for this session.

**How to avoid:** After a successful purchase, set a local flag (e.g., `@State private var hasPurchased = true`) in MontagePreviewView. When retrying publish, skip the tier check if `hasPurchased` is true. The card already has the right `maxParticipants` in Supabase even if the local struct doesn't reflect it.

**Warning signs:** Host sees checkout twice for the same publish attempt.

### Pitfall 5: Checkout Sheet Blocks Publish for Free Cards

**What goes wrong:** A card with 3 clips (within free tier) should publish instantly without any checkout interaction. If the publish button always shows the checkout sheet, free-tier users are confused by a payment screen.

**Why it happens:** Incorrect gating condition. The gate must check `needsUpgradeToPublish(for: card)` which returns `false` for free-tier cards, NOT simply `clipCount > 0`.

**How to avoid:** The gate condition is: `CardTier.requiredTier(for: clips.count) > CardTier.fromMaxParticipants(card.maxParticipants)`. This returns `false` for any card where the clip count is within the already-purchased (or free) tier.

**Warning signs:** Users with 2-5 clips see a checkout sheet when publishing.

## Code Examples

### Existing: PurchaseService.purchase() Returns Full Tuple

```swift
// Source: PurchaseService.swift line 85-92 (current code)
// The StoreTransaction is available but currently discarded
public func purchase(package: Package) async throws -> CustomerInfo {
    do {
        let (_, customerInfo, _) = try await Purchases.shared.purchase(package: package)
        //  ^ StoreTransaction discarded here -- Phase 15 must capture this
        return customerInfo
    } catch {
        throw PurchaseError.purchaseFailed(error.localizedDescription)
    }
}
```

### Needed: PurchaseService.purchase() Returning Transaction

```swift
// Modified to return transaction identifier for Supabase recording
public func purchase(package: Package) async throws -> (customerInfo: CustomerInfo, transactionId: String?) {
    do {
        let (transaction, customerInfo, userCancelled) = try await Purchases.shared.purchase(package: package)
        if userCancelled {
            throw PurchaseError.purchaseCancelled
        }
        return (customerInfo: customerInfo, transactionId: transaction?.transactionIdentifier)
    } catch let error as PurchaseError {
        throw error
    } catch {
        throw PurchaseError.purchaseFailed(error.localizedDescription)
    }
}
```

### Existing: CardService.updateCardMaxParticipants()

```swift
// Source: CardService.swift line 210-225 (current code)
// Only updates maxParticipants -- no transaction ID tracking
public func updateCardMaxParticipants(cardId: UUID, maxParticipants: Int) async throws {
    do {
        try await supabase
            .from("cards")
            .update(["max_participants": maxParticipants])
            .eq("id", value: cardId)
            .execute()
    } catch {
        if Task.isCancelled { throw CancellationError() }
        throw CardError.updateFailed(error.localizedDescription)
    }
}
```

### Needed: CardService Method for Purchase Recording

```swift
// Writes both maxParticipants and transactionId atomically
public func recordTierPurchase(
    cardId: UUID,
    maxParticipants: Int,
    transactionId: String
) async throws {
    do {
        try await supabase
            .from("cards")
            .update([
                "max_participants": maxParticipants,
                "purchase_transaction_id": transactionId
            ])
            .eq("id", value: cardId)
            .execute()
    } catch {
        if Task.isCancelled { throw CancellationError() }
        throw CardError.updateFailed(error.localizedDescription)
    }
}
```

**Note:** This requires adding a `purchase_transaction_id TEXT` column to the Supabase `cards` table. The STACK.md research recommended additional columns (`purchased_tier`, `purchased_at`), but for MVP, `purchase_transaction_id` alone satisfies PURCH-01. The tier can be derived from `maxParticipants`.

### Existing: MontagePreviewView Publish Button (No Gate)

```swift
// Source: MontagePreviewView.swift lines 278-294 (current code)
@ViewBuilder
private var actionButtons: some View {
    VStack(spacing: TOYSpacing.md) {
        TOYButton.primary(
            publishViewModel.state.isInProgress ? "Publishing..." : "Publish Card",
            isLoading: publishViewModel.state.isInProgress
        ) {
            Task {
                await publishViewModel.publishWithStitching(
                    card: card,
                    clips: sortedClips
                )
            }
        }
        .disabled(isLoadingURLs || publishViewModel.state.isInProgress)
    }
}
```

### Needed: MontagePreviewView Publish Button (With Tier Gate)

```swift
// Intercepts publish when upgrade is needed
@ViewBuilder
private var actionButtons: some View {
    VStack(spacing: TOYSpacing.md) {
        TOYButton.primary(
            publishButtonTitle,
            isLoading: publishViewModel.state.isInProgress
        ) {
            if !hasPurchased && cardDetailViewModel.needsUpgradeToPublish(for: card) {
                showCheckout = true
            } else {
                Task {
                    await publishViewModel.publishWithStitching(
                        card: card,
                        clips: sortedClips
                    )
                }
            }
        }
        .disabled(isLoadingURLs || publishViewModel.state.isInProgress)
    }
}
```

### Existing: TierSelectionSheet (Browse-Only)

```swift
// Source: TierSelectionSheet.swift (Phase 14 -- browse-only, no purchase)
struct TierSelectionSheet: View {
    let card: Card
    let clipCount: Int
    // ... displays all tiers with prices, no purchase button
}
```

### Needed: CheckoutSheet (Purchase + Publish CTA)

The CheckoutSheet should be a NEW view (not a modification of TierSelectionSheet). TierSelectionSheet remains browse-only for the CardDetailView flow. CheckoutSheet is the publish-time checkout presented from MontagePreviewView.

```swift
struct CheckoutSheet: View {
    let card: Card
    let clipCount: Int
    let onPurchaseComplete: () -> Void
    let onCancel: () -> Void

    @State private var packages: [String: Package] = [:]
    @State private var selectedTier: CardTier
    @State private var purchaseState: PurchaseState = .idle
    // ... static tier visualization with purchase CTA
}
```

## State of the Art

| Old Approach (Current) | New Approach (Phase 15) | Impact |
|------------------------|------------------------|--------|
| Binary upgrade: free vs unlimited | 4-tier system: free/starter/group/mega | Graduated pricing, better conversion |
| Upgrade from CardDetailView only | Gate at publish time in MontagePreviewView | Payment when host is emotionally invested |
| maxParticipants = 999 after purchase | maxParticipants = tier.maxParticipantsValue | Granular tier tracking |
| No transaction ID recorded | purchase_transaction_id saved to card | Audit trail, dispute resolution |
| Publish always succeeds after tap | Publish gated by tier check | Revenue enforcement |
| UpgradeViewModel handles everything | CheckoutSheet with focused checkout flow | Cleaner separation of concerns |

**Deprecated/outdated:**
- `PurchaseService.isCardUpgraded(cardId:)` -- already marked `@available(*, deprecated)`. Do not use. Remove in Phase 16.
- `CardUpgradeView` -- binary upgrade UI. Superseded by CheckoutSheet and TierSelectionSheet. Remove in Phase 16.
- `UpgradeViewModel` -- binary upgrade VM. Superseded by checkout logic. Remove in Phase 16.

## Key Codebase Facts (Verified by Direct Code Reading)

These are facts the planner needs, verified against the actual codebase:

1. **MontagePreviewView receives `cardViewModel: CardDetailViewModel?`** (line 12, optional). It can call `cardViewModel?.needsUpgradeToPublish(for: card)` for the tier check. However, `cardViewModel` is optional, so a fallback check using CardTier directly is needed.

2. **MontagePreviewView already has `@State private var publishViewModel = PublishViewModel()`** (line 15). The publish VM is local to the view.

3. **The publish button title is hardcoded** (line 282: `"Publish Card"` / `"Publishing..."`). Phase 15 needs this to show the price for paid tiers.

4. **PurchaseService.purchase(package:) returns `(StoreTransaction?, CustomerInfo, Bool)` from RevenueCat** but wraps it to return only `CustomerInfo`. The `StoreTransaction.transactionIdentifier` must be exposed.

5. **CardTier has exactly 4 cases** (free, starter, group, mega). The StoreKit config has 3 products (starter $1.99, group $4.99, mega $9.99). Free tier has no product.

6. **TierSelectionSheet already loads prices and shows all tiers.** The checkout can reuse the same price-loading pattern (`PurchaseService.shared.fetchTierPackages()`).

7. **CardDetailViewModel.needsUpgradeToPublish(for:)** already exists (line 209-211). It returns `requiredTier(for: card) > purchasedTier(for: card)`.

8. **The Card model has NO purchase tracking fields** beyond `maxParticipants`. No `purchaseTransactionId`, no `purchasedTier`, no `purchasedAt`. Either the Card model needs updating or the write-only transaction ID is handled as a pure Supabase write.

9. **Card is a struct (value type)** and is passed as `let card: Card` to MontagePreviewView. It cannot be mutated in-place after purchase.

10. **The existing `showUpgradeSheet` state in CardDetailView** (line 19) and the `CardUpgradeView` sheet (line 231-235) are the OLD binary upgrade flow. Phase 15 should NOT modify these -- Phase 16 removes them.

## Open Questions

1. **Should Card.swift model be updated with purchase tracking fields?**
   - What we know: PURCH-01 requires recording transaction ID and tier. Supabase can store these columns. The Card model currently has no purchase fields.
   - What's unclear: Whether to add `purchaseTransactionId` to the Card struct (requiring CodingKeys update) or treat it as a write-only field that CardService writes but Card doesn't decode.
   - Recommendation: For MVP, add a write-only `recordTierPurchase` method to CardService that writes `max_participants` and `purchase_transaction_id` without changing the Card model. The transaction ID is for server-side auditing, not client-side display. This avoids a Supabase migration that adds columns the client doesn't read. If a migration IS acceptable (the STACK.md recommended one), then add the column to Supabase but still don't add it to the Card struct (it's write-only).

2. **Should `purchase_transaction_id` column be added to Supabase cards table?**
   - What we know: The column doesn't exist yet. PURCH-01 requires recording the transaction ID.
   - What's unclear: Whether this requires a Supabase migration step (external dependency) or can be done via the Supabase dashboard.
   - Recommendation: Add the column via Supabase dashboard or migration: `ALTER TABLE cards ADD COLUMN IF NOT EXISTS purchase_transaction_id TEXT;`. This is a low-risk schema change (nullable column, no constraints). The planner should include this as a task.

3. **Should PurchaseService.purchase() be modified or should the checkout call RevenueCat directly?**
   - What we know: The current method signature returns only `CustomerInfo`, discarding the transaction. The checkout needs the transaction ID.
   - What's unclear: Whether to modify the existing method (breaking change) or add a new method.
   - Recommendation: Add a new method `purchaseWithTransaction(package:)` that returns `(CustomerInfo, String?)` (customerInfo + transactionId). Keep the old method for backward compatibility until Phase 16 removes UpgradeViewModel.

4. **How should the CheckoutSheet handle the card having ALREADY been purchased (retry scenario)?**
   - What we know: PURCH-03 requires retry without re-purchase. The local card is stale after purchase. The Supabase card has the correct maxParticipants.
   - What's unclear: The exact UI flow for retry.
   - Recommendation: After successful purchase in a MontagePreviewView session, set `@State private var hasPurchased = true`. On retry, skip the tier check entirely and go straight to `publishWithStitching`. The card already has the right tier in Supabase.

## Recommended File Changes

### New Files

| File | Location | Purpose |
|------|----------|---------|
| `CheckoutSheet.swift` | `TOY/Features/Monetization/` | Publish-time tier selection + purchase CTA |

### Modified Files

| File | Change | Scope |
|------|--------|-------|
| `PurchaseService.swift` | Add `purchaseWithTransaction(package:)` returning transaction ID; add `PurchaseError.purchaseCancelled` case | Small |
| `CardService.swift` | Add `recordTierPurchase(cardId:, maxParticipants:, transactionId:)` method | Small |
| `MontagePreviewView.swift` | Add tier gate before publish, `@State showCheckout`, `@State hasPurchased`, wire CheckoutSheet | Medium |

### Unchanged Files (Phase 16 handles these)

| File | Why Unchanged |
|------|---------------|
| `CardUpgradeView.swift` | Old binary flow -- removed in Phase 16 |
| `UpgradeViewModel.swift` | Old binary VM -- removed in Phase 16 |
| `TierSelectionSheet.swift` | Browse-only -- stays as-is for CardDetailView |
| `TierIndicatorView.swift` | Display-only -- no purchase logic needed |
| `CardDetailView.swift` | Its tier indicator and TierSelectionSheet remain browse-only |
| `PublishViewModel.swift` | No state changes needed -- tier gate is at view level |
| `CardTier.swift` | No changes needed -- all tier logic exists |
| `Card.swift` | No model changes for MVP (transaction ID is write-only) |

### Supabase Schema

| Change | SQL |
|--------|-----|
| Add purchase_transaction_id column | `ALTER TABLE cards ADD COLUMN IF NOT EXISTS purchase_transaction_id TEXT;` |

## Sources

### Primary (HIGH confidence)
- Direct codebase reading: PurchaseService.swift, UpgradeViewModel.swift, CardUpgradeView.swift, MontagePreviewView.swift, PublishViewModel.swift, CardDetailView.swift, CardDetailViewModel.swift, CardService.swift, Card.swift, CardTier.swift, TierIndicatorView.swift, TierSelectionSheet.swift, TOYButton.swift, TOYProducts.storekit
- RevenueCat SDK 5.57.0 source: `PurchaseResultData` = `(StoreTransaction?, CustomerInfo, Bool)` (Purchases.swift line 32), `StoreTransaction.transactionIdentifier` (StoreTransaction.swift line 42)
- Phase 13 VERIFICATION.md -- confirmed all tier infrastructure works
- Phase 14 VERIFICATION.md -- confirmed tier UI is browse-only, no purchase logic
- STATE.md -- locked decisions: consumable IAPs, gate at publish time, static tier visualization, client-side purchase recording

### Secondary (MEDIUM confidence)
- .planning/research/monetization/ARCHITECTURE.md -- publish flow design, component detail
- .planning/research/monetization/PITFALLS.md -- purchase-publish atomicity, stale card state, cancellation handling
- .planning/research/monetization/STACK.md -- Supabase schema changes, RevenueCat configuration
- .planning/research/FEATURES.md -- checkout UX patterns, tier auto-selection, anti-features

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH -- all dependencies already integrated, verified by Phase 13/14
- Architecture: HIGH -- publish flow, tier gate, and purchase recording patterns directly informed by codebase reading and prior architecture research
- Pitfalls: HIGH -- informed by existing PITFALLS.md research, verified against actual code (discarded StoreTransaction, stale Card struct, missing cancellation handling)

**Research date:** 2026-02-08
**Valid until:** 2026-03-08 (stable -- no dependencies expected to change)
