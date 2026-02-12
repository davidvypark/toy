import SwiftUI
import RevenueCat
import TOYShared

/// Publish-time checkout sheet presented when a host needs to upgrade before publishing.
/// Shows the required tier prominently with neighboring tiers grayed out for context.
struct CheckoutSheet: View {
    let card: Card
    let clipCount: Int
    let onPurchaseComplete: () -> Void
    let onCancel: () -> Void

    @State private var packages: [String: Package] = [:]
    @State private var isPurchasing = false
    @State private var errorMessage: String?
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL

    /// The minimum tier required for the current clip count.
    private var requiredTier: CardTier {
        CardTier.requiredTier(for: clipCount)
    }

    /// Show only the required tier plus one below and one above (for context).
    private var visibleTiers: [CardTier] {
        let all = CardTier.allCases
        guard let idx = all.firstIndex(of: requiredTier) else { return [requiredTier] }
        let lower = idx > 0 ? idx - 1 : idx
        let upper = min(idx + 1, all.count - 1)
        return Array(all[lower...upper])
    }

    var body: some View {
        NavigationStack {
            ZStack {
                TOYBackground()

                VStack(spacing: 0) {
                    ScrollView {
                        VStack(alignment: .leading, spacing: TOYSpacing.xl) {
                            headerView
                            tierListView

                            if let errorMessage {
                                Text(errorMessage)
                                    .font(.toyCaption())
                                    .foregroundColor(.toyDestructive)
                                    .padding(.horizontal, TOYSpacing.xs)
                            }
                        }
                        .padding(.horizontal, TOYSpacing.lg)
                        .padding(.vertical, TOYSpacing.lg)
                    }
                    .scrollBounceBehavior(.basedOnSize)

                    // Pinned bottom CTA (not in ScrollView)
                    VStack(spacing: TOYSpacing.md) {
                        purchaseButton

                        HStack(spacing: 0) {
                            Text("By purchasing, you agree to our ")
                                .font(.toyCaption())
                                .foregroundColor(.toyTextSecondary)
                            Button("Terms") {
                                openURL(URL(string: "https://sendtoycard.com/terms")!)
                            }
                            .font(.toyCaption())
                            .foregroundColor(.toyTextSecondary)
                            .underline()
                        }
                    }
                    .padding(.horizontal, TOYSpacing.lg)
                    .padding(.bottom, TOYSpacing.lg)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Color.toyBackground, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        onCancel()
                        dismiss()
                    }
                    .font(.toyBody())
                    .foregroundColor(.toyTextSecondary)
                }
            }
        }
        .task { await loadPrices() }
    }

    // MARK: - Header

    private var headerView: some View {
        VStack(alignment: .leading, spacing: TOYSpacing.md) {
            Text("Purchase Card")
                .font(.toyTitle())
                .foregroundColor(.toyText)
            Text("\(clipCount) clips \u{2014} upgrade required")
                .font(.toySubheadline())
                .foregroundColor(.toyTextSecondary)
            Text("One-time purchase to publish this card with \(requiredTier.displayName.lowercased()).")
                .font(.toyCaption())
                .foregroundColor(.toyTextSecondary)
        }
    }

    // MARK: - Tier List

    private var tierListView: some View {
        VStack(spacing: TOYSpacing.md) {
            ForEach(visibleTiers, id: \.self) { tier in
                let isRequired = tier == requiredTier
                CheckoutTierRow(
                    tier: tier,
                    priceString: priceString(for: tier),
                    isRequired: isRequired
                )
                .opacity(isRequired ? 1.0 : 0.4)
            }
        }
    }

    // MARK: - Purchase Button

    @ViewBuilder
    private var purchaseButton: some View {
        let ctaTitle: String = {
            if isPurchasing { return "Purchasing..." }
            if let price = priceString(for: requiredTier) {
                return "Purchase \u{2014} \(price)"
            }
            return "Purchase"
        }()

        TOYButton.primary(
            ctaTitle,
            isLoading: isPurchasing
        ) {
            Task { await handlePurchase() }
        }
        .disabled(isPurchasing)
    }

    // MARK: - Price Helpers

    private func priceString(for tier: CardTier) -> String? {
        guard let identifier = tier.packageIdentifier,
              let package = packages[identifier] else {
            return tier.fallbackPrice
        }
        return package.localizedPriceString
    }

    private func loadPrices() async {
        #if DEBUG
        await PurchaseService.shared.debugFetchProducts()
        #endif
        do {
            packages = try await PurchaseService.shared.fetchTierPackages()
        } catch {
            #if DEBUG
            print("[Purchase] loadPrices error: \(error)")
            #endif
        }
    }

    // MARK: - Purchase Flow

    private func handlePurchase() async {
        guard let identifier = requiredTier.packageIdentifier,
              let package = packages[identifier] else { return }

        isPurchasing = true
        errorMessage = nil

        do {
            // Step 1: Execute purchase via RevenueCat
            let (_, transactionId) = try await PurchaseService.shared.purchaseWithTransaction(package: package)

            // Step 2: Record purchase to Supabase IMMEDIATELY (before publish)
            let cardService = CardService()
            try await cardService.recordTierPurchase(
                cardId: card.id,
                maxParticipants: requiredTier.maxParticipantsValue,
                transactionId: transactionId ?? "unknown"
            )

            // Step 3: Dismiss and trigger publish
            await MainActor.run {
                dismiss()
                onPurchaseComplete()
            }
        } catch {
            if case PurchaseError.purchaseCancelled = error {
                // User cancelled Apple payment sheet -- stay on checkout
                isPurchasing = false
                return
            }
            errorMessage = error.localizedDescription
            isPurchasing = false
        }
    }
}

// MARK: - Checkout Tier Row

/// A single row displaying a tier's name, price, and whether it's the required tier.
private struct CheckoutTierRow: View {
    let tier: CardTier
    let priceString: String?
    let isRequired: Bool

    private var tierLabel: String {
        tier == .free ? "Up to \(tier.clipLimit) People" : tier.displayName
    }

    var body: some View {
        HStack(spacing: TOYSpacing.md) {
            Text(tierLabel)
                .font(.toyBodyMedium())
                .foregroundColor(.toyText)

            Spacer()

            Text(priceString ?? "\u{2014}")
                .font(.toyBodyMedium())
                .foregroundColor(.toyText)
        }
        .padding(TOYSpacing.md)
        .background(
            Rectangle()
                .stroke(isRequired ? Color.toyText : Color.toyDivider, lineWidth: isRequired ? 2 : 1)
        )
    }
}
