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
    // Use local @State for text fields to avoid @Observable re-renders on every keystroke
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

                // Form fields - native TextFields for best responsiveness
                VStack(spacing: 16) {
                    textField(
                        placeholder: "Card title (e.g., Happy Birthday Sarah!)",
                        text: $title,
                        icon: "gift"
                    )

                    textField(
                        placeholder: "Who is this card for?",
                        text: $recipientName,
                        icon: "person"
                    )
                }

                // Error display
                if let errorMessage = errorMessage {
                    Text(errorMessage)
                        .font(.toyCaption())
                        .foregroundColor(.red)
                        .padding(.horizontal, 4)
                }

                // Continue button
                Button {
                    Task { await createCard() }
                } label: {
                    HStack {
                        if isCreating {
                            ProgressView()
                                .tint(.white)
                        }
                        Text("Continue")
                            .fontWeight(.semibold)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(canSubmit ? Color.toyPrimary : Color.toyPrimary.opacity(0.5))
                    .foregroundColor(.white)
                    .cornerRadius(12)
                }
                .disabled(!canSubmit)

                Spacer()
            }
            .padding(.horizontal, 24)
            .padding(.top, 24)
        }
        .background(Color.toyBackground)
        .onChange(of: createdCard) { _, newCard in
            if let card = newCard {
                onCardCreated(card)
            }
        }
    }

    // MARK: - Components

    @ViewBuilder
    private func textField(placeholder: String, text: Binding<String>, icon: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(.toyTextSecondary)
                .frame(width: 20)

            TextField(placeholder, text: text)
                .font(.toyBody())
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(Color.toySurface)
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color.gray.opacity(0.3), lineWidth: 1)
        )
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
