# Domain Pitfalls: Seat-Based Monetization for iOS

**Domain:** Adding tier-based IAP pricing to an existing iOS video card app
**Researched:** 2026-02-08
**Applies to:** TOY v1.2 -- seat-based pricing (5 free, pay-at-publish, consumable per-card purchases)
**Overall confidence:** HIGH (Apple guidelines directly reviewed, RevenueCat docs verified, community reports cross-referenced)

---

## Critical Pitfalls

Mistakes that cause App Store rejection, lost revenue, or require architectural rework.

### Pitfall 1: Wrong IAP Product Type Causes App Store Rejection

**What goes wrong:** Choosing "consumable" for per-card tier purchases when Apple expects a different product type. Apple has rejected apps that use consumable IAPs for unlocking content or service access, insisting on non-renewing subscriptions or non-consumables instead. The distinction matters because Apple defines consumables as items that "deplete with use" (like game currency), not as one-time access grants.

**Why it happens:** TOY's model -- "pay $1.99 to publish this specific card with up to 10 participants" -- sits in a gray area. It feels consumable (one purchase per card, can buy again for a different card), but it unlocks persistent content (a published card that lives forever). Apple's guidelines say consumables are "used once and become depleted." A published card does not deplete.

**Consequences:**
- App Store rejection with Guideline 3.1.1 citation
- Rework of App Store Connect product configuration and RevenueCat setup
- Potential delay of weeks if the rejection requires fundamental model rethinking

**Warning signs:**
- App Store review notes questioning why a consumable unlocks permanent content
- RevenueCat entitlement staying "unlocked forever" after a single consumable purchase (documented RevenueCat behavior: consumables added to entitlements report as permanently unlocked because they have no expiration)

**Prevention:**
- **Use consumable IAPs.** Despite the gray area, TOY's model maps best to consumables because: (1) the user can buy the same tier product multiple times for different cards, (2) non-consumables can only be purchased once per Apple ID and cannot be re-purchased, which breaks the per-card model entirely, and (3) the "consumption" is the act of publishing the card, after which the purchase is spent. The published card persists, but the purchase itself is consumed.
- **Frame it correctly in App Store Connect.** The product description should say "Publish a card with up to 10 participants" not "Unlock 10 participant slots." The verb "publish" implies a one-time action. The verb "unlock" implies persistent access.
- **In the App Review notes**, explicitly explain: "This consumable allows the user to publish one group video card with up to N participants. Each purchase applies to a single card. Users create multiple cards over time and purchase separately for each."
- **Do NOT add consumable products to RevenueCat entitlements.** RevenueCat will report the entitlement as permanently unlocked. Track card-level purchase status in your own database (Supabase), not via RevenueCat entitlements.

**Detection:** Submit to App Store review early with a single tier product. Get approval on the product type before building all 6+ tiers.

**Confidence:** HIGH -- Apple's IAP type definitions are from official documentation. The non-consumable "can only be purchased once" limitation is documented and would break the per-card model. The RevenueCat entitlement behavior for consumables is confirmed in their official docs.

**Which phase should address it:** Phase 1 (App Store Connect setup) -- product type must be decided before any code is written. Submit a test build with one consumable product for review validation.

---

### Pitfall 2: Purchase Fails Mid-Publish and Card State Is Corrupted

**What goes wrong:** The host taps "Publish" which triggers a purchase flow. The purchase succeeds in StoreKit but the subsequent server call to publish the card fails (network error, Supabase timeout, stitching failure). Now the user has been charged but has no published card. Alternatively, the purchase fails but the app has already started the publish process, leaving the card in a half-published state.

**Why it happens:** Purchase and publish are two separate operations that the UX combines into a single button. There is no atomic transaction spanning "charge Apple" and "publish card on Supabase." The current `UpgradeViewModel.purchase()` method calls `purchaseService.purchase(package:)` and then `recordCardUpgrade()` sequentially. If `recordCardUpgrade()` fails, the comment says "Best effort - purchase succeeded even if local record fails." This is dangerous when the consequence is a published card, not just a database flag.

**Consequences:**
- User charged $4.99 but sees an error and no published card
- User contacts support demanding a refund
- If the app retries publish without re-checking purchase status, it could try to charge again
- If the app publishes without verifying purchase, users get free publishes

**Warning signs:**
- Support tickets: "I paid but my card didn't publish"
- Mismatched counts between RevenueCat purchases and published cards in Supabase
- `recordCardUpgrade()` failure logs in production

**Prevention:**
- **Separate purchase from publish.** Purchase is Step 1: "Pay for this card." Publish is Step 2: "Now publish it." These should be two distinct user actions OR the publish step must be idempotent and retriable.
- **Record purchase proof immediately.** After `Purchases.shared.purchase()` succeeds, write the `transactionId` to the card record in Supabase BEFORE attempting video stitching/publishing. This is the "receipt" that proves the card was paid for.
- **Make publish retriable.** If video stitching or publishing fails after payment, the card screen should show "Payment complete. Publishing failed. Tap to retry." The retry only re-runs the publish logic, not the payment.
- **Never start publish before payment confirmation.** The current flow should be: (1) User taps "Publish", (2) StoreKit payment sheet appears, (3) Payment succeeds and returns a verified transaction, (4) Write transactionId to card in Supabase, (5) Begin video stitching and publishing, (6) If step 5 fails, card is marked "paid but not published" -- user retries step 5 only.
- **Use StoreKit 2's `Transaction.updates` listener** to catch purchases that complete after app crash or background. On app launch, iterate `Transaction.unfinished` to find any purchases that succeeded but were never recorded in Supabase.

**Detection:** Test by killing the app (force quit) immediately after the StoreKit payment sheet dismisses but before the publish API call completes. On relaunch, verify the app recovers the purchase and offers to retry publishing.

**Confidence:** HIGH -- this is a well-documented distributed systems problem. The current codebase's "best effort" pattern in `UpgradeViewModel.recordCardUpgrade()` confirms the risk exists.

**Which phase should address it:** Phase 2 (purchase flow implementation) -- this is the core transaction integrity problem. Must be solved before any purchase goes live.

---

### Pitfall 3: No Server-Side Purchase Verification Enables Free Publishes

**What goes wrong:** If purchase verification happens only on the client (checking RevenueCat's `CustomerInfo` or StoreKit's local transaction), a jailbroken device or modified app binary can bypass the check and publish cards without paying. More commonly, a race condition or bug in the client-side check allows publishing without a valid purchase.

**Why it happens:** The current `PurchaseService.isCardUpgraded(cardId:)` checks `customerInfo.nonSubscriptions` on the client. If the card's `maxParticipants` in Supabase is updated client-side (as in the current `recordCardUpgrade()` which calls `updateCardMaxParticipants` directly), there is no server-side gate. Anyone who can call the Supabase API directly can set `maxParticipants` to 999.

**Consequences:**
- Revenue loss from bypassed purchases
- Inconsistency between RevenueCat purchase records and Supabase card states
- If discovered by users, could spread as an exploit

**Warning signs:**
- Cards in Supabase with `maxParticipants > 5` but no corresponding RevenueCat transaction
- Published cards with more than 5 clips that have no purchase record

**Prevention:**
- **Gate publishing in a Supabase Edge Function**, not client-side. The publish endpoint should: (1) receive the card ID and StoreKit transactionId, (2) verify the transaction with Apple's App Store Server API (or accept RevenueCat webhook confirmation), (3) only then proceed with stitching/publishing.
- **At minimum**, use Row-Level Security (RLS) in Supabase to prevent clients from directly modifying `maxParticipants`. Only a server function (Edge Function or database trigger) should update this field after verifying purchase proof.
- **For MVP**, a pragmatic middle ground: the client sends the transactionId to Supabase, the Edge Function records it, and a background job periodically reconciles RevenueCat transactions against Supabase card records. This catches exploits after the fact without blocking the publish flow on server-side Apple API calls.

**Detection:** Write a Supabase query that joins cards with `maxParticipants > 5` against purchase records. Run weekly. Any card without a matching purchase is suspicious.

**Confidence:** HIGH -- client-side-only purchase verification is a known anti-pattern documented across Apple developer resources and RevenueCat best practices.

**Which phase should address it:** Phase 2 (purchase flow) for basic transactionId recording; Phase 3 (hardening) for full server-side verification via Edge Function.

---

### Pitfall 4: Restore Purchases Button Missing or Broken

**What goes wrong:** Apple requires a "Restore Purchases" button for non-consumable and subscription IAPs. For consumables, Apple does not require restore (consumables cannot be restored by definition). However, if the app uses consumables AND has any UI that implies permanent unlock (e.g., showing "Purchased" badge on a card), users will expect to restore that state on a new device. If "Restore Purchases" does nothing for consumables, users submit 1-star reviews saying "I paid but lost my purchases."

**Why it happens:** Consumable purchases are device-specific and cannot be restored via StoreKit's `restorePurchases()`. Once consumed (transaction finished), they are gone from Apple's perspective. The current `CardUpgradeView` has a "Restore Purchases" button that calls `purchaseService.restorePurchases()`. For consumables, this will return nothing -- the user's purchased card tiers will not appear.

**Consequences:**
- App Store rejection if review team expects restore for your product type and it does not work
- 1-star reviews from users who reinstall and lose their "purchased" card states
- Support burden from users confused about why restore does not recover their cards

**Warning signs:**
- Restore button does nothing (returns success but no purchases appear)
- Users report losing their purchase state after reinstalling the app

**Prevention:**
- **Consumables cannot be restored via Apple.** This is by design. Accept this limitation.
- **TOY's purchase state lives in Supabase, not on-device.** When a user signs in on a new device, their cards (including purchased/published status) load from the database. This IS the restore mechanism, but it is implicit (sign-in), not a button press.
- **Remove the "Restore Purchases" button** if all IAPs are consumable. Apple does not require it for consumables. Keeping it and having it do nothing is worse than not having it.
- **If you keep the button**, have it check Supabase for the user's purchase history (by user ID) rather than calling StoreKit restore. Label it "Restore Card History" or similar to set correct expectations.
- **Document this in App Review notes:** "All IAPs are consumable. Purchase state is synced via user account (Supabase), not StoreKit restore. Users sign in to access their cards and purchase history on new devices."

**Detection:** Test: purchase a tier, delete the app, reinstall, sign in. Verify the card shows as "paid/published" from the Supabase record, not from StoreKit.

**Confidence:** HIGH -- Apple's documentation explicitly states consumables cannot be restored. RevenueCat docs confirm this. The existing `CardUpgradeView` has a restore button that will not work for consumables.

**Which phase should address it:** Phase 1 (product type decisions) and Phase 2 (purchase UI) -- decide on restore strategy before building UI.

---

### Pitfall 5: Participant Count Changes Between Checkout and Publish

**What goes wrong:** A host sees 8 clips submitted, chooses the 10-participant tier ($1.99), pays, but by the time they publish, 3 more participants submitted clips (total 11). Now the card has more clips than the tier allows. Alternatively, a participant deletes their clip during checkout, and the host overpaid.

**Why it happens:** There is no lock on the card during checkout. Participants can submit or delete clips at any time via the App Clip or main app. The host's payment is based on a snapshot of the participant count that may be stale by the time publish executes.

**Consequences:**
- Host pays for 10-tier but card has 11 clips -- either block publishing (frustrating) or allow it (revenue leak)
- Host pays for 10-tier but only 7 clips remain -- host overpaid (feels bad)
- Edge case: host sees exactly 5 clips, doesn't pay (free tier), but a 6th clip arrives during publish -- card publishes for free with 6 clips

**Warning signs:**
- Mismatch between `currentParticipantCount` shown in checkout UI and actual clip count at publish time
- User complaints about paying for a tier they didn't need

**Prevention:**
- **Enforce tier limits at publish time, not purchase time.** When the publish API runs, count the actual clips. If clipCount > paidTier.maxParticipants, block with a clear message: "2 more clips arrived since you purchased. Upgrade to the 25-participant tier to include everyone, or remove clips to stay within your tier."
- **Never block incoming clips.** The design principle is "never block submissions." Participants can always submit. The tier only governs how many clips appear in the PUBLISHED montage.
- **Show a real-time clip count** on the publish/checkout screen that updates live (Supabase real-time subscription). If the count crosses a tier boundary while the user is on the checkout screen, update the recommended tier dynamically.
- **For the "overpaid" case**, accept this gracefully. Do not offer automatic refunds for the difference. The user chose to pay for the tier. They may have expected more clips to arrive. A $1.99 overpayment is not worth the complexity of partial refunds.
- **For the "free tier exceeded" race condition**, the publish Edge Function should verify: `clipCount <= paidTier.maxParticipants`. If the host has no purchase record and clipCount > 5, reject the publish and prompt for payment.

**Detection:** Log the clip count at purchase time and at publish time. Alert if they differ by more than 2.

**Confidence:** HIGH -- this is a fundamental concurrency issue inherent to the "pay at publish" model. The design explicitly allows participants to submit freely, which means the count is never stable until the card is locked at publish.

**Which phase should address it:** Phase 2 (purchase flow) for the enforcement logic; Phase 3 (UI polish) for real-time count updates on the checkout screen.

---

## Moderate Pitfalls

Mistakes that cause poor user experience, support burden, or revenue leakage.

### Pitfall 6: RevenueCat Webhook Delays Break Real-Time Purchase Verification

**What goes wrong:** If the server-side publish gate relies on a RevenueCat webhook to confirm the purchase, delays in webhook delivery can block publishing. RevenueCat community reports show webhooks are usually delivered in 5-60 seconds, but delays of 6+ hours have been documented. A user who pays and then waits minutes for their card to publish will abandon the flow.

**Why it happens:** RevenueCat webhooks are not real-time guarantees. They depend on Apple's server notification pipeline, RevenueCat's processing queue, and network delivery to your server. The documented retry policy is 5 retries with exponential backoff (5, 10, 20, 40, 80 minutes).

**Consequences:**
- User pays but card does not publish for minutes or hours
- Support tickets: "I paid but nothing happened"
- If the system falls back to polling RevenueCat API, it adds latency and complexity

**Warning signs:**
- Time gap between purchase timestamp and webhook receipt timestamp exceeds 30 seconds
- Published card counts lag behind RevenueCat dashboard revenue

**Prevention:**
- **Do NOT gate publishing on RevenueCat webhooks.** Use the client-side StoreKit 2 transaction as the primary proof of purchase.
- **The flow should be:** (1) Client purchases via RevenueCat SDK, (2) RevenueCat SDK returns a verified transaction to the client, (3) Client sends the `transactionId` (or the full JWS-signed transaction) to the server, (4) Server records the transactionId and proceeds with publishing, (5) RevenueCat webhook arrives later as a reconciliation/backup, not as the gate.
- **Use webhooks for reconciliation**, not real-time gating. A background job compares webhook-confirmed purchases against Supabase card records. Discrepancies trigger alerts, not publish blocks.
- **For extra safety**, the server can verify the JWS-signed transaction directly with Apple's public key (no network call needed -- the signing certificate chain is verifiable offline). RevenueCat SDK 5.x provides this signed data.

**Detection:** Monitor the time delta between client purchase and webhook receipt. Alert if the p95 exceeds 60 seconds.

**Confidence:** HIGH -- RevenueCat community forums document the 6-hour delay case. RevenueCat's own docs recommend webhooks for syncing, not for real-time gating. The 5-60 second "usual" delivery is from their official documentation.

**Which phase should address it:** Phase 2 (purchase flow architecture) -- the decision to use client-side transaction proof vs. webhook-gated publishing must be made before building the publish flow.

---

### Pitfall 7: Refund Granted but Published Card Remains Live

**What goes wrong:** A user publishes a card (paying $4.99 for the 25-participant tier), sends the link to the recipient, and then requests a refund from Apple. Apple grants the refund. The published card remains accessible at its URL. The user got the card for free.

**Why it happens:** Apple sends a `REFUND` server notification (via App Store Server Notifications or RevenueCat webhook). If the app does not handle this notification, the published card remains live. Even if the app does handle it, the question is: what should happen? Unpublishing a card that has already been viewed by the recipient creates a terrible experience for an innocent party.

**Consequences:**
- Revenue loss from refund abuse
- Ethical dilemma: penalizing the recipient for the host's refund request
- If you unpublish the card, the recipient loses their video message -- bad PR

**Warning signs:**
- Apple `CONSUMPTION_REQUEST` notifications (Apple asking you whether the product was consumed before deciding on the refund)
- Rising refund rates after launch

**Prevention:**
- **Respond to `CONSUMPTION_REQUEST` notifications.** When Apple asks whether the consumable was used, respond YES with full consumption data. This gives Apple the information to deny the refund. Apple considers consumption data when making refund decisions.
- **Set up App Store Server Notifications V2** (or RevenueCat webhooks for `REFUND` events) to be notified when a refund IS granted.
- **Do NOT unpublish the card on refund.** The recipient should not suffer. The published card should remain accessible.
- **Flag the host's account** on refund. If a host has a refund on record, require them to pay before their NEXT card's clips are visible (degrade to the free tier experience on future cards). This prevents serial abuse without punishing innocent recipients.
- **Accept small refund losses as a cost of business.** For a consumer app with $1.99-$4.99 price points, aggressive anti-refund measures create more UX harm than the refund costs.
- **Track refund rate.** If it exceeds 5%, investigate whether the pricing feels unfair or the product under-delivers.

**Detection:** Set up `REFUND` webhook handler. Log all refunds. Dashboard showing refund rate per tier and per user.

**Confidence:** HIGH -- Apple's `CONSUMPTION_REQUEST` and `REFUND` notification flows are documented in official StoreKit 2 and App Store Server API docs. The ethical dilemma of unpublishing is a design decision, not a technical question.

**Which phase should address it:** Phase 3 (post-purchase handling) -- refund handling is not launch-blocking but must be implemented before significant revenue flows.

---

### Pitfall 8: Pricing UI Accidentally Triggers "Dark Pattern" Rejection

**What goes wrong:** The App Store review team rejects the app for deceptive pricing UI. Common triggers: price not shown clearly, tier comparison designed to pressure users toward expensive options, countdown timers or artificial urgency, pre-selecting the most expensive tier, or hiding the free option.

**Why it happens:** TOY's "checkout carousel at publish" design -- showing the current tier with prev/next tiers visible -- is inherently a comparison UI. If the most expensive tier is visually prominent or the free tier is hard to find, Apple may flag it. Research shows iOS apps are cited more often for deceptive patterns than Android apps, and Apple's review team actively looks for these.

**Consequences:**
- App Store rejection with "dark patterns" citation
- Required redesign of pricing UI
- If the rejection is repeated, escalation to App Review Board

**Warning signs:**
- Review team notes mentioning "clarity of pricing" or "misleading"
- User complaints about feeling pressured to purchase
- High purchase-to-refund ratio (users buying then immediately regretting)

**Prevention:**
- **Always show the full price in the largest text.** "$1.99" should be the most prominent text element on the purchase button. Never show "$1.99/month" when it is a one-time purchase, or vice versa.
- **Make the free option obvious and easy to select.** If the card has 5 or fewer clips, the "Publish Free" option should be the PRIMARY button, with paid tiers shown as upgrades. Never hide or minimize the free option.
- **Do not pre-select a paid tier.** Let the app recommend a tier based on clip count, but do not auto-select a paid tier with the user needing to opt OUT. The user should opt IN to a paid tier.
- **No urgency tactics.** No "Publish now before clips expire!" No countdown timers. No "Limited time pricing." TOY's pricing is permanent and transparent.
- **Show exactly what the user gets.** "Publish with all 12 clips -- $4.99" is clear. "Premium Card -- $4.99" is vague.
- **Do not use the decoy effect** intentionally. If the tier structure naturally has a "sweet spot" tier, that is fine. But do not add a deliberately overpriced tier just to make the adjacent tier look cheaper.
- **Per Apple guidelines**, the checkout screen must show: exact price, what the purchase includes, and that it is a one-time charge (not a subscription).

**Detection:** Have 3 people who have never seen the app test the checkout flow. Ask them: "What does this cost? What do you get? Do you feel pressured?" If any answer is wrong or uncomfortable, redesign.

**Confidence:** HIGH -- Apple's guidelines on pricing transparency are explicit. The dark pattern research cited applies directly to tier comparison UIs.

**Which phase should address it:** Phase 2 (purchase UI design) -- design the checkout screen with Apple guidelines in mind from the start.

---

### Pitfall 9: StoreKit 2 Transaction.updates Listener Not Set Up at App Launch

**What goes wrong:** If the app crashes or is killed between StoreKit processing a payment and the app recording the purchase in Supabase, the purchase is "lost." The user was charged but the app has no record. StoreKit 2's `Transaction.updates` async sequence delivers unfinished transactions -- but only if the app is listening for them at launch.

**Why it happens:** `Transaction.updates` is an `AsyncSequence` that must be iterated in a long-lived `Task` started at app launch. If the listener is not started, or is started too late (e.g., only when the purchase UI appears), unfinished transactions from interrupted purchases are never delivered. Apple Developer Forums document cases where unfinished transactions were not emitted reliably on app launch, though behavior improved on real devices vs. simulators.

**Consequences:**
- User charged but app does not know about the purchase
- No way to recover without manual support intervention
- User re-attempts purchase, gets "already purchased" error from StoreKit

**Warning signs:**
- Support tickets: "I was charged but my card shows as unpaid"
- StoreKit "already purchased" errors when user tries to buy again
- RevenueCat dashboard shows purchase but app/Supabase has no record

**Prevention:**
- **Start a `Transaction.updates` listener in `TOYApp.init()` or `.task` on the root view.** This listener should run for the entire app lifecycle.
- **In the listener, for each transaction:** (1) verify it is a valid purchase (check `transaction.revocationDate == nil`), (2) write the transactionId to the appropriate card record in Supabase, (3) only then call `transaction.finish()`.
- **Also iterate `Transaction.unfinished` on launch** to catch any transactions that were pending from a previous session. This is the safety net for the `Transaction.updates` reliability issues documented on Apple Developer Forums.
- **If using RevenueCat SDK**, RevenueCat handles transaction finishing by default. Check `Purchases.shared.finishTransactions` -- if `true` (default), RevenueCat finishes transactions automatically. Set to `false` ONLY if you need to verify server-side before finishing. For TOY's use case, let RevenueCat finish transactions and rely on the SDK's purchase callback + webhook for reconciliation.

**Detection:** Test by making a purchase, force-killing the app before the Supabase write completes, then relaunching. Verify the purchase is recovered.

**Confidence:** MEDIUM -- `Transaction.updates` behavior is documented by Apple but has known reliability issues reported on Developer Forums. RevenueCat SDK abstracts most of this, but the underlying StoreKit behavior matters for edge cases.

**Which phase should address it:** Phase 2 (purchase flow) -- the transaction listener must be in place before any purchase goes live.

---

### Pitfall 10: Multiple Tier Products Create App Store Connect Management Burden

**What goes wrong:** TOY plans 6+ tiers (5 free, 10/$1.99, 25/$4.99, 50/$9.99, 100/$29.99, 250/$89.99). Each tier is a separate consumable product in App Store Connect. Each needs: a unique product ID, display name, description, price, review screenshot, and review notes. If any single product is rejected, the entire app update may be held.

**Why it happens:** App Store Connect requires per-product review for new IAP products. Each product is reviewed independently for appropriate description, pricing, and screenshots. Six products means six opportunities for a reviewer to find an issue.

**Consequences:**
- Delayed launch if one product is rejected and needs revision
- Ongoing maintenance burden when changing pricing (must update each product individually)
- Risk of inconsistent product descriptions across tiers

**Warning signs:**
- Reviewer notes on one product but not others ("Description unclear for 25-participant tier")
- Typos or inconsistencies across product descriptions

**Prevention:**
- **Use a consistent naming convention.** Product IDs: `com.toy.card.tier10`, `com.toy.card.tier25`, etc. Display names: "Card -- Up to 10 Participants", "Card -- Up to 25 Participants", etc.
- **Write all product descriptions from a single template.** "Publish one group video card with up to [N] participant clips. This is a one-time purchase for a single card." Change only the number.
- **Submit all products in a single app update** so they are reviewed together. Do not trickle them in across multiple updates.
- **In RevenueCat, set up a single Offering** with multiple Packages (one per tier). This keeps the client code simple -- fetch one offering, display its packages.
- **Start with 3 tiers for MVP** (free/10/$1.99/25/$4.99), add more tiers after initial approval. Fewer products = fewer review risks = faster launch.

**Detection:** Check App Store Connect status for each product after submission. All should transition to "Approved" within the same review cycle.

**Confidence:** HIGH -- App Store Connect product review process is well-documented. The recommendation to start with fewer tiers is a pragmatic risk reduction.

**Which phase should address it:** Phase 1 (App Store Connect setup) -- create and submit products early in the development process to allow time for review.

---

## Minor Pitfalls

Mistakes that cause user confusion or minor UX friction but are fixable.

### Pitfall 11: Pricing Does Not Feel "Worth It" at Higher Tiers

**What goes wrong:** The $89.99 tier for 250 participants seems expensive for a greeting card. Users at the upper tiers are likely event organizers (company farewells, school projects) with different price sensitivity than casual birthday card senders. If the pricing feels arbitrary, users at all tiers question the value.

**Why it happens:** Tier pricing that does not follow a clear per-participant logic feels unpredictable. If Tier 1 is $0.20/participant (10 for $1.99) and Tier 5 is $0.36/participant (250 for $89.99), the price per participant INCREASES at higher tiers, which violates the "bulk discount" expectation.

**Consequences:**
- Users at mid-to-high tiers feel overcharged
- Users try to game the system (submit under free tier, delete extras)
- Higher tiers have near-zero conversion

**Warning signs:**
- Zero purchases at the $29.99+ tiers after 30 days
- Users creating multiple cards (each with 5 free clips) instead of one large card

**Prevention:**
- **Consider a clear per-participant formula** that users can intuit: "First 5 free, then $0.25/participant." This is more transparent than arbitrary tier prices, though it may be harder to implement as discrete IAP products.
- **Ensure per-participant cost decreases at higher tiers** (bulk discount). Users expect volume discounts.
- **Show the per-participant cost** in the checkout UI: "$4.99 -- just $0.20 per clip" helps users rationalize the purchase.
- **A/B test pricing after launch.** Do not over-engineer the initial price points. Ship with a reasonable structure and adjust based on conversion data.

**Detection:** Track conversion rate per tier. Track "card creation abandoned at checkout" rate. Compare against free-tier completion rate.

**Confidence:** MEDIUM -- pricing psychology literature supports these patterns but optimal price points require market data. The specific TOY tier prices are hypothetical and may need adjustment.

**Which phase should address it:** Phase 2 (checkout UI) for showing per-participant cost; post-launch iteration for price optimization.

---

### Pitfall 12: Free Tier Users Never Convert Because 5 Slots Is Enough

**What goes wrong:** If most real-world use cases involve 3-5 participants (family birthday cards), the free tier covers the dominant use case. No one ever needs to pay. Revenue is zero.

**Why it happens:** The free tier of 5 participants was chosen to be generous enough for a good free experience. But "generous enough" may mean "generous enough to never need to upgrade." Without data on actual group sizes, 5 may be too high.

**Consequences:**
- Zero revenue despite high usage
- No signal about willingness to pay
- Difficult to lower the free tier later without angering existing users

**Warning signs:**
- 90%+ of cards have 5 or fewer clips
- Less than 2% of cards trigger the upgrade flow

**Prevention:**
- **Start with 5 free and monitor.** If 90%+ of cards are under 5, consider reducing to 3 free. But do this based on data, not speculation.
- **The free tier serves a critical purpose:** it lets hosts experience the full flow (create, invite, collect, publish) before ever encountering a paywall. A free tier that is too small (1-2 clips) makes the free experience feel broken, not just limited.
- **Consider the free tier as a marketing tool**, not a revenue segment. The free cards generate invite links that bring new users into the funnel. Each free card potentially creates 5 new users who might later host their own cards.
- **Track the distribution of clip counts** from day one. This data determines the optimal free tier threshold.

**Detection:** Histogram of clips-per-card across all cards. Overlay the tier boundaries. Where do the natural clusters fall?

**Confidence:** MEDIUM -- this is a business model risk, not a technical pitfall. The optimal free tier size depends on actual user behavior data that does not exist yet.

**Which phase should address it:** Post-launch analytics. Instrument clip count tracking in Phase 1 so the data is available for analysis.

---

### Pitfall 13: Localized Pricing Surprises Users in Non-USD Markets

**What goes wrong:** App Store prices are set in tiers, not exact amounts. A $1.99 USD product may be 2.49 EUR or 3.49 AUD. If the checkout UI shows "$1.99" from the app's hardcoded strings but the actual StoreKit charge is the local equivalent, users see a price mismatch.

**Why it happens:** Developers hardcode USD prices in their UI instead of using StoreKit's `product.displayPrice` (StoreKit 2) or RevenueCat's `package.localizedPriceString`. The existing `CardUpgradeView` correctly uses `package.localizedPriceString` for the button, but any other place prices are mentioned (marketing copy, tier comparison, help text) might use hardcoded values.

**Consequences:**
- Users in non-USD markets see conflicting prices
- Potential App Store rejection for price misrepresentation
- Users feel deceived if the charged amount differs from what was shown

**Warning signs:**
- Non-US users reporting price discrepancies
- Reviewer (often based in non-US locale) seeing conflicting prices

**Prevention:**
- **Never hardcode prices.** Always use `package.localizedPriceString` from RevenueCat or `product.displayPrice` from StoreKit 2.
- **Fetch product prices before displaying the checkout UI.** Show a loading state until prices are available. The current `UpgradeViewModel.loadOffering()` does this correctly.
- **In the tier comparison carousel**, each tier's price must come from the corresponding StoreKit product, not from a static array of strings.
- **Test with a non-USD App Store account** (or StoreKit configuration file set to a non-USD storefront).

**Detection:** Set up a StoreKit test configuration with a European storefront. Verify all prices display in EUR, not USD.

**Confidence:** HIGH -- this is a well-documented iOS development best practice. The existing codebase handles it correctly in one place (`CardUpgradeView`) but the new tier carousel will need the same treatment.

**Which phase should address it:** Phase 2 (checkout UI) -- all price display must use localized strings from StoreKit/RevenueCat.

---

### Pitfall 14: Sandbox Testing Confusion Between Consumable and Non-Consumable Behavior

**What goes wrong:** During development, StoreKit sandbox and Xcode's StoreKit testing environment behave differently from production for consumables. Sandbox allows re-purchasing consumables, but the behavior of `Transaction.unfinished` and webhook timing differs. Developers think the flow works, ship it, and encounter different behavior in production.

**Why it happens:** The sandbox environment is optimized for rapid testing, not production fidelity. Webhook delivery in sandbox is even less reliable than production. Transaction finishing behavior may differ. The StoreKit Testing in Xcode (local testing) does not involve Apple's servers at all, so server-side validation paths are untested.

**Consequences:**
- Purchase flow works perfectly in testing but fails in production
- Server-side verification that worked in sandbox fails against production Apple APIs
- Webhook-dependent logic that worked locally (because webhooks were instant in Xcode testing) fails in production (where webhooks are delayed)

**Warning signs:**
- All tests pass in Xcode StoreKit testing environment
- First production users report purchase issues

**Prevention:**
- **Test in sandbox AND production.** After initial development in Xcode's StoreKit testing, do a full end-to-end test with sandbox Apple ID and real App Store Connect products.
- **Do not rely on Xcode's StoreKit testing for webhook flow testing.** Xcode testing does not send real webhooks. You must test webhooks with sandbox purchases.
- **Create a dedicated sandbox testing checklist:** (1) Fresh purchase, (2) Purchase with app kill mid-flow, (3) Purchase on one device, verify on another, (4) Refund via sandbox, verify webhook, (5) Purchase with no internet after payment sheet, restore on reconnect.
- **Use RevenueCat's sandbox mode** for initial testing, then test with production configuration (but sandbox Apple ID) before submitting.

**Detection:** Maintain a testing matrix: [Local Xcode StoreKit | Sandbox Apple ID | TestFlight | Production]. Each flow must pass in all columns before shipping.

**Confidence:** HIGH -- sandbox vs. production behavioral differences are widely documented across Apple Developer Forums and RevenueCat community.

**Which phase should address it:** Phase 2 (purchase flow) -- establish the testing matrix before writing purchase code.

---

## Phase-Specific Warnings

| Phase Topic | Likely Pitfall | Mitigation |
|---|---|---|
| Phase 1: App Store Connect setup | Wrong product type (Pitfall 1), Too many products for initial review (Pitfall 10) | Submit 3 tier products as consumables early. Validate with review before building all tiers. Include explanatory review notes. |
| Phase 1: RevenueCat configuration | Consumables added to entitlements report as permanently unlocked (Pitfall 1) | Do NOT add consumable products to entitlements. Track card purchase state in Supabase. |
| Phase 2: Purchase flow | Purchase-publish atomicity failure (Pitfall 2), No server verification (Pitfall 3), Transaction listener missing (Pitfall 9) | Separate purchase from publish. Record transactionId in Supabase before publishing. Start Transaction.updates listener at app launch. |
| Phase 2: Checkout UI | Dark pattern rejection (Pitfall 8), Hardcoded prices (Pitfall 13), Restore button confusion (Pitfall 4) | Use localized prices only. Make free option prominent. Remove or repurpose restore button. |
| Phase 2: Tier enforcement | Clip count race condition (Pitfall 5) | Enforce tier limits at publish time in server-side Edge Function. Allow all submissions regardless of tier. |
| Phase 3: Post-purchase handling | Refund abuse (Pitfall 7), Webhook delays (Pitfall 6) | Respond to CONSUMPTION_REQUEST. Use webhooks for reconciliation, not real-time gating. Flag hosts with refunds. |
| Phase 3: Testing & QA | Sandbox/production differences (Pitfall 14) | Full sandbox and TestFlight testing before production launch. |
| Post-launch | Free tier too generous (Pitfall 12), Higher tiers overpriced (Pitfall 11) | Instrument clip count analytics. Track conversion rate per tier. Adjust based on data. |

---

## Existing Codebase Issues to Address During Implementation

These are concrete issues in the current monetization code that will cause problems if not addressed alongside the seat-based pricing work.

| File | Issue | Severity | Resolution |
|---|---|---|---|
| `PurchaseService.swift` | `isCardUpgraded(cardId:)` constructs a per-card product ID (`card_upgrade_{uuid}`) -- this pattern does not work with tier-based consumables. You would need thousands of products, one per card. | Critical (architectural) | Replace with Supabase-based purchase state lookup. The purchase service should track which TIER was purchased for a card, not a per-card product. |
| `UpgradeViewModel.swift` | `recordCardUpgrade()` sets `maxParticipants = 999` as a "best effort" client-side write. No purchase verification. No transactionId recorded. | Critical (security) | Write transactionId to card record. Gate maxParticipants update on verified purchase. Move to server-side Edge Function. |
| `UpgradeViewModel.swift` | `purchase()` does not handle `PurchaseResult.pending` (Ask to Buy, parental controls). Only handles success and error. | Moderate (edge case) | Add `.pending` case handling: show "Purchase pending approval" state. Do not proceed to publish. |
| `CardUpgradeView.swift` | Restore Purchases button calls `purchaseService.restorePurchases()` which will not restore consumable purchases. | Moderate (UX confusion) | Remove button or replace with Supabase-based card history check. |
| `CardUpgradeView.swift` | Single-tier UI ("Upgrade - $X.XX") needs complete redesign for multi-tier carousel. | Moderate (UI rework) | Redesign as tier selector carousel with current-tier highlight and adjacent tier preview. |
| `TOYApp.swift` | No `Transaction.updates` listener at app launch. Interrupted purchases will be lost. | High (purchase loss) | Add transaction listener in app's root `.task` modifier or `init()`. |

---

## Sources

- [App Store Review Guidelines -- Section 3.1 (In-App Purchase)](https://developer.apple.com/app-store/review/guidelines/) -- consumable vs. non-consumable definitions, restore requirements, dark pattern rules [HIGH confidence]
- [In-App Purchase Types -- App Store Connect](https://developer.apple.com/help/app-store-connect/reference/in-app-purchase-types/) -- official product type definitions [HIGH confidence]
- [RevenueCat: Non-Subscription Purchases](https://www.revenuecat.com/docs/platform-resources/non-subscriptions) -- consumable entitlement behavior, webhook event types [HIGH confidence]
- [RevenueCat Community: Consumable IAP Architecture](https://community.revenuecat.com/general-questions-7/setting-up-a-consumable-in-app-purchase-architecture-387) -- server-side tracking requirement [MEDIUM confidence]
- [RevenueCat Community: Webhook Delay (6+ hours)](https://community.revenuecat.com/general-questions-7/webhook-delay-caused-subscription-status-bug-first-event-delayed-by-6-hours-6342) -- real-world webhook latency [MEDIUM confidence]
- [RevenueCat Webhooks Documentation](https://www.revenuecat.com/docs/integrations/webhooks) -- delivery timing, retry policy [HIGH confidence]
- [Apple Developer: Handling Refund Notifications](https://developer.apple.com/documentation/storekit/handling-refund-notifications) -- CONSUMPTION_REQUEST flow [HIGH confidence]
- [Apple Developer Forums: Transaction.updates Unfinished Transactions](https://developer.apple.com/forums/thread/722222) -- reliability issues with unfinished transaction delivery [MEDIUM confidence]
- [Apple Developer Forums: StoreKit 2 Transaction.unfinished](https://developer.apple.com/forums/thread/726200) -- use case for catching interrupted purchases [MEDIUM confidence]
- [Adapty: iOS Paywall Design Guide](https://adapty.io/blog/how-to-design-ios-paywall/) -- Apple rejection patterns for pricing UI [MEDIUM confidence]
- [Adapty: App Store Review Guidelines 2026 Checklist](https://adapty.io/blog/how-to-pass-app-store-review/) -- common rejection reasons [MEDIUM confidence]
- [Adapty: Dark Patterns in Mobile Apps](https://adapty.io/blog/dark-patterns-and-tricks-in-mobile-apps/) -- deceptive pattern taxonomy [MEDIUM confidence]
- [How to Pass App Store Review for IAP](https://capgo.app/blog/how-to-pass-app-store-review-iap/) -- paywall transparency requirements [MEDIUM confidence]
