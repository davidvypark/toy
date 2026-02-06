//
//  RecordingViewModel.swift
//  TOYShared
//
//  ViewModel for the recording screen.
//

import AVFoundation
import Combine
import SwiftUI

#if canImport(UIKit)
import UIKit
#endif

/// ViewModel for the recording screen.
@MainActor
public final class RecordingViewModel: ObservableObject {
    // MARK: - Published State
    
    @Published public var permissionStatus: PermissionStatus = .unknown
    @Published public var showPreview: Bool = false
    @Published public var uploadState: UploadState? = nil
    @Published public var uploadedPath: String? = nil
    @Published public var createdClip: Clip? = nil
    
    // MARK: - Card Context
    
    public var cardId: UUID?
    public var participantId: UUID?
    public var isHostClip: Bool
    
    /// Optional callback when a participant (non-host) clip is successfully uploaded.
    /// Used by the main app to send push notifications to the director.
    public var onParticipantClipUploaded: ((Card) async -> Void)?

    /// Callback when a clip record is created on the server.
    /// Used to optimistically update the parent view before dismiss.
    public var onClipCreated: ((Clip) -> Void)?
    
    // MARK: - Dependencies
    
    public let recorder = VideoRecorder()
    private var cancellables = Set<AnyCancellable>()
    private let storageService = StorageService()
    private let cardService = CardService()
    
    // MARK: - Upload State
    
    private var currentVideoURL: URL?
    private var uploadRetryCount = 0
    private let maxRetries = 3
    
    // MARK: - Permission Status
    
    public enum PermissionStatus {
        case unknown
        case granted
        case denied
        case restricted
    }
    
    // MARK: - Initialization
    
    public init(cardId: UUID? = nil, participantId: UUID? = nil, isHostClip: Bool = false) {
        self.cardId = cardId
        self.participantId = participantId
        self.isHostClip = isHostClip
        
        // Forward changes from nested ObservableObject to trigger view updates
        recorder.objectWillChange
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.objectWillChange.send()
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Lifecycle
    
    public func onAppear() async {
        await checkAndRequestPermissions()
    }
    
    public func onDisappear() {
        recorder.teardownSession()
    }
    
    // MARK: - Permissions
    
    private func checkAndRequestPermissions() async {
        let cameraStatus = AVCaptureDevice.authorizationStatus(for: .video)
        let micStatus = AVCaptureDevice.authorizationStatus(for: .audio)
        
        // Check if already granted
        if cameraStatus == .authorized && micStatus == .authorized {
            permissionStatus = .granted
            await setupRecorder()
            return
        }
        
        // Check if restricted or denied
        if cameraStatus == .restricted || micStatus == .restricted {
            permissionStatus = .restricted
            return
        }
        
        if cameraStatus == .denied || micStatus == .denied {
            permissionStatus = .denied
            return
        }
        
        // Request permissions
        var cameraGranted = cameraStatus == .authorized
        var micGranted = micStatus == .authorized
        
        if cameraStatus == .notDetermined {
            cameraGranted = await AVCaptureDevice.requestAccess(for: .video)
        }
        
        if micStatus == .notDetermined {
            micGranted = await AVCaptureDevice.requestAccess(for: .audio)
        }
        
        if cameraGranted && micGranted {
            permissionStatus = .granted
            await setupRecorder()
        } else {
            permissionStatus = .denied
        }
    }
    
    private func setupRecorder() async {
        do {
            try await recorder.setupSession()
        } catch {
            // Handle setup error
            print("Failed to setup recorder: \(error)")
        }
    }
    
    // MARK: - Actions
    
    public func startRecording() {
        recorder.startRecording()
    }
    
    public func stopRecording() {
        recorder.stopRecording()
    }
    
    public func finishRecording() async {
        do {
            try await recorder.finishAndMerge()
            showPreview = true
        } catch {
            // Error is captured in recorder.state
        }
    }
    
    public func startOver() {
        showPreview = false
        recorder.startOver()
    }
    
    public func confirmVideo() {
        guard case .completed(let url) = recorder.state else { return }
        currentVideoURL = url
        uploadRetryCount = 0
        uploadState = .uploading
        Task {
            await performUpload()
        }
    }
    
    private func performUpload() async {
        guard let videoURL = currentVideoURL else {
            uploadState = .failed(error: "No video to upload")
            return
        }
        
        let clipId = UUID()
        
        do {
            // Calculate video duration before upload
            let duration = await getVideoDuration(url: videoURL)
#if DEBUG
            print("[DURATION DEBUG] Video URL: \(videoURL)")
            print("[DURATION DEBUG] Calculated duration: \(String(describing: duration))")
#endif
            
            // Generate thumbnail from local video file (fast - no network)
            let thumbnailData = await generateThumbnail(from: videoURL)
#if DEBUG
            if let data = thumbnailData {
                print("[THUMBNAIL] Generated thumbnail: \(data.count / 1024) KB")
            } else {
                print("[THUMBNAIL] Failed to generate thumbnail")
            }
#endif
            
            // Upload video
            let path = try await storageService.uploadVideo(fileURL: videoURL, clipId: clipId)
            uploadedPath = path
            print("Upload successful: \(path)")

            // Upload thumbnail (best-effort, don't fail if thumbnail upload fails)
            var thumbnailPath: String? = nil
            if let thumbnailData {
                do {
                    thumbnailPath = try await storageService.uploadThumbnail(data: thumbnailData, clipId: clipId)
#if DEBUG
                    print("[THUMBNAIL] Uploaded thumbnail: \(thumbnailPath ?? "nil")")
#endif
                } catch {
#if DEBUG
                    print("[THUMBNAIL] Failed to upload thumbnail: \(error)")
#endif
                }
            }

            // Create clip record — must succeed for upload to count
            if let cardId = cardId, let participantId = participantId {
                // Host clip = orderPosition 0 (appears first in montage)
                let orderPosition = isHostClip ? 0 : 1
#if DEBUG
                print("[DURATION DEBUG] Creating clip with duration: \(String(describing: duration))")
                print("[DURATION DEBUG] cardId: \(cardId), participantId: \(participantId)")
#endif
                let clip = try await cardService.createClip(
                    cardId: cardId,
                    participantId: participantId,
                    videoUrl: path,
                    thumbnailUrl: thumbnailPath,
                    durationSeconds: duration,
                    orderPosition: orderPosition,
                    status: "uploaded"
                )
                createdClip = clip
                onClipCreated?(clip)
#if DEBUG
                print("[DURATION DEBUG] Created clip, returned duration: \(String(describing: clip.durationSeconds))")
#endif

                // If host clip, update card status to 'collecting'
                if isHostClip {
                    try await cardService.updateCardStatus(cardId: cardId, status: "collecting")
                } else if let callback = onParticipantClipUploaded {
                    // Notify director of new participant clip (main app provides this callback)
                    if let card = try? await cardService.fetchCardById(cardId: cardId) {
                        await callback(card)
                    }
                }
            } else {
                #if DEBUG
                print("[DURATION DEBUG] No card context - cardId: \(String(describing: cardId)), participantId: \(String(describing: participantId))")
                #endif
            }

            uploadState = .success(storagePath: path)
        } catch {
            let message = (error as? UploadError)?.errorDescription ?? error.localizedDescription
            uploadState = .failed(error: message)
            print("Upload failed: \(error)")
        }
    }

    /// Gets the duration of a video file in seconds.
    /// - Parameter url: The local URL of the video file
    /// - Returns: Duration as Decimal, or nil if cannot be determined
    private func getVideoDuration(url: URL) async -> Decimal? {
        let asset = AVAsset(url: url)
        do {
            let duration = try await asset.load(.duration)
            let seconds = CMTimeGetSeconds(duration)
            #if DEBUG
            print("[DURATION DEBUG] Raw CMTime: \(duration)")
            print("[DURATION DEBUG] Seconds from CMTime: \(seconds)")
            print("[DURATION DEBUG] isFinite: \(seconds.isFinite), > 0: \(seconds > 0)")
            #endif
            guard seconds.isFinite && seconds > 0 else {
                #if DEBUG
                print("[DURATION DEBUG] Duration check failed, returning nil")
                #endif
                return nil
            }
            // Round to 1 decimal place for cleaner display
            let rounded = Double(round(seconds * 10) / 10)
            let decimal = Decimal(rounded)
            #if DEBUG
            print("[DURATION DEBUG] Rounded: \(rounded), Decimal: \(decimal)")
            #endif
            return decimal
        } catch {
            print("[DURATION DEBUG] Failed to load video duration: \(error)")
            return nil
        }
    }

    /// Generates a thumbnail image from a local video file.
    /// - Parameter videoURL: The local URL of the video file
    /// - Returns: JPEG data for the thumbnail, or nil if generation fails
    private func generateThumbnail(from videoURL: URL) async -> Data? {
        #if canImport(UIKit)
        let asset = AVAsset(url: videoURL)
        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        generator.maximumSize = CGSize(width: 150, height: 200)

        let time = CMTime(seconds: 1.5, preferredTimescale: 600)

        do {
            let cgImage = try await generator.image(at: time).image
            let uiImage = UIImage(cgImage: cgImage)
            return uiImage.jpegData(compressionQuality: 0.7)
        } catch {
            #if DEBUG
            print("[THUMBNAIL] Failed to generate thumbnail: \(error)")
            #endif
            return nil
        }
        #else
        return nil
        #endif
    }

    public func retryUpload() {
        guard uploadRetryCount < maxRetries else {
            uploadState = .failed(error: "Maximum retries exceeded")
            return
        }

        uploadRetryCount += 1
        let delay = pow(2.0, Double(uploadRetryCount)) // 2s, 4s, 8s

        uploadState = .uploading
        Task {
            try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            await performUpload()
        }
    }

    /// Dismisses the upload overlay. Returns true if upload was successful (caller should navigate away).
    @discardableResult
    public func dismissUpload() -> Bool {
        let wasSuccess: Bool
        if case .success = uploadState {
            wasSuccess = true
        } else {
            wasSuccess = false
        }
        uploadState = nil
        return wasSuccess
    }

    // MARK: - Computed Properties

    public var canFinish: Bool {
        recorder.state.hasContent && !recorder.state.isRecording
    }
}
