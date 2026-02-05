//
//  NotificationService.swift
//  TOY
//
//  Handles push notification permission, registration, and device token management.
//

import Foundation
import UIKit
import UserNotifications
import TOYShared

/// Actor-based service for managing push notifications.
public actor NotificationService {

    public static let shared = NotificationService()

    private init() {}

    // MARK: - Permission

    /// Requests push notification permission from the user.
    /// - Returns: Whether permission was granted
    public func requestPermission() async -> Bool {
        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()

        // If already determined, return current authorization status
        guard settings.authorizationStatus == .notDetermined else {
            return settings.authorizationStatus == .authorized
        }

        do {
            let granted = try await center.requestAuthorization(options: [.alert, .sound, .badge])
            if granted {
                await registerForRemoteNotifications()
            }
            return granted
        } catch {
            #if DEBUG
            print("🔔 Notification permission error: \(error)")
            #endif
            return false
        }
    }

    /// Checks if notifications are currently authorized.
    public func isAuthorized() async -> Bool {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        return settings.authorizationStatus == .authorized
    }

    /// Checks if notification permission has not been determined yet.
    public func needsPermissionRequest() async -> Bool {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        return settings.authorizationStatus == .notDetermined
    }

    /// Requests permission for a director (card creator) with appropriate context.
    /// Call this after the director creates a card and records their clip.
    /// - Returns: Whether permission was granted
    public func requestPermissionForDirector() async -> Bool {
        // Only request if not already determined
        guard await needsPermissionRequest() else {
            return await isAuthorized()
        }
        return await requestPermission()
    }

    /// Requests permission for a participant with appropriate context.
    /// Call this after a participant records and uploads their clip.
    /// - Returns: Whether permission was granted
    public func requestPermissionForParticipant() async -> Bool {
        // Only request if not already determined
        guard await needsPermissionRequest() else {
            return await isAuthorized()
        }
        return await requestPermission()
    }

    // MARK: - Registration

    /// Registers for remote notifications on the main thread.
    @MainActor
    public func registerForRemoteNotifications() {
        UIApplication.shared.registerForRemoteNotifications()
    }

    /// Saves the device token to Supabase for the given user.
    /// - Parameters:
    ///   - token: The APNs device token data
    ///   - userId: The user's UUID
    public func saveDeviceToken(_ token: Data, userId: UUID) async throws {
        let tokenString = token.map { String(format: "%02.2hhx", $0) }.joined()

        #if DEBUG
        print("🔔 Saving device token: \(tokenString.prefix(20))...")
        #endif

        try await supabase
            .from("device_tokens")
            .upsert([
                "user_id": userId.uuidString,
                "token": tokenString,
                "platform": "ios"
            ])
            .execute()

        #if DEBUG
        print("🔔 Device token saved successfully")
        #endif
    }

    /// Removes the device token when user logs out.
    /// - Parameter userId: The user's UUID
    public func removeDeviceToken(userId: UUID) async throws {
        try await supabase
            .from("device_tokens")
            .delete()
            .eq("user_id", value: userId)
            .execute()

        #if DEBUG
        print("🔔 Device token removed")
        #endif
    }

    // MARK: - Send Notifications

    /// Notifies the card director that a new clip was uploaded.
    /// - Parameters:
    ///   - directorId: The host/director's user ID
    ///   - cardTitle: The title of the card
    public func notifyDirectorOfNewClip(directorId: UUID, cardTitle: String) async {
        await sendNotification(
            userIds: [directorId],
            title: "New clip received!",
            body: "Someone added a video to \(cardTitle)"
        )
    }

    /// Notifies all participants that a card has been published.
    /// - Parameters:
    ///   - participantIds: Array of participant user IDs
    ///   - cardTitle: The title of the card
    ///   - cardId: The card ID for deep linking
    public func notifyParticipantsOfPublish(
        participantIds: [UUID],
        cardTitle: String,
        cardId: UUID
    ) async {
        await sendNotification(
            userIds: participantIds,
            title: "Your card is ready!",
            body: "\(cardTitle) has been published",
            data: ["card_id": cardId.uuidString, "type": "published"]
        )
    }

    /// Sends a push notification via the Supabase edge function.
    private func sendNotification(
        userIds: [UUID],
        title: String,
        body: String,
        data: [String: String]? = nil
    ) async {
        guard !userIds.isEmpty else { return }

        do {
            let payload = NotificationPayload(
                user_ids: userIds.map { $0.uuidString },
                title: title,
                body: body,
                data: data ?? [:]
            )

            // Call the edge function
            try await supabase.functions.invoke(
                "send-notification",
                options: .init(body: payload)
            )

            #if DEBUG
            print("🔔 Notification sent to \(userIds.count) user(s)")
            #endif
        } catch {
            #if DEBUG
            print("🔔 Failed to send notification: \(error)")
            #endif
        }
    }
}

// MARK: - Payload Types

private struct NotificationPayload: Encodable {
    let user_ids: [String]
    let title: String
    let body: String
    let data: [String: String]
}
