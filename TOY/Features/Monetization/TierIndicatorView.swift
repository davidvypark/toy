import SwiftUI
import TOYShared

/// Stateless tier indicator component for CardDetailView.
/// Shows clip count and pricing status with a tappable area to browse tiers.
struct TierIndicatorView: View {
    let clipCount: Int
    let needsUpgrade: Bool
    let onTapUpgrade: () -> Void

    private var subtitleText: String {
        needsUpgrade ? "Check Pricing" : "Free Tier"
    }

    var body: some View {
        Button(action: onTapUpgrade) {
            HStack(spacing: TOYSpacing.md) {
                VStack(alignment: .leading, spacing: TOYSpacing.xs) {
                    Text("\(clipCount) clips submitted")
                        .font(.toyBodyMedium())
                        .foregroundColor(.toyText)
                    Text(subtitleText)
                        .font(.toyCaption())
                        .foregroundColor(.toyTextSecondary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.toyTextSecondary)
            }
            .padding(TOYSpacing.md)
            .contentShape(Rectangle())
            .background(
                Rectangle()
                    .stroke(Color.toyDivider, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}
