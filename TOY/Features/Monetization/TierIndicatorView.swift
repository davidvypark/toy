import SwiftUI
import TOYShared

/// Stateless tier indicator component for CardDetailView.
/// Shows clip count and tier status with a tappable chevron to browse tiers.
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
