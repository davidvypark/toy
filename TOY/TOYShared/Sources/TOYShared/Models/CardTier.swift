import Foundation

/// Pure value type for tier logic. No persistence, no service dependency.
/// Maps between clip counts, tier names, and maxParticipants column values.
public enum CardTier: Int, CaseIterable, Comparable, Sendable {
    case free = 0       // up to 5 clips (default)
    case card10 = 1     // up to 10 clips
    case card25 = 2     // up to 25 clips
    case card50 = 3     // up to 50 clips
    case card100 = 4    // up to 100 clips
    case card150 = 5    // up to 150 clips
    case card200 = 6    // up to 200 clips

    /// The clip limit for this tier (used for display and pricing, NOT for enforcement).
    ///
    /// For enforcement of clip limits, always compare against `card.maxParticipants` directly.
    public var clipLimit: Int {
        switch self {
        case .free: return 5
        case .card10: return 10
        case .card25: return 25
        case .card50: return 50
        case .card100: return 100
        case .card150: return 150
        case .card200: return 200
        }
    }

    /// Human-readable tier name for display in UI.
    public var displayName: String {
        switch self {
        case .free: return "Free"
        case .card10: return "Up to 10 People"
        case .card25: return "Up to 25 People"
        case .card50: return "Up to 50 People"
        case .card100: return "Up to 100 People"
        case .card150: return "Up to 150 People"
        case .card200: return "Up to 200 People"
        }
    }

    /// The `maxParticipants` value to store in Supabase when this tier is purchased.
    public var maxParticipantsValue: Int {
        switch self {
        case .free: return 5
        case .card10: return 10
        case .card25: return 25
        case .card50: return 50
        case .card100: return 100
        case .card150: return 150
        case .card200: return 200
        }
    }

    /// Fallback price string used when RevenueCat packages aren't available yet.
    public var fallbackPrice: String {
        switch self {
        case .free: return "Free"
        case .card10: return "$1.99"
        case .card25: return "$4.99"
        case .card50: return "$14.99"
        case .card100: return "$29.99"
        case .card150: return "$49.99"
        case .card200: return "$69.99"
        }
    }

    /// Whether this tier requires a purchase.
    public var isPaid: Bool { self != .free }

    /// The RevenueCat package identifier for this tier.
    /// Returns nil for the free tier (no purchase needed).
    public var packageIdentifier: String? {
        switch self {
        case .free: return nil
        case .card10: return "toy_card_10"
        case .card25: return "toy_card_25"
        case .card50: return "toy_card_50"
        case .card100: return "toy_card_100"
        case .card150: return "toy_card_150"
        case .card200: return "toy_card_200"
        }
    }

    /// Determines the minimum tier required for a given clip count.
    ///
    /// Iterates through all tiers in order and returns the first tier whose
    /// `clipLimit` is greater than or equal to `clipCount`.
    ///
    /// - Parameter clipCount: The number of clips on the card.
    /// - Returns: The cheapest tier that can accommodate the given clip count.
    public static func requiredTier(for clipCount: Int) -> CardTier {
        for tier in CardTier.allCases {
            if clipCount <= tier.clipLimit { return tier }
        }
        return .card200
    }

    /// Maps a database `maxParticipants` column value to a `CardTier` for display purposes.
    ///
    /// For **enforcement** (determining whether a card can publish), always compare
    /// `clips.count` against `card.maxParticipants` directly, NOT against `CardTier.clipLimit`.
    ///
    /// - Parameter maxParticipants: The value from the `cards.max_participants` database column.
    /// - Returns: The corresponding `CardTier` for display purposes.
    public static func fromMaxParticipants(_ maxParticipants: Int) -> CardTier {
        switch maxParticipants {
        case ...5: return .free
        case 6...10: return .card10
        case 11...25: return .card25
        case 26...50: return .card50
        case 51...100: return .card100
        case 101...150: return .card150
        default: return .card200
        }
    }

    public static func < (lhs: CardTier, rhs: CardTier) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}
