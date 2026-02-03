import SwiftUI
import TOYShared

/// The card creation form where hosts enter card details.
struct CreateCardView: View {

    // MARK: - Properties

    let hostId: UUID
    let onCardCreated: (Card) -> Void

    // MARK: - State

    @State private var title: String = ""
    @State private var recipientName: String = ""
    @State private var isCreating: Bool = false
    @State private var errorMessage: String? = nil
    @State private var createdCard: Card? = nil

    private let cardService = CardService()

    // MARK: - Computed

    private var isFormValid: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !recipientName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var canSubmit: Bool {
        isFormValid && !isCreating
    }

    // MARK: - Body

    var body: some View {
        ZStack {
            TOYBackground()

            ScrollView {
                VStack(alignment: .leading, spacing: TOYSpacing.xl) {
                    // Header - large serif title
                    VStack(alignment: .leading, spacing: TOYSpacing.sm) {
                        Text("Create a\nCard")
                            .font(.toyTitle())
                            .foregroundColor(.toyText)
                            .lineSpacing(-4)

                        Text("Enter the details for your video card.")
                            .font(.toySubheadline())
                            .foregroundColor(.toyTextSecondary)
                    }
                    .padding(.top, TOYSpacing.xl)

                    // Form fields - minimal bottom border style
                    VStack(spacing: TOYSpacing.xl) {
                        TOYLabeledTextField(
                            label: "CARD TITLE",
                            placeholder: "Happy Birthday Sarah!",
                            text: $title
                        )

                        TOYLabeledTextField(
                            label: "RECIPIENT",
                            placeholder: "Who is this card for?",
                            text: $recipientName
                        )
                    }

                    // Error display
                    if let errorMessage = errorMessage {
                        Text(errorMessage)
                            .font(.toyCaption())
                            .foregroundColor(.toyDestructive)
                    }

                    Spacer(minLength: TOYSpacing.xxl)

                    // Continue button
                    TOYButton.primary(isCreating ? "Creating..." : "Continue", isLoading: isCreating) {
                        Task { await createCard() }
                    }
                    .disabled(!canSubmit)
                    .opacity(canSubmit ? 1.0 : 0.5)
                }
                .padding(.horizontal, TOYSpacing.lg)
                .padding(.bottom, TOYSpacing.xl)
            }
        }
        .onChange(of: createdCard) { _, newCard in
            if let card = newCard {
                onCardCreated(card)
            }
        }
    }

    // MARK: - Actions

    private func createCard() async {
        guard canSubmit else { return }

        isCreating = true
        errorMessage = nil

        do {
            let card = try await cardService.createCard(
                title: title.trimmingCharacters(in: .whitespacesAndNewlines),
                recipientName: recipientName.trimmingCharacters(in: .whitespacesAndNewlines),
                occasion: nil,
                hostId: hostId
            )
            createdCard = card
        } catch {
            errorMessage = error.localizedDescription
        }

        isCreating = false
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
