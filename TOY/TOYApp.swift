//
//  TOYApp.swift
//  TOY
//
//  Created by David Park on 2/1/26.
//

import SwiftUI
import TOYShared

@main
struct TOYApp: App {
    @State private var themeManager = ThemeManager()
    @State private var authViewModel = AuthViewModel()

    var body: some Scene {
        WindowGroup {
            ContentView(authViewModel: authViewModel)
                .environment(themeManager)
                .preferredColorScheme(themeManager.colorScheme)
                .task {
                    await authViewModel.checkAuthState()
                }
        }
    }
}
