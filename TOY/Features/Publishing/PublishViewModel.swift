import AVFoundation
import Foundation
import Observation
import TOYShared

/// State of the publishing process
enum PublishState: Equatable {
    case idle
    case generating(progress: Float, phase: String)
    case uploading(progress: Float)
    case publishing
    case success(videoURL: URL)
    case failed(error: String)
}

@Observable
@MainActor
final class PublishViewModel {
    // MARK: - Published State
    var state: PublishState = .idle
    var montageURL: URL?

    // MARK: - Dependencies
    private let montageService = MontageService()
    private let storageService = StorageService()
    private let cardService = CardService()

    // MARK: - Public Methods

    /// Generates the montage preview (without uploading)
    func generatePreview(card: Card, clips: [Clip]) async {
        guard state == .idle || state.isFailed else { return }

        state = .generating(progress: 0, phase: "Preparing...")

        do {
            let url = try await montageService.generateMontage(
                clips: clips,
                hostId: card.hostId
            ) { [weak self] progress in
                Task { @MainActor in
                    let phaseText: String
                    switch progress.phase {
                    case .downloading(let current, let total):
                        phaseText = "Downloading clip \(current + 1) of \(total)..."
                    case .stitching:
                        phaseText = "Stitching video..."
                    }
                    self?.state = .generating(progress: progress.overallProgress, phase: phaseText)
                }
            }

            montageURL = url
            state = .idle

            #if DEBUG
            print("Preview generated: \(url)")
            #endif
        } catch {
            state = .failed(error: error.localizedDescription)
        }
    }

    /// Publishes the card: uploads montage and updates card status
    func publish(card: Card) async {
        guard let montageURL, state == .idle else { return }

        state = .uploading(progress: 0)

        do {
            // Upload montage to videos bucket
            let storagePath = try await storageService.uploadMontage(
                fileURL: montageURL,
                cardId: card.id
            )

            state = .publishing

            // Update card status
            try await cardService.publishCard(cardId: card.id, videoUrl: storagePath)

            // Get signed URL for preview
            let signedURL = try await storageService.createSignedVideoURL(path: storagePath)

            state = .success(videoURL: signedURL)

            // Cleanup local file
            try? FileManager.default.removeItem(at: montageURL)
            self.montageURL = nil

            #if DEBUG
            print("Card published! Video URL: \(signedURL)")
            #endif
        } catch {
            state = .failed(error: error.localizedDescription)
        }
    }

    /// Resets state to try again
    func reset() {
        state = .idle
        // Keep montageURL if it exists so user can retry publish
    }

    /// Cleans up any temporary files
    func cleanup() {
        if let url = montageURL {
            try? FileManager.default.removeItem(at: url)
            montageURL = nil
        }
    }
}

// MARK: - State Helpers

extension PublishState {
    var isFailed: Bool {
        if case .failed = self { return true }
        return false
    }

    var isInProgress: Bool {
        switch self {
        case .generating, .uploading, .publishing:
            return true
        default:
            return false
        }
    }
}
