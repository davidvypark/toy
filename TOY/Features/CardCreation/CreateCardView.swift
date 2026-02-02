import SwiftUI
import TOYShared

/// The card creation form where hosts enter card details.
/// Collects title and recipient name, creates the card via CardService,
/// and invokes a callback when creation is successful.
struct CreateCardView: View {

    // MARK: - Properties

    let hostId: UUID
    let onCardCreated: (Card) -> Void

    // MARK: - State

    @State private var viewModel = CreateCardViewModel()

    // MARK: - Body

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // Header section
                VStack(alignment: .leading, spacing: 8) {
                    TOYLabel.largeTitle("Create a Card")
                    TOYLabel(
                        "Enter the details for your group video card. You'll be able to record your clip and invite others next.",
                        style: .subheadline,
                        color: .toyTextSecondary
                    )
                }

                // Form fields
                VStack(spacing: 16) {
                    TOYTextField(
                        "e.g., Happy Birthday Sarah!",
                        text: $viewModel.title,
                        icon: "gift"
                    )

                    TOYTextField(
                        "Who is this card for?",
                        text: $viewModel.recipientName,
                        icon: "person"
                    )
                }

                // Error display
                if let errorMessage = viewModel.errorMessage {
                    Text(errorMessage)
                        .font(.toyCaption())
                        .foregroundColor(.red)
                        .padding(.horizontal, 4)
                }

                // Continue button
                TOYButton(
                    "Continue",
                    style: .primary,
                    size: .large,
                    isLoading: viewModel.isCreating
                ) {
                    Task {
                        await viewModel.createCard(hostId: hostId)
                    }
                }
                .disabled(!viewModel.canSubmit)
                .opacity(viewModel.canSubmit ? 1.0 : 0.5)

                Spacer()
            }
            .padding(.horizontal, 24)
            .padding(.top, 24)
        }
        .background(Color.toyBackground)
        .onChange(of: viewModel.createdCard) { _, newCard in
            if let card = newCard {
                onCardCreated(card)
            }
        }
    }
}

// MARK: - Preview

#Preview {
    CreateCardView(
        hostId: UUID(),
        onCardCreated: { card in
            print("Card created: \(card.title)")
        }
    )
}
