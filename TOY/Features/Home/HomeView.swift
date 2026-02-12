//
//  HomeView.swift
//  TOY
//
//  Created by David Park on 2/1/26.
//

import AVFoundation
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

    // Participant recording flow state
    @State private var participantRecordingCard: Card? = nil

    // Card list state
    @State private var hostedCards: [Card] = []
    @State private var cardClips: [UUID: [Clip]] = [:]
    @State private var cardProfiles: [UUID: [UUID: (displayName: String?, avatarURL: URL?)]] = [:]
    @State private var cardThumbnailURLs: [UUID: [UUID: URL]] = [:]  // cardId -> clipId -> signedURL
    @State private var participatingCardsData: [(card: Card, hasSubmitted: Bool)] = []
    @State private var publishedParticipatingCards: [Card] = []
    @State private var isLoadingCards = false
    @State private var publishedVideoURLCache: [UUID: URL] = [:]
    @State private var prefetchedVideoAssets: [UUID: AVURLAsset] = [:]
    @State private var publishedThumbnailURLCache: [UUID: URL] = [:]
    @State private var pendingCardForRecording: Card?
    @State private var hostRecordingViewModel: RecordingViewModel?
    @State private var participantRecordingViewModel: RecordingViewModel?
    @State private var isPreparingHostCamera = false
    @State private var isPreparingParticipantCamera = false
    @State private var pendingParticipantCard: Card?

    private let cardService = CardService()
    private let storageService = StorageService()

    // Participant cards that need action (not submitted)
    private var participatingCardsNeedingAction: [Card] {
        participatingCardsData.filter { !$0.hasSubmitted }.map(\.card)
    }

    // Participant cards that are done (submitted)
    private var participatingCardsSubmitted: [Card] {
        participatingCardsData.filter { $0.hasSubmitted }.map(\.card)
    }

    // MARK: - Computed Properties

    private var inProgressCards: [Card] {
        hostedCards.filter { $0.status != "published" }
    }

    private var publishedCards: [Card] {
        let hosted = hostedCards.filter { $0.status == "published" }
        let participated = publishedParticipatingCards
        // Combine and sort by published date (newest first)
        return (hosted + participated).sorted {
            ($0.publishedAt ?? .distantPast) > ($1.publishedAt ?? .distantPast)
        }
    }

    private var hasCards: Bool {
        !hostedCards.isEmpty || !participatingCardsData.isEmpty || !publishedParticipatingCards.isEmpty
    }

    var body: some View {
        NavigationStack {
            ZStack {
                // Textured background
                TOYBackground()

                VStack(spacing: 0) {
                    // Settings button bar
                    settingsBar

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
                CardDetailView(
                    card: card,
                    initialClips: cardClips[card.id] ?? [],
                    initialProfiles: cardProfiles[card.id] ?? [:],
                    initialThumbnailURLs: cardThumbnailURLs[card.id] ?? [:],
                    currentUser: viewModel.authState.user,
                    onClipsChanged: { clips in
                        cardClips[card.id] = clips
                    }
                )
                .onDisappear {
                    Task { await loadCardDetails() }
                }
            }
            .sheet(isPresented: $showSettings) {
                SettingsView(authViewModel: viewModel)
            }
            .navigationBarHidden(true)
            .fullScreenCover(item: $publishedCardToPlay) { card in
                PublishedCardPlayerView(
                    card: card,
                    currentUserId: viewModel.authState.user?.id,
                    cachedVideoURL: publishedVideoURLCache[card.id],
                    cachedVideoAsset: prefetchedVideoAssets[card.id],
                    initialThumbnailURL: publishedThumbnailURLCache[card.id],
                    onVideoURLLoaded: { url in
                        publishedVideoURLCache[card.id] = url
                    }
                )
            }
            .sheet(isPresented: $showCreateCard, onDismiss: {
                if let card = pendingCardForRecording {
                    pendingCardForRecording = nil
                    cardInProgress = card
                }
            }) {
                if let user = viewModel.authState.user {
                    CreateCardView(hostId: user.id) { createdCard in
                        pendingCardForRecording = createdCard
                        showCreateCard = false
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
            .fullScreenCover(item: $participantRecordingCard) { card in
                if let vm = participantRecordingViewModel {
                    RecordingView(viewModel: vm)
                        .onDisappear {
                            participantRecordingViewModel = nil
                            Task { await loadCards() }
                        }
                }
            }
            .task {
                await loadCards()
            }
            .onReceive(NotificationCenter.default.publisher(for: .cardSavedForLater)) { notification in
                // Optimistic UI - add card immediately
                if let card = notification.object as? Card {
                    // Only add if not already in list
                    if !participatingCardsData.contains(where: { $0.card.id == card.id }) {
                        participatingCardsData.insert((card: card, hasSubmitted: false), at: 0)
                    }
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: .participantDidRecord)) { notification in
                // Optimistic UI - mark card as submitted immediately
                if let card = notification.object as? Card,
                   let index = participatingCardsData.firstIndex(where: { $0.card.id == card.id }) {
                    participatingCardsData[index] = (card: card, hasSubmitted: true)
                }
            }
        }
    }

    // MARK: - Header

    private var settingsBar: some View {
        HStack {
            Spacer()
            Button {
                showSettings = true
            } label: {
                profileAvatarView
            }
        }
        .padding(.horizontal, TOYSpacing.lg)
    }

    private var titleView: some View {
        Text("Thinking\nOf You")
            .font(.toyDisplaySmall())
            .foregroundColor(.toyText)
            .lineSpacing(-8)
            .padding(.leading, -8) // Slight crop effect
            .padding(.top, TOYSpacing.sm)
            .padding(.bottom, TOYSpacing.sm)
            .padding(.leading, TOYSpacing.lg)
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
        Spacer()
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
                    titleView

                    // Participating cards needing action (top priority - user needs to do something)
                    if !participatingCardsNeedingAction.isEmpty {
                        ParticipantActionSectionView(
                            cards: participatingCardsNeedingAction,
                            isPreparingCamera: isPreparingParticipantCamera,
                            preparingCardId: pendingParticipantCard?.id,
                            onRecordTapped: { card in
                                prepareAndShowParticipantRecording(card: card)
                            }
                        )
                    }

                    // Director's in-progress cards
                    if !inProgressCards.isEmpty {
                        DirectorSectionView(
                            cards: inProgressCards,
                            cardClips: cardClips
                        )
                    }

                    // Participating cards already submitted (done)
                    if !participatingCardsSubmitted.isEmpty {
                        ParticipantSubmittedSectionView(
                            cards: participatingCardsSubmitted
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

        do {
            // Phase 1: Fetch card lists in parallel — UI unblocks immediately after
            async let fetchedHostedCards = cardService.fetchCardsForHost(hostId: user.id)
            async let fetchedParticipatingCards = cardService.fetchParticipatingCards(userId: user.id)
            async let fetchedPublishedParticipating = cardService.fetchPublishedParticipatingCards(userId: user.id)

            hostedCards = try await fetchedHostedCards
            participatingCardsData = try await fetchedParticipatingCards
            publishedParticipatingCards = try await fetchedPublishedParticipating

            // Home screen can render now — show card tiles immediately
            isLoadingCards = false

            // Phase 2: Background detail fetching (non-blocking)
            await loadCardDetails()
        } catch {
            isLoadingCards = false
            #if DEBUG
            Swift.print("Failed to load cards: \(error.localizedDescription)")
            #endif
        }
    }

    private func loadCardDetails() async {
        // Fetch clips, profiles, and thumbnail URLs for hosted cards
        var clipsDict: [UUID: [Clip]] = [:]
        var profilesDict: [UUID: [UUID: (displayName: String?, avatarURL: URL?)]] = [:]
        var thumbnailURLsDict: [UUID: [UUID: URL]] = [:]

        for card in hostedCards {
            do {
                let clips = try await cardService.fetchClipsForCard(cardId: card.id)
                clipsDict[card.id] = clips

                let participantIds = clips.map(\.participantId)
                if !participantIds.isEmpty {
                    let profiles = try await cardService.fetchProfiles(userIds: participantIds)
                    profilesDict[card.id] = profiles
                }

                var clipThumbnailURLs: [UUID: URL] = [:]
                for clip in clips {
                    if let thumbnailPath = clip.thumbnailUrl {
                        if let signedURL = try? await storageService.createSignedURL(path: thumbnailPath) {
                            clipThumbnailURLs[clip.id] = signedURL
                        }
                    }
                }
                thumbnailURLsDict[card.id] = clipThumbnailURLs
            } catch {
                #if DEBUG
                Swift.print("Failed to load details for card \(card.id): \(error)")
                #endif
            }
        }

        cardClips = clipsDict
        cardProfiles = profilesDict
        cardThumbnailURLs = thumbnailURLsDict

        // Prefetch images and video URLs in background
        Task {
            await prefetchThumbnails(clips: clipsDict.values.flatMap { $0 })
            prefetchAvatars(profiles: profilesDict.values.flatMap { $0.values })
        }
        Task {
            await prefetchVideoURLs()
        }
    }

    private func prefetchVideoURLs() async {
        let allPublished = publishedCards
        guard !allPublished.isEmpty else { return }

        for card in allPublished {
            guard let videoPath = card.videoUrl,
                  publishedVideoURLCache[card.id] == nil else { continue }

            do {
                let signedURL = try await storageService.createSignedVideoURL(path: videoPath)
                publishedVideoURLCache[card.id] = signedURL

                // Pre-create AVURLAsset and trigger metadata load to warm the connection
                let asset = AVURLAsset(url: signedURL)
                _ = try? await asset.load(.isPlayable)
                prefetchedVideoAssets[card.id] = asset

                #if DEBUG
                Swift.print("🎬 Prefetched video URL + asset for card \(card.id)")
                #endif
            } catch {
                #if DEBUG
                Swift.print("Failed to prefetch video URL for card \(card.id): \(error)")
                #endif
            }

            // Pre-fetch first clip thumbnail URL (prevents black flash in player view)
            if publishedThumbnailURLCache[card.id] == nil {
                do {
                    let clips = try await cardService.fetchClipsForCard(cardId: card.id)
                    let firstClip = clips.first { $0.participantId == card.hostId } ?? clips.first
                    if let thumbnailPath = firstClip?.thumbnailUrl {
                        let thumbnailURL = try await storageService.createSignedURL(path: thumbnailPath)
                        publishedThumbnailURLCache[card.id] = thumbnailURL
                    }
                } catch {
                    #if DEBUG
                    Swift.print("Failed to prefetch thumbnail for card \(card.id): \(error)")
                    #endif
                }
            }
        }
    }

    /// Prefetches thumbnail images into Kingfisher cache for instant display
    private func prefetchThumbnails(clips: [Clip]) async {
        // Get clips that have pre-generated thumbnails
        let clipsWithThumbnails = clips.filter { $0.thumbnailUrl != nil }
        guard !clipsWithThumbnails.isEmpty else { return }

        // Build resources with signed URLs and stable cache keys
        var resources: [KF.ImageResource] = []
        for clip in clipsWithThumbnails {
            guard let thumbnailPath = clip.thumbnailUrl else { continue }
            do {
                let signedURL = try await storageService.createSignedURL(path: thumbnailPath)
                let resource = KF.ImageResource(downloadURL: signedURL, cacheKey: thumbnailPath)
                resources.append(resource)
            } catch {
                #if DEBUG
                Swift.print("Failed to create signed URL for thumbnail: \(error)")
                #endif
            }
        }

        // Prefetch into Kingfisher cache
        guard !resources.isEmpty else { return }
        let sources: [Source] = resources.map { .network($0) }
        let prefetcher = ImagePrefetcher(sources: sources)
        prefetcher.start()

        #if DEBUG
        Swift.print("🖼️ Prefetching \(resources.count) thumbnails")
        #endif
    }

    /// Prefetches avatar images into Kingfisher cache
    private func prefetchAvatars(profiles: [( displayName: String?, avatarURL: URL?)]) {
        let avatarURLs = profiles.compactMap { $0.avatarURL }
        guard !avatarURLs.isEmpty else { return }

        let prefetcher = ImagePrefetcher(urls: avatarURLs)
        prefetcher.start()

        #if DEBUG
        Swift.print("👤 Prefetching \(avatarURLs.count) avatars")
        #endif
    }

    // MARK: - Camera Pre-warming

    private func prepareAndShowParticipantRecording(card: Card) {
        guard let user = viewModel.authState.user else { return }
        isPreparingParticipantCamera = true
        pendingParticipantCard = card

        let vm = RecordingViewModel(
            cardId: card.id,
            participantId: user.id,
            isHostClip: false
        )
        participantRecordingViewModel = vm

        Task {
            await vm.onAppear()

            // Wait for session to be ready (with timeout)
            for _ in 0..<30 {  // 3 second timeout
                if vm.recorder.isSessionReady {
                    break
                }
                try? await Task.sleep(nanoseconds: 100_000_000)  // 0.1s
            }

            await MainActor.run {
                isPreparingParticipantCamera = false
                pendingParticipantCard = nil
                participantRecordingCard = card
            }
        }
    }
}

// MARK: - Participant Action Section (Needs to Record)

private struct ParticipantActionSectionView: View {
    let cards: [Card]
    var isPreparingCamera: Bool = false
    var preparingCardId: UUID? = nil
    let onRecordTapped: (Card) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: TOYSpacing.md) {
            // Section label with empty checkbox
            HStack(spacing: TOYSpacing.sm) {
                Image(systemName: "square")
                    .font(.system(size: 12))
                Text("NEEDS RECORDING")
                    .toyLetterSpacing(1.5)
            }
            .font(.toyCaption())
            .foregroundColor(.toyText)
            .padding(.horizontal, TOYSpacing.lg)

            ForEach(cards) { card in
                ParticipantActionTile(
                    card: card,
                    isPreparing: isPreparingCamera && preparingCardId == card.id
                ) {
                    onRecordTapped(card)
                }
                .disabled(isPreparingCamera)
                .padding(.horizontal, TOYSpacing.lg)
            }
        }
    }
}

// MARK: - Participant Submitted Section (Done)

private struct ParticipantSubmittedSectionView: View {
    let cards: [Card]

    var body: some View {
        VStack(alignment: .leading, spacing: TOYSpacing.md) {
            // Section label with filled checkbox
            HStack(spacing: TOYSpacing.sm) {
                Image(systemName: "checkmark.square.fill")
                    .font(.system(size: 12))
                Text("SUBMITTED")
                    .toyLetterSpacing(1.5)
            }
            .font(.toyCaption())
            .foregroundColor(.toyTextSecondary)
            .padding(.horizontal, TOYSpacing.lg)

            ForEach(cards) { card in
                ParticipantSubmittedTile(card: card)
                    .padding(.horizontal, TOYSpacing.lg)
            }
        }
    }
}

// MARK: - Director Section (Hosting In Progress Cards)

private struct DirectorSectionView: View {
    let cards: [Card]
    let cardClips: [UUID: [Clip]]

    @State private var currentIndex: Int = 0

    var body: some View {
        VStack(alignment: .leading, spacing: TOYSpacing.md) {
            // Section label - small, understated
            Text("DIRECTING\(cards.count > 1 ? " - \(cards.count)" : "")")
                .font(.toyCaption())
                .foregroundColor(.toyTextSecondary)
                .toyLetterSpacing(1.5)
                .padding(.horizontal, TOYSpacing.lg)

            // Card carousel
            TabView(selection: $currentIndex) {
                ForEach(Array(cards.enumerated()), id: \.element.id) { index, card in
                    NavigationLink(value: card) {
                        DirectorCardTile(
                            card: card,
                            clipCount: cardClips[card.id]?.count
                        )
                    }
                    .buttonStyle(.plain)
                    .tag(index)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .frame(height: 180)

            // Page indicators
            if cards.count > 1 {
                if cards.count <= 7 {
                    HStack(spacing: TOYSpacing.sm) {
                        ForEach(0..<cards.count, id: \.self) { index in
                            Rectangle()
                                .fill(index == currentIndex
                                      ? Color.toyText
                                      : Color.toyDivider)
                                .frame(width: 24, height: 2)
                        }
                    }
                    .padding(.horizontal, TOYSpacing.lg)
                } else {
                    Text("\(currentIndex + 1) of \(cards.count)")
                        .font(.toyCaption())
                        .foregroundColor(.toyTextSecondary)
                        .padding(.horizontal, TOYSpacing.lg)
                }
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

// MARK: - Participant Action Tile (Needs to Record)

private struct ParticipantActionTile: View {
    let card: Card
    var isPreparing: Bool = false
    let onRecordTapped: () -> Void

    var body: some View {
        Button(action: onRecordTapped) {
            HStack(spacing: TOYSpacing.md) {
                // Card info
                VStack(alignment: .leading, spacing: TOYSpacing.xs) {
                    Text(card.title)
                        .font(.toyHeadline())
                        .foregroundColor(.toyBackground)
                        .lineLimit(1)

                    Text("For \(card.recipientName)")
                        .font(.toyCaption())
                        .foregroundColor(.toyBackground.opacity(0.7))
                }

                Spacer()

                // Record CTA
                HStack(spacing: TOYSpacing.xs) {
                    if isPreparing {
                        ProgressView()
                            .tint(.toyBackground)
                            .scaleEffect(0.8)
                        Text("Preparing...")
                            .font(.toyBodyMedium())
                    } else {
                        Image(systemName: "video.fill")
                            .font(.system(size: 14))
                        Text("Record")
                            .font(.toyBodyMedium())
                    }
                }
                .foregroundColor(.toyBackground)
            }
            .padding(TOYSpacing.md)
            .background(Color.toyText)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Participant Submitted Tile (Done)

private struct ParticipantSubmittedTile: View {
    let card: Card

    var body: some View {
        HStack(spacing: TOYSpacing.md) {
            // Checkmark
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 20))
                .foregroundColor(.green)

            // Card info
            VStack(alignment: .leading, spacing: TOYSpacing.xs) {
                Text(card.title)
                    .font(.toyBody())
                    .foregroundColor(.toyText)
                    .lineLimit(1)

                Text("For \(card.recipientName)")
                    .font(.toyCaption())
                    .foregroundColor(.toyTextSecondary)
            }

            Spacer()

            Text("Submitted")
                .font(.toyCaption())
                .foregroundColor(.toyTextSecondary)
        }
        .padding(TOYSpacing.md)
        .background(
            Rectangle()
                .stroke(Color.toyDivider, lineWidth: 1)
        )
    }
}

// MARK: - Director Card Tile

private struct DirectorCardTile: View {
    let card: Card
    let clipCount: Int?

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

            // Clip count - bottom, minimal (hidden until data loads)
            if let clipCount {
                Text("\(clipCount) clip\(clipCount == 1 ? "" : "s") submitted")
                    .font(.toyCaption())
                    .foregroundColor(.toyTextSecondary)
            }
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
