//
//  HomeView.swift
//  TOY
//
//  Created by David Park on 2/1/26.
//

import SwiftUI
import TOYShared

struct HomeView: View {
    @Bindable var viewModel: AuthViewModel
    @State private var showRecording = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                // Welcome Header
                VStack(spacing: 8) {
                    TOYLabel.largeTitle("Thinking Of You")
                    if let user = viewModel.authState.user {
                        TOYLabel("Welcome, \(user.displayNameOrEmail)", style: .subheadline, color: .toyTextSecondary)
                    }
                }
                .padding(.top, 40)

                Spacer()

                // Placeholder for future card creation
                VStack(spacing: 16) {
                    Image(systemName: "video.badge.plus")
                        .font(.system(size: 60))
                        .foregroundColor(.toyPrimary)

                    TOYLabel.headline("Create Your First Card")
                    TOYLabel("Gather video messages from friends and family", style: .body, color: .toyTextSecondary)
                        .multilineTextAlignment(.center)

                    TOYButton("Create Card", style: .primary, size: .large) {
                        // TODO: Navigate to card creation (Phase 4)
                    }
                    .padding(.top, 8)

                    // Temporary: Record Video button for testing (Phase 2)
                    TOYButton("Record Video", style: .secondary, size: .medium) {
                        showRecording = true
                    }
                }
                .padding(.horizontal, 40)

                Spacer()

                // Sign Out
                TOYButton("Sign Out", style: .text) {
                    Task { await viewModel.signOut() }
                }
                .padding(.bottom, 20)
            }
            .padding(.horizontal, 24)
            .background(Color.toyBackground)
            .fullScreenCover(isPresented: $showRecording) {
                RecordingView()
            }
        }
    }
}
