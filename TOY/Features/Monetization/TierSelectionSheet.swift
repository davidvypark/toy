import SwiftUI
import RevenueCat
import TOYShared

/// A sheet view that displays all available tiers with real prices from RevenueCat.
/// Browse-only -- no purchase button. Phase 15 adds the purchase CTA.
struct TierSelectionSheet: View {
    let card: Card
    let clipCount: Int

    @State private var packages: [String: Package] = [:]
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL

    private var currentTier: CardTier {
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

                        Button("Terms of Service") {
                            openURL(URL(string: "https://sendtoycard.com/terms")!)
                        }
                        .font(.toyCaption())
                        .foregroundColor(.toyTextSecondary)
                        .underline()
                        .frame(maxWidth: .infinity, alignment: .center)
                    }
                    .padding(.horizontal, TOYSpacing.lg)
                    .padding(.vertical, TOYSpacing.lg)
                }
                .scrollBounceBehavior(.basedOnSize)
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Color.toyBackground, for: .navigationBar)
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

    private var tierListView: some View {
        VStack(spacing: TOYSpacing.md) {
            ForEach(CardTier.allCases, id: \.self) { tier in
                TierRowView(
                    tier: tier,
                    priceString: priceString(for: tier),
                    isCurrentTier: tier == currentTier
                )
            }
        }
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
}

// MARK: - Tier Row View

/// A single row displaying a tier's name, price, and status.
private struct TierRowView: View {
    let tier: CardTier
    let priceString: String?
    let isCurrentTier: Bool

    var body: some View {
        HStack(spacing: TOYSpacing.md) {
            Text(tier.displayName)
                .font(.toyBodyMedium())
                .foregroundColor(.toyText)

            Spacer()

            VStack(alignment: .trailing, spacing: TOYSpacing.xs) {
                Text(priceString ?? "\u{2014}")
                    .font(.toyBodyMedium())
                    .foregroundColor(.toyText)
                if isCurrentTier {
                    Text("Current")
                        .font(.toyCaption())
                        .foregroundColor(.toyTextSecondary)
                }
            }
        }
        .padding(TOYSpacing.md)
        .background(
            Rectangle()
                .stroke(isCurrentTier ? Color.toyText : Color.toyDivider, lineWidth: isCurrentTier ? 2 : 1)
        )
    }
}
