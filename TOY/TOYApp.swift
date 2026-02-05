//
//  TOYApp.swift
//  TOY
//
//  Created by David Park on 2/1/26.
//

import AVFoundation
import RevenueCat
import SwiftUI
import TOYShared
import UserNotifications

// MARK: - App Delegate

/// AppDelegate for handling push notification registration.
class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        // Set notification delegate for foreground handling
        UNUserNotificationCenter.current().delegate = self
        return true
    }

    func application(
        _ application: UIApplication,
        didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
    ) {
        Task {
            // Get current user and save token
            if let session = try? await supabase.auth.session {
                try? await NotificationService.shared.saveDeviceToken(deviceToken, userId: session.user.id)
            }
        }
    }

    func application(
        _ application: UIApplication,
        didFailToRegisterForRemoteNotificationsWithError error: Error
    ) {
        #if DEBUG
        print("🔔 Failed to register for remote notifications: \(error)")
        #endif
    }

    // MARK: - UNUserNotificationCenterDelegate

    /// Handle notification when app is in foreground - show it anyway.
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        return [.banner, .sound]
    }

    /// Handle notification tap - could navigate to specific card.
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse
    ) async {
        let userInfo = response.notification.request.content.userInfo

        #if DEBUG
        print("🔔 Notification tapped: \(userInfo)")
        #endif

        // TODO: Handle navigation to card if card_id is present
        // if let cardId = userInfo["card_id"] as? String {
        //     Navigate to card
        // }
    }
}

// MARK: - Notifications

extension Notification.Name {
    static let cardSavedForLater = Notification.Name("cardSavedForLater")
}

// MARK: - Pending Invite

/// Data needed to show the invite sheet - using Identifiable for sheet(item:) pattern
struct PendingInvite: Identifiable {
    let id = UUID()
    let shareToken: String
    let userId: UUID
}

// MARK: - App

@main
struct TOYApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    @State private var themeManager = ThemeManager()
    @State private var authViewModel = AuthViewModel()
    @State private var pendingDeepLink: DeepLinkDestination?

    // Invite flow state
    @State private var pendingInvite: PendingInvite?
    @State private var cardToRecord: Card?

    // Notification prompt state
    @State private var showParticipantNotificationPrompt = false

    init() {
        // Configure audio session to play sound even when silent switch is on
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .moviePlayback)
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            #if DEBUG
            print("Failed to configure audio session: \(error)")
            #endif
        }

        // Configure RevenueCat for in-app purchases
        #if DEBUG
        Purchases.logLevel = .debug
        #endif
        Purchases.configure(withAPIKey: Configuration.revenueCatAPIKey)
    }

    var body: some Scene {
        WindowGroup {
            ContentView(authViewModel: authViewModel)
                .environment(themeManager)
                .preferredColorScheme(themeManager.colorScheme)
                .tint(.toyText)
                .task {
                    await authViewModel.checkAuthState()
                }
                .onOpenURL { url in
                    handleDeepLink(url)
                }
                .sheet(item: $pendingInvite) { invite in
                    InviteReceivedSheet(
                        shareToken: invite.shareToken,
                        userId: invite.userId
                    ) { action in
                        handleInviteAction(action)
                    }
                }
                .fullScreenCover(item: $cardToRecord, onDismiss: {
                    // After participant finishes recording, check if we should ask for notifications
                    Task {
                        if await NotificationService.shared.needsPermissionRequest() {
                            showParticipantNotificationPrompt = true
                        }
                    }
                }) { card in
                    if let user = authViewModel.authState.user {
                        RecordingView(
                            cardId: card.id,
                            participantId: user.id,
                            isHostClip: false,
                            onParticipantClipUploaded: { uploadedCard in
                                // Notify the card director that a new clip was uploaded
                                await NotificationService.shared.notifyDirectorOfNewClip(
                                    directorId: uploadedCard.hostId,
                                    cardTitle: uploadedCard.title
                                )
                            }
                        )
                    }
                }
                .alert("Stay in the loop", isPresented: $showParticipantNotificationPrompt) {
                    Button("Enable Notifications") {
                        Task {
                            _ = await NotificationService.shared.requestPermissionForParticipant()
                        }
                    }
                    Button("Not Now", role: .cancel) {}
                } message: {
                    Text("We'll notify you when the final video card is ready to watch.")
                }
        }
    }

    private func handleDeepLink(_ url: URL) {
        let destination = DeepLinkService.parse(url)

        #if DEBUG
        print("Deep link received: \(url)")
        print("Parsed destination: \(destination)")
        #endif

        switch destination {
        case .card(let shareToken):
            pendingDeepLink = .card(shareToken: shareToken)

            // Only show invite sheet if user is signed in
            if case .signedIn(let user) = authViewModel.authState {
                pendingInvite = PendingInvite(shareToken: shareToken, userId: user.id)
            }
        case .unknown:
            // Ignore unrecognized deep links
            break
        }
    }

    private func handleInviteAction(_ action: InviteReceivedSheet.InviteAction) {
        pendingInvite = nil

        switch action {
        case .recordNow(let card):
            // Small delay to let sheet dismiss before showing full screen cover
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                cardToRecord = card
            }
        case .savedForLater(let card):
            // Post notification with card for optimistic UI update
            NotificationCenter.default.post(
                name: .cardSavedForLater,
                object: card
            )
        case .dismiss:
            break
        }
    }
}
