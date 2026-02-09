# Technology Stack: Seat-Based Monetization

**Project:** TOY - Seat-based pricing tiers
**Researched:** 2026-02-08
**Overall confidence:** HIGH

## Executive Summary

The existing RevenueCat 5.57.0 + Supabase stack is sufficient for seat-based pricing. No new libraries are needed. The key architectural decision is **consumable products** (not non-consumable), because the same tier product (e.g. "10 participants for $1.99") will be purchased multiple times by the same user across different cards. Non-consumables can only be purchased once ever per Apple ID and are therefore unsuitable.

The current codebase already has the right foundation: `PurchaseService`, `UpgradeViewModel`, `CardUpgradeView`, and a `max_participants` column on the `cards` table. The work is primarily reconfiguration and UI updates, not new infrastructure.

## Critical Decision: Consumable Products

**Recommendation: Use consumable in-app purchases.**

**Confidence: HIGH** -- verified against Apple's IAP type definitions and RevenueCat documentation.

| IAP Type | Can Buy Multiple Times? | Restorable? | Fits TOY? |
|----------|------------------------|-------------|-----------|
| Non-consumable | NO -- once per Apple ID, forever | YES | NO -- user needs to buy $4.99 tier for Card A, then again for Card B |
| Consumable | YES -- unlimited repurchases | NO | YES -- each card is a separate purchase event |
| Non-renewing subscription | YES -- time-limited access | Partially | NO -- card upgrades are permanent, not time-limited |

**Why not non-consumable:** A host who creates 5 cards and upgrades each to the 25-participant tier needs to purchase that $4.99 product 5 separate times. Non-consumables prevent repurchase. Apple would reject this configuration or the purchase would silently restore instead of charging.

**Why consumable works:** Each purchase is a discrete event that unlocks a specific card's tier. The app tracks the card-to-purchase mapping in Supabase, not in StoreKit/RevenueCat entitlements. RevenueCat records the transactions, but the app's database is the source of truth for "which card has which tier."

**Entitlement strategy:** Do NOT attach consumable products to RevenueCat entitlements. RevenueCat docs explicitly state: "logic for keeping track of consumable redemptions must be handled outside of RevenueCat." If you attach a consumable to an entitlement, that entitlement becomes permanently active after the first purchase, which is incorrect for per-card upgrades.

## Recommended Stack

### Existing (No Changes Needed)

| Technology | Version | Purpose | Status |
|------------|---------|---------|--------|
| RevenueCat SDK | 5.57.0 | Purchase flow, receipt validation | Already integrated |
| StoreKit 2 | iOS 17+ | IAP framework (via RevenueCat) | Already active (RevenueCat 5.x uses SK2 by default) |
| Supabase | 2.x | Database, auth, storage | Already integrated |
| SwiftUI | iOS 17+ | UI framework | Already in use |

### App Store Connect: 8 New Products Required

Create 8 consumable products in App Store Connect:

| Product ID | Type | Price | Unlocks |
|------------|------|-------|---------|
| `com.toy.tier.free` | (no product needed) | Free | 5 participants (default) |
| `com.toy.tier.10` | Consumable | $1.99 | 10 participants |
| `com.toy.tier.25` | Consumable | $4.99 | 25 participants |
| `com.toy.tier.50` | Consumable | $14.99 | 50 participants |
| `com.toy.tier.100` | Consumable | $29.99 | 100 participants |
| `com.toy.tier.150` | Consumable | $49.99 | 150 participants |
| `com.toy.tier.200` | Consumable | $69.99 | 200 participants |
| `com.toy.tier.250` | Consumable | $89.99 | 250 participants |

Product IDs encode the tier, making it trivial to derive `max_participants` from the purchased product: parse the number after `com.toy.tier.`.

### RevenueCat Dashboard Configuration

**Offering:** Create one offering called `card_tiers` (replaces or supplements the existing default offering).

**Packages within `card_tiers`:** 7 packages with custom identifiers:

| Package Identifier | Product | Display Order |
|-------------------|---------|---------------|
| `tier_10` | `com.toy.tier.10` | 1 |
| `tier_25` | `com.toy.tier.25` | 2 |
| `tier_50` | `com.toy.tier.50` | 3 |
| `tier_100` | `com.toy.tier.100` | 4 |
| `tier_150` | `com.toy.tier.150` | 5 |
| `tier_200` | `com.toy.tier.200` | 6 |
| `tier_250` | `com.toy.tier.250` | 7 |

Use custom identifiers (not duration-based like "monthly") since these are consumable tier products, not subscriptions. RevenueCat supports custom identifiers for exactly this use case.

**No entitlements to configure.** Consumable products should not be attached to entitlements.

## Supabase Schema Changes

### Cards Table Modifications

The `cards` table already has `max_participants INTEGER DEFAULT 8`. This needs two changes:

1. **Change default from 8 to 5** (new free tier limit)
2. **Add purchase tracking columns**

```sql
-- Migration: 008_seat_based_pricing.sql

-- Change default free tier from 8 to 5
ALTER TABLE cards ALTER COLUMN max_participants SET DEFAULT 5;

-- Add purchase tracking
ALTER TABLE cards ADD COLUMN IF NOT EXISTS purchased_tier TEXT;
-- Values: null (free), 'tier_10', 'tier_25', 'tier_50', 'tier_100', 'tier_150', 'tier_200', 'tier_250'

ALTER TABLE cards ADD COLUMN IF NOT EXISTS purchase_product_id TEXT;
-- The App Store product ID, e.g. 'com.toy.tier.25'

ALTER TABLE cards ADD COLUMN IF NOT EXISTS purchase_transaction_id TEXT;
-- RevenueCat/StoreKit transaction ID for audit trail

ALTER TABLE cards ADD COLUMN IF NOT EXISTS purchased_at TIMESTAMPTZ;
-- When the upgrade was purchased
```

**Why track `purchase_transaction_id`:** For consumable products, RevenueCat cannot tell you which card a transaction belongs to. The transaction ID stored on the card provides an audit trail if disputes arise. It also prevents double-application of a single purchase to multiple cards.

**Why `purchased_tier` AND `max_participants`:** `max_participants` is the enforced limit (used in queries and UI). `purchased_tier` is the semantic record of what was bought (useful for analytics, upgrade/downgrade logic, and customer support). They could diverge if you ever need to grant bonus participants.

### No New Tables Needed

The existing `cards`, `clips`, and `participants` tables are sufficient. The participant count is derived from `COUNT(*)` on participants or clips, not stored redundantly.

### RLS Policy Updates

The existing "Hosts can update own cards" policy already covers the new columns -- no RLS changes needed since hosts already have UPDATE permission on their own cards.

## Purchase Flow Architecture

### Client-Side Flow (No Webhook Needed for MVP)

The simplest correct architecture for this use case:

```
1. Host taps "Upgrade to 25 participants" on publish screen
2. App sets subscriber attribute: Purchases.shared.setAttributes(["pending_card_id": cardId])
3. App calls Purchases.shared.purchase(package: tier25Package)
4. On success, app receives PurchaseResultData with transaction
5. App writes to Supabase: UPDATE cards SET max_participants=25, purchased_tier='tier_25',
   purchase_product_id='com.toy.tier.25', purchase_transaction_id=transaction.id,
   purchased_at=now() WHERE id=cardId AND host_id=auth.uid()
6. App proceeds with publish flow
```

**Why no webhook for MVP:** The purchase and database update happen in the same client session. The user is present and the app can retry the database write if it fails. RevenueCat is still the receipt validation layer (it talks to Apple's servers). The database update is a best-effort record of which card the purchase applies to.

**When to add webhooks:** If you need server-side validation (e.g., someone could theoretically modify the client to skip the purchase), add a Supabase Edge Function webhook later. For an early-stage app with low fraud risk, client-side tracking is sufficient and dramatically simpler.

### Subscriber Attribute Strategy

Set a `pending_card_id` subscriber attribute before initiating purchase. This provides a fallback if the app crashes between purchase and database write:

```swift
// Before purchase
Purchases.shared.setAttributes(["pending_card_id": cardId.uuidString])

// After successful purchase + DB write
Purchases.shared.setAttributes(["pending_card_id": ""])
```

This is a recovery mechanism, not the primary tracking path. The primary path is the immediate database write after purchase success.

### Upgrade Path (Tier Changes)

A host who bought the 10-participant tier ($1.99) and wants to upgrade to 25 ($4.99) makes a new consumable purchase. Each purchase is independent. The app updates `max_participants` to the new tier's value. This means:

- No partial refund logic needed
- No differential pricing (they pay full price for the new tier)
- Simple to implement: new purchase overwrites previous tier on the card
- Consider showing "You already purchased the 10-participant tier" and offering only higher tiers

**Future consideration:** You could implement upgrade pricing (charge only the difference) by creating separate "upgrade from X to Y" products, but this explodes the product matrix. Avoid this complexity at launch.

## What NOT to Add

| Technology | Why Not |
|------------|---------|
| RevenueCatUI PaywallView | Pre-built paywalls are designed for subscription tiers, not per-card consumable selection. You need a custom UI showing the participant tiers for the specific card being upgraded. |
| Supabase Edge Function (webhook) | Premature for MVP. Client-side purchase tracking is sufficient. Add when fraud prevention becomes a real concern. |
| RevenueCat Entitlements | Consumable products should not use entitlements. Entitlements become permanently active after first purchase, which is wrong for per-card upgrades. |
| Additional analytics SDK | PostHog is already integrated per Phase 8 research. Track `card_upgraded` events there. |
| Server-side receipt validation | RevenueCat handles this. Don't build your own Apple receipt validation. |
| `PurchaseParams.with(metadata:)` | This API exists in RevenueCat 5.x source but is gated behind `ENABLE_TRANSACTION_METADATA` compiler flag, which is not enabled in production builds. Do not rely on it. |

## Migration from Current Implementation

The existing code has a single "card upgrade" flow with one product (binary: free vs unlimited). Changes needed:

### PurchaseService.swift
- Replace `isCardUpgraded(cardId:)` which checks `nonSubscriptions` for a specific product ID per card
- Add method to fetch `card_tiers` offering with all 7 packages
- Add method to purchase a specific tier package
- Remove the per-card-UUID product ID approach (`card_upgrade_\(cardId)` was never going to work -- you'd need infinite products in App Store Connect)

### UpgradeViewModel.swift
- Replace single-package loading with multi-tier package display
- Add tier selection state
- Update purchase flow to write tier data to card record
- Change from "ready with one package" to "ready with array of packages"

### CardUpgradeView.swift
- Replace "Upgrade - $X.XX" single button with tier picker
- Show current participant count and what each tier unlocks
- Indicate which tier is already purchased (if upgrading)
- Move from sheet presentation to likely inline in the publish flow

### Card.swift (Model)
- Add `purchasedTier`, `purchaseProductId`, `purchaseTransactionId`, `purchasedAt` optional properties
- Update `CodingKeys`

### CardService.swift
- Replace `updateCardMaxParticipants` with a more comprehensive `upgradeCardTier` method that writes all purchase-related fields atomically

## StoreKit Testing Configuration

Create a `.storekit` configuration file for local testing:

```
// TOYProducts.storekit
// Add all 7 consumable products with their product IDs and prices
// Set type to "Consumable" for each
// Enable StoreKit Testing in scheme to test purchases without App Store Connect
```

This allows testing the full purchase flow in the simulator without needing products configured in App Store Connect first.

## Sources

### HIGH Confidence
- [RevenueCat Non-Subscription Purchases](https://www.revenuecat.com/docs/platform-resources/non-subscriptions) -- Consumable vs non-consumable behavior, entitlement warnings
- [RevenueCat Offerings](https://www.revenuecat.com/docs/offerings/overview) -- Custom package identifiers, offering structure
- [RevenueCat Entitlements](https://www.revenuecat.com/docs/getting-started/entitlements) -- Why not to attach consumables to entitlements
- [Apple IAP Types](https://developer.apple.com/help/app-store-connect/reference/in-app-purchase-types/) -- Consumable = repurchasable, Non-consumable = once ever
- RevenueCat SDK 5.57.0 source code (local checkout) -- `PurchaseParams`, `purchase(package:)`, `ENABLE_TRANSACTION_METADATA` flag verification
- Existing codebase: `PurchaseService.swift`, `UpgradeViewModel.swift`, `CardUpgradeView.swift`, `CardService.swift`, `Card.swift`

### MEDIUM Confidence
- [RevenueCat Webhooks](https://www.revenuecat.com/docs/integrations/webhooks) -- NON_RENEWING_PURCHASE event for consumables, retry policy
- [RevenueCat Customer Attributes](https://www.revenuecat.com/docs/customers/customer-attributes) -- Setting attributes before purchase as fallback tracking
- [RevenueCat Community: Consumable Architecture](https://community.revenuecat.com/general-questions-7/setting-up-a-consumable-in-app-purchase-architecture-387) -- Server-side tracking pattern
- [RevenueCat Community: Tiered Feature Sets](https://community.revenuecat.com/general-questions-7/confused-about-entitlements-products-and-offerings-for-tiered-feature-sets-4488) -- Unique product per tier recommendation

### LOW Confidence
- [RevenueCat Community: Attach Metadata to Purchase](https://community.revenuecat.com/sdks-51/how-to-add-custom-meta-data-to-webhook-after-success-purchasing-2700) -- Subscriber attributes in webhooks can be missing due to race conditions
- [Medium: RevenueCat + Supabase Virtual Currency](https://medium.com/@d13nunes/implementing-revenuecat-virtual-currency-with-supabase-7944bd3444a4) -- Edge function webhook pattern (single community source)
