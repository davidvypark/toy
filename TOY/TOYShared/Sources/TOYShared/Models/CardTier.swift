import Foundation

/// Pure value type for tier logic. No persistence, no service dependency.
/// Maps between clip counts, tier names, and maxParticipants column values.
public enum CardTier: Int, CaseIterable, Comparable, Sendable {
    case free = 0       // up to 5 clips (new default)
    case starter = 1    // up to 10 clips
    case group = 2      // up to 25 clips
    case mega = 3       // unlimited (999 in database)

    /// The clip limit for this tier (used for display and pricing, NOT for enforcement).
    ///
    /// For enforcement of clip limits, always compare against `card.maxParticipants` directly.
    /// This avoids breaking grandfathered cards (e.g., legacy cards with maxParticipants=8 should
    /// allow 8 clips, not 5).
    public var clipLimit: Int {
        switch self {
        case .free: return 5
        case .starter: return 10
        case .group: return 25
        case .mega: return .max
        }
    }

    /// Human-readable tier name for display in UI.
    public var displayName: String {
        switch self {
        case .free: return "Free"
        case .starter: return "Starter"
        case .group: return "Group"
        case .mega: return "Mega"
        }
    }

    /// The `maxParticipants` value to store in Supabase when this tier is purchased.
    ///
    /// This is the canonical database value for each tier:
    /// - free: 5, starter: 10, group: 25, mega: 999
    public var maxParticipantsValue: Int {
        switch self {
        case .free: return 5
        case .starter: return 10
        case .group: return 25
        case .mega: return 999
        }
    }

    /// Whether this tier requires a purchase.
    public var isPaid: Bool { self != .free }

    /// The RevenueCat package identifier for this tier.
    /// Returns nil for the free tier (no purchase needed).
    public var packageIdentifier: String? {
        switch self {
        case .free: return nil
        case .starter: return "starter"
        case .group: return "group"
        case .mega: return "mega"
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
        return .mega
    }

    /// Maps a database `maxParticipants` column value to a `CardTier` for display purposes.
    ///
    /// **Grandfathering behavior:** Cards created before the tier system may have
    /// `maxParticipants = 8` (the old free tier default). These map to `.free` for display,
    /// even though `.free.clipLimit` is 5. This is intentional -- for display and pricing UI,
    /// these cards appear as "Free" tier. For **enforcement** (determining whether a card can
    /// publish), always compare `clips.count` against `card.maxParticipants` directly, NOT
    /// against `CardTier.clipLimit`. This ensures legacy cards with 6-8 clips are not
    /// incorrectly prompted to upgrade.
    ///
    /// Mapping:
    /// - `...5` -> `.free`
    /// - `6...10` -> `.starter`
    /// - `11...25` -> `.group`
    /// - `>25` (including 999) -> `.mega`
    ///
    /// - Parameter maxParticipants: The value from the `cards.max_participants` database column.
    /// - Returns: The corresponding `CardTier` for display purposes.
    public static func fromMaxParticipants(_ maxParticipants: Int) -> CardTier {
        switch maxParticipants {
        case ...5: return .free
        case 6...10: return .starter
        case 11...25: return .group
        default: return .mega
        }
    }

    public static func < (lhs: CardTier, rhs: CardTier) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}
