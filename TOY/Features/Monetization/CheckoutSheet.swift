import SwiftUI
import RevenueCat
import TOYShared

/// Publish-time checkout sheet presented when a host needs to upgrade before publishing.
/// Distinct from TierSelectionSheet (browse-only) -- this includes a purchase CTA.
struct CheckoutSheet: View {
    let card: Card
    let clipCount: Int
    let onPurchaseComplete: () -> Void
    let onCancel: () -> Void

    @State private var packages: [String: Package] = [:]
    @State private var selectedTier: CardTier
    @State private var isLoading = true
    @State private var isPurchasing = false
    @State private var errorMessage: String?
    @Environment(\.dismiss) private var dismiss

    /// The minimum tier required for the current clip count.
    private var requiredTier: CardTier {
        CardTier.requiredTier(for: clipCount)
    }

    init(
        card: Card,
        clipCount: Int,
        onPurchaseComplete: @escaping () -> Void,
        onCancel: @escaping () -> Void
    ) {
        self.card = card
        self.clipCount = clipCount
        self.onPurchaseComplete = onPurchaseComplete
        self.onCancel = onCancel
        // Auto-select the cheapest tier that fits the clip count (TIER-04)
        self._selectedTier = State(initialValue: CardTier.requiredTier(for: clipCount))
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

                    // Pinned bottom CTA (not in ScrollView)
                    purchaseButton
                        .padding(.horizontal, TOYSpacing.lg)
                        .padding(.bottom, TOYSpacing.xl)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
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
            Text("Publish Card")
                .font(.toyTitle())
                .foregroundColor(.toyText)
            Text("\(clipCount) clips \u{2014} requires \(requiredTier.displayName) tier")
                .font(.toySubheadline())
                .foregroundColor(.toyTextSecondary)
        }
    }

    // MARK: - Tier List

    @ViewBuilder
    private var tierListView: some View {
        if isLoading {
            ProgressView()
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.vertical, TOYSpacing.xl)
        } else {
            VStack(spacing: TOYSpacing.md) {
                ForEach(CardTier.allCases.filter { $0.isPaid }, id: \.self) { tier in
                    let isDisabled = isTierDisabled(tier)
                    let isSelected = tier == selectedTier

                    Button {
                        selectedTier = tier
                    } label: {
                        CheckoutTierRow(
                            tier: tier,
                            priceString: priceString(for: tier),
                            isSelected: isSelected,
                            clipCount: clipCount
                        )
                    }
                    .disabled(isDisabled)
                    .opacity(isDisabled ? 0.4 : 1.0)
                }
            }
        }
    }

    // MARK: - Purchase Button

    @ViewBuilder
    private var purchaseButton: some View {
        let ctaTitle: String = {
            if isPurchasing { return "Publishing..." }
            if let price = priceString(for: selectedTier) {
                return "Publish \u{2014} \(price)"
            }
            return "Publish"
        }()

        TOYButton.primary(
            ctaTitle,
            isLoading: isPurchasing
        ) {
            Task { await handlePurchase() }
        }
        .disabled(isPurchasing || isLoading)
    }

    // MARK: - Tier Helpers

    /// A tier is disabled (not selectable) if it cannot hold the current clip count.
    /// Mega tier is never disabled (unlimited).
    private func isTierDisabled(_ tier: CardTier) -> Bool {
        guard tier != .mega else { return false }
        return tier.clipLimit < clipCount
    }

    // MARK: - Price Helpers

    private func priceString(for tier: CardTier) -> String? {
        guard let identifier = tier.packageIdentifier,
              let package = packages[identifier] else { return nil }
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

    // MARK: - Purchase Flow

    private func handlePurchase() async {
        guard let identifier = selectedTier.packageIdentifier,
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
                maxParticipants: selectedTier.maxParticipantsValue,
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

/// A single selectable row displaying a tier's name, clip limit, price, and selection state.
private struct CheckoutTierRow: View {
    let tier: CardTier
    let priceString: String?
    let isSelected: Bool
    let clipCount: Int

    private var clipLimitText: String {
        if tier == .mega {
            return "Unlimited clips"
        }
        return "Up to \(tier.clipLimit) clips"
    }

    var body: some View {
        HStack(spacing: TOYSpacing.md) {
            VStack(alignment: .leading, spacing: TOYSpacing.xs) {
                Text(tier.displayName)
                    .font(.toyBodyMedium())
                    .foregroundColor(.toyText)
                Text(clipLimitText)
                    .font(.toyCaption())
                    .foregroundColor(.toyTextSecondary)
            }

            Spacer()

            HStack(spacing: TOYSpacing.sm) {
                Text(priceString ?? "\u{2014}")
                    .font(.toyBodyMedium())
                    .foregroundColor(.toyText)

                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 20))
                        .foregroundColor(.toyText)
                }
            }
        }
        .padding(TOYSpacing.md)
        .background(
            Rectangle()
                .stroke(isSelected ? Color.toyText : Color.toyDivider, lineWidth: isSelected ? 2 : 1)
        )
    }
}
