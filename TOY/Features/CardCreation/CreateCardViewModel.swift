import Foundation
import SwiftUI
import TOYShared

/// ViewModel for the card creation form.
/// Manages form state, validation, and card creation via CardService.
@MainActor
@Observable
final class CreateCardViewModel {

    // MARK: - Form State

    var title: String = ""
    var recipientName: String = ""
    var occasion: String? = nil

    // MARK: - UI State

    var isCreating: Bool = false
    var errorMessage: String? = nil
    var createdCard: Card? = nil

    // MARK: - Dependencies

    private let cardService = CardService()

    // MARK: - Computed Properties

    /// Returns true if the form has valid input (non-empty title and recipient name).
    var isFormValid: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !recipientName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    /// Returns true if the form can be submitted (valid and not currently creating).
    var canSubmit: Bool {
        isFormValid && !isCreating
    }

    // MARK: - Actions

    /// Creates a new card in the database.
    /// - Parameter hostId: The ID of the authenticated user creating the card
    func createCard(hostId: UUID) async {
        guard canSubmit else { return }

        isCreating = true
        errorMessage = nil

        do {
            #if DEBUG
            print("🔄 Creating card for host: \(hostId)")
            #endif

            let card = try await cardService.createCard(
                title: title.trimmingCharacters(in: .whitespacesAndNewlines),
                recipientName: recipientName.trimmingCharacters(in: .whitespacesAndNewlines),
                occasion: occasion?.trimmingCharacters(in: .whitespacesAndNewlines),
                hostId: hostId
            )
            createdCard = card

            // Track card creation event
            AnalyticsService.shared.trackCardCreated(
                cardId: card.id,
                occasion: occasion?.trimmingCharacters(in: .whitespacesAndNewlines)
            )

            #if DEBUG
            print("Card created: \(card.id)")
            #endif
        } catch {
            #if DEBUG
            print("❌ Card creation failed: \(error)")
            print("   Underlying error: \(String(describing: error))")
            #endif
            errorMessage = error.localizedDescription
        }

        isCreating = false
    }

    /// Resets the form to its initial state.
    func reset() {
        title = ""
        recipientName = ""
        occasion = nil
        isCreating = false
        errorMessage = nil
        createdCard = nil
    }
}
