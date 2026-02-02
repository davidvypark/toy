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
    @State private var showSuccess = false

    private let cardService = CardService()

    var body: some View {
        Group {
            if isLoading {
                loadingView
            } else if let error = error {
                errorView(message: error)
            } else if showSuccess {
                UploadSuccessView()
            } else if let card = card, let participantId = participantId {
                recordingView(card: card, participantId: participantId)
            }
        }
        .task {
            await loadCard()
        }
    }

    // MARK: - Views

    private var loadingView: some View {
        VStack(spacing: 20) {
            ProgressView()
                .scaleEffect(1.5)
            Text("Loading card...")
                .foregroundStyle(.secondary)
        }
    }

    private func errorView(message: String) -> some View {
        VStack(spacing: 20) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 50))
                .foregroundStyle(.orange)

            Text("Unable to Load Card")
                .font(.title2)
                .fontWeight(.semibold)

            Text(message)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            Button("Try Again") {
                isLoading = true
                error = nil
                Task {
                    await loadCard()
                }
            }
            .buttonStyle(.borderedProminent)
        }
    }

    private func recordingView(card: Card, participantId: UUID) -> some View {
        RecordingFlowWrapper(
            card: card,
            participantId: participantId,
            onComplete: {
                showSuccess = true
            }
        )
    }

    // MARK: - Data Loading

    private func loadCard() async {
        do {
            let fetchedCard = try await cardService.fetchCardByShareToken(shareToken: shareToken)

            // Generate a participant ID for this App Clip session
            // In a full implementation, this would create a participant record
            // For now, we use a new UUID for each session
            let newParticipantId = UUID()

            await MainActor.run {
                self.card = fetchedCard
                self.participantId = newParticipantId
                self.isLoading = false
            }

            #if DEBUG
            print("[AppClip] Loaded card: \(fetchedCard.title)")
            print("[AppClip] Participant ID: \(newParticipantId)")
            #endif
        } catch {
            await MainActor.run {
                self.error = "This invite link is invalid or has expired."
                self.isLoading = false
            }

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

        // Initialize with card context
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
                    // Brief delay then show success
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                        onComplete()
                    }
                }
            }
    }
}
