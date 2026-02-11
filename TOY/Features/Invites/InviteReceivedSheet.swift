//
//  InviteReceivedSheet.swift
//  TOY
//
//  Sheet shown when user opens an invite link in the main app.
//  Offers options to record immediately or save for later.
//

import Kingfisher
import SwiftUI
import TOYShared

struct InviteReceivedSheet: View {
    let shareToken: String
    let userId: UUID
    let userEmail: String?
    let onAction: (InviteAction) -> Void

    @State private var card: Card?
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var hostDisplayName: String?
    @State private var hostAvatarURL: URL?

    private let cardService = CardService()

    enum InviteAction {
        case recordNow(Card)
        case savedForLater(Card)
        case dismiss
    }

    var body: some View {
        NavigationStack {
            ZStack {
                TOYBackground()

                if isLoading {
                    ProgressView()
                        .scaleEffect(1.2)
                } else if let error = errorMessage {
                    errorView(error)
                } else if let card {
                    contentView(card: card)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Close") {
                        onAction(.dismiss)
                    }
                    .font(.toyBody())
                    .foregroundColor(.toyText)
                }
            }
        }
        .task {
            await loadCard()
        }
    }

    // MARK: - Content View

    @ViewBuilder
    private func contentView(card: Card) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Spacer()

            VStack(alignment: .leading, spacing: TOYSpacing.lg) {
                // Host avatar
                if let avatarURL = hostAvatarURL {
                    KFImage(avatarURL)
                        .placeholder {
                            Circle()
                                .fill(Color.toyDivider)
                        }
                        .resizable()
                        .aspectRatio(contentMode: .fill)
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

            // Actions
            VStack(spacing: TOYSpacing.md) {
                TOYButton.primary("Record Now") {
                    joinCardInBackground()
                    onAction(.recordNow(card))
                }

                Button {
                    joinCardInBackground()
                    onAction(.savedForLater(card))
                } label: {
                    Text("Save for Later")
                        .font(.toyBody())
                        .foregroundColor(.toyTextSecondary)
                }
                .frame(height: 44)
            }
            .padding(.horizontal, TOYSpacing.lg)
            .padding(.bottom, TOYSpacing.xl)
        }
    }

    // MARK: - Error View

    @ViewBuilder
    private func errorView(_ error: String) -> some View {
        VStack(spacing: TOYSpacing.lg) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 48, weight: .light))
                .foregroundColor(.toyTextSecondary)

            Text("Couldn't load invite")
                .font(.toyHeadline())
                .foregroundColor(.toyText)

            Text(error)
                .font(.toyBody())
                .foregroundColor(.toyTextSecondary)
                .multilineTextAlignment(.center)

            Button("Try Again") {
                Task { await loadCard() }
            }
            .font(.toyBodyMedium())
            .foregroundColor(.toyText)
        }
        .padding()
    }

    // MARK: - Actions

    private func loadCard() async {
        isLoading = true
        errorMessage = nil

        do {
            let fetchedCard = try await cardService.fetchCardByShareToken(shareToken: shareToken)
            card = fetchedCard

            // Fetch host profile
            let profiles = try await cardService.fetchProfiles(userIds: [fetchedCard.hostId])
            if let profile = profiles[fetchedCard.hostId] {
                hostDisplayName = profile.displayName
                hostAvatarURL = profile.avatarURL
            }
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    private func joinCardInBackground() {
        guard card != nil else { return }

        let service = cardService
        let token = shareToken
        let uid = userId
        let email = userEmail
        Task.detached {
            do {
                _ = try await service.joinCard(userId: uid, shareToken: token, email: email)
                #if DEBUG
                print("✅ Card joined successfully")
                #endif
            } catch {
                #if DEBUG
                print("❌ Failed to join card: \(error.localizedDescription)")
                #endif
            }
        }
    }
}

// MARK: - Preview

#Preview {
    InviteReceivedSheet(
        shareToken: "test-token",
        userId: UUID(),
        userEmail: "test@example.com"
    ) { action in
        print("Action: \(action)")
    }
}
