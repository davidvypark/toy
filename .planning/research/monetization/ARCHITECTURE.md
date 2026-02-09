# Architecture: Seat-Based Monetization

**Domain:** Seat-based pricing integration for group video card app
**Researched:** 2026-02-08
**Confidence:** HIGH (based on full codebase reading + RevenueCat documentation)

## Executive Summary

TOY already has a working monetization skeleton: `PurchaseService` (RevenueCat actor), `UpgradeViewModel` (purchase flow), `CardUpgradeView` (upgrade sheet), and `Card.maxParticipants` (database column, default 8, 999 = unlimited). The current model is binary -- free tier (up to 8 participants) or unlimited upgrade. Seat-based pricing replaces this binary model with graduated tiers that gate publishing, not clip submission.

The critical architectural insight: **the gate should be at publish time, not at clip submission**. Let participants submit freely. The host pays based on the clip count when they try to publish. This is both better UX (participants never get blocked) and simpler architecture (no real-time enforcement needed during collection).

## Current Architecture (As-Is)

### Component Map

```
HomeView
  |
  +--> CardDetailView
  |      |
  |      +--> CardDetailViewModel (@Observable, @MainActor)
  |      |      +-- clips: [Clip]
  |      |      +-- participants: [Participant]
  |      |      +-- cachedSignedURLs: [UUID: URL]
  |      |      +-- cardService: CardService (actor)
  |      |      +-- storageService: StorageService
  |      |
  |      +--> CardUpgradeView (sheet, shown when needsUpgrade)
  |      |      +-- UpgradeViewModel (@Observable, @MainActor)
  |      |            +-- purchaseService: PurchaseService (actor, singleton)
  |      |            +-- state: .idle -> .loading -> .ready(Package) -> .purchasing -> .success
  |      |
  |      +--> MontagePreviewView (fullScreenCover)
  |             +-- PublishViewModel (@Observable, @MainActor)
  |             |     +-- state: .idle -> .generating -> .uploading -> .publishing -> .success
  |             |     +-- montageService, storageService, cardService
  |             |
  |             +--> PublishedCardView (fullScreenCover, shown on success)
  |
  +--> PurchaseService.shared (actor, singleton)
         +-- fetchOfferings() -> Offerings
         +-- purchase(package:) -> CustomerInfo
         +-- restorePurchases() -> CustomerInfo
         +-- hasEntitlement(_:) -> Bool
         +-- isCardUpgraded(cardId:) -> Bool
```

### Existing Data Model

**Card** (Supabase `cards` table):
- `maxParticipants: Int` (default 8, 999 = unlimited)
- `status: String` ("draft", "collecting", "stitching", "published")
- `hostId: UUID`

**Current Upgrade Logic:**
- `CardDetailView.needsUpgrade` = `participants.count >= card.maxParticipants && card.maxParticipants < 999`
- When upgrade purchased: `CardService.updateCardMaxParticipants(cardId:, maxParticipants: 999)`
- Single RevenueCat offering, single package, binary unlock

### Existing RevenueCat Setup

- `PurchaseService` is an actor singleton wrapping `Purchases.shared`
- Uses `offerings.current?.availablePackages.first` (single product)
- `UpgradeViewModel` manages purchase flow, calls `recordCardUpgrade()` to write `maxParticipants = 999` to Supabase
- Non-consumable product: `card_upgrade_{cardId}` pattern (per-card tracking in `isCardUpgraded`)

## Proposed Architecture (To-Be)

### Design Decision: Gate at Publish, Not at Submit

**Recommended:** Clips are always accepted. Tier determines what you pay at publish time, based on total clip count.

**Rationale:**
1. Better UX: Participants are never blocked from contributing
2. Simpler real-time logic: No enforcement during async clip collection
3. Natural upsell moment: Host sees full montage, feels emotional investment, then is shown tier
4. Reduces race conditions: No need to count participants in real-time for gating

**Consequence:** `Card.maxParticipants` is repurposed from a hard cap (block new participants) to a "paid-up-to" marker (what tier the host has purchased for this card).

### Tier Model

```swift
/// Pure value type -- no persistence, no service dependency.
/// Lives in TOYShared so it's available everywhere.
enum CardTier: Int, CaseIterable, Comparable {
    case free = 0       // up to 5 clips
    case starter = 1    // up to 10 clips
    case group = 2      // up to 25 clips
    case mega = 3       // unlimited

    var clipLimit: Int {
        switch self {
        case .free: return 5
        case .starter: return 10
        case .group: return 25
        case .mega: return .max
        }
    }

    var displayName: String {
        switch self {
        case .free: return "Free"
        case .starter: return "Starter"
        case .group: return "Group"
        case .mega: return "Mega"
        }
    }

    /// Determines the required tier for a given clip count
    static func requiredTier(for clipCount: Int) -> CardTier {
        for tier in CardTier.allCases {
            if clipCount <= tier.clipLimit { return tier }
        }
        return .mega
    }

    /// Map from existing maxParticipants column value
    static func fromMaxParticipants(_ maxParticipants: Int) -> CardTier {
        switch maxParticipants {
        case ...5: return .free
        case 6...10: return .starter
        case 11...25: return .group
        default: return .mega // 999 or any value > 25
        }
    }

    /// The maxParticipants value to store in Supabase
    var maxParticipantsValue: Int {
        switch self {
        case .free: return 5
        case .starter: return 10
        case .group: return 25
        case .mega: return 999
        }
    }

    var isPaid: Bool { self != .free }

    static func < (lhs: CardTier, rhs: CardTier) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}
```

**Why this enum lives in TOYShared:** It is pure logic with no dependencies. CardDetailView, MontagePreviewView, and any future surface can compute the current tier from clip count without calling a service.

### Critical Architecture Decision: Consumable Products

**Problem:** A host may create multiple cards. Non-consumable products (the current approach) can only be purchased once per Apple ID. A host creating a second card that needs an upgrade cannot re-purchase the same non-consumable product.

**Solution:** Use **consumable** products for tier upgrades.

```
Product: "toy_card_starter" (consumable, $X.XX)
Product: "toy_card_group"   (consumable, $X.XX)
Product: "toy_card_mega"    (consumable, $X.XX)
```

**Consumable handling with RevenueCat:**
- RevenueCat tracks the purchase event but does NOT manage redemption
- Supabase records which card was upgraded and to what tier (via `maxParticipants` column)
- The existing `UpgradeViewModel.recordCardUpgrade()` already does this -- it writes to Supabase after purchase
- For robustness, a RevenueCat webhook to Supabase Edge Function can serve as a backup

**This matches the existing pattern:** The current `UpgradeViewModel` already writes `maxParticipants = 999` to Supabase after purchase. The new version writes `tier.maxParticipantsValue` instead. Same pattern, different value.

**Important implication:** "Restore purchases" does NOT restore consumable tier upgrades from RevenueCat alone. The source of truth for each card's tier is Supabase (`card.maxParticipants`). If a user reinstalls the app and restores, their card data comes from Supabase, which already has the tier recorded. RevenueCat restore is only useful for subscription-based models.

### Component Changes

#### Modified Components

| Component | Change | Scope |
|-----------|--------|-------|
| `Card` model | No schema change -- reuse `maxParticipants` with tier mapping | None |
| `CardDetailView` | Replace binary `needsUpgrade` banner with `TierIndicatorView` | Medium |
| `CardDetailViewModel` | Add `currentTier` and `requiredTier` computed properties | Small |
| `MontagePreviewView` | Intercept publish button when tier upgrade needed | Medium |
| `PublishViewModel` | Add `.needsUpgrade` state, pre-publish tier check | Medium |
| `UpgradeViewModel` | Support multiple packages (tiers) instead of single product | Medium |
| `CardUpgradeView` | Replace with `TierCheckoutSheet` (carousel/selector) | Large (effective rewrite) |
| `PurchaseService` | Fetch tier-specific offerings, support multiple products | Small |
| `CardService` | No change -- `updateCardMaxParticipants` already accepts any Int | None |

#### New Components

| Component | Purpose | Location |
|-----------|---------|----------|
| `CardTier` enum | Pure tier logic (limits, display names, tier calculation) | `TOYShared/Models/CardTier.swift` |
| `TierIndicatorView` | Progress bar + tier label + upgrade CTA in CardDetailView | `Features/Monetization/TierIndicatorView.swift` |
| `TierCheckoutSheet` | Tier carousel with purchase, replaces `CardUpgradeView` | `Features/Monetization/TierCheckoutSheet.swift` |

### Data Flow: Tier Calculation (Pure Local)

```
clips.count --> CardTier.requiredTier(for:) --> requiredTier
card.maxParticipants --> CardTier.fromMaxParticipants() --> purchasedTier
requiredTier > purchasedTier --> needsUpgradeToPublish = true
```

This is a **pure local calculation**. No network call, no service. The clip count is already loaded in `CardDetailViewModel.clips`. The purchased tier is on the `Card` model from Supabase. The `CardTier` enum does the math.

```swift
// In CardDetailViewModel
var currentClipCount: Int { clips.count }

var requiredTier: CardTier {
    CardTier.requiredTier(for: currentClipCount)
}

var purchasedTier: CardTier {
    CardTier.fromMaxParticipants(card.maxParticipants)
}

var needsUpgradeToPublish: Bool {
    requiredTier > purchasedTier
}

var remainingFreeSlots: Int {
    max(0, purchasedTier.clipLimit - currentClipCount)
}
```

### Data Flow: Publish with Tier Check

```
Host taps "Publish Card" in MontagePreviewView
    |
    v
PublishViewModel.publishWithStitching(card:, clips:)
    |
    +--> Check: CardTier.requiredTier(for: clips.count) > CardTier.fromMaxParticipants(card.maxParticipants)?
    |      |
    |      NO --> proceed to stitch + upload + publish (existing flow, unchanged)
    |      |
    |      YES --> state = .needsUpgrade(requiredTier)
    |               |
    |               v
    |         MontagePreviewView observes state change, presents TierCheckoutSheet
    |               |
    |               v
    |         User selects tier and purchases via RevenueCat
    |               |
    |               v
    |         UpgradeViewModel:
    |           1. PurchaseService.purchase(package:) -- Apple payment
    |           2. CardService.updateCardMaxParticipants(cardId:, maxParticipants: tier.maxParticipantsValue)
    |               |
    |               v
    |         TierCheckoutSheet dismisses with onPurchaseComplete callback
    |               |
    |               v
    |         MontagePreviewView re-triggers PublishViewModel.publishWithStitching()
    |         (re-checks tier -- now passes -- proceeds with existing flow)
    |
    v
.generating -> .uploading -> .publishing -> .success -> PublishedCardView
```

### State Machine: PublishViewModel

Current states:
```
.idle -> .generating -> .uploading -> .publishing -> .success
                                                  \-> .failed
```

Proposed states (add one new state):
```
.idle -> .needsUpgrade(CardTier) -> [purchase completes] -> .generating -> ...
     \-> .generating -> .uploading -> .publishing -> .success (free tier path)
                                                  \-> .failed
```

```swift
enum PublishState: Equatable {
    case idle
    case needsUpgrade(requiredTier: CardTier)  // NEW
    case generating(progress: Float, phase: String)
    case uploading(progress: Float)
    case publishing
    case success(videoURL: URL)
    case failed(error: String)
}
```

When `PublishViewModel` enters `.needsUpgrade`, `MontagePreviewView` observes this via its existing `.onChange(of: publishViewModel.state)` pattern and presents the `TierCheckoutSheet`. When the sheet completes successfully, the view calls `publishViewModel.publishWithStitching()` again, which re-checks the tier (now passes since `card.maxParticipants` was updated) and proceeds.

### RevenueCat Product Structure

```
Offering: "card_tiers" (set as current/default offering in RevenueCat dashboard)
  |
  +-- Package: "starter"  --> Product: "toy_card_starter" (consumable)
  +-- Package: "group"    --> Product: "toy_card_group"   (consumable)
  +-- Package: "mega"     --> Product: "toy_card_mega"    (consumable)
```

**Changes to PurchaseService:**

```swift
// Current: fetches single package
let package = offering.availablePackages.first

// New: fetches all packages, caller selects by tier
func fetchTierPackages() async throws -> [String: Package] {
    let offerings = try await Purchases.shared.offerings()
    guard let offering = offerings.current else {
        throw PurchaseError.noOfferings
    }
    var packages: [String: Package] = [:]
    for package in offering.availablePackages {
        packages[package.identifier] = package
    }
    return packages
}
```

**Changes to UpgradeViewModel:**

```swift
// Current: single package, single state
case ready(Package)

// New: multiple packages, selected tier
case ready(packages: [String: Package], selectedTier: CardTier)
```

The `UpgradeViewModel` initializer changes from `init(cardId: UUID)` to `init(cardId: UUID, clipCount: Int, currentTier: CardTier)`, so it can pre-select the minimum required tier.

### Backward Compatibility

The `Card.maxParticipants` field already exists with these values:
- `8` = free tier (default for existing cards)
- `999` = unlimited (upgraded cards)

New tier mapping (reuse same column, no DB migration):

| maxParticipants | CardTier | Status |
|-----------------|----------|--------|
| 5 | .free | New default for new cards |
| 8 | .free | Legacy cards -- grandfathered (treated as free, but with 8 clip allowance) |
| 10 | .starter | Paid |
| 25 | .group | Paid |
| 999 | .mega | Paid (backward compatible with existing upgrades) |

**Migration strategy:** The `CardTier.fromMaxParticipants()` method handles legacy values:
- `maxParticipants <= 5` -> `.free`
- `maxParticipants = 8` (old default) -> `.free` but effectively has 8 clip allowance (grandfathered)
- `maxParticipants = 10` -> `.starter`
- etc.

For grandfathering, the simplest approach: treat `maxParticipants = 8` as `.free` with a clip limit of 8 (not 5). The `CardTier.fromMaxParticipants()` can return `.free` but `clipLimit` should be read from `card.maxParticipants` directly for the actual enforcement, not from `CardTier.clipLimit`. This avoids penalizing existing users.

Alternatively, just change the new default to 5 for new cards and leave 8 for existing ones. The tier check becomes `clips.count > card.maxParticipants` regardless of which CardTier that maps to. This is actually simpler and avoids the grandfathering complexity entirely.

**Recommendation: Use `card.maxParticipants` directly for the clip limit check, and `CardTier` for display/pricing purposes only.** This means:
- Existing cards with `maxParticipants = 8` keep working (8 free clips)
- New cards get `maxParticipants = 5` (5 free clips)
- The publish gate checks `clips.count > card.maxParticipants`, not `clips.count > cardTier.clipLimit`
- `CardTier` is used for UI labels, price display, and determining which upgrade package to offer

### Component Detail: TierCheckoutSheet

```
+--------------------------------------+
|           Publish Your Card          |
|                                      |
|  You have 12 clips. Upgrade to      |
|  publish your full montage.          |
|                                      |
|  +----------+  +----------+  +----+ |
|  |  Starter |  |  Group   |  |Mega| |
|  |  10 clips|  | 25 clips |  |Unlm| |
|  |  $1.99   |  |  $3.99   |  |$6.9| |
|  |          |  | SELECTED |  |    | |
|  +----------+  +----------+  +----+ |
|                                      |
|  [  Upgrade & Publish - $3.99  ]     |
|  Restore Purchases                   |
+--------------------------------------+
```

**Input props:**
- `clipCount: Int` -- to calculate required minimum tier
- `card: Card` -- to identify which card to upgrade
- `onPurchaseComplete: (CardTier) -> Void` -- callback to resume publish

**Behavior:**
- Auto-selects the minimum tier that covers `clipCount`
- Tiers below the minimum are disabled/grayed out
- Host can select a higher tier if they expect more clips later
- "Upgrade & Publish" button label combines action with price
- On purchase success, calls `onPurchaseComplete` which triggers publish resume

**Presentation:** `.sheet()` from MontagePreviewView, consistent with existing modal patterns.

### Component Detail: TierIndicatorView

Shown in `CardDetailView` in place of the current `upgradeBannerView`:

When under free limit:
```
+--------------------------------------+
|  3 of 5 clips (Free)                |
|  ||||||||___________                  |
+--------------------------------------+
```

When at or over free limit:
```
+--------------------------------------+
|  8 clips submitted                   |
|  ||||||||||||||||||||||               |
|  Upgrade required to publish  -->    |
+--------------------------------------+
```

**This replaces:**
- The current `upgradeBannerView` (only shown when `participants.count >= maxParticipants`)
- The current `needsUpgrade` computed property logic

**Always visible** when clips > 0, so the host always sees tier context. Not just when they hit the wall.

### Integration Points Summary

```
CardDetailView
  |-- reads: viewModel.clips.count, card.maxParticipants
  |-- shows: TierIndicatorView (replaces upgradeBannerView)
  |-- shows: TierCheckoutSheet (when host taps upgrade on indicator)
  |
  +--> MontagePreviewView
         |-- "Publish Card" button always enabled (no change)
         |-- on publish tap: PublishViewModel checks tier
         |     |
         |     +--> if .needsUpgrade: present TierCheckoutSheet
         |     |      +--> on purchase complete: re-trigger publish
         |     |
         |     +--> if within tier: proceed with existing stitch/upload/publish
```

### Interaction Between TierCheckoutSheet Entry Points

The `TierCheckoutSheet` can be opened from two places:
1. **CardDetailView** -- host taps upgrade on `TierIndicatorView` (proactive upgrade)
2. **MontagePreviewView** -- host taps "Publish" and tier check triggers (just-in-time upgrade)

Both entry points use the same `TierCheckoutSheet` component. The difference:
- From CardDetailView: `onPurchaseComplete` just dismisses the sheet and refreshes card data
- From MontagePreviewView: `onPurchaseComplete` dismisses the sheet AND triggers `publishWithStitching()` to resume the publish flow

## Server-Side Considerations

### MVP: Client-Side Recording (Existing Pattern)

The current `UpgradeViewModel.recordCardUpgrade()` writes directly to Supabase after Apple confirms the purchase via RevenueCat. This is sufficient for MVP:

1. User taps "Upgrade & Publish"
2. RevenueCat handles Apple payment
3. On success: `CardService.updateCardMaxParticipants(cardId:, maxParticipants: tier.maxParticipantsValue)`
4. Supabase updates `cards.max_participants`
5. Publish proceeds

**Risk:** If the app crashes between step 2 (payment) and step 3 (DB write), the user paid but the card is not upgraded. RevenueCat has the purchase record, but it is a consumable, so there is no entitlement to restore.

**Mitigation for MVP:** After any purchase, re-check the latest `card.maxParticipants` from Supabase before showing an error. If it was not updated, retry the write. The purchase transaction ID from RevenueCat can be logged for support escalation.

### Post-MVP: Webhook Pipeline

Add a RevenueCat webhook -> Supabase Edge Function for defense in depth:

```
RevenueCat -(webhook)-> Supabase Edge Function
  |
  +-- Receives: NON_RENEWING_PURCHASE event (consumable)
  +-- Extracts: product_id, app_user_id, transaction metadata
  +-- Validates: purchase receipt
  +-- Updates: cards.max_participants for the associated card
```

**Challenge:** The webhook does not know which card the purchase is for. Options:
1. Use RevenueCat subscriber attributes to attach `card_id` before purchase
2. Use the `metadata` field in the purchase if supported
3. Client writes a pending `card_purchases` table row before purchase, webhook matches by user + timestamp

Option 1 (subscriber attributes) is the most straightforward with RevenueCat's API.

## Database Changes

**No schema migration needed.** Reuse `Card.maxParticipants`:
- Change default for new cards from 8 to 5 (in `createCard` or database default)
- Existing cards with `maxParticipants = 8` are grandfathered with 8-clip allowance
- Tier upgrades write the tier's clip limit (10, 25, or 999) to `maxParticipants`

**Optional future migration:** Add a `purchased_tier` column for cleaner semantics:
```sql
ALTER TABLE cards ADD COLUMN purchased_tier integer DEFAULT 0;
```
This is not needed for MVP. The `maxParticipants` column already serves the purpose.

## Build Order (Dependency-Ordered)

### Phase 1: Tier Model + Calculation (Foundation, no UI)
1. Create `CardTier` enum in `TOYShared/Models/CardTier.swift`
2. Add `requiredTier(for:)`, `fromMaxParticipants()`, `maxParticipantsValue`
3. Add computed properties to `CardDetailViewModel` (`requiredTier`, `purchasedTier`, `needsUpgradeToPublish`)
4. Unit test tier calculation logic

**Dependencies:** None. Pure logic.
**Risk:** LOW. No external dependencies.

### Phase 2: Tier Indicator UI (CardDetailView surface)
1. Build `TierIndicatorView` (progress bar + tier label + optional upgrade CTA)
2. Replace `upgradeBannerView` in `CardDetailView` with `TierIndicatorView`
3. Wire to `CardDetailViewModel` computed properties
4. Remove old `needsUpgrade` computed property from `CardDetailView`

**Dependencies:** Phase 1 (CardTier enum).
**Risk:** LOW. UI change only.

### Phase 3: RevenueCat Multi-Product Setup
1. Create 3 consumable products in App Store Connect (toy_card_starter, toy_card_group, toy_card_mega)
2. Configure offering with 3 packages in RevenueCat dashboard
3. Update `PurchaseService.fetchTierPackages()` to return package dictionary
4. Update `UpgradeViewModel` to accept tier selection and purchase specific package
5. Update `recordCardUpgrade()` to write `tier.maxParticipantsValue` instead of 999

**Dependencies:** Phase 1 (CardTier enum), App Store Connect configuration.
**Risk:** MEDIUM. Requires App Store Connect product creation and RevenueCat dashboard configuration. These are external dependencies that cannot be coded locally.

### Phase 4: Checkout UI + Publish Gate (Core Flow)
1. Build `TierCheckoutSheet` (tier carousel, price display, purchase button)
2. Add `.needsUpgrade(CardTier)` case to `PublishState`
3. Add tier check to `PublishViewModel.publishWithStitching()` (check before stitch)
4. Wire `MontagePreviewView` to show `TierCheckoutSheet` on `.needsUpgrade`
5. Wire purchase-complete callback to re-trigger publish
6. Wire `CardDetailView` TierIndicatorView upgrade tap to `TierCheckoutSheet`

**Dependencies:** Phase 1, Phase 2, Phase 3.
**Risk:** MEDIUM. The purchase -> resume-publish flow needs careful state management.

### Phase 5: Edge Cases + Polish
1. Upgrade path: user has starter (10 clips) but now has 15 clips, needs group
2. Error handling: purchase failed, network error during DB write
3. Grandfathering: verify existing cards with `maxParticipants = 8` work correctly
4. Change new card default `maxParticipants` from 8 to 5
5. Remove old `CardUpgradeView` (fully replaced by `TierCheckoutSheet`)

**Dependencies:** Phase 4.
**Risk:** LOW-MEDIUM. Edge cases are bounded.

## Anti-Patterns to Avoid

### Do NOT gate clip submission
Blocking participants from recording destroys UX. Let clips come in freely. Gate only at publish time when the host decides to finalize. The host can always upgrade before publishing.

### Do NOT check RevenueCat entitlements for tier status
RevenueCat entitlements do not work well with consumables -- they show as permanently active after one purchase. Use Supabase `card.maxParticipants` as the source of truth for each card's tier.

### Do NOT create per-card products in App Store Connect
The existing `card_upgrade_{cardId}` product ID pattern in `PurchaseService.isCardUpgraded()` would require creating products dynamically, which Apple does not support. Use generic tier products (`toy_card_starter`, etc.) and track the card association in Supabase.

### Do NOT make the checkout a navigation destination
Use `.sheet()` consistent with the existing `CardUpgradeView` presentation pattern. The checkout is modal -- it interrupts the publish flow, completes, and returns. It is not a screen in the navigation stack.

### Do NOT compute a card's tier from RevenueCat customer info
A host can have multiple cards at different tiers. RevenueCat does not know which consumable purchase went to which card. Always read the tier from `card.maxParticipants` in Supabase.

### Do NOT add a new Supabase column for MVP
The `maxParticipants` column already stores exactly the right information: how many clips this card is paid for. Adding a `purchased_tier` column is unnecessary complexity. The `CardTier.fromMaxParticipants()` mapping handles the translation.

## File Impact Summary

**New files (3):**
| File | Location |
|------|----------|
| `CardTier.swift` | `TOYShared/Sources/TOYShared/Models/` |
| `TierIndicatorView.swift` | `TOY/Features/Monetization/` |
| `TierCheckoutSheet.swift` | `TOY/Features/Monetization/` |

**Modified files (5):**
| File | Change |
|------|--------|
| `CardDetailView.swift` | Replace `upgradeBannerView` with `TierIndicatorView`, update `needsUpgrade` |
| `CardDetailViewModel.swift` | Add tier computed properties |
| `MontagePreviewView.swift` | Add tier check gate, present `TierCheckoutSheet` on `.needsUpgrade` |
| `PublishViewModel.swift` | Add `.needsUpgrade` state, tier check before stitch |
| `UpgradeViewModel.swift` | Support multiple packages, tier selection |

**Modified files (low-touch, 1):**
| File | Change |
|------|--------|
| `PurchaseService.swift` | Add `fetchTierPackages()` method |

**Deleted files (1):**
| File | Reason |
|------|--------|
| `CardUpgradeView.swift` | Replaced by `TierCheckoutSheet.swift` (Phase 5) |

**Unchanged files:**
| File | Reason |
|------|--------|
| `Card.swift` | No model change -- reuse `maxParticipants` |
| `CardService.swift` | `updateCardMaxParticipants` already accepts any Int |
| `HomeView.swift` | No monetization concerns at home level |
| All recording/playback files | No monetization concerns |

## Sources

- Full codebase reading: `CardDetailView.swift`, `CardDetailViewModel.swift`, `MontagePreviewView.swift`, `PublishViewModel.swift`, `CardUpgradeView.swift`, `UpgradeViewModel.swift`, `PurchaseService.swift`, `CardService.swift`, `Card.swift`, `Clip.swift`, `HomeView.swift` (HIGH confidence -- direct code analysis)
- [RevenueCat Non-Subscription Purchases documentation](https://www.revenuecat.com/docs/platform-resources/non-subscriptions) (HIGH confidence -- verified consumable vs non-consumable semantics and redemption tracking)
- [RevenueCat Offerings documentation](https://www.revenuecat.com/docs/offerings/overview) (MEDIUM confidence -- confirmed multi-package offering structure)
- [RevenueCat community: consumable IAP handling](https://community.revenuecat.com/general-questions-7/how-to-handle-consumable-iaps-without-offerings-entitlements-etc-4128) (MEDIUM confidence -- confirmed server-side redemption tracking pattern)
- [RevenueCat community: structuring offerings](https://community.revenuecat.com/general-questions-7/how-should-i-structure-my-offerings-520) (MEDIUM confidence -- confirmed multi-tier offering structure)
