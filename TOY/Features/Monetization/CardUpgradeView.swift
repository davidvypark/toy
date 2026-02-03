import SwiftUI
import RevenueCat
import TOYShared

/// A view that displays the card upgrade purchase UI.
struct CardUpgradeView: View {
    let card: Card
    let currentParticipantCount: Int

    @State private var viewModel: UpgradeViewModel
    @Environment(\.dismiss) private var dismiss

    init(card: Card, currentParticipantCount: Int) {
        self.card = card
        self.currentParticipantCount = currentParticipantCount
        self._viewModel = State(initialValue: UpgradeViewModel(cardId: card.id))
    }

    var body: some View {
        NavigationStack {
            ZStack {
                TOYBackground()

                VStack(spacing: TOYSpacing.xl) {
                    // Header
                    VStack(alignment: .leading, spacing: TOYSpacing.md) {
                        Text("Upgrade\nYour Card")
                            .font(.toyTitle())
                            .foregroundColor(.toyText)
                            .lineSpacing(-4)

                        Text("Unlock unlimited participants")
                            .font(.toySubheadline())
                            .foregroundColor(.toyTextSecondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.top, TOYSpacing.xl)

                    // Current status
                    VStack(spacing: TOYSpacing.xs) {
                        Text("\(currentParticipantCount) of \(card.maxParticipants)")
                            .font(.toyDisplaySmall())
                            .foregroundColor(.toyText)
                        Text("participants used")
                            .font(.toyCaption())
                            .foregroundColor(.toyTextSecondary)
                    }
                    .padding(TOYSpacing.lg)
                    .frame(maxWidth: .infinity)
                    .overlay(
                        Rectangle()
                            .stroke(Color.toyDivider, lineWidth: 1)
                    )

                    // Benefits list
                    VStack(alignment: .leading, spacing: TOYSpacing.md) {
                        benefitRow(text: "Unlimited participants")
                        benefitRow(text: "No restrictions on this card")
                        benefitRow(text: "Support TOY development")
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    Spacer()

                    // Action buttons
                    VStack(spacing: TOYSpacing.md) {
                        actionContent
                    }
                    .padding(.bottom, TOYSpacing.xl)
                }
                .padding(.horizontal, TOYSpacing.lg)
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .font(.toyBody())
                    .foregroundColor(.toyTextSecondary)
                }
            }
        }
    }

    // MARK: - Subviews

    @ViewBuilder
    private var actionContent: some View {
        switch viewModel.state {
        case .idle, .loading:
            ProgressView()
                .task { await viewModel.loadOffering() }

        case .ready(let package):
            TOYButton.primary("Upgrade - \(package.localizedPriceString)") {
                Task { await viewModel.purchase() }
            }
            restorePurchasesButton

        case .purchasing:
            TOYButton.primary("Processing...", isLoading: true) {}

        case .success:
            successContent

        case .error(let message):
            errorContent(message: message)
        }
    }

    private var successContent: some View {
        VStack(spacing: TOYSpacing.sm) {
            Image(systemName: "checkmark")
                .font(.system(size: 48, weight: .light))
                .foregroundColor(.toyText)
            Text("Upgrade Complete")
                .font(.toyHeadline())
                .foregroundColor(.toyText)
        }
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                dismiss()
            }
        }
    }

    private func errorContent(message: String) -> some View {
        VStack(spacing: TOYSpacing.md) {
            Text(message)
                .font(.toyBody())
                .foregroundColor(.toyDestructive)
                .multilineTextAlignment(.center)

            TOYButton.primary("Try Again") {
                Task { await viewModel.loadOffering() }
            }

            restorePurchasesButton
        }
    }

    private var restorePurchasesButton: some View {
        Button("Restore Purchases") {
            Task { await viewModel.restore() }
        }
        .font(.toyCaption())
        .foregroundColor(.toyTextSecondary)
        .underline()
    }

    private func benefitRow(text: String) -> some View {
        HStack(spacing: TOYSpacing.sm) {
            Rectangle()
                .fill(Color.toyText)
                .frame(width: 8, height: 1)
            Text(text)
                .font(.toyBody())
                .foregroundColor(.toyText)
        }
    }
}

// MARK: - Preview

#Preview {
    CardUpgradeView(
        card: Card(
            id: UUID(),
            hostId: UUID(),
            title: "Happy Birthday Sarah!",
            recipientName: "Sarah",
            maxParticipants: 8
        ),
        currentParticipantCount: 8
    )
}
