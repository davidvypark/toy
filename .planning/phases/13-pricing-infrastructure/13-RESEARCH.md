# Phase 13: Pricing Infrastructure - Research

**Researched:** 2026-02-08
**Domain:** Tiered consumable IAP pricing model with RevenueCat + Supabase for iOS group video card app
**Confidence:** HIGH

## Summary

Phase 13 establishes the foundational data model and purchase capability that all downstream phases (14: Tier Awareness UI, 15: Checkout & Purchase Flow, 16: Cleanup) depend on. The scope is deliberately narrow: create the `CardTier` enum, update `PurchaseService` for multi-product offerings, change the new-card default from 8 to 5, and ensure grandfathered cards continue working.

The existing codebase has a working monetization skeleton: `PurchaseService` (RevenueCat actor singleton), `UpgradeViewModel` (purchase flow), `CardUpgradeView` (single-product upgrade sheet), and `Card.maxParticipants` (database column, default 8, 999 = unlimited). The current model is binary -- free tier (up to 8 participants) or unlimited upgrade via a single non-consumable purchase. Phase 13 replaces this binary model with graduated tiers using consumable IAPs.

The critical constraint is that `PurchaseService.isCardUpgraded(cardId:)` uses a per-card product ID pattern (`card_upgrade_{cardId}`) that fundamentally cannot work -- it would require creating infinite products in App Store Connect. This must be replaced. The replacement uses Supabase `card.maxParticipants` as the source of truth for each card's tier, not RevenueCat entitlements.

**Primary recommendation:** Create `CardTier` enum in TOYShared as pure logic (no service dependency), add `fetchTierPackages()` to PurchaseService, change NewCard default to maxParticipants=5, and validate that grandfathered cards with maxParticipants=8 work correctly with the new tier logic. Do NOT build UI, checkout flows, or publish-time gates in this phase -- those are phases 14-15.

## Standard Stack

### Core (Already Integrated -- No New Dependencies)

| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| RevenueCat SDK | 5.57.0 | IAP purchase flow, receipt validation | Already integrated in TOYApp.swift; handles StoreKit 2 by default on iOS 16+ |
| Supabase Swift | 2.x | Database (cards table), auth | Already integrated; `card.maxParticipants` is the tier source of truth |
| StoreKit 2 | iOS 17+ | IAP framework (via RevenueCat) | RevenueCat 5.x wraps SK2; no direct StoreKit code needed |

### Supporting (No Changes Needed)

| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| SwiftUI | iOS 17+ | UI framework | All views (no UI work in Phase 13) |
| Kingfisher | 8.x | Image caching | Not relevant to pricing infrastructure |

### Alternatives Considered

| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| RevenueCat for consumables | Raw StoreKit 2 | RevenueCat handles receipt validation, analytics, and cross-platform. Not worth switching for consumables. |
| Supabase for tier tracking | RevenueCat entitlements | Entitlements become permanently active after one consumable purchase -- wrong for per-card model. Supabase is already the source of truth. |
| RevenueCatUI PaywallView | Custom tier UI | PaywallView is designed for subscription paywalls. Not suitable for 3-7 discrete consumable tier products. Custom UI deferred to Phase 15. |

**No installation needed.** All dependencies are already in the project.

## Architecture Patterns

### Recommended File Placement

```
TOYShared/Sources/TOYShared/Models/
    CardTier.swift              # NEW - pure tier enum, no dependencies

TOY/Features/Monetization/
    PurchaseService.swift       # MODIFIED - add fetchTierPackages()
    UpgradeViewModel.swift      # NOT MODIFIED in Phase 13 (Phase 15)
    CardUpgradeView.swift       # NOT MODIFIED in Phase 13 (removed in Phase 16)

TOY/TOYShared/Sources/TOYShared/Models/
    Card.swift                  # MODIFIED - change default maxParticipants from 8 to 5
```

### Pattern 1: CardTier Enum (Pure Value Type in TOYShared)

**What:** An enum that maps between clip counts, tier names, and `maxParticipants` values. Zero dependencies -- no services, no imports beyond Foundation.

**When to use:** Anywhere the app needs to determine what tier a card is on, what tier is required for a clip count, or what the clip limit is for a given tier.

**Why in TOYShared:** `CardTier` is needed by `CardDetailViewModel` (in the main app), and potentially by any future shared component. It has no dependencies on RevenueCat, PurchaseService, or any app-level code. It is pure logic.

**Example:**
```swift
// Source: Architecture decision from .planning/research/monetization/ARCHITECTURE.md
// Lives in TOYShared/Sources/TOYShared/Models/CardTier.swift

import Foundation

/// Pure value type for tier logic. No persistence, no service dependency.
/// Maps between clip counts, tier names, and maxParticipants column values.
public enum CardTier: Int, CaseIterable, Comparable, Sendable {
    case free = 0       // up to 5 clips (new default)
    case starter = 1    // up to 10 clips
    case group = 2      // up to 25 clips
    case mega = 3       // unlimited (999)

    /// The clip limit for this tier (used for display, NOT for enforcement)
    public var clipLimit: Int {
        switch self {
        case .free: return 5
        case .starter: return 10
        case .group: return 25
        case .mega: return .max
        }
    }

    /// Human-readable tier name
    public var displayName: String {
        switch self {
        case .free: return "Free"
        case .starter: return "Starter"
        case .group: return "Group"
        case .mega: return "Mega"
        }
    }

    /// The maxParticipants value to store in Supabase when this tier is purchased
    public var maxParticipantsValue: Int {
        switch self {
        case .free: return 5
        case .starter: return 10
        case .group: return 25
        case .mega: return 999
        }
    }

    /// Whether this tier requires a purchase
    public var isPaid: Bool { self != .free }

    /// Determines the minimum tier required for a given clip count
    public static func requiredTier(for clipCount: Int) -> CardTier {
        for tier in CardTier.allCases {
            if clipCount <= tier.clipLimit { return tier }
        }
        return .mega
    }

    /// Maps from existing maxParticipants column value to a CardTier
    /// Handles legacy values (8 = grandfathered free tier)
    public static func fromMaxParticipants(_ maxParticipants: Int) -> CardTier {
        switch maxParticipants {
        case ...5: return .free
        case 6...10: return .starter
        case 11...25: return .group
        default: return .mega  // 999 or any value > 25
        }
    }

    public static func < (lhs: CardTier, rhs: CardTier) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}
```

**Critical grandfathering detail:** Cards with `maxParticipants = 8` map to `CardTier.free` via `fromMaxParticipants()`, but their actual clip allowance is 8, not 5. The enforcement check should compare `clips.count` against `card.maxParticipants` directly (the database value), NOT against `CardTier.clipLimit`. The `CardTier` enum is for display and pricing purposes only.

### Pattern 2: Grandfathering via Direct maxParticipants Check

**What:** Use `card.maxParticipants` as the authoritative clip limit for enforcement, and `CardTier` only for display/pricing UI.

**When to use:** Any time the app needs to determine if a card needs an upgrade to publish.

**Example:**
```swift
// Enforcement: always compare against the actual database value
let needsUpgradeToPublish = clips.count > card.maxParticipants

// Display: use CardTier for labels and pricing
let currentTier = CardTier.fromMaxParticipants(card.maxParticipants)
let requiredTier = CardTier.requiredTier(for: clips.count)
```

This means:
- Existing cards with `maxParticipants = 8`: can publish up to 8 clips free (grandfathered)
- New cards with `maxParticipants = 5`: can publish up to 5 clips free (new default)
- Both map to `CardTier.free` for display, but enforcement uses the actual column value

### Pattern 3: Multi-Package Offering Fetch

**What:** Fetch all tier packages from a single RevenueCat offering, keyed by custom package identifier.

**When to use:** When PurchaseService needs to provide tier options to downstream UI (Phase 15).

**Example:**
```swift
// Source: RevenueCat Offerings docs (https://www.revenuecat.com/docs/offerings/overview)
// In PurchaseService.swift

/// Fetches all tier packages from the "card_tiers" offering
public func fetchTierPackages() async throws -> [String: Package] {
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

RevenueCat dashboard configuration:
- Offering: set as current/default offering (or create a named "card_tiers" offering)
- Packages with custom identifiers: `starter`, `group`, `mega`
- Each package maps to a consumable App Store Connect product
- No entitlements configured (consumables must NOT be attached to entitlements)

### Pattern 4: NewCard Default Change

**What:** Change `Card.init` default for `maxParticipants` from 8 to 5.

**When to use:** All new cards created after this phase should default to the free tier (5 clips).

**Example:**
```swift
// In Card.swift, change the default parameter:
public init(
    // ... other params ...
    maxParticipants: Int = 5,  // Changed from 8
    // ...
)
```

**Also required:** The Supabase database default for `cards.max_participants` should be changed from 8 to 5. This is a SQL migration:
```sql
ALTER TABLE cards ALTER COLUMN max_participants SET DEFAULT 5;
```

Both the Swift model default AND the database default must change together. The Swift default is used in code-side Card construction (previews, tests). The database default is used when `NewCard` is inserted (since `NewCard` does not include `maxParticipants` -- it relies on the database default).

### Anti-Patterns to Avoid

- **Do NOT gate clip submission on tier.** Participants must always be able to record and submit clips regardless of how many clips exist. Enforcement happens at publish time only (Phase 15).
- **Do NOT check RevenueCat entitlements for tier status.** RevenueCat entitlements become permanently active after one consumable purchase. Always read the tier from `card.maxParticipants` in Supabase.
- **Do NOT create per-card products in App Store Connect.** The existing `card_upgrade_{cardId}` pattern in `PurchaseService.isCardUpgraded()` would require infinite products. Use generic tier products and track card association in Supabase.
- **Do NOT add consumable products to RevenueCat entitlements.** RevenueCat docs explicitly warn: "if you add a consumable product to an entitlement, RevenueCat will report that entitlement as unlocked forever."
- **Do NOT build checkout UI in this phase.** Phase 13 is infrastructure only. The tier selection carousel and publish-time gate are Phase 14 and 15 respectively.
- **Do NOT add new Supabase columns for MVP.** The `maxParticipants` column already stores exactly the right information. A `purchased_tier` column adds complexity without value for MVP.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Receipt validation | Custom Apple receipt verification | RevenueCat SDK | RevenueCat handles all receipt validation with Apple's servers. Building custom verification is error-prone and unnecessary. |
| Product price formatting | Manual currency formatting | `package.localizedPriceString` | RevenueCat provides localized price strings that handle all currencies, decimal separators, and formatting rules. |
| Transaction listener | Custom StoreKit 2 observer | RevenueCat SDK (auto-finishes) | RevenueCat SDK handles transaction finishing by default (`Purchases.shared.finishTransactions = true`). Do not build a custom Transaction.updates listener unless you need to control finishing. |
| Tier calculation logic | Complex service with network calls | Pure `CardTier` enum | Tier logic is a pure function of clip count and maxParticipants. No network call needed. Keep it simple. |

**Key insight:** The existing RevenueCat integration handles all the hard StoreKit/Apple plumbing. Phase 13's code work is almost entirely pure Swift logic (the `CardTier` enum) and a thin wrapper around existing RevenueCat APIs (`fetchTierPackages`).

## Common Pitfalls

### Pitfall 1: Wrong IAP Product Type Causes App Store Rejection

**What goes wrong:** Choosing the wrong IAP product type. Non-consumable products can only be purchased once per Apple ID, which breaks the per-card model (a host who creates multiple cards cannot buy the same tier twice).
**Why it happens:** TOY's model sits in a gray area -- it feels like unlocking permanent content, but the same tier must be purchasable for multiple cards.
**How to avoid:** Use consumable IAPs. Frame the product description correctly: "Publish a card with up to N participants" (one-time action verb) rather than "Unlock N participant slots" (permanent access verb). In App Review notes, explain the per-card model explicitly.
**Warning signs:** App Store rejection citing Guideline 3.1.1; StoreKit refusing re-purchase of non-consumable.

### Pitfall 2: Restore Purchases Button Does Nothing for Consumables

**What goes wrong:** The existing `CardUpgradeView` has a "Restore Purchases" button that calls `purchaseService.restorePurchases()`. For consumable products, this returns nothing -- consumables cannot be restored via StoreKit by design.
**Why it happens:** Consumable purchases are not tracked by Apple for restoration. Once consumed, they are gone from Apple's perspective.
**How to avoid:** Remove the "Restore Purchases" button from any consumable-only purchase UI. TOY's purchase state lives in Supabase (via `card.maxParticipants`), not on-device. When a user signs in on a new device, their cards load from the database -- this IS the restore mechanism. Document this in App Review notes.
**Warning signs:** Users tapping "Restore" and seeing no change; 1-star reviews about "lost purchases."

### Pitfall 3: maxParticipants=8 Cards Break Under New Tier Logic

**What goes wrong:** Existing cards have `maxParticipants = 8`. If the enforcement logic uses `CardTier.clipLimit` (which is 5 for `.free`), existing cards with 6-8 clips would suddenly require a paid upgrade.
**Why it happens:** `CardTier.fromMaxParticipants(8)` returns `.free`, and `.free.clipLimit` is 5. But these cards were created under the old system where 8 was the free limit.
**How to avoid:** Always compare `clips.count` against `card.maxParticipants` (the database value) for enforcement, NOT against `CardTier.clipLimit`. The `CardTier` enum is for display/pricing only. This is the single most important pattern in Phase 13.
**Warning signs:** Existing users seeing upgrade prompts on cards that previously worked fine.

### Pitfall 4: Database Default and Swift Default Out of Sync

**What goes wrong:** If the Swift `Card.init` default is changed to 5 but the Supabase `cards.max_participants` column default stays at 8 (or vice versa), new cards will have inconsistent defaults depending on whether the value comes from code or the database.
**Why it happens:** `NewCard` does NOT include `maxParticipants` in its encoded fields -- it relies on the Supabase database default. If only the Swift default changes, actual new cards in the database still get 8.
**How to avoid:** Change BOTH: the Swift `Card.init` default parameter AND the Supabase column default (via SQL migration). The critical one is the Supabase default, since that is what governs actual card creation.
**Warning signs:** New cards appearing with `maxParticipants = 8` instead of 5 in the database despite the code change.

### Pitfall 5: PurchaseService.isCardUpgraded() Continues to Be Called

**What goes wrong:** Even after adding `fetchTierPackages()`, if `isCardUpgraded(cardId:)` is not deprecated or removed, it may continue to be called by other code, checking for a per-card product ID that will never exist in the new tier model.
**Why it happens:** The method exists and compiles. Nothing prevents other code from calling it. It silently returns `false` for all cards since no products match the `card_upgrade_{cardId}` pattern.
**How to avoid:** In Phase 13, mark `isCardUpgraded(cardId:)` with `@available(*, deprecated, message: "Use card.maxParticipants for tier status")`. Full removal happens in Phase 16 cleanup.
**Warning signs:** Code calling `isCardUpgraded` and getting `false` even for upgraded cards.

## Code Examples

### CardTier Enum Usage

```swift
// Source: Derived from architecture research in ARCHITECTURE.md

// Determine required tier for a card with 12 clips
let required = CardTier.requiredTier(for: 12)  // .group (up to 25)

// Determine purchased tier from database value
let purchased = CardTier.fromMaxParticipants(card.maxParticipants)  // depends on value

// Check if upgrade needed (for display purposes)
let needsUpgrade = required > purchased  // true if card needs upgrade

// But enforcement uses raw database value:
let needsUpgradeToPublish = clips.count > card.maxParticipants

// Grandfathered card example:
let legacyCard = Card(/* ... */ maxParticipants: 8)
CardTier.fromMaxParticipants(8)  // .free (for display)
// But enforcement: clips.count > 8 (allows 8 clips free)

// New card example:
let newCard = Card(/* ... */ maxParticipants: 5)
CardTier.fromMaxParticipants(5)  // .free (for display)
// Enforcement: clips.count > 5 (allows 5 clips free)
```

### Fetching Tier Packages from RevenueCat

```swift
// Source: RevenueCat Offerings docs (https://www.revenuecat.com/docs/offerings/overview)
// In PurchaseService.swift

/// Fetches all tier packages from the current RevenueCat offering.
/// Returns packages keyed by their custom identifier (e.g., "starter", "group", "mega").
public func fetchTierPackages() async throws -> [String: Package] {
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

### Mapping CardTier to RevenueCat Package Identifier

```swift
// Source: Architecture decision from ARCHITECTURE.md

extension CardTier {
    /// The RevenueCat package identifier for this tier.
    /// Returns nil for the free tier (no purchase needed).
    public var packageIdentifier: String? {
        switch self {
        case .free: return nil
        case .starter: return "starter"
        case .group: return "group"
        case .mega: return "mega"
        }
    }
}
```

### NewCard Default Change

```swift
// In Card.swift -- change from:
maxParticipants: Int = 8,
// To:
maxParticipants: Int = 5,
```

### Supabase Migration

```sql
-- Change default for new cards from 8 to 5
ALTER TABLE cards ALTER COLUMN max_participants SET DEFAULT 5;
-- No data migration needed: existing cards keep their maxParticipants = 8 value
```

## State of the Art

| Old Approach (Current) | New Approach (Phase 13) | Impact |
|------------------------|-------------------------|--------|
| Single non-consumable product per card (`card_upgrade_{cardId}`) | Consumable tier products (`starter`, `group`, `mega`) shared across all cards | Hosts can purchase the same tier for multiple cards |
| `maxParticipants` default = 8 | `maxParticipants` default = 5 | New free tier is smaller; existing cards grandfathered at 8 |
| Binary upgrade (free vs unlimited/999) | Graduated tiers (5, 10, 25, 999) | Multiple price points instead of one |
| `PurchaseService.isCardUpgraded(cardId:)` checks RevenueCat non-subscriptions | Tier status read from `card.maxParticipants` in Supabase | Database is source of truth, not RevenueCat |
| Single package from `offerings.current?.availablePackages.first` | Multiple packages from offering, keyed by identifier | Downstream UI can display tier options |

**Deprecated/outdated:**
- `PurchaseService.isCardUpgraded(cardId:)` -- per-card product ID pattern is architecturally broken for tier model. Deprecate in Phase 13, remove in Phase 16.
- The concept of `maxParticipants = 999` as "unlimited" is preserved for backward compatibility but semantically becomes the `mega` tier.

## Scope Boundaries for Phase 13

Phase 13 is infrastructure only. Here is what IS and IS NOT in scope:

### In Scope (Phase 13)

| Item | Requirement | Why Phase 13 |
|------|-------------|--------------|
| `CardTier` enum in TOYShared | PRICE-01, PRICE-05 | Foundation for all tier logic downstream |
| `PurchaseService.fetchTierPackages()` | PRICE-05 | Enables Phase 15 to display and purchase tier products |
| `Card.init` default change (8 -> 5) | PRICE-01 | New cards default to free tier of 5 |
| Supabase column default change (8 -> 5) | PRICE-01 | Database matches code default |
| Deprecate `isCardUpgraded(cardId:)` | PRICE-05 | Mark broken method as deprecated |
| Grandfathering validation | PURCH-04 | Verify cards with maxParticipants=8 work correctly |
| Verify no submission blocking exists | PRICE-02 | Confirm participants can always submit clips |

### Out of Scope (Later Phases)

| Item | Phase | Why Not Phase 13 |
|------|-------|------------------|
| Tier indicator on card detail view | Phase 14 | UI work, depends on Phase 13 enum |
| Publish-time tier gate | Phase 15 | Purchase flow, depends on Phase 13+14 |
| TierCheckoutSheet / carousel | Phase 15 | Checkout UI, depends on Phase 13+14 |
| `PublishViewModel.needsUpgrade` state | Phase 15 | State machine change for publish flow |
| Recording `transactionId` on card | Phase 15 | Purchase recording is part of checkout flow |
| Remove old `CardUpgradeView` | Phase 16 | Cleanup after new system is working |
| Remove `isCardUpgraded(cardId:)` | Phase 16 | Cleanup after deprecation in Phase 13 |

## Open Questions

1. **App Store Connect product creation timing**
   - What we know: Consumable products must be created in App Store Connect and configured in RevenueCat dashboard before `fetchTierPackages()` returns real products.
   - What's unclear: Whether the user has created these products yet or plans to do so as part of this phase.
   - Recommendation: The `fetchTierPackages()` code can be written and tested with a StoreKit Configuration file locally. Real App Store Connect products are needed for sandbox/TestFlight testing but are not blocking for the code work. Create a `.storekit` configuration file with 3 consumable products for local testing.

2. **Number of tiers for initial launch**
   - What we know: The ARCHITECTURE.md research proposes 3 paid tiers (starter/10, group/25, mega/999). The FEATURES.md research proposes 7 paid tiers (10, 25, 50, 100, 150, 200, 250).
   - What's unclear: How many tiers to ship with initially.
   - Recommendation: Start with 3 tiers (starter, group, mega) for Phase 13. The `CardTier` enum can be extended later. Fewer App Store Connect products means fewer review risks and faster initial approval. The PITFALLS.md research explicitly recommends starting with fewer tiers.

3. **StoreKit Configuration file for local testing**
   - What we know: A `.storekit` configuration file enables local testing of consumable purchases without App Store Connect products.
   - What's unclear: Whether one already exists in the project.
   - Recommendation: Create `TOYProducts.storekit` with 3 consumable products matching the tier model. Enable it in the scheme for development.

4. **Tier pricing**
   - What we know: STACK.md proposes $1.99/10, $4.99/25, and escalating for higher tiers. These are placeholder prices.
   - What's unclear: Final pricing decisions.
   - Recommendation: Use placeholder prices in the StoreKit configuration file. Actual prices are an App Store Connect configuration concern, not a code concern. The code uses `package.localizedPriceString` and never hardcodes prices.

## Sources

### Primary (HIGH confidence)
- **Existing codebase analysis** -- `PurchaseService.swift`, `UpgradeViewModel.swift`, `CardUpgradeView.swift`, `Card.swift`, `CardService.swift`, `CardDetailViewModel.swift`, `PublishViewModel.swift`, `TOYApp.swift`, `Configuration.swift` (direct code reading)
- **Prior project research** -- `.planning/research/monetization/ARCHITECTURE.md`, `STACK.md`, `PITFALLS.md`, `FEATURES.md` (comprehensive existing analysis)
- **[RevenueCat: Non-Subscription Purchases](https://www.revenuecat.com/docs/platform-resources/non-subscriptions)** -- Consumable product behavior, entitlement warnings, webhook events
- **[RevenueCat: Offerings Overview](https://www.revenuecat.com/docs/offerings/overview)** -- Multi-package offerings, custom package identifiers for non-subscription products
- **[RevenueCat: Displaying Products](https://www.revenuecat.com/docs/getting-started/displaying-products)** -- Fetching offerings, accessing packages by identifier
- **[RevenueCat: Making Purchases](https://www.revenuecat.com/docs/getting-started/making-purchases)** -- `Purchases.shared.purchase(package:)` API, transaction handling, consumable auto-finishing
- **[Apple: In-App Purchase Types](https://developer.apple.com/help/app-store-connect/reference/in-app-purchase-types/)** -- Consumable = repurchasable, Non-consumable = once per Apple ID

### Secondary (MEDIUM confidence)
- **[Apple: Setting up StoreKit Testing in Xcode](https://developer.apple.com/documentation/xcode/setting-up-storekit-testing-in-xcode)** -- StoreKit configuration file for local consumable testing
- **[RevenueCat SDK 5.0 Blog](https://www.revenuecat.com/blog/engineering/revenuecat-sdk-5-0-the-storekit-2-update/)** -- SDK v5 StoreKit 2 migration details, async/await API
- **[RevenueCat Community: Consumable IAP Handling](https://community.revenuecat.com/general-questions-7/how-to-handle-consumable-iaps-without-offerings-entitlements-etc-4128)** -- No entitlements for consumables, server-side tracking pattern

### Tertiary (LOW confidence)
- **[GitHub: RevenueCat purchases-ios #2086](https://github.com/RevenueCat/purchases-ios/issues/2086)** -- Re-purchasing consumable products edge case (resolved)

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH -- all dependencies already integrated, no new libraries needed
- Architecture: HIGH -- CardTier enum is pure logic with clear mapping to existing database schema; verified against extensive prior research in ARCHITECTURE.md
- Pitfalls: HIGH -- grandfathering risk is the primary concern; clearly mitigated by using `card.maxParticipants` directly for enforcement
- RevenueCat consumable handling: HIGH -- verified against official docs that consumables must NOT use entitlements and offerings support custom package identifiers

**Research date:** 2026-02-08
**Valid until:** 2026-03-08 (stable domain -- RevenueCat SDK and StoreKit 2 are mature)
