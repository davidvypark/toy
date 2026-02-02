//
//  AnalyticsService.swift
//  TOY
//
//  Created for TOY App.
//

import Foundation
import PostHog

/// Type-safe analytics event definitions
public enum AnalyticsEvent: String {
    // Card lifecycle
    case cardCreated = "card_created"
    case cardPublished = "card_published"
    case cardShared = "card_shared"
    case cardViewed = "card_viewed"

    // Recording
    case recordingStarted = "recording_started"
    case recordingCompleted = "recording_completed"
    case clipUploaded = "clip_uploaded"

    // Monetization
    case upgradePromptShown = "upgrade_prompt_shown"
    case upgradePurchased = "upgrade_purchased"
    case upgradeRestored = "upgrade_restored"

    // Engagement
    case shareButtonTapped = "share_button_tapped"
    case inviteLinkCopied = "invite_link_copied"
}

/// Centralized analytics service using PostHog
public final class AnalyticsService {
    public static let shared = AnalyticsService()

    private init() {}

    // MARK: - User Identification

    /// Identify the current user (call after authentication)
    public func identify(userId: UUID, email: String? = nil, name: String? = nil) {
        var properties: [String: Any] = [:]
        if let email = email { properties["email"] = email }
        if let name = name { properties["name"] = name }

        PostHogSDK.shared.identify(userId.uuidString, userProperties: properties)

        #if DEBUG
        print("[Analytics] Identified user \(userId.uuidString)")
        #endif
    }

    /// Reset user identity (call on sign out)
    public func reset() {
        PostHogSDK.shared.reset()

        #if DEBUG
        print("[Analytics] Reset user identity")
        #endif
    }

    // MARK: - Event Tracking

    /// Track an event with optional properties
    public func track(_ event: AnalyticsEvent, properties: [String: Any]? = nil) {
        PostHogSDK.shared.capture(event.rawValue, properties: properties)

        #if DEBUG
        print("[Analytics] \(event.rawValue) \(properties ?? [:])")
        #endif
    }

    // MARK: - Convenience Methods

    /// Track card created event
    public func trackCardCreated(cardId: UUID, occasion: String?) {
        track(.cardCreated, properties: [
            "card_id": cardId.uuidString,
            "occasion": occasion ?? "none"
        ])
    }

    /// Track card published event
    public func trackCardPublished(cardId: UUID, participantCount: Int, clipCount: Int) {
        track(.cardPublished, properties: [
            "card_id": cardId.uuidString,
            "participant_count": participantCount,
            "clip_count": clipCount
        ])
    }

    /// Track card shared event
    public func trackCardShared(cardId: UUID, shareMethod: String) {
        track(.cardShared, properties: [
            "card_id": cardId.uuidString,
            "share_method": shareMethod
        ])
    }

    /// Track upgrade prompt shown
    public func trackUpgradePromptShown(cardId: UUID, participantCount: Int) {
        track(.upgradePromptShown, properties: [
            "card_id": cardId.uuidString,
            "participant_count": participantCount
        ])
    }

    /// Track successful upgrade purchase
    public func trackUpgradePurchased(cardId: UUID, price: String) {
        track(.upgradePurchased, properties: [
            "card_id": cardId.uuidString,
            "price": price
        ])
    }
}
