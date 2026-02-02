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
    @State private var cardInProgress: Card? = nil  // When non-nil, shows recording fullScreenCover
    @State private var completedCard: Card? = nil

    // Card list state
    @State private var hostedCards: [Card] = []
    @State private var participatingCards: [Card] = []
    @State private var isLoadingCards = false

    private let cardService = CardService()

    /// Whether there are any cards to display
    private var hasCards: Bool {
        !hostedCards.isEmpty || !participatingCards.isEmpty
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Welcome Header
                VStack(spacing: 8) {
                    TOYLabel.largeTitle("Thinking Of You")
                    if let user = viewModel.authState.user {
                        TOYLabel("Welcome, \(user.displayNameOrEmail)", style: .subheadline, color: .toyTextSecondary)
                    }
                }
                .padding(.top, 40)
                .padding(.bottom, 24)

                if isLoadingCards && !hasCards {
                    Spacer()
                    ProgressView("Loading cards...")
                    Spacer()
                } else if !hasCards {
                    // Empty state - Create Your First Card
                    Spacer()

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
                    }
                    .padding(.horizontal, 40)

                    Spacer()
                } else {
                    // Horizontal scrolling card sections
                    ScrollView {
                        VStack(alignment: .leading, spacing: 24) {
                            // My Cards section (hosted)
                            if !hostedCards.isEmpty {
                                CardSectionView(
                                    title: "My Cards",
                                    cards: hostedCards
                                )
                            }

                            // Participating section
                            if !participatingCards.isEmpty {
                                CardSectionView(
                                    title: "Participating",
                                    cards: participatingCards
                                )
                            }
                        }
                        .padding(.vertical, 16)
                    }

                    // Create Card button at bottom
                    TOYButton("Create Card", style: .primary, size: .large) {
                        showCreateCard = true
                    }
                    .padding(.horizontal, 40)
                    .padding(.bottom, 8)
                }

                // Sign Out
                TOYButton("Sign Out", style: .text) {
                    Task { await viewModel.signOut() }
                }
                .padding(.bottom, 20)
            }
            .background(Color.toyBackground)
            .navigationDestination(for: Card.self) { card in
                CardDetailView(card: card)
            }
            .fullScreenCover(isPresented: $showRecording) {
                RecordingView()
            }
            // Card creation sheet
            .sheet(isPresented: $showCreateCard) {
                if let user = viewModel.authState.user {
                    CreateCardView(hostId: user.id) { createdCard in
                        #if DEBUG
                        print("Card created: \(createdCard.id), dismissing sheet")
                        #endif
                        // Dismiss sheet first, then set card after delay
                        // This ensures sheet is gone before fullScreenCover presents
                        showCreateCard = false
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                            #if DEBUG
                            print("Presenting recording for card: \(createdCard.id)")
                            #endif
                            cardInProgress = createdCard
                        }
                    }
                }
            }
            // Host recording cover - use item-based presentation for reliability
            .fullScreenCover(item: $cardInProgress, onDismiss: {
                #if DEBUG
                print("Recording fullScreenCover dismissed")
                print("   completedCard will trigger sheet: \(completedCard?.id.uuidString ?? "nil")")
                #endif
                // completedCard is set in onDisappear; item-based sheet will present automatically
            }) { card in
                if let user = viewModel.authState.user {
                    RecordingView(
                        cardId: card.id,
                        participantId: user.id,
                        isHostClip: true
                    )
                    .onDisappear {
                        // Store the card before the cover fully dismisses
                        #if DEBUG
                        print("Recording view disappearing, storing card: \(card.id)")
                        #endif
                        completedCard = card
                    }
                }
            }
            // Card created sheet - use item-based presentation for reliable data passing
            .sheet(item: $completedCard) { card in
                CardCreatedView(card: card) {
                    completedCard = nil
                    // Reload cards after creation flow completes
                    Task {
                        await loadCards()
                    }
                }
                .onAppear {
                    #if DEBUG
                    print("CardCreatedView appeared for card: \(card.title)")
                    #endif
                }
            }
            .task {
                await loadCards()
            }
        }
    }

    // MARK: - Private Methods

    private func loadCards() async {
        guard let user = viewModel.authState.user else { return }

        isLoadingCards = true
        defer { isLoadingCards = false }

        do {
            // Fetch cards where user is host
            hostedCards = try await cardService.fetchCardsForHost(hostId: user.id)

            // TODO: Fetch cards where user is participant (future feature)
            // For now, participatingCards remains empty
            participatingCards = []
        } catch {
            #if DEBUG
            print("Failed to load cards: \(error.localizedDescription)")
            #endif
        }
    }
}

// MARK: - Card Section View

/// A horizontally scrolling section of cards
private struct CardSectionView: View {
    let title: String
    let cards: [Card]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Section header
            TOYLabel(title, style: .headline)
                .padding(.horizontal, 24)

            // Horizontal scroll
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: 16) {
                    ForEach(cards) { card in
                        NavigationLink(value: card) {
                            CardTileView(card: card)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 24)
            }
        }
    }
}

// MARK: - Card Tile View

/// A card tile for horizontal scrolling display
private struct CardTileView: View {
    let card: Card

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Card visual
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.toySurface)
                .frame(width: 140, height: 100)
                .overlay {
                    VStack(spacing: 8) {
                        Image(systemName: "video.fill")
                            .font(.system(size: 28))
                            .foregroundColor(.toyPrimary)

                        StatusBadge(status: card.status)
                    }
                }

            // Card info
            VStack(alignment: .leading, spacing: 2) {
                Text(card.title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(.toyText)
                    .lineLimit(1)

                Text("For \(card.recipientName)")
                    .font(.caption)
                    .foregroundColor(.toyTextSecondary)
                    .lineLimit(1)
            }
            .frame(width: 140, alignment: .leading)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.toySurface)
                .shadow(color: .black.opacity(0.08), radius: 8, x: 0, y: 2)
        )
    }
}

// MARK: - Status Badge

private struct StatusBadge: View {
    let status: String

    var body: some View {
        Text(displayText)
            .font(.system(size: 11, weight: .medium))
            .foregroundColor(textColor)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(backgroundColor)
            .cornerRadius(6)
    }

    private var displayText: String {
        switch status {
        case "draft":
            return "Draft"
        case "collecting":
            return "Collecting"
        case "stitching":
            return "Stitching"
        case "published":
            return "Published"
        default:
            return status.capitalized
        }
    }

    private var textColor: Color {
        switch status {
        case "draft":
            return .toyTextSecondary
        case "collecting":
            return .toyPrimary
        case "stitching":
            return .orange
        case "published":
            return .green
        default:
            return .toyTextSecondary
        }
    }

    private var backgroundColor: Color {
        switch status {
        case "draft":
            return Color.toyTextSecondary.opacity(0.15)
        case "collecting":
            return Color.toyPrimary.opacity(0.15)
        case "stitching":
            return Color.orange.opacity(0.15)
        case "published":
            return Color.green.opacity(0.15)
        default:
            return Color.toyTextSecondary.opacity(0.15)
        }
    }
}
