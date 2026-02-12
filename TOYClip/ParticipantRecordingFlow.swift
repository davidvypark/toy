//
//  ParticipantRecordingFlow.swift
//  TOYClip
//
//  Coordinates the participant recording experience from invite link to upload.
//

import SwiftUI
import TOYShared

struct ParticipantRecordingFlow: View {
    let shareToken: String

    @State private var card: Card?
    @State private var participantId: UUID?
    @State private var error: String?
    @State private var isLoading = true
    @State private var showRecording = false
    @State private var showSuccess = false
    @State private var hostDisplayName: String?
    @State private var hostAvatarURL: URL?

    private let cardService = CardService()

    var body: some View {
        Group {
            if isLoading {
                loadingView
            } else if let error = error {
                errorView(message: error)
            } else if showSuccess {
                UploadSuccessView()
            } else if let card, let participantId {
                inviteView(card: card, participantId: participantId)
                    .fullScreenCover(isPresented: $showRecording) {
                        RecordingFlowWrapper(
                            card: card,
                            participantId: participantId,
                            onComplete: {
                                showRecording = false
                                showSuccess = true
                            }
                        )
                    }
            }
        }
        .task {
            await loadCard()
        }
    }

    // MARK: - Invite View

    private func inviteView(card: Card, participantId: UUID) -> some View {
        ZStack {
            TOYBackground()

            VStack(alignment: .leading, spacing: 0) {
                // Branding
                Text("toy")
                    .font(.custom("DMSerifDisplay-Regular", size: 120))
                    .foregroundColor(.toyText)
                    .frame(maxWidth: .infinity)
                    .padding(.top, TOYSpacing.xl)

                Spacer()

                VStack(alignment: .leading, spacing: TOYSpacing.lg) {
                    // Host avatar
                    if let avatarURL = hostAvatarURL {
                        AsyncImage(url: avatarURL) { image in
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                        } placeholder: {
                            Circle()
                                .fill(Color.toyDivider)
                        }
                        .frame(width: 56, height: 56)
                        .clipShape(Circle())
                    } else {
                        Circle()
                            .fill(Color.toyDivider)
                            .frame(width: 56, height: 56)
                            .overlay {
                                Image(systemName: "person.fill")
                                    .foregroundColor(.toyTextSecondary)
                            }
                    }

                    // Invitation text
                    Text("\(hostDisplayName ?? "Someone") has invited you to record a 7 second video message to be included in this card.")
                        .font(.toyBody())
                        .foregroundColor(.toyTextSecondary)
                        .fixedSize(horizontal: false, vertical: true)

                    // Card title and recipient
                    VStack(alignment: .leading, spacing: TOYSpacing.sm) {
                        Text(card.title)
                            .font(.toyTitle())
                            .foregroundColor(.toyText)

                        Text("For \(card.recipientName)")
                            .font(.toyTitle2())
                            .foregroundColor(.toyTextSecondary)
                    }
                }
                .padding(.horizontal, TOYSpacing.lg)

                Spacer()
                Spacer()

                // Record button
                TOYButton.primary("Record Now") {
                    showRecording = true
                }
                .padding(.horizontal, TOYSpacing.lg)
                .padding(.bottom, TOYSpacing.xl)
            }
        }
    }

    // MARK: - Loading & Error Views

    private var loadingView: some View {
        ZStack {
            TOYBackground()
            ProgressView()
                .scaleEffect(1.2)
        }
    }

    private func errorView(message: String) -> some View {
        ZStack {
            TOYBackground()

            VStack(spacing: TOYSpacing.lg) {
                Image(systemName: "exclamationmark.triangle")
                    .font(.system(size: 48, weight: .light))
                    .foregroundColor(.toyTextSecondary)

                Text("Unable to Load Card")
                    .font(.toyHeadline())
                    .foregroundColor(.toyText)

                Text(message)
                    .font(.toyBody())
                    .foregroundColor(.toyTextSecondary)
                    .multilineTextAlignment(.center)

                Button("Try Again") {
                    isLoading = true
                    error = nil
                    Task { await loadCard() }
                }
                .font(.toyBodyMedium())
                .foregroundColor(.toyText)
            }
            .padding()
        }
    }

    // MARK: - Data Loading

    private func loadCard() async {
        do {
            // Sign in anonymously for RLS-protected operations
            let session = try await supabase.auth.signInAnonymously()
            let userId = session.user.id

            #if DEBUG
            print("[AppClip] Signed in anonymously: \(userId)")
            #endif

            let fetchedCard = try await cardService.fetchCardByShareToken(shareToken: shareToken)

            // Fetch host profile
            let profiles = try await cardService.fetchProfiles(userIds: [fetchedCard.hostId])
            if let profile = profiles[fetchedCard.hostId] {
                hostDisplayName = profile.displayName
                hostAvatarURL = profile.avatarURL
            }

            card = fetchedCard
            participantId = userId
            isLoading = false

            #if DEBUG
            print("[AppClip] Loaded card: \(fetchedCard.title)")
            print("[AppClip] Participant ID: \(userId)")
            #endif
        } catch {
            self.error = "This invite link is invalid or has expired."
            isLoading = false

            #if DEBUG
            print("[AppClip] Failed to load card: \(error)")
            #endif
        }
    }
}

// MARK: - Recording Flow Wrapper

/// Wraps RecordingView to handle completion callback
private struct RecordingFlowWrapper: View {
    let card: Card
    let participantId: UUID
    let onComplete: () -> Void

    @StateObject private var viewModel: RecordingViewModel

    init(card: Card, participantId: UUID, onComplete: @escaping () -> Void) {
        self.card = card
        self.participantId = participantId
        self.onComplete = onComplete

        _viewModel = StateObject(wrappedValue: RecordingViewModel(
            cardId: card.id,
            participantId: participantId,
            isHostClip: false
        ))
    }

    var body: some View {
        RecordingView(viewModel: viewModel)
            .onChange(of: viewModel.uploadState) { _, newState in
                if case .success = newState {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                        onComplete()
                    }
                }
            }
    }
}
