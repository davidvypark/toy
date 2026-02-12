import Foundation
import RevenueCat
import StoreKit

/// Errors that can occur during purchase operations
public enum PurchaseError: LocalizedError, Sendable {
    case productNotFound
    case purchaseFailed(String)
    case purchaseCancelled
    case restoreFailed(String)
    case noOfferings

    public var errorDescription: String? {
        switch self {
        case .productNotFound:
            return "Product not found"
        case .purchaseFailed(let message):
            return "Purchase failed: \(message)"
        case .purchaseCancelled:
            return "Purchase was cancelled"
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
/// let packages = try await PurchaseService.shared.fetchTierPackages()
/// if let package = packages["starter"] {
///     let (info, txnId) = try await PurchaseService.shared.purchaseWithTransaction(package: package)
/// }
/// ```
public actor PurchaseService {
    /// Shared singleton instance
    public static let shared = PurchaseService()

    private init() {}

    // MARK: - Offerings

    /// Fetches all tier packages from the current RevenueCat offering.
    ///
    /// Returns packages keyed by their custom identifier (e.g., "toy_card_10", "toy_card_25").
    /// These are consumable IAP products -- each purchase applies to a single card.
    /// The offering should be configured in RevenueCat Dashboard with packages
    /// matching CardTier.packageIdentifier values.
    ///
    /// - Returns: Dictionary of packages keyed by identifier string
    /// - Throws: PurchaseError.noOfferings if no current offering exists
    public func fetchTierPackages() async throws -> [String: Package] {
        let offerings: Offerings
        do {
            offerings = try await Purchases.shared.offerings()
        } catch {
            #if DEBUG
            print("[Purchase] ❌ offerings() threw: \(error)")
            print("[Purchase] ❌ Error type: \(type(of: error))")
            #endif
            throw error
        }

        #if DEBUG
        print("[Purchase] All offerings: \(Array(offerings.all.keys))")
        print("[Purchase] Current offering: \(offerings.current?.identifier ?? "nil")")
        if let current = offerings.current {
            print("[Purchase] Available packages: \(current.availablePackages.count)")
            for pkg in current.availablePackages {
                print("[Purchase]   Package: \(pkg.identifier), Product: \(pkg.storeProduct.productIdentifier)")
            }
        }
        #endif

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

    /// Purchases a package and returns both the customer info and the transaction identifier.
    ///
    /// Unlike `purchase(package:)`, this method:
    /// - Returns the transaction identifier for audit trail recording
    /// - Explicitly detects and throws on user cancellation
    ///
    /// - Parameter package: The package to purchase (from offerings)
    /// - Returns: Tuple of customer info and optional transaction identifier
    /// - Throws: `PurchaseError.purchaseCancelled` if user cancels, `PurchaseError.purchaseFailed` for other errors
    public func purchaseWithTransaction(package: Package) async throws -> (customerInfo: CustomerInfo, transactionId: String?) {
        do {
            let (transaction, customerInfo, userCancelled) = try await Purchases.shared.purchase(package: package)
            if userCancelled {
                throw PurchaseError.purchaseCancelled
            }
            return (customerInfo: customerInfo, transactionId: transaction?.transactionIdentifier)
        } catch let error as PurchaseError {
            throw error
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

    // MARK: - Diagnostics

    #if DEBUG
    /// Fetches products directly via StoreKit 2, bypassing RevenueCat.
    /// Use to determine if StoreKit itself can see the products.
    public func debugFetchProducts() async {
        let ids = ["toy_card_10", "toy_card_25", "toy_card_50", "toy_card_100", "toy_card_150", "toy_card_200"]
        print("[StoreKit2] Fetching products directly: \(ids)")
        do {
            let products = try await Product.products(for: Set(ids))
            print("[StoreKit2] Found \(products.count) products:")
            for p in products {
                print("[StoreKit2]   \(p.id) — \(p.displayPrice)")
            }
            if products.isEmpty {
                print("[StoreKit2] ⚠️ No products found — StoreKit config file may not be loading")
            }
        } catch {
            print("[StoreKit2] ❌ Direct fetch failed: \(error)")
        }
    }
    #endif

}
