import StoreKit
import SwiftUI

/// Requests App Store review after positive actions (publish or clip submit).
/// Apple handles rate limiting (3 per 365 days).
enum ReviewManager {

    /// Call after a positive action. Delays 1.5s to let transitions settle.
    static func requestReviewAfterDelay(requestReview: RequestReviewAction) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            requestReview()
        }
    }
}
