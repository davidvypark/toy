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

    // Card creation flow state
    @State private var showCreateCard = false
    @State private var cardInProgress: Card? = nil  // When non-nil, shows recording fullScreenCover
    @State private var completedCard: Card? = nil
    @State private var showSettings = false
    @State private var publishedCardToPlay: Card? = nil  // For fullscreen video player

    // Card list state
    @State private var hostedCards: [Card] = []
    @State private var clipCounts: [UUID: Int] = [:]  // cardId -> clip count
    @State private var participatingCards: [Card] = []
    @State private var isLoadingCards = false

    private let cardService = CardService()

    // MARK: - Computed Properties

    /// Cards that are still in progress (not published)
    private var inProgressCards: [Card] {
        hostedCards.filter { $0.status != "published" }
    }

    /// Cards that have been published
    private var publishedCards: [Card] {
        hostedCards.filter { $0.status == "published" }
    }

    /// Whether there are any cards to display
    private var hasCards: Bool {
        !hostedCards.isEmpty || !participatingCards.isEmpty
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Header with title and settings
                HStack {
                    Spacer()
                    TOYLabel.largeTitle("Thinking Of You")
                    Spacer()
                }
                .overlay(alignment: .trailing) {
                    Button {
                        showSettings = true
                    } label: {
                        Image(systemName: "gearshape.fill")
                            .font(.title3)
                            .foregroundColor(.toyTextSecondary)
                    }
                    .padding(.trailing, 24)
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
                    // Card sections
                    ScrollView {
                        VStack(alignment: .leading, spacing: 32) {
                            // In Progress section (paginated single card)
                            if !inProgressCards.isEmpty {
                                InProgressSectionView(
                                    cards: inProgressCards,
                                    clipCounts: clipCounts
                                )
                            }

                            // Published section (horizontal scroll)
                            if !publishedCards.isEmpty {
                                PublishedSectionView(
                                    cards: publishedCards,
                                    clipCounts: clipCounts,
                                    onCardTapped: { card in
                                        publishedCardToPlay = card
                                    }
                                )
                            }

                            // Participating section
                            if !participatingCards.isEmpty {
                                PublishedSectionView(
                                    title: "Participating",
                                    cards: participatingCards,
                                    clipCounts: clipCounts,
                                    onCardTapped: { card in
                                        publishedCardToPlay = card
                                    }
                                )
                            }
                        }
                        .padding(.vertical, 8)
                    }
                    .scrollBounceBehavior(.basedOnSize)

                    // Create Card button at bottom
                    TOYButton("Create Card", style: .primary, size: .large) {
                        showCreateCard = true
                    }
                    .padding(.horizontal, 40)
                    .padding(.vertical, 16)
                }
            }
            .background(Color.toyBackground)
            .navigationDestination(for: Card.self) { card in
                CardDetailView(card: card)
            }
            // Settings sheet
            .sheet(isPresented: $showSettings) {
                SettingsView(authViewModel: viewModel)
            }
            // Published card video player
            .fullScreenCover(item: $publishedCardToPlay) { card in
                PublishedCardPlayerView(card: card)
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

            // Fetch clip counts for each card
            var counts: [UUID: Int] = [:]
            for card in hostedCards {
                let clips = try await cardService.fetchClipsForCard(cardId: card.id)
                counts[card.id] = clips.count
            }
            clipCounts = counts

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

// MARK: - In Progress Section View

/// Paginated single-card view with page dots for in-progress cards
private struct InProgressSectionView: View {
    let cards: [Card]
    let clipCounts: [UUID: Int]

    @State private var currentIndex: Int = 0

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Section header
            TOYLabel("In Progress", style: .headline)
                .padding(.horizontal, 24)
                .padding(.bottom, 12)

            // Paginated card view
            TabView(selection: $currentIndex) {
                ForEach(Array(cards.enumerated()), id: \.element.id) { index, card in
                    NavigationLink(value: card) {
                        InProgressCardTile(
                            card: card,
                            clipCount: clipCounts[card.id] ?? 0
                        )
                    }
                    .buttonStyle(.plain)
                    .tag(index)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .frame(height: 176)  // Card height (160) + minimal padding

            // Custom page dots (only show if more than 1 card, max 3 dots)
            if cards.count > 1 {
                HStack(spacing: 8) {
                    ForEach(0..<min(cards.count, 3), id: \.self) { index in
                        Circle()
                            .fill(index == currentIndex % min(cards.count, 3) ? Color.toyPrimary : Color.toyTextSecondary.opacity(0.3))
                            .frame(width: 8, height: 8)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.top, 8)
            }
        }
    }
}

// MARK: - Published Section View

/// Horizontal scrolling section for published cards
private struct PublishedSectionView: View {
    var title: String = "Published"
    let cards: [Card]
    let clipCounts: [UUID: Int]
    var onCardTapped: ((Card) -> Void)? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Section header
            TOYLabel(title, style: .headline)
                .padding(.horizontal, 24)

            // Horizontal scroll
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: 16) {
                    ForEach(cards) { card in
                        Button {
                            onCardTapped?(card)
                        } label: {
                            PublishedCardTile(
                                card: card,
                                clipCount: clipCounts[card.id] ?? 0
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 8)  // Extra padding to prevent clipping
            }
        }
    }
}

// MARK: - In Progress Card Tile

/// Large card tile for paginated in-progress section
private struct InProgressCardTile: View {
    let card: Card
    let clipCount: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Top row: Director badge
            HStack {
                DirectorBadge()
                Spacer()
            }

            Spacer()

            // Bottom content
            VStack(alignment: .leading, spacing: 6) {
                // Title (prominent)
                Text(card.title)
                    .font(.title3.weight(.bold))
                    .foregroundColor(.toyText)
                    .lineLimit(2)

                // Recipient
                Text("For \(card.recipientName)")
                    .font(.subheadline)
                    .foregroundColor(.toyTextSecondary)

                // Clip count
                HStack(spacing: 4) {
                    Image(systemName: "person.2.fill")
                        .font(.caption)
                    Text("\(clipCount)/\(card.maxParticipants) clips")
                        .font(.caption.weight(.medium))
                }
                .foregroundColor(.toyPrimary)
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(height: 160)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color.toySurface)
                .shadow(color: .black.opacity(0.1), radius: 12, x: 0, y: 4)
        )
        .padding(.horizontal, 24)
    }
}

// MARK: - Published Card Tile

/// Smaller card tile for horizontal scrolling published section
private struct PublishedCardTile: View {
    let card: Card
    let clipCount: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Title (prominent)
            Text(card.title)
                .font(.subheadline.weight(.bold))
                .foregroundColor(.toyText)
                .lineLimit(2)

            // Recipient
            Text("For \(card.recipientName)")
                .font(.caption)
                .foregroundColor(.toyTextSecondary)
                .lineLimit(1)

            Spacer()

            // Clip count
            HStack(spacing: 4) {
                Image(systemName: "person.2.fill")
                    .font(.system(size: 10))
                Text("\(clipCount) clips")
                    .font(.caption2.weight(.medium))
            }
            .foregroundColor(.toyTextSecondary)
        }
        .padding(16)
        .frame(width: 150, height: 120, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.toySurface)
                .shadow(color: .black.opacity(0.08), radius: 8, x: 0, y: 2)
        )
    }
}

// MARK: - Director Badge

private struct DirectorBadge: View {
    var body: some View {
        Text("Director")
            .font(.system(size: 11, weight: .semibold))
            .foregroundColor(.toyPrimary)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(Color.toyPrimary.opacity(0.15))
            .cornerRadius(8)
    }
}
