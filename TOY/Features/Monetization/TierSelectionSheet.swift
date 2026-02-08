import SwiftUI
import RevenueCat
import TOYShared

/// A sheet view that displays all available tiers with real prices from RevenueCat.
/// Browse-only -- no purchase button. Phase 15 adds the purchase CTA.
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

    private var currentTier: CardTier {
        CardTier.fromMaxParticipants(card.maxParticipants)
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

    // MARK: - Header

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

    // MARK: - Tier List

    @ViewBuilder
    private var tierListView: some View {
        if isLoading {
            ProgressView()
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.vertical, TOYSpacing.xl)
        } else {
            VStack(spacing: TOYSpacing.md) {
                ForEach(CardTier.allCases, id: \.self) { tier in
                    TierRowView(
                        tier: tier,
                        priceString: priceString(for: tier),
                        isRequired: tier == requiredTier,
                        isCurrentTier: tier == currentTier,
                        clipCount: clipCount
                    )
                }
            }
        }
    }

    // MARK: - Price Helpers

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

// MARK: - Tier Row View

/// A single row displaying a tier's name, clip limit, price, and status.
private struct TierRowView: View {
    let tier: CardTier
    let priceString: String?
    let isRequired: Bool
    let isCurrentTier: Bool
    let clipCount: Int

    private var clipLimitText: String {
        if tier == .mega {
            return "Unlimited clips"
        }
        return "Up to \(tier.clipLimit) clips"
    }

    private var statusLabel: String {
        if isCurrentTier {
            return "Current"
        }
        if isRequired && !isCurrentTier {
            return "Required"
        }
        return ""
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

            VStack(alignment: .trailing, spacing: TOYSpacing.xs) {
                Text(priceString ?? "\u{2014}")
                    .font(.toyBodyMedium())
                    .foregroundColor(.toyText)
                if !statusLabel.isEmpty {
                    Text(statusLabel)
                        .font(.toyCaption())
                        .foregroundColor(.toyTextSecondary)
                }
            }
        }
        .padding(TOYSpacing.md)
        .background(
            Rectangle()
                .stroke(isRequired ? Color.toyText : Color.toyDivider, lineWidth: 1)
        )
    }
}
