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
    @State private var cardInProgress: Card? = nil
    @State private var completedCard: Card? = nil
    @State private var showSettings = false
    @State private var publishedCardToPlay: Card? = nil

    // Card list state
    @State private var hostedCards: [Card] = []
    @State private var clipCounts: [UUID: Int] = [:]
    @State private var participatingCards: [Card] = []
    @State private var isLoadingCards = false

    private let cardService = CardService()

    // MARK: - Computed Properties

    private var inProgressCards: [Card] {
        hostedCards.filter { $0.status != "published" }
    }

    private var publishedCards: [Card] {
        hostedCards.filter { $0.status == "published" }
    }

    private var hasCards: Bool {
        !hostedCards.isEmpty || !participatingCards.isEmpty
    }

    var body: some View {
        NavigationStack {
            ZStack {
                // Textured background
                TOYBackground()

                VStack(spacing: 0) {
                    // Header with cropped title
                    headerView

                    if isLoadingCards && !hasCards {
                        loadingView
                    } else if !hasCards {
                        emptyStateView
                    } else {
                        cardListView
                    }
                }
            }
            .navigationDestination(for: Card.self) { card in
                CardDetailView(card: card)
            }
            .sheet(isPresented: $showSettings) {
                SettingsView(authViewModel: viewModel)
            }
            .fullScreenCover(item: $publishedCardToPlay) { card in
                PublishedCardPlayerView(card: card)
            }
            .sheet(isPresented: $showCreateCard) {
                if let user = viewModel.authState.user {
                    CreateCardView(hostId: user.id) { createdCard in
                        showCreateCard = false
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                            cardInProgress = createdCard
                        }
                    }
                }
            }
            .fullScreenCover(item: $cardInProgress, onDismiss: {}) { card in
                if let user = viewModel.authState.user {
                    RecordingView(
                        cardId: card.id,
                        participantId: user.id,
                        isHostClip: true
                    )
                    .onDisappear {
                        completedCard = card
                    }
                }
            }
            .sheet(item: $completedCard) { card in
                CardCreatedView(card: card) {
                    completedCard = nil
                    Task { await loadCards() }
                }
            }
            .task {
                await loadCards()
            }
        }
    }

    // MARK: - Header

    private var headerView: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Top bar with settings button (top right)
            HStack {
                Spacer()
                Button {
                    showSettings = true
                } label: {
                    Image(systemName: "person.crop.circle")
                        .font(.system(size: 24, weight: .light))
                        .foregroundColor(.toyTextSecondary)
                }
            }
            .padding(.horizontal, TOYSpacing.lg)
            .padding(.top, TOYSpacing.sm)

            // Cropped title - extends beyond leading edge
            Text("Thinking\nOf You")
                .font(.toyDisplaySmall())
                .foregroundColor(.toyText)
                .lineSpacing(-8)
                .padding(.leading, -8) // Slight crop effect
                .padding(.top, TOYSpacing.lg)
                .padding(.bottom, TOYSpacing.lg)
                .padding(.leading, TOYSpacing.lg)
        }
    }

    // MARK: - Loading View

    private var loadingView: some View {
        VStack {
            Spacer()
            ProgressView()
                .scaleEffect(1.2)
            Spacer()
        }
    }

    // MARK: - Empty State

    private var emptyStateView: some View {
        VStack(spacing: 0) {
            Spacer()

            VStack(alignment: .leading, spacing: TOYSpacing.lg) {
                Text("Create your\nfirst card")
                    .font(.toyTitle())
                    .foregroundColor(.toyText)
                    .lineSpacing(-4)

                Text("Gather video messages from friends and family into a single montage.")
                    .font(.toyBody())
                    .foregroundColor(.toyTextSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, TOYSpacing.lg)

            Spacer()

            // CTA at bottom
            TOYButton.primary("Create Card") {
                showCreateCard = true
            }
            .padding(.horizontal, TOYSpacing.lg)
            .padding(.bottom, TOYSpacing.xl)
        }
    }

    // MARK: - Card List

    private var cardListView: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: TOYSpacing.xxl) {
                    // In Progress section
                    if !inProgressCards.isEmpty {
                        InProgressSectionView(
                            cards: inProgressCards,
                            clipCounts: clipCounts
                        )
                    }

                    // Published section
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
                .padding(.vertical, TOYSpacing.md)
            }
            .scrollBounceBehavior(.basedOnSize)

            // Bottom CTA
            TOYButton.primary("Create Card") {
                showCreateCard = true
            }
            .padding(.horizontal, TOYSpacing.lg)
            .padding(.vertical, TOYSpacing.lg)
        }
    }

    // MARK: - Data Loading

    private func loadCards() async {
        guard let user = viewModel.authState.user else { return }

        isLoadingCards = true
        defer { isLoadingCards = false }

        do {
            hostedCards = try await cardService.fetchCardsForHost(hostId: user.id)

            var counts: [UUID: Int] = [:]
            for card in hostedCards {
                let clips = try await cardService.fetchClipsForCard(cardId: card.id)
                counts[card.id] = clips.count
            }
            clipCounts = counts
            participatingCards = []
        } catch {
            #if DEBUG
            print("Failed to load cards: \(error.localizedDescription)")
            #endif
        }
    }
}

// MARK: - In Progress Section

private struct InProgressSectionView: View {
    let cards: [Card]
    let clipCounts: [UUID: Int]

    @State private var currentIndex: Int = 0

    var body: some View {
        VStack(alignment: .leading, spacing: TOYSpacing.md) {
            // Section label - small, understated
            Text("IN PROGRESS\(cards.count > 1 ? " - \(cards.count)" : "")")
                .font(.toyCaption())
                .foregroundColor(.toyTextSecondary)
                .toyLetterSpacing(1.5)
                .padding(.horizontal, TOYSpacing.lg)

            // Card carousel
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
            .frame(height: 180)

            // Minimal page indicators
            if cards.count > 1 {
                HStack(spacing: TOYSpacing.sm) {
                    ForEach(0..<min(cards.count, 3), id: \.self) { index in
                        Rectangle()
                            .fill(index == currentIndex % min(cards.count, 3)
                                  ? Color.toyText
                                  : Color.toyDivider)
                            .frame(width: 24, height: 2)
                    }
                }
                .padding(.horizontal, TOYSpacing.lg)
            }
        }
    }
}

// MARK: - Published Section

private struct PublishedSectionView: View {
    var title: String = "Published"
    let cards: [Card]
    let clipCounts: [UUID: Int]
    var onCardTapped: ((Card) -> Void)? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: TOYSpacing.md) {
            // Section label
            Text(title.uppercased())
                .font(.toyCaption())
                .foregroundColor(.toyTextSecondary)
                .toyLetterSpacing(1.5)
                .padding(.horizontal, TOYSpacing.lg)

            // Horizontal scroll
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: TOYSpacing.md) {
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
                .padding(.horizontal, TOYSpacing.lg)
            }
        }
    }
}

// MARK: - In Progress Card Tile

private struct InProgressCardTile: View {
    let card: Card
    let clipCount: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Director label - understated
            Text("DIRECTOR")
                .font(.toyCaption2())
                .foregroundColor(.toyTextSecondary)
                .toyLetterSpacing(1)

            Spacer()

            // Card info - asymmetric, type-forward
            VStack(alignment: .leading, spacing: TOYSpacing.xs) {
                Text(card.title)
                    .font(.toyTitle2())
                    .foregroundColor(.toyText)
                    .lineLimit(2)

                Text("For \(card.recipientName)")
                    .font(.toySubheadline())
                    .foregroundColor(.toyTextSecondary)
            }

            Spacer()

            // Clip count - bottom, minimal
            Text("\(clipCount)/\(card.maxParticipants) clips")
                .font(.toyCaption())
                .foregroundColor(.toyTextSecondary)
        }
        .padding(TOYSpacing.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(height: 160)
        .background(
            Rectangle()
                .fill(Color.toyBackground)
                .overlay(
                    Rectangle()
                        .stroke(Color.toyDivider, lineWidth: 1)
                )
        )
        .padding(.horizontal, TOYSpacing.lg)
    }
}

// MARK: - Published Card Tile

private struct PublishedCardTile: View {
    let card: Card
    let clipCount: Int

    var body: some View {
        VStack(alignment: .leading, spacing: TOYSpacing.xs) {
            Text(card.title)
                .font(.toyHeadline())
                .foregroundColor(.toyText)
                .lineLimit(2)

            Text("For \(card.recipientName)")
                .font(.toyCaption())
                .foregroundColor(.toyTextSecondary)
                .lineLimit(1)

            Spacer()

            Text("\(clipCount) clips")
                .font(.toyCaption2())
                .foregroundColor(.toyTextSecondary)
        }
        .padding(TOYSpacing.md)
        .frame(width: 140, height: 110, alignment: .leading)
        .background(
            Rectangle()
                .fill(Color.toyBackground)
                .overlay(
                    Rectangle()
                        .stroke(Color.toyDivider, lineWidth: 1)
                )
        )
    }
}
