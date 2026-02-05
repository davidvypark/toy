//
//  InviteReceivedSheet.swift
//  TOY
//
//  Sheet shown when user opens an invite link in the main app.
//  Offers options to record immediately or save for later.
//

import SwiftUI
import TOYShared

struct InviteReceivedSheet: View {
    let shareToken: String
    let userId: UUID
    let onAction: (InviteAction) -> Void

    @State private var card: Card?
    @State private var isLoading = true
    @State private var errorMessage: String?

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
        VStack(spacing: 0) {
            Spacer()

            // Invitation message
            VStack(alignment: .leading, spacing: TOYSpacing.lg) {
                Text("You're invited!")
                    .font(.toyTitle())
                    .foregroundColor(.toyText)

                VStack(alignment: .leading, spacing: TOYSpacing.sm) {
                    Text(card.title)
                        .font(.toyHeadline())
                        .foregroundColor(.toyText)

                    Text("For \(card.recipientName)")
                        .font(.toyBody())
                        .foregroundColor(.toyTextSecondary)
                }

                Text("Record a video message to be included in this card.")
                    .font(.toyBody())
                    .foregroundColor(.toyTextSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, TOYSpacing.lg)

            Spacer()
            Spacer()

            // Actions
            VStack(spacing: TOYSpacing.md) {
                TOYButton.primary("Record Now") {
                    onAction(.recordNow(card))
                }

                Button {
                    saveForLater()
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
            card = try await cardService.fetchCardByShareToken(shareToken: shareToken)
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    private func saveForLater() {
        guard let card else { return }

        // Optimistic UI - dismiss immediately with card
        onAction(.savedForLater(card))

        // Fire-and-forget background join
        Task {
            do {
                _ = try await cardService.joinCard(userId: userId, shareToken: shareToken)
            } catch {
                #if DEBUG
                print("Failed to join card: \(error.localizedDescription)")
                #endif
            }
        }
    }
}

// MARK: - Preview

#Preview {
    InviteReceivedSheet(
        shareToken: "test-token",
        userId: UUID()
    ) { action in
        print("Action: \(action)")
    }
}
