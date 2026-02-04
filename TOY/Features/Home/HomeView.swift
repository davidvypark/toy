//
//  HomeView.swift
//  TOY
//
//  Created by David Park on 2/1/26.
//

import Kingfisher
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
    @State private var cardClips: [UUID: [Clip]] = [:]
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
                CardDetailView(card: card, initialClips: cardClips[card.id] ?? [])
            }
            .sheet(isPresented: $showSettings) {
                SettingsView(authViewModel: viewModel)
            }
            .navigationBarHidden(true)
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
                    profileAvatarView
                }
            }
            .padding(.horizontal, TOYSpacing.lg)

            // Cropped title - extends beyond leading edge
            Text("Thinking\nOf You")
                .font(.toyDisplaySmall())
                .foregroundColor(.toyText)
                .lineSpacing(-8)
                .padding(.leading, -8) // Slight crop effect
                .padding(.top, TOYSpacing.sm)
                .padding(.bottom, TOYSpacing.sm)
                .padding(.leading, TOYSpacing.lg)
        }
    }

    @ViewBuilder
    private var profileAvatarView: some View {
        // Prefer pending image for optimistic UI
        if let pendingImage = viewModel.pendingAvatarImage {
            Image(uiImage: pendingImage)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: 28, height: 28)
                .clipShape(Circle())
        } else if let user = viewModel.authState.user, let avatarURL = user.avatarURL {
            KFImage(avatarURL)
                .placeholder {
                    Image(systemName: "person.crop.circle")
                        .font(.system(size: 24, weight: .light))
                        .foregroundColor(.toyTextSecondary)
                }
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: 28, height: 28)
                .clipShape(Circle())
        } else {
            Image(systemName: "person.crop.circle")
                .font(.system(size: 24, weight: .light))
                .foregroundColor(.toyTextSecondary)
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
                VStack(alignment: .leading, spacing: TOYSpacing.lg) {
                    // In Progress section
                    if !inProgressCards.isEmpty {
                        InProgressSectionView(
                            cards: inProgressCards,
                            cardClips: cardClips
                        )
                    }

                    // Published section
                    if !publishedCards.isEmpty {
                        PublishedSectionView(
                            cards: publishedCards,
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
                            onCardTapped: { card in
                                publishedCardToPlay = card
                            }
                        )
                    }
                }
                .padding(.vertical, TOYSpacing.sm)
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

            var clipsDict: [UUID: [Clip]] = [:]
            for card in hostedCards {
                let clips = try await cardService.fetchClipsForCard(cardId: card.id)
                clipsDict[card.id] = clips
            }
            cardClips = clipsDict
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
    let cardClips: [UUID: [Clip]]

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
                            clipCount: cardClips[card.id]?.count ?? 0
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
    var onCardTapped: ((Card) -> Void)? = nil

    private let columns = [
        GridItem(.flexible(), spacing: TOYSpacing.md),
        GridItem(.flexible(), spacing: TOYSpacing.md)
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: TOYSpacing.md) {
            // Section label
            Text(title.uppercased())
                .font(.toyCaption())
                .foregroundColor(.toyTextSecondary)
                .toyLetterSpacing(1.5)
                .padding(.horizontal, TOYSpacing.lg)

            // 2-column grid
            LazyVGrid(columns: columns, spacing: TOYSpacing.md) {
                ForEach(cards) { card in
                    Button {
                        onCardTapped?(card)
                    } label: {
                        PublishedCardTile(card: card)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, TOYSpacing.lg)
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
            Text("\(clipCount) clip\(clipCount == 1 ? "" : "s") submitted")
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

    private var publishedDateText: String {
        guard let publishedAt = card.publishedAt else { return "" }
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: publishedAt)
    }

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

            Text(publishedDateText)
                .font(.toyCaption2())
                .foregroundColor(.toyTextSecondary)
        }
        .padding(TOYSpacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(height: 110)
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
