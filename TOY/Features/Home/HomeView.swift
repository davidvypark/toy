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

    // Standalone recording (temporary for testing)
    @State private var showRecording = false

    // Card creation flow state
    @State private var showCreateCard = false
    @State private var cardInProgress: Card? = nil
    @State private var showHostRecording = false
    @State private var completedCard: Card? = nil
    @State private var showCardCreated = false

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
                        showCreateCard = true
                    }
                    .padding(.top, 8)

                    // Temporary - for testing standalone recording (Phase 2)
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
            // Card creation sheet
            .sheet(isPresented: $showCreateCard) {
                if let user = viewModel.authState.user {
                    CreateCardView(hostId: user.id) { createdCard in
                        // Card created, navigate to recording
                        cardInProgress = createdCard
                        showCreateCard = false
                        showHostRecording = true
                    }
                }
            }
            // Host recording cover
            .fullScreenCover(isPresented: $showHostRecording) {
                if let card = cardInProgress, let user = viewModel.authState.user {
                    RecordingView(
                        cardId: card.id,
                        participantId: user.id,
                        isHostClip: true
                    )
                    .onDisappear {
                        // Recording complete (dismissed via upload success)
                        if cardInProgress != nil {
                            completedCard = cardInProgress
                            cardInProgress = nil
                            showCardCreated = true
                        }
                    }
                }
            }
            // Card created sheet
            .sheet(isPresented: $showCardCreated) {
                if let card = completedCard {
                    CardCreatedView(card: card) {
                        completedCard = nil
                        showCardCreated = false
                    }
                }
            }
        }
    }
}
