# Feature Landscape: Seat-Based Monetization UX

**Domain:** Tiered pricing UX for consumer iOS group video card app
**Researched:** 2026-02-08
**Overall Confidence:** HIGH (based on competitive analysis of 7+ apps, iOS paywall research, UX psychology research, and existing codebase analysis)

## Current State Analysis

Before listing features, here is what TOY has today and what needs to change for the new seat-based pricing model.

**What exists:**
- `Card.maxParticipants` field (default 8, upgraded to 999 for "unlimited")
- `CardUpgradeView` with a single non-consumable purchase (one price, unlocks "unlimited")
- `UpgradeViewModel` loads a single RevenueCat package from the current offering
- `PurchaseService` actor wrapping RevenueCat for fetch/purchase/restore
- Upgrade banner on `CardDetailView` that appears when `participants.count >= maxParticipants`
- Banner says "Card is full" with "Upgrade for unlimited participants"

**What needs to change for seat-based tiers:**
1. The single "unlimited" upgrade must become 8 discrete tiers: 5 free, 10/$1.99, 25/$4.99, 50/$14.99, 100/$29.99, 150/$49.99, 200/$69.99, 250/$89.99
2. Payment timing shifts from "upgrade when full" to "pay at publish time"
3. Participants should never be blocked from recording (collect all clips, pay for the tier you need when you publish)
4. The current "Card is full" binary state becomes a progressive tier awareness indicator
5. Checkout needs a tier selection carousel, not a single "buy" button
6. The upgrade flow needs to feel fun and generous, not restrictive

**TOY's unique positioning vs competitors:**

| Competitor | Model | Payment Timing | Participant Limits |
|-----------|-------|---------------|-------------------|
| Tribute | Flat $35-99+ | Before collecting videos | Unlimited |
| VidDay | Per-video $24-60 | At download/export | Unlimited |
| Kudoboard | Per-board $5.99-19.99 | Per-board tiers by posts | 10 free, then paid |
| Celebrate | Flat $29.99 | At download | Unlimited |
| Memento | Subscription $29.99/mo | Before download | 3 free clips |
| **TOY** | **Tiered by participants** | **At publish time** | **5 free, up to 250** |

TOY's model is unique: it is the only group video app that (a) scales pricing by number of participants and (b) defers payment to publish time. This is a competitive advantage if the UX is right. Competitors either charge flat rates or subscriptions. TOY's per-participant pricing lets casual users pay nothing (5 free) while large groups pay proportionally.

---

## Table Stakes

Features users expect for any monetization flow. Missing any of these creates friction, confusion, or distrust.

| # | Feature | Why Expected | Complexity | Confidence | Real-World Reference |
|---|---------|-------------|------------|------------|---------------------|
| T1 | **Transparent price display before commitment** | Users must always know what they will pay before taking any action. Hiding pricing behind multiple taps makes users assume deception. Studies show clear upfront pricing reduces bounce rates by up to 40%. | LOW | HIGH | Every app store listing, Kudoboard's tier comparison cards, VidDay's "pay only when ready" messaging |
| T2 | **Free tier that works without any payment friction** | The first 5 participants must work with zero mention of payment, credit cards, or upgrade prompts. Spotify, Duolingo, and Slack all provide genuine free tiers without constant monetization pressure during the free period. "Freemium users become familiar with workflows and build habits, making them more likely to pay when they encounter limits." | LOW | HIGH | Spotify free tier, Duolingo hearts system, Kudoboard 10-post free board |
| T3 | **Restore purchases mechanism** | Apple requires this. Users who reinstall or switch devices must recover paid upgrades. The existing `PurchaseService.restorePurchases()` handles this already but needs to restore the correct tier, not just "unlimited." | LOW | HIGH | Apple App Store Review Guidelines requirement, already partially implemented |
| T4 | **Clear participant count indicator on card detail** | The host must always know how many people have submitted and what tier they are on. This is the equivalent of Kudoboard showing "X of 20 posts used." The current `summaryStatsView` shows "X of Y clips submitted" but does not show tier context. | LOW | HIGH | Kudoboard per-board limits, Eventbrite capacity indicators, GitHub seat counts |
| T5 | **Payment at publish time only** | The founder's requirement: never block participants from recording, collect everything, pay only when publishing. This mirrors VidDay ("free to start, pay only when ready to download"), Celebrate ("pay when ready to complete"), and Tribute ("free to create, pay to publish"). This is the dominant pattern in group video/card apps. | MEDIUM | HIGH | VidDay, Celebrate, Tribute all use this exact pattern |
| T6 | **User-initiated upgrade (no auto-charge)** | The host explicitly chooses to upgrade. No surprise charges. This mirrors Figma's 2025 change where "seat upgrades that incur additional costs need admin approval" and GitHub's explicit "Add seats" button. User-initiated payment builds trust. | LOW | HIGH | Figma seat approval flow, GitHub seat management |
| T7 | **Error handling and retry for failed purchases** | StoreKit transactions can fail for many reasons (network, declined card, parental controls). The existing error state in `UpgradeViewModel` handles this but needs refinement for tier-specific failures. | LOW | HIGH | Already partially implemented, standard RevenueCat pattern |

---

## Differentiators

Features that make TOY's pricing feel fun, generous, and delightful rather than transactional. These are what separate "I have to pay" from "I want to support this."

| # | Feature | Value Proposition | Complexity | Confidence | Real-World Reference |
|---|---------|------------------|------------|------------|---------------------|
| D1 | **"Never block" philosophy with visual grace** | When participant count exceeds the free tier (5), do NOT show a paywall or block. Instead, show all clips as normal. At publish time, present the appropriate tier. The key insight: let the host see that 12 people recorded messages for their friend. The emotional investment of seeing those faces makes upgrading feel like "of course I'll pay $1.99 to include everyone" rather than "ugh, another paywall." This is Spotify's "you discovered a Premium feature" reframing -- restriction as discovery, not punishment. | MEDIUM | HIGH | Spotify's discovery framing, Tribute's "100% free to start," VidDay's unlimited collection |
| D2 | **Tier awareness indicator on card detail** | Instead of the binary "Card is full" banner, show a friendly progress visualization: "12 friends joined -- you're on the $1.99 tier (up to 10) -- 2 more friends pushed you to $4.99 tier (up to 25)." This makes the pricing feel transparent and progressive. The visualization should show the current tier, remaining capacity in that tier, and what the next tier costs. Think of it like a gas gauge that also shows you the price. | MEDIUM | HIGH | Kudoboard post limits, GitHub seat usage dashboard, storage meters in iCloud/Google Drive |
| D3 | **Horizontal snap carousel for tier selection at checkout** | At publish time, show a horizontally scrollable carousel of tier cards. The current tier is centered and highlighted. Previous and next tiers are partially visible on either side, inviting exploration. Snap to each card on swipe. This is the pattern recommended by mobile pricing UX experts: "When you have a lot of plans, stacking cards or navigating with tabs won't cut it. Use a sliding carousel." For 8 tiers, a carousel is the only pattern that works on mobile. | MEDIUM | HIGH | Superwall paywall patterns, NamiML horizontal product lists, App Store subscription selection |
| D4 | **Celebratory publish moment** | After successful purchase and publish, show a brief celebratory animation. Confetti, a checkmark, or a delightful transition. Duolingo's purchase success feels rewarding. The current `successContent` shows a static checkmark -- this should feel like a moment worth celebrating. The host just created something meaningful for someone they care about. | LOW | MEDIUM | Duolingo achievement celebrations, Headspace session completion, Apple Pay success haptic |
| D5 | **Per-participant cost framing** | On the tier selection carousel, show not just the total price but the per-person cost: "$4.99 for 25 participants = $0.20 each." This reframing makes even higher tiers feel affordable. "$29.99 for 100 people = $0.30 per person" sounds trivially cheap for a video gift. This is price anchoring: the per-unit cost is so low it eliminates pricing anxiety. | LOW | HIGH | Kudoboard multi-board discounts, Eventbrite per-ticket pricing, Amazon per-unit pricing |
| D6 | **Smart tier auto-selection** | At publish time, auto-select the cheapest tier that fits the current participant count. If 12 people participated, auto-scroll the carousel to the $4.99 / 25-participant tier (not the exact-fit $1.99 / 10 tier, because 12 > 10). The host sees this pre-selected but can scroll to explore other options. This reduces decision anxiety -- the app already made the smart choice. | LOW | HIGH | Slack auto-billing to correct seat count, GitHub prorated seat billing |
| D7 | **"Just for you" pricing context** | On the card detail view, show a friendly one-liner like "13 friends joined -- that's the $4.99 tier when you're ready to publish." This is not a paywall. It is informational. It appears alongside the participant list as ambient context. The host always knows the cost without needing to navigate to a checkout screen. | LOW | HIGH | Spotify's plan details in settings, iCloud storage tier indicator |
| D8 | **Tier upgrade from card detail (pre-publish)** | Allow the host to proactively upgrade their card's tier before publish time. Maybe they know they are inviting 50 people and want to lock in that tier now. This is the "user-initiated upgrade" pattern from the requirements. Present it as optional, not required. | MEDIUM | MEDIUM | GitHub's "Add seats" preemptive action, Figma seat request flow |

---

## Anti-Features

Features to explicitly NOT build. These are common mistakes in pricing UX that would hurt TOY's brand or user experience.

| Anti-Feature | Why Avoid | What to Do Instead |
|-------------|-----------|-------------------|
| **Hard paywall when free tier exceeded** | Never block a participant from recording because the host hasn't paid yet. The founder's explicit requirement is "never block participant submissions." Blocking recordings means lost emotional content that can never be recreated. A grandmother's birthday message lost because the host didn't upgrade in time is an irreversible UX failure. | Let everyone record. Resolve payment at publish time. The host sees all clips and decides then. |
| **Auto-upgrade / auto-charge when limit exceeded** | Surprise charges destroy trust. Memento charges subscriptions; users hate it (Trustpilot complaints). The host must explicitly choose to pay. No silent tier bumps. | Show informational tier indicator. Payment only happens when the host taps "Publish" and confirms tier selection. |
| **Subscription model** | Competitors like Memento use subscriptions ($29.99/mo) and get poor reviews for it. TOY's use case is event-based (birthdays, weddings, retirements). A subscription for something you use 2-3 times a year feels extractive. Kudoboard's per-board pricing and VidDay's per-video pricing both outperform subscription models in user satisfaction for this category. | Keep one-time per-card purchases. Each card is an independent transaction. |
| **Complex pricing table with feature comparisons** | TOY tiers differ only in participant count, not features. A feature comparison table (like SaaS products use) implies different capabilities per tier. All TOY tiers get the same features -- the only variable is how many people can participate. A feature table would confuse users. | Show tiers as a simple escalation: more people = higher tier. All features identical across tiers. |
| **Hiding the free tier or downplaying it** | Some apps bury the free option to push paid conversions. Research shows this backfires: "people hate losing money more than they enjoy gaining something of equal value." A visible, genuine free tier builds trust. Users who have a good free experience become paying users on their next card. | Make the free tier prominent. "5 friends, totally free" should be the first thing users see. |
| **Urgency/scarcity pressure tactics** | "Upgrade NOW -- offer expires in 24 hours!" or "Only 2 spots left!" These tactics are appropriate for e-commerce, not for a heartfelt video gift app. The emotional context (making something for a loved one) makes pressure tactics feel gross. | Let the product sell itself. 15 people recorded video messages for your friend's birthday. The value is self-evident. |
| **Multiple payment touchpoints** | Do not prompt for payment at card creation, at invite sending, at participant joining, AND at publish time. Pick one moment. Every additional payment prompt increases the chance the host abandons the card. Tribute's model (pay before collecting videos) is worse than VidDay's (pay at download). | Single payment moment at publish time. Everything before that is free and frictionless. |
| **RevenueCat pre-built PaywallView for tier selection** | RevenueCat's `PaywallView` is designed for subscription paywalls (annual vs monthly). It is not designed for 8 discrete one-time purchase tiers with a carousel UX. Forcing TOY's tier model into RevenueCat's paywall template would produce a generic, un-branded experience. | Build a custom tier selection view using RevenueCat's programmatic API (`Purchases.shared.purchase(package:)`). Use RevenueCat for the purchase transaction but own the UI completely. |

---

## Feature Dependencies

```
T2 (free tier works) -- foundation, no dependencies
    |
    v
T4 (participant count indicator) -- shows count context
    |
    +-- D2 (tier awareness indicator) -- extends T4 with pricing context
    |       |
    |       v
    |   D7 ("just for you" pricing context) -- ambient one-liner from D2 data
    |
    v
T5 (payment at publish time) -- core flow change
    |
    +-- D6 (smart tier auto-selection) -- needs T5's checkout trigger
    |
    +-- D3 (carousel for tier selection) -- the UI for T5's checkout
    |       |
    |       v
    |   D5 (per-participant cost framing) -- label within D3 cards
    |
    +-- D1 ("never block" philosophy) -- T5 enables this naturally
    |
    v
T6 (user-initiated upgrade) -- purchase confirmation step
    |
    v
T1 (transparent price display) -- visible throughout D2, D3, D7
    |
    v
D4 (celebratory publish moment) -- after successful T6 purchase
    |
    v
T3 (restore purchases) -- cleanup, independent but needed
    |
    v
D8 (proactive tier upgrade) -- optional, can be added later
```

**Key insight:** The dependency chain flows from "free experience" (T2) through "tier awareness" (T4, D2) to "publish-time payment" (T5, D3, D6) to "celebration" (D4). This is also the user's emotional journey: discover the app for free, see it work beautifully, understand what they'll pay, pay happily, celebrate.

---

## The "Free Tier Exceeded" Moment -- Detailed Analysis

This is the single most important UX moment in TOY's monetization. When the 6th person records a clip on a free card, what happens? This moment determines whether the host feels punished or supported.

### What Competitors Do

| App | When Limit Exceeded | User Sees | Tone |
|-----|---------------------|-----------|------|
| Kudoboard | 11th post on free board | "Upgrade to Lite ($5.99) for up to 20 posts" | Transactional |
| Memento | 4th clip on free tier | Subscription paywall blocks access | Punishing |
| Tribute | No limit (pay before collecting) | N/A -- payment happens first | Preemptive |
| VidDay | No limit (unlimited contributors) | N/A -- payment happens at download | Absent |
| Spotify | Skip limit reached | "You discovered a Premium feature" | Aspirational |
| Slack | Search limit reached | "Learn more" link, no hard block | Gentle |
| Duolingo | Hearts depleted | "Watch an ad or get Super Duolingo" | Gamified |

### What TOY Should Do

**Approach: "More friends showed up" (celebratory reframing)**

When the 6th participant records on a free-tier card:
1. The host sees the clip appear in their contributor list like any other clip
2. No popup, no banner, no alert
3. The tier awareness indicator (D2) updates naturally: "6 friends joined" with a subtle note that the publish tier is now $1.99
4. At publish time, the carousel (D3) auto-selects the correct tier

The psychological principle: Spotify reframes limits as "discoveries." TOY should reframe exceeded limits as "more friends showed up for your person." The 6th clip is a sign that people care, not a billing event.

**The language matters:**
- BAD: "You've exceeded your free tier. Upgrade to continue."
- BAD: "Card is full. Upgrade for unlimited participants."
- GOOD: "13 friends joined! When you're ready to publish, that's the $4.99 tier."
- BETTER: "13 friends recorded messages for Sarah. Publish for $4.99."

The focus stays on the recipient and the emotional content, not on the transaction.

---

## Checkout Carousel -- Detailed Design Pattern

The publish-time checkout is the revenue-critical screen. Based on research into mobile pricing carousels:

### Layout

```
+----------------------------------+
|                                  |
|  Ready to publish?               |
|  13 friends recorded for Sarah   |
|                                  |
|  +------+ +--------+ +------+   |
|  | $1.99| | $4.99  | |$14.99|   |
|  | 10   | |  25    | |  50  |   |
|  | ppl  | |  ppl   | |  ppl |   |
|  |      | |  *YOU* | |      |   |
|  +------+ +--------+ +------+   |
|                                  |
|  $4.99 for up to 25 friends      |
|  That's $0.38 per person         |
|                                  |
|  [ Publish Card - $4.99 ]        |
|                                  |
|  Restore Purchases               |
+----------------------------------+
```

### Key Design Decisions

1. **Show 3 cards at a time** with the selected tier centered and emphasized. Adjacent tiers peek from the sides, inviting swipe exploration. This leverages the "page gutter" pattern recommended for iOS to avoid swipe ambiguity.

2. **Current tier pre-selected** based on participant count. The carousel auto-scrolls to the cheapest tier that accommodates all participants. The host can swipe to explore but the default is always correct.

3. **Per-person cost shown** below the selected tier card. This reframing eliminates pricing anxiety: "$0.38 per person" for a personalized video gift is a no-brainer.

4. **Free tier card included** when applicable (5 or fewer participants). If the host has 4 participants, the free tier is centered with "Publish Free" as the CTA. No payment required.

5. **Dim unavailable tiers** -- tiers that cannot accommodate the current participant count should appear dimmed (but still scrollable for exploration). The host can see "you'd need at least the $4.99 tier" without being confused.

6. **Single CTA button** at the bottom. Text updates as the user scrolls: "Publish Free" / "Publish Card - $1.99" / "Publish Card - $4.99". The button is always at the bottom, always visible, always clear about what it costs.

### Psychology Applied

- **Anchoring:** The carousel naturally shows higher-priced tiers to the right, making the selected tier feel like a deal by comparison.
- **Decoy effect:** Mid-range tiers look attractive compared to adjacent options.
- **Loss aversion mitigation:** The host has already seen all the clips. They are not "buying a service" -- they are "including everyone's message." The emotional sunk cost works in favor of conversion.
- **Three-second rule:** The pricing page must communicate cost and value within 3 seconds. "13 friends, $4.99, $0.38 each" -- done.

---

## Tier Awareness Indicator -- Detailed Design Pattern

On the card detail view, replace the binary "Card is full" / no banner with a persistent, informational tier indicator.

### When to show

| Participant Count | What to Show |
|------------------|-------------|
| 0-5 | Nothing (free tier, no pricing mention) |
| 6-10 | "6 friends joined -- $1.99 to publish (up to 10)" |
| 11-25 | "13 friends joined -- $4.99 to publish (up to 25)" |
| 26-50 | "34 friends joined -- $14.99 to publish (up to 50)" |
| 51+ | Pattern continues per tier |

### Visual Treatment

The indicator should feel informational, not urgent. Think iCloud storage meter, not a "DANGER: disk full" warning.

- **Position:** Below the summary stats, above the contributor list
- **Style:** Same understated design language as the rest of CardDetailView (toyBody font, toyTextSecondary for supporting text)
- **Tone:** Factual, not promotional. "13 friends" not "13/25 slots used"
- **Tap action:** Tapping opens the tier selection carousel for exploration (D8 proactive upgrade)

---

## MVP Recommendation

For the monetization milestone, prioritize in this order:

### Wave 1: Data Model and Core Flow (must ship together)

1. **T2** -- Free tier works frictionlessly (verify current 5-participant default works without payment mention)
2. **T5** -- Payment at publish time only (restructure the publish flow to include tier check)
3. **D1** -- Never block participants (remove any hard limits on participant recording)
4. **D6** -- Smart tier auto-selection (compute correct tier from participant count)
5. **T1** -- Transparent price display (prices visible wherever tier context appears)
6. **T6** -- User-initiated upgrade at publish (explicit purchase confirmation)
7. **T3** -- Restore purchases for correct tier

### Wave 2: UI Polish (makes it delightful)

1. **D3** -- Horizontal snap carousel for tier selection at checkout
2. **D5** -- Per-participant cost framing on carousel cards
3. **T4** -- Participant count indicator with tier context
4. **D2** -- Tier awareness indicator on card detail view
5. **D7** -- Ambient pricing one-liner

### Wave 3: Celebratory Touches (makes it fun)

1. **D4** -- Celebratory publish animation
2. **D8** -- Proactive tier upgrade from card detail (optional, nice-to-have)

**Defer to future milestones:**
- A/B testing different pricing presentations (need baseline conversion data first)
- Tier-specific promotional pricing or discounts
- Group gifting / cost-splitting among participants

---

## RevenueCat Implementation Notes

The current implementation uses a single offering with one package. The tier model requires:

**RevenueCat Dashboard Setup:**
- Create 8 products in App Store Connect (one per tier, non-consumable)
- Create a single offering in RevenueCat with 8 packages
- Package identifiers should map to tier participant counts: `tier_5_free`, `tier_10`, `tier_25`, `tier_50`, `tier_100`, `tier_150`, `tier_200`, `tier_250`

**Code Changes:**
- `PurchaseService.fetchOfferings()` already returns all packages -- the carousel displays them
- `UpgradeViewModel` needs to handle tier selection (which package to purchase) instead of just "the first available package"
- `recordCardUpgrade()` needs to set `maxParticipants` to the purchased tier's limit, not 999
- The free tier (5 participants) does not involve RevenueCat at all -- it is just the default

**Critical decision:** Non-consumable vs consumable products. Non-consumable means each tier purchase is permanent and restorable. Consumable means the purchase is "used up" and cannot be restored. For TOY's model (one purchase per card, tied to a specific card), **non-consumable is correct** because Apple requires restore functionality and the purchase should survive device changes. However, per-card tracking requires storing the card ID alongside the purchase in the app's database, because RevenueCat entitlements are user-level, not card-level. The existing `recordCardUpgrade()` pattern of writing to the database is the right approach.

---

## Sources

### PRIMARY (HIGH confidence)
- [Kudoboard Pricing Page](https://www.kudoboard.com/pricing/) -- Tier structure and per-board limits
- [RevenueCat: Creating Paywalls](https://www.revenuecat.com/docs/tools/paywalls/creating-paywalls) -- Paywall design guidance
- [RevenueCat: Guide to Mobile Paywalls](https://www.revenuecat.com/blog/growth/guide-to-mobile-paywalls-subscription-apps/) -- Conversion best practices
- [Superwall: 20 iOS Paywalls in Production](https://superwall.com/blog/20-ios-paywalls-in-production/) -- Real paywall design patterns
- [Figma Blog: Updates to Pricing, Seats, and Billing Experience](https://www.figma.com/blog/billing-experience-update-2025/) -- Seat-based pricing UX changes
- [GitHub Docs: Managing User Licenses](https://docs.github.com/en/billing/using-the-new-billing-platform/adding-seats-to-your-account) -- Seat management UX

### SECONDARY (MEDIUM confidence)
- [Appcues: Best Freemium Upgrade Prompts](https://www.appcues.com/blog/best-freemium-upgrade-prompts) -- Spotify, Slack, Dropbox upgrade patterns
- [Glance: Psychology of Effective App Pricing Pages](https://thisisglance.com/learning-centre/whats-the-psychology-of-effective-app-pricing-pages) -- Pricing anxiety reduction
- [Celebrate vs VidDay vs Tribute vs Memento Comparison](https://www.celebrate.buzz/blog/celebrate-vs-vidday-vs-tribute-vs-memento) -- Competitor pricing models
- [NamiML: 20 Types of Mobile App Paywalls](https://www.nami.ml/blog/20-types-of-mobile-app-paywalls) -- Paywall design taxonomy
- [NNGroup: Carousels on Mobile Devices](https://www.nngroup.com/articles/mobile-carousels/) -- iOS carousel UX pitfalls and solutions

### TERTIARY (LOW confidence)
- [Duolingo monetization analysis](https://medium.com/@nicobottaro/monetization-7-lessons-on-how-duolingo-increased-premium-users-by-176-from-3-to-8-8-42e8d63b58f2) -- Emotional copy and upsell timing
- [Adapty: How to Design a Paywall for a Mobile App](https://adapty.io/blog/how-to-design-a-paywall-for-a-mobile-app/) -- General paywall patterns
- WebSearch results on pricing psychology and mobile checkout UX
