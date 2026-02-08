import Foundation
import RevenueCat

/// Errors that can occur during purchase operations
public enum PurchaseError: LocalizedError, Sendable {
    case productNotFound
    case purchaseFailed(String)
    case restoreFailed(String)
    case noOfferings

    public var errorDescription: String? {
        switch self {
        case .productNotFound:
            return "Product not found"
        case .purchaseFailed(let message):
            return "Purchase failed: \(message)"
        case .restoreFailed(let message):
            return "Restore failed: \(message)"
        case .noOfferings:
            return "No offerings available"
        }
    }
}

/// Actor-based service for in-app purchases via RevenueCat.
///
/// Provides a clean interface to RevenueCat's purchase and entitlement APIs.
/// Use this service to fetch offerings, make purchases, restore purchases,
/// and check entitlement status.
///
/// Usage:
/// ```swift
/// let offerings = try await PurchaseService.shared.fetchOfferings()
/// if let package = offerings.current?.availablePackages.first {
///     let customerInfo = try await PurchaseService.shared.purchase(package: package)
/// }
/// ```
public actor PurchaseService {
    /// Shared singleton instance
    public static let shared = PurchaseService()

    private init() {}

    // MARK: - Offerings

    /// Fetches available offerings from RevenueCat
    ///
    /// Offerings contain the products configured in RevenueCat Dashboard.
    /// Each offering can contain multiple packages (e.g., monthly, yearly).
    ///
    /// - Returns: The available offerings
    /// - Throws: Error if fetch fails
    public func fetchOfferings() async throws -> Offerings {
        try await Purchases.shared.offerings()
    }

    /// Fetches all tier packages from the current RevenueCat offering.
    ///
    /// Returns packages keyed by their custom identifier (e.g., "starter", "group", "mega").
    /// These are consumable IAP products -- each purchase applies to a single card.
    /// The offering should be configured in RevenueCat Dashboard with packages
    /// matching CardTier.packageIdentifier values.
    ///
    /// - Returns: Dictionary of packages keyed by identifier string
    /// - Throws: PurchaseError.noOfferings if no current offering exists
    public func fetchTierPackages() async throws -> [String: Package] {
        let offerings = try await Purchases.shared.offerings()
        guard let offering = offerings.current else {
            throw PurchaseError.noOfferings
        }
        var packages: [String: Package] = [:]
        for package in offering.availablePackages {
            packages[package.identifier] = package
        }
        return packages
    }

    // MARK: - Purchases

    /// Purchases a package and returns the customer info
    ///
    /// - Parameter package: The package to purchase (from offerings)
    /// - Returns: Updated customer info with entitlements
    /// - Throws: PurchaseError if purchase fails
    public func purchase(package: Package) async throws -> CustomerInfo {
        do {
            let (_, customerInfo, _) = try await Purchases.shared.purchase(package: package)
            return customerInfo
        } catch {
            throw PurchaseError.purchaseFailed(error.localizedDescription)
        }
    }

    /// Restores previous purchases for the current user
    ///
    /// Use this when a user logs in on a new device or reinstalls the app.
    ///
    /// - Returns: Updated customer info with restored entitlements
    /// - Throws: PurchaseError if restore fails
    public func restorePurchases() async throws -> CustomerInfo {
        do {
            return try await Purchases.shared.restorePurchases()
        } catch {
            throw PurchaseError.restoreFailed(error.localizedDescription)
        }
    }

    // MARK: - Customer Info

    /// Gets current customer info (entitlements)
    ///
    /// - Returns: Current customer info
    /// - Throws: Error if fetch fails
    public func getCustomerInfo() async throws -> CustomerInfo {
        try await Purchases.shared.customerInfo()
    }

    /// Checks if user has an active entitlement
    ///
    /// - Parameter entitlementId: The entitlement identifier to check
    /// - Returns: True if the entitlement is active
    public func hasEntitlement(_ entitlementId: String) async -> Bool {
        do {
            let customerInfo = try await getCustomerInfo()
            return customerInfo.entitlements[entitlementId]?.isActive == true
        } catch {
            return false
        }
    }

    /// Checks if a specific card has been upgraded (purchased)
    ///
    /// This checks the product ID for per-card purchases.
    /// The product ID should match the card's purchase identifier.
    ///
    /// - Parameter cardId: The card UUID to check
    /// - Returns: True if the card upgrade was purchased
    @available(*, deprecated, message: "Use card.maxParticipants for tier status. Per-card product IDs are not used in the tier model.")
    public func isCardUpgraded(cardId: UUID) async -> Bool {
        do {
            let customerInfo = try await getCustomerInfo()
            // Check if any active subscription or non-consumable includes this card
            // In RevenueCat 5.x, nonSubscriptions is [NonSubscriptionTransaction]
            let productId = "card_upgrade_\(cardId.uuidString.lowercased())"
            // Search through all non-subscription transactions for matching product
            return customerInfo.nonSubscriptions.contains { transaction in
                transaction.productIdentifier == productId
            }
        } catch {
            return false
        }
    }
}
