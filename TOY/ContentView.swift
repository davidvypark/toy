//
//  ContentView.swift
//  TOY
//
//  Created by David Park on 2/1/26.
//

import SwiftUI
import TOYShared

struct ContentView: View {
    @Bindable var authViewModel: AuthViewModel

    var body: some View {
        Group {
            switch authViewModel.authState {
            case .unknown:
                TOYBackground()

            case .signedOut:
                // TODO: Uncomment to skip onboarding for returning users
                // if hasCompletedOnboarding {
                //     LoginView(viewModel: authViewModel)
                // } else {
                    OnboardingView(authViewModel: authViewModel)
                // }

            case .signedIn:
                HomeView(viewModel: authViewModel)
            }
        }
        .animation(.easeInOut, value: authViewModel.authState)
    }
}

#Preview {
    ContentView(authViewModel: AuthViewModel())
}
