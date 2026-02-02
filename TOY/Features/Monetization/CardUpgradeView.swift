import SwiftUI
import RevenueCat
import TOYShared

/// A view that displays the card upgrade purchase UI.
///
/// Shows the current participant count, benefits of upgrading,
/// and allows the host to purchase unlimited participants for their card.
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
            VStack(spacing: 24) {
                // Header
                VStack(spacing: 8) {
                    Image(systemName: "person.3.fill")
                        .font(.system(size: 48))
                        .foregroundStyle(.toyPrimary)

                    Text("Upgrade Your Card")
                        .font(.custom("DMSerifDisplay-Regular", size: 28))

                    Text("Unlock unlimited participants")
                        .foregroundStyle(.secondary)
                }
                .padding(.top, 24)

                // Current status
                VStack(spacing: 4) {
                    Text("\(currentParticipantCount) of \(card.maxParticipants)")
                        .font(.title2.bold())
                    Text("participants used")
                        .foregroundStyle(.secondary)
                }
                .padding()
                .frame(maxWidth: .infinity)
                .background(.toySurface)
                .cornerRadius(12)

                // Benefits list
                VStack(alignment: .leading, spacing: 12) {
                    benefitRow(icon: "infinity", text: "Unlimited participants")
                    benefitRow(icon: "star.fill", text: "No restrictions on this card")
                    benefitRow(icon: "heart.fill", text: "Support TOY development")
                }
                .padding()

                Spacer()

                // Action buttons
                VStack(spacing: 12) {
                    actionContent
                }
                .padding(.bottom, 24)
            }
            .padding(.horizontal)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
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
            TOYButton("Upgrade - \(package.localizedPriceString)", size: .large) {
                Task { await viewModel.purchase() }
            }

            restorePurchasesButton

        case .purchasing:
            TOYButton("Processing...", size: .large, isLoading: true) {}

        case .success:
            successContent

        case .error(let message):
            errorContent(message: message)
        }
    }

    private var successContent: some View {
        VStack(spacing: 8) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 48))
                .foregroundStyle(.green)
            Text("Upgrade Complete!")
                .font(.headline)
        }
        .onAppear {
            // Auto-dismiss after success animation
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                dismiss()
            }
        }
    }

    private func errorContent(message: String) -> some View {
        VStack(spacing: 12) {
            Text(message)
                .foregroundStyle(.red)
                .multilineTextAlignment(.center)

            TOYButton("Try Again", size: .large) {
                Task { await viewModel.loadOffering() }
            }

            restorePurchasesButton
        }
    }

    private var restorePurchasesButton: some View {
        Button("Restore Purchases") {
            Task { await viewModel.restore() }
        }
        .font(.footnote)
        .foregroundStyle(.secondary)
    }

    private func benefitRow(icon: String, text: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundStyle(.toyPrimary)
                .frame(width: 24)
            Text(text)
                .foregroundStyle(.primary)
            Spacer()
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
