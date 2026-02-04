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

@main
struct TOYApp: App {
    @State private var themeManager = ThemeManager()
    @State private var authViewModel = AuthViewModel()
    @State private var pendingDeepLink: DeepLinkDestination?

    // Invite flow state
    @State private var pendingShareToken: String?
    @State private var showInviteSheet = false
    @State private var cardToRecord: Card?

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
                .sheet(isPresented: $showInviteSheet) {
                    if let token = pendingShareToken,
                       let user = authViewModel.authState.user {
                        InviteReceivedSheet(
                            shareToken: token,
                            userId: user.id
                        ) { action in
                            handleInviteAction(action)
                        }
                    }
                }
                .fullScreenCover(item: $cardToRecord) { card in
                    if let user = authViewModel.authState.user {
                        RecordingView(
                            cardId: card.id,
                            participantId: user.id,
                            isHostClip: false
                        )
                    }
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
            if case .signedIn = authViewModel.authState {
                pendingShareToken = shareToken
                showInviteSheet = true
            }
        case .unknown:
            // Ignore unrecognized deep links
            break
        }
    }

    private func handleInviteAction(_ action: InviteReceivedSheet.InviteAction) {
        showInviteSheet = false

        switch action {
        case .recordNow(let card):
            // Small delay to let sheet dismiss before showing full screen cover
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                cardToRecord = card
            }
        case .savedForLater:
            // Card is now in the user's participating cards list
            // HomeView will refresh and show it
            pendingShareToken = nil
        case .dismiss:
            pendingShareToken = nil
        }
    }
}
