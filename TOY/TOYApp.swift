//
//  TOYApp.swift
//  TOY
//
//  Created by David Park on 2/1/26.
//

import RevenueCat
import SwiftUI
import TOYShared

@main
struct TOYApp: App {
    @State private var themeManager = ThemeManager()
    @State private var authViewModel = AuthViewModel()
    @State private var pendingDeepLink: DeepLinkDestination?

    init() {
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
            // Store for navigation - actual navigation will be implemented in Phase 4
            pendingDeepLink = .card(shareToken: shareToken)
        case .unknown:
            // Ignore unrecognized deep links
            break
        }
    }
}
