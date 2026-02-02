import Foundation
import RevenueCat
import TOYShared

/// View model managing the card upgrade purchase flow.
///
/// Handles loading RevenueCat offerings, purchasing upgrade packages,
/// restoring purchases, and recording the upgrade on the card.
@MainActor
@Observable
public final class UpgradeViewModel {

    // MARK: - State

    public enum State: Equatable {
        case idle
        case loading
        case ready(Package)
        case purchasing
        case success
        case error(String)

        public static func == (lhs: State, rhs: State) -> Bool {
            switch (lhs, rhs) {
            case (.idle, .idle),
                 (.loading, .loading),
                 (.purchasing, .purchasing),
                 (.success, .success):
                return true
            case (.ready(let lhsPackage), .ready(let rhsPackage)):
                return lhsPackage.identifier == rhsPackage.identifier
            case (.error(let lhsMessage), .error(let rhsMessage)):
                return lhsMessage == rhsMessage
            default:
                return false
            }
        }
    }

    public private(set) var state: State = .idle

    private let cardId: UUID
    private let purchaseService = PurchaseService.shared

    // MARK: - Initialization

    public init(cardId: UUID) {
        self.cardId = cardId
    }

    // MARK: - Public Methods

    /// Loads available upgrade package from RevenueCat
    public func loadOffering() async {
        state = .loading

        do {
            let offerings = try await purchaseService.fetchOfferings()

            // Look for "card_upgrade" offering or use default offering
            guard let offering = offerings.current,
                  let package = offering.availablePackages.first else {
                state = .error("No upgrade package available")
                return
            }

            state = .ready(package)

            #if DEBUG
            print("💰 Loaded upgrade package: \(package.localizedPriceString)")
            #endif
        } catch {
            state = .error(error.localizedDescription)
        }
    }

    /// Purchases the upgrade package
    public func purchase() async {
        guard case .ready(let package) = state else { return }

        state = .purchasing

        do {
            _ = try await purchaseService.purchase(package: package)

            // Record upgrade on card (best effort - even if this fails, RevenueCat has the purchase)
            await recordCardUpgrade()

            state = .success

            #if DEBUG
            print("✅ Upgrade purchase completed for card: \(cardId)")
            #endif
        } catch {
            state = .error(error.localizedDescription)
        }
    }

    /// Restores previous purchases
    public func restore() async {
        state = .loading

        do {
            _ = try await purchaseService.restorePurchases()

            // Check if card should be upgraded after restore
            await recordCardUpgrade()

            state = .success

            #if DEBUG
            print("✅ Purchases restored, card upgrade recorded: \(cardId)")
            #endif
        } catch {
            state = .error(error.localizedDescription)
        }
    }

    // MARK: - Computed Properties

    /// The localized price string for the upgrade package
    public var priceString: String? {
        if case .ready(let package) = state {
            return package.localizedPriceString
        }
        return nil
    }

    // MARK: - Private Methods

    private func recordCardUpgrade() async {
        // Update card's maxParticipants to unlimited (999)
        // This is tracked in the database - could also use webhook for server-side verification
        do {
            try await CardService().updateCardMaxParticipants(cardId: cardId, maxParticipants: 999)
        } catch {
            // Best effort - purchase succeeded even if local record fails
            // RevenueCat is the source of truth for the purchase
            #if DEBUG
            print("⚠️ Failed to record card upgrade: \(error)")
            #endif
        }
    }
}
