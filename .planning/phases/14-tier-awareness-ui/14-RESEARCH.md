# Phase 14: Tier Awareness UI - Research

**Researched:** 2026-02-08
**Domain:** SwiftUI tier status indicator + tier selection browsing view for iOS app
**Confidence:** HIGH

## Summary

Phase 14 adds two UI components to the existing card management flow: (1) a tier indicator on the CardDetailView that shows clip count, current tier, and cost to publish when over the free limit, and (2) a tappable tier selection view for proactive browsing of available tiers. This phase is purely display-oriented -- no purchase logic, no payment processing (that is Phase 15).

The implementation is straightforward because Phase 13 delivered a comprehensive `CardTier` enum with all the computational logic needed: `requiredTier(for:)` maps clip counts to tiers, `fromMaxParticipants(_:)` maps database values to tiers, and properties like `displayName`, `clipLimit`, and `isPaid` provide all display data. The ViewModel needs 2-3 computed properties, and the views are standard SwiftUI components matching the existing monochrome design system.

The only meaningful complexity is the scope boundary: Phase 14 builds the tier selection view that Phase 15 will add a purchase button to. This means the tier selection view must be designed with a clear extension point for Phase 15's purchase CTA, but must NOT include any purchase logic itself.

**Primary recommendation:** Build a `TierIndicatorView` component for CardDetailView and a `TierSelectionSheet` for browsing tiers. Both are pure SwiftUI views using existing CardTier enum logic. Replace the current binary `upgradeBannerView` + `needsUpgrade` computed property with the new tier-aware indicator.

## Standard Stack

### Core

| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| SwiftUI | iOS 17+ | All view components | Already used throughout the app |
| CardTier (TOYShared) | Phase 13 | Tier computation logic | Already exists, no new dependency |
| TOY Theme System | Existing | Colors, typography, spacing | Ensures visual consistency |

### Supporting

| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| RevenueCat | 5.x (existing) | Fetch tier package pricing for display | Only for `localizedPriceString` in TierSelectionSheet |
| PurchaseService | Existing actor | Fetch packages to display prices | Used in TierSelectionSheet to show real prices |

### Alternatives Considered

| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| Custom tier indicator | RevenueCat PaywallView | PaywallView is for subscription paywalls, not consumable tier browsing. Custom matches TOY's monochrome design system and is simpler. |
| Fetching prices in ViewModel | Hardcoded price strings | Hardcoded prices would get out of sync with App Store Connect. Always use `localizedPriceString` from RevenueCat packages for display. |

## Architecture Patterns

### Recommended File Structure

```
TOY/Features/Monetization/
    TierIndicatorView.swift        # NEW - indicator component for CardDetailView
    TierSelectionSheet.swift        # NEW - browsable tier list sheet
    CardUpgradeView.swift          # EXISTING - will be replaced by Phase 15's checkout
    UpgradeViewModel.swift         # EXISTING - untouched in Phase 14
    PurchaseService.swift          # EXISTING - used for price fetching only

TOY/Features/CardManagement/
    CardDetailView.swift           # MODIFIED - replace upgradeBannerView, wire TierIndicatorView
    CardDetailViewModel.swift      # MODIFIED - add tier computed properties
```

### Pattern 1: Tier Computation via Computed Properties on ViewModel

**What:** Add computed properties to `CardDetailViewModel` that derive tier status from existing data (clips array and card.maxParticipants). No new network calls, no new state.

**When to use:** Whenever the view needs tier information for display.

**Key insight:** The ViewModel already has `clips: [Clip]` loaded. The `Card` is passed to `CardDetailView` as a parameter. All tier computation is pure local math via `CardTier`.

**Example:**
```swift
// In CardDetailViewModel (add these computed properties)
// Note: card must be stored or passed for purchasedTier calculation

var clipCount: Int { clips.count }

func requiredTier(for card: Card) -> CardTier {
    CardTier.requiredTier(for: clips.count)
}

func purchasedTier(for card: Card) -> CardTier {
    CardTier.fromMaxParticipants(card.maxParticipants)
}

func needsUpgradeToPublish(for card: Card) -> Bool {
    requiredTier(for: card) > purchasedTier(for: card)
}
```

**Why computed properties, not stored state:** The clip count and maxParticipants are already reactive (@Observable on the ViewModel). Computed properties derive automatically when clips change (e.g., new clip submitted). No manual state synchronization needed.

### Pattern 2: Conditional Visibility Based on Free Tier

**What:** The tier indicator is ONLY shown when the card exceeds the free tier (clip count > 5, or for grandfathered cards, > maxParticipants). Success criterion #2 explicitly requires: "When a card is within the free tier (5 or fewer clips), no pricing or tier information appears."

**When to use:** In CardDetailView's body, when deciding whether to show the tier indicator.

**Critical nuance -- grandfathered cards:** A card with `maxParticipants = 8` is grandfathered. For this card, the free allowance is 8 clips, not 5. The tier indicator should NOT appear until clip 9. The correct check uses `card.maxParticipants` (the actual database limit), not `CardTier.free.clipLimit` (which is 5).

**Example:**
```swift
// In CardDetailView body
// Use card.maxParticipants for enforcement threshold (handles grandfathering)
if viewModel.clips.count > card.maxParticipants {
    TierIndicatorView(
        clipCount: viewModel.clips.count,
        requiredTier: viewModel.requiredTier(for: card),
        purchasedTier: viewModel.purchasedTier(for: card),
        onTapUpgrade: { showTierSelection = true }
    )
}
```

**Why `card.maxParticipants` and not `CardTier.free.clipLimit`:** A grandfathered card with maxParticipants=8 and 7 clips should show NO pricing info. Using clipLimit (5) would incorrectly show pricing. CardTier docs explicitly state: "For enforcement, always compare against card.maxParticipants directly."

### Pattern 3: TierIndicatorView as a Stateless Component

**What:** The tier indicator is a pure stateless view that receives all data as parameters. It does not fetch data, manage state, or have a ViewModel.

**When to use:** For the tier indicator displayed inline in CardDetailView.

**Example:**
```swift
struct TierIndicatorView: View {
    let clipCount: Int
    let requiredTier: CardTier
    let purchasedTier: CardTier
    let onTapUpgrade: () -> Void

    var body: some View {
        Button(action: onTapUpgrade) {
            HStack(spacing: TOYSpacing.md) {
                VStack(alignment: .leading, spacing: TOYSpacing.xs) {
                    Text("\(clipCount) clips")
                        .font(.toyBodyMedium())
                        .foregroundColor(.toyText)
                    Text("\(requiredTier.displayName) tier to publish")
                        .font(.toyCaption())
                        .foregroundColor(.toyTextSecondary)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.toyTextSecondary)
            }
            .padding(TOYSpacing.md)
            .background(
                Rectangle()
                    .stroke(Color.toyDivider, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}
```

### Pattern 4: TierSelectionSheet with Price Fetching

**What:** The tier selection sheet is a separate view presented as a `.sheet()` that displays all available tiers with their prices. It fetches real prices from RevenueCat via `PurchaseService.fetchTierPackages()` but does NOT include a purchase button (that is Phase 15).

**When to use:** When the host taps the tier indicator to browse tiers.

**Key design:** This sheet needs to be designed so Phase 15 can add a purchase CTA without restructuring. Use a simple VStack of tier rows. Phase 15 will add a "Purchase" button at the bottom.

**Example:**
```swift
struct TierSelectionSheet: View {
    let card: Card
    let clipCount: Int
    @State private var packages: [String: Package] = [:]
    @State private var isLoading = true
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                TOYBackground()
                ScrollView {
                    VStack(alignment: .leading, spacing: TOYSpacing.xl) {
                        // Header with clip count context
                        // Tier rows (free + paid tiers)
                        // Each row: tier name, clip limit, price
                        // Highlight the required tier for current clip count
                    }
                    .padding(.horizontal, TOYSpacing.lg)
                }
            }
            .task { await loadPrices() }
            .toolbar { /* dismiss button */ }
        }
    }

    private func loadPrices() async {
        do {
            packages = try await PurchaseService.shared.fetchTierPackages()
        } catch { /* handle gracefully */ }
        isLoading = false
    }
}
```

### Pattern 5: Replace, Don't Layer

**What:** The new tier indicator REPLACES the existing `upgradeBannerView` and `needsUpgrade` logic entirely. Do not add the tier indicator alongside the old upgrade banner.

**Why:** The existing `upgradeBannerView` uses `needsUpgrade` which checks `participants.count >= card.maxParticipants` -- this is the old binary "card is full" logic. The new tier indicator uses clip counts and tier computation. The two logics conflict. Also, the existing `showUpgradeSheet` state and `.sheet(isPresented: $showUpgradeSheet)` for `CardUpgradeView` should remain temporarily (Phase 15 will replace it), but the trigger changes.

**Scope boundary:** In Phase 14, replace the upgrade banner trigger with the tier indicator. The tier indicator's tap action opens the new `TierSelectionSheet` for browsing. The old `CardUpgradeView` sheet can remain wired but hidden (Phase 15/16 will clean it up).

### Anti-Patterns to Avoid

- **Fetching prices in CardDetailViewModel:** Price fetching requires a network call to RevenueCat. Do NOT add price fetching to CardDetailViewModel -- it would slow down the card detail load and add complexity to an already-loaded ViewModel. Prices belong only in TierSelectionSheet where they are needed for display.

- **Adding a "Buy" button in Phase 14:** The scope note is explicit -- Phase 14 is display only. The tier selection sheet should show tiers and prices but the actual purchase button is Phase 15. Resist the temptation to "just add the buy button while we're here."

- **Using CardTier.clipLimit for free tier visibility threshold:** For grandfathered cards (maxParticipants=8), using clipLimit (5) would show the tier indicator too early. Always use `card.maxParticipants` as the threshold for "is this card in free territory."

- **Creating a separate ViewModel for TierIndicatorView:** The indicator is a simple stateless view. All data flows from CardDetailViewModel's existing state. A separate ViewModel adds unnecessary indirection.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Tier computation from clip count | Custom if/else chain in views | `CardTier.requiredTier(for:)` | Already exists, tested, handles all edge cases including mega tier |
| Mapping maxParticipants to tier | Custom mapping logic | `CardTier.fromMaxParticipants(_:)` | Handles grandfathering (8 -> .free), tested in Phase 13 verification |
| Localized price strings | Hardcoded "$1.99" etc. | `package.localizedPriceString` from RevenueCat | Handles locale-specific formatting, currency conversion, real pricing |
| Tier display names | Inline string literals | `CardTier.displayName` | Single source of truth for "Free", "Starter", "Group", "Mega" |

**Key insight:** Phase 13 built the CardTier enum specifically so downstream phases don't need to hand-roll tier logic. Every tier computation needed for Phase 14 is a single method call on CardTier.

## Common Pitfalls

### Pitfall 1: Grandfathered Card Display Bug

**What goes wrong:** Showing tier/pricing info on a grandfathered card (maxParticipants=8) when it has 6 clips. The card is within its free allowance but CardTier.free.clipLimit is 5, so a naive check `clips.count > CardTier.free.clipLimit` shows pricing incorrectly.

**Why it happens:** Confusing "display tier" with "enforcement limit." CardTier.fromMaxParticipants(8) returns .free (correct for display), but the actual enforcement limit is 8, not 5.

**How to avoid:** Use `card.maxParticipants` as the visibility threshold, not `CardTier.free.clipLimit`. The CardTier docs (lines 76-84 in CardTier.swift) explicitly warn about this.

**Warning signs:** Tier indicator appearing on a card with 6-8 clips and maxParticipants=8. Test with a Card(maxParticipants: 8) and 7 clips -- indicator should NOT appear.

### Pitfall 2: Clips Count vs. Participants Count Confusion

**What goes wrong:** Using `viewModel.participants.count` instead of `viewModel.clips.count` for tier calculations. The current `needsUpgrade` property uses participants count. The tier system uses clip counts.

**Why it happens:** The old upgrade banner logic was: "are there enough participants to fill all slots?" The new tier logic is: "how many clips exist, and what tier does that require?" A participant who joined but hasn't recorded yet doesn't count toward the clip-based tier.

**How to avoid:** Always use `viewModel.clips.count` for tier calculations. The CardTier enum's `requiredTier(for:)` takes a clip count, not a participant count.

**Warning signs:** If you see `.participants.count` anywhere near tier logic, it's wrong.

### Pitfall 3: Price Fetch Failure Blocking Tier Indicator

**What goes wrong:** If RevenueCat is unreachable, the tier indicator becomes unusable or crashes.

**Why it happens:** The TierIndicatorView is on CardDetailView (always visible for eligible cards). If it depends on price fetching, network failures break it.

**How to avoid:** TierIndicatorView uses NO network calls. It gets all data from CardTier (pure enum) and local clip count. Only TierSelectionSheet fetches prices, and it shows a loading state / graceful error. If prices fail to load, the sheet can still show tier names and clip limits.

**Warning signs:** ProgressView or error state on the main card detail screen for tier info.

### Pitfall 4: Phase 15 Scope Creep

**What goes wrong:** Adding purchase logic, transaction recording, or maxParticipants updates in Phase 14.

**Why it happens:** The tier selection sheet is "right there" and it feels incomplete without a buy button.

**How to avoid:** Phase 14 scope is explicitly "display tier status." The TierSelectionSheet should show tiers and prices but have no purchase CTA. Phase 15 adds the purchase flow. Design the sheet layout with space for a CTA button at the bottom, but leave that space empty or put a placeholder "Purchase available at publish time" message.

**Warning signs:** Any import of `PurchaseService.purchase()` or `CardService.updateCardMaxParticipants()` in new Phase 14 files. The ONLY PurchaseService call in Phase 14 is `fetchTierPackages()` for price display.

### Pitfall 5: Not Removing the Old Upgrade Banner

**What goes wrong:** The old "Card is full" upgrade banner continues to appear alongside the new tier indicator, creating duplicate and conflicting upgrade prompts.

**Why it happens:** The old `upgradeBannerView` and `needsUpgrade` computed property are still in CardDetailView. If the new indicator is added but the old one isn't removed/guarded, both appear.

**How to avoid:** Remove the `if needsUpgrade { upgradeBannerView }` block from CardDetailView when adding the tier indicator. The tier indicator fully replaces this functionality.

**Warning signs:** Two upgrade-related UI elements appearing on the same screen.

## Code Examples

### Example 1: CardDetailViewModel Tier Computed Properties

```swift
// Source: Derived from existing CardTier API (CardTier.swift lines 69-101)
// Add to CardDetailViewModel

/// The number of clips currently on this card
var clipCount: Int { clips.count }

/// The minimum tier required to publish this card based on clip count
func requiredTier(for card: Card) -> CardTier {
    CardTier.requiredTier(for: clips.count)
}

/// The tier this card currently has (from database maxParticipants)
func purchasedTier(for card: Card) -> CardTier {
    CardTier.fromMaxParticipants(card.maxParticipants)
}

/// Whether the card needs a tier upgrade before publishing
func needsUpgradeToPublish(for card: Card) -> Bool {
    requiredTier(for: card) > purchasedTier(for: card)
}
```

### Example 2: TierIndicatorView Component

```swift
// Source: Based on existing CardDetailView design patterns (upgradeBannerView, inviteLinkView)
import SwiftUI
import TOYShared

struct TierIndicatorView: View {
    let clipCount: Int
    let requiredTier: CardTier
    let purchasedTier: CardTier
    let onTapUpgrade: () -> Void

    private var tierStatusText: String {
        if requiredTier == purchasedTier {
            return "\(requiredTier.displayName) tier"
        }
        return "\(requiredTier.displayName) tier to publish"
    }

    var body: some View {
        Button(action: onTapUpgrade) {
            HStack(spacing: TOYSpacing.md) {
                VStack(alignment: .leading, spacing: TOYSpacing.xs) {
                    Text("\(clipCount) clips submitted")
                        .font(.toyBodyMedium())
                        .foregroundColor(.toyText)
                    Text(tierStatusText)
                        .font(.toyCaption())
                        .foregroundColor(.toyTextSecondary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.toyTextSecondary)
            }
            .padding(TOYSpacing.md)
            .background(
                Rectangle()
                    .stroke(Color.toyDivider, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}
```

### Example 3: TierSelectionSheet Structure

```swift
// Source: Based on existing CardUpgradeView patterns and TOY design system
import SwiftUI
import RevenueCat
import TOYShared

struct TierSelectionSheet: View {
    let card: Card
    let clipCount: Int

    @State private var packages: [String: Package] = [:]
    @State private var isLoading = true
    @State private var errorMessage: String?
    @Environment(\.dismiss) private var dismiss

    private var requiredTier: CardTier {
        CardTier.requiredTier(for: clipCount)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                TOYBackground()
                ScrollView {
                    VStack(alignment: .leading, spacing: TOYSpacing.xl) {
                        headerView
                        tierListView
                    }
                    .padding(.horizontal, TOYSpacing.lg)
                    .padding(.vertical, TOYSpacing.lg)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Done") { dismiss() }
                        .font(.toyBody())
                        .foregroundColor(.toyTextSecondary)
                }
            }
        }
        .task { await loadPrices() }
    }

    private var headerView: some View {
        VStack(alignment: .leading, spacing: TOYSpacing.md) {
            Text("Card Tiers")
                .font(.toyTitle())
                .foregroundColor(.toyText)
            Text("\(clipCount) clips on this card")
                .font(.toySubheadline())
                .foregroundColor(.toyTextSecondary)
        }
    }

    @ViewBuilder
    private var tierListView: some View {
        if isLoading {
            ProgressView()
                .frame(maxWidth: .infinity, alignment: .center)
        } else {
            VStack(spacing: TOYSpacing.md) {
                ForEach(CardTier.allCases, id: \.self) { tier in
                    TierRowView(
                        tier: tier,
                        priceString: priceString(for: tier),
                        isRequired: tier == requiredTier,
                        isCurrentTier: tier == CardTier.fromMaxParticipants(card.maxParticipants),
                        clipCount: clipCount
                    )
                }
            }
        }
    }

    private func priceString(for tier: CardTier) -> String? {
        guard let identifier = tier.packageIdentifier,
              let package = packages[identifier] else {
            return tier == .free ? "Free" : nil
        }
        return package.localizedPriceString
    }

    private func loadPrices() async {
        do {
            packages = try await PurchaseService.shared.fetchTierPackages()
        } catch {
            errorMessage = "Unable to load prices"
        }
        isLoading = false
    }
}
```

### Example 4: CardDetailView Integration

```swift
// Source: Existing CardDetailView body structure (lines 119-170)
// Replace the `if needsUpgrade { upgradeBannerView }` block with:

// Tier indicator (only shown when over free allowance)
if viewModel.clips.count > card.maxParticipants {
    TierIndicatorView(
        clipCount: viewModel.clips.count,
        requiredTier: viewModel.requiredTier(for: card),
        purchasedTier: viewModel.purchasedTier(for: card),
        onTapUpgrade: { showTierSelection = true }
    )
}

// Add to CardDetailView:
// @State private var showTierSelection = false
// .sheet(isPresented: $showTierSelection) {
//     TierSelectionSheet(card: card, clipCount: viewModel.clips.count)
// }
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| Binary "Card is full" banner | Tier-aware indicator with clip count + tier status | Phase 14 | Host always knows tier cost before publishing |
| `needsUpgrade` based on participants.count | `clips.count > card.maxParticipants` + CardTier computation | Phase 14 | Correct tier calculation, handles grandfathered cards |
| Single "Upgrade for unlimited" CTA | Multi-tier browsing with per-tier pricing | Phase 14 | Host can explore options proactively |
| `CardUpgradeView` (single product) | `TierSelectionSheet` (multi-tier browse) | Phase 14 (browse) / Phase 15 (purchase) | Supports 4-tier pricing model |

**Deprecated/outdated:**
- `CardDetailView.needsUpgrade` computed property: Uses participants.count instead of clips.count. Replace with tier-based visibility check.
- `CardDetailView.upgradeBannerView`: Binary "card is full" message. Replace with TierIndicatorView.
- `CardDetailView.showUpgradeSheet` + `CardUpgradeView` sheet: Will be replaced over Phase 14-15. In Phase 14, wire to new TierSelectionSheet instead.

## Open Questions

1. **Should the tier indicator show price inline?**
   - What we know: FEATURES.md D7 suggests showing price inline ("13 friends joined -- that's the $4.99 tier"). The success criteria says "cost to publish when over free limit." This implies showing the price on the indicator itself.
   - What's unclear: Showing the price inline requires fetching RevenueCat packages on CardDetailView load, which adds a network call. The alternative is showing just the tier name ("Starter tier") and revealing price only when the user taps to open TierSelectionSheet.
   - Recommendation: Show the tier name inline on the indicator (no network call needed -- just CardTier.displayName). Show actual prices in TierSelectionSheet only. This is the cleanest separation and avoids network dependency on the main screen. If user later wants inline pricing, it can be added as an enhancement. The success criteria says "cost to publish" which can be satisfied by the price being one tap away in the TierSelectionSheet.

2. **How prominently should the tier indicator integrate into CardDetailView layout?**
   - What we know: FEATURES.md says "Position: Below the summary stats, above the contributor list." The current upgradeBannerView sits in that position. ARCHITECTURE.md says it replaces `upgradeBannerView`.
   - What's unclear: Should it be styled as an attention-getting element (like the Record Your Clip CTA with solid background) or a subtle informational row (like the invite link)?
   - Recommendation: Use the subtle informational style (outlined border, like inviteLinkView or the current upgradeBannerView). The FEATURES.md specifically says "informational, not urgent. Think iCloud storage meter, not a DANGER: disk full warning." Use `Rectangle().stroke(Color.toyDivider)` border, not a solid fill.

3. **Should TierSelectionSheet visually highlight which tier the user "needs"?**
   - What we know: The required tier (based on current clip count) should be visually differentiated from other tiers. The user needs to understand "this is the tier you're on" vs "this is what's available."
   - What's unclear: The exact visual treatment for highlighting.
   - Recommendation: Use a bolder border (`.toyText` instead of `.toyDivider`) on the required tier row, and add a small label like "Your tier" or "Required." Keep other rows with the standard `.toyDivider` border. This matches the existing monochrome design language without introducing new colors.

## Sources

### Primary (HIGH confidence)
- `TOY/TOYShared/Sources/TOYShared/Models/CardTier.swift` -- Complete tier enum API (4 tiers, all computation methods, grandfathering logic)
- `TOY/Features/CardManagement/CardDetailView.swift` -- Current card detail layout, upgrade banner, design patterns
- `TOY/Features/CardManagement/CardDetailViewModel.swift` -- ViewModel structure (@Observable, clips array, data loading)
- `TOY/Features/Monetization/CardUpgradeView.swift` -- Existing upgrade UI patterns, TOY design system usage
- `TOY/Features/Monetization/PurchaseService.swift` -- fetchTierPackages() API for price display
- `.planning/phases/13-pricing-infrastructure/13-VERIFICATION.md` -- Confirmed Phase 13 deliverables (all 5 truths verified)
- `.planning/ROADMAP.md` -- Phase 14 success criteria, requirements TIER-01 and TIER-02
- `.planning/research/monetization/ARCHITECTURE.md` -- TierIndicatorView design, data flow patterns, integration points
- `.planning/research/monetization/FEATURES.md` -- D2 (tier awareness indicator), D7 (pricing context), D8 (proactive upgrade) specifications
- `TOY/TOYProducts.storekit` -- Actual product pricing: starter $1.99, group $4.99, mega $9.99

### Secondary (MEDIUM confidence)
- `.planning/research/monetization/FEATURES.md` -- Competitive analysis of tier awareness patterns (Kudoboard, GitHub, iCloud)
- `.planning/STATE.md` -- Prior decisions on consumable IAPs, client-side recording, static visualization

### Tertiary (LOW confidence)
- None. All findings verified directly from codebase inspection.

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH -- All libraries already in use, no new dependencies
- Architecture: HIGH -- Patterns directly derived from existing CardDetailView code and CardTier API
- Pitfalls: HIGH -- Grandfathering edge case is well-documented in CardTier.swift; scope boundary is explicitly defined in ROADMAP

**Research date:** 2026-02-08
**Valid until:** 2026-03-08 (stable -- no external dependencies likely to change)
