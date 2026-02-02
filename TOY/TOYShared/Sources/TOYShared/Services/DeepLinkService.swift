//
//  DeepLinkService.swift
//  TOYShared
//
//  Created by Claude on 2/2/26.
//

import Foundation

/// Destinations that can be reached via deep links.
public enum DeepLinkDestination: Equatable {
    case card(shareToken: String)
    case unknown
}

/// Service for parsing deep link URLs into navigation destinations.
public struct DeepLinkService {
    /// Parses a URL into a deep link destination.
    /// - Parameter url: The incoming URL from Universal Link
    /// - Returns: The destination to navigate to
    public static func parse(_ url: URL) -> DeepLinkDestination {
        // Expected format: https://domain/card/{shareToken}
        let pathComponents = url.pathComponents

        // pathComponents includes "/" as first element
        // So /card/abc123 becomes ["/", "card", "abc123"]
        guard pathComponents.count >= 3,
              pathComponents[1] == "card" else {
            return .unknown
        }

        let shareToken = pathComponents[2]
        guard !shareToken.isEmpty else {
            return .unknown
        }

        return .card(shareToken: shareToken)
    }
}
